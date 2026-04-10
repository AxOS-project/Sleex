#include "ExtCaptureItem.hpp"
#include "GbmBuffer.hpp"

#include "ext-image-copy-capture-v1-client-protocol.h"
#include "ext-image-capture-source-v1-client-protocol.h"
#include "ext-foreign-toplevel-list-v1-client-protocol.h"
#include "linux-dmabuf-unstable-v1-client-protocol.h"

#include <QGuiApplication>
#include <QQuickWindow>
#include <QSGSimpleTextureNode>
#include <QSGTexture>
#include <QMutexLocker>
#include <QDebug>
#include <QTimer>

#include <qpa/qplatformnativeinterface.h>

#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>

#include <drm_fourcc.h>
#include <xf86drm.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <qt6/QtQuick/qsgtexture_platform.h>

static const wl_registry_listener s_registryListener = {
    .global        = &ExtCaptureItem::onRegistryGlobal,
    .global_remove = &ExtCaptureItem::onRegistryGlobalRemove,
};

static const ext_foreign_toplevel_list_v1_listener s_toplevelListListener = {
    .toplevel = &ExtCaptureItem::onToplevelListToplevel,
    .finished = &ExtCaptureItem::onToplevelListFinished,
};

static const ext_foreign_toplevel_handle_v1_listener s_toplevelHandleListener = {
    .closed     = &ExtCaptureItem::onToplevelClosed,
    .done       = &ExtCaptureItem::onToplevelDone,
    .title      = &ExtCaptureItem::onToplevelTitle,
    .app_id     = &ExtCaptureItem::onToplevelAppId,
    .identifier = &ExtCaptureItem::onToplevelIdentifier,
};

static const ext_image_copy_capture_session_v1_listener s_sessionListener = {
    .buffer_size   = &ExtCaptureItem::onSessionBufferSize,
    .shm_format    = &ExtCaptureItem::onSessionShmFormat,
    .dmabuf_device = &ExtCaptureItem::onSessionDmabufDevice,
    .dmabuf_format = &ExtCaptureItem::onSessionDmabufFormat,
    .done          = &ExtCaptureItem::onSessionDone,
    .stopped       = &ExtCaptureItem::onSessionStopped,
};

static const ext_image_copy_capture_frame_v1_listener s_frameListener = {
    .transform         = &ExtCaptureItem::onFrameTransform,
    .damage            = &ExtCaptureItem::onFrameDamage,
    .presentation_time = &ExtCaptureItem::onFramePresentationTime,
    .ready             = &ExtCaptureItem::onFrameReady,
    .failed            = &ExtCaptureItem::onFrameFailed,
};

ExtCaptureItem::ExtCaptureItem(QQuickItem* parent) : QQuickItem(parent)
{
    setFlag(ItemHasContents, true);
}

ExtCaptureItem::~ExtCaptureItem()
{
    stopCapture();

    // Destroy protocol objects
    if (m_toplevelList) ext_foreign_toplevel_list_v1_destroy(m_toplevelList);
    if (m_sourceManager) ext_foreign_toplevel_image_capture_source_manager_v1_destroy(m_sourceManager);
    if (m_captureManager) ext_image_copy_capture_manager_v1_destroy(m_captureManager);
    if (m_dmabuf) zwp_linux_dmabuf_v1_destroy(m_dmabuf);

    // release GBM buffers before the device
    for (auto& buf : m_buffers) buf.reset();

    if (m_gbmDev) gbm_device_destroy(m_gbmDev);
    if (m_drmFd >= 0) close(m_drmFd);
}

void ExtCaptureItem::componentComplete()
{
    QQuickItem::componentComplete();
    initWayland();
    initGbm();
    if (m_active) tryStartCapture();
}

void ExtCaptureItem::setActive(bool active)
{
    if (m_active == active) return;
    m_active = active;
    emit activeChanged();

    if (m_waylandReady) {
        if (active)  tryStartCapture();
        else         stopCapture();
    }
}

void ExtCaptureItem::initWayland()
{
    // QPlatformNativeInterface is available on all Qt 5/6 Wayland QPA backends
    // without pulling in any QtWaylandClient private headers.
    QPlatformNativeInterface* ni = qGuiApp->platformNativeInterface();
    if (!ni) {
        qWarning() << "[ExtCapture] Not running on a Wayland QPA backend";
        return;
    }
    m_display = static_cast<wl_display*>(
        ni->nativeResourceForIntegration(QByteArrayLiteral("wl_display")));
    if (!m_display) {
        qWarning() << "[ExtCapture] wl_display not available via QPlatformNativeInterface";
        return;
    }

    // registry
    m_registry = wl_display_get_registry(m_display);
    wl_registry_add_listener(m_registry, &s_registryListener, this);

    // Blocking roundtrip so that all globals are bound synchronously before
    // we proceed.  A production implementation may prefer a deferred approach.
    wl_display_roundtrip(m_display);
    wl_display_roundtrip(m_display); // second roundtrip picks up any late events

    m_waylandReady = true;
}

// Sometimes, even I don't understand my own code
void ExtCaptureItem::onRegistryGlobal(void* data, wl_registry* registry, uint32_t name, const char* iface, uint32_t version)
{
    auto* self = static_cast<ExtCaptureItem*>(data);

    if (strcmp(iface, ext_image_copy_capture_manager_v1_interface.name) == 0) {
        self->m_captureManager = static_cast<ext_image_copy_capture_manager_v1*>(wl_registry_bind(registry, name, &ext_image_copy_capture_manager_v1_interface, qMin(version, 1u)));
    }
    else if (strcmp(iface, ext_foreign_toplevel_image_capture_source_manager_v1_interface.name) == 0) {
        self->m_sourceManager = static_cast<ext_foreign_toplevel_image_capture_source_manager_v1*>( wl_registry_bind(registry, name, &ext_foreign_toplevel_image_capture_source_manager_v1_interface, qMin(version, 1u)));
    }
    else if (strcmp(iface, ext_foreign_toplevel_list_v1_interface.name) == 0) {
        self->m_toplevelList = static_cast<ext_foreign_toplevel_list_v1*>(wl_registry_bind(registry, name, &ext_foreign_toplevel_list_v1_interface, qMin(version, 1u)));
        ext_foreign_toplevel_list_v1_add_listener(self->m_toplevelList, &s_toplevelListListener, self);
    }
    else if (strcmp(iface, zwp_linux_dmabuf_v1_interface.name) == 0) {
        if (version >= 3) {
            self->m_dmabuf = static_cast<zwp_linux_dmabuf_v1*>(wl_registry_bind(registry, name, &zwp_linux_dmabuf_v1_interface, qMin(version, 4u)));
        }
    }
}

void ExtCaptureItem::onRegistryGlobalRemove(void* /*data*/, wl_registry*, uint32_t /*name*/) {}


void ExtCaptureItem::onToplevelListToplevel(void* data, ext_foreign_toplevel_list_v1*, ext_foreign_toplevel_handle_v1* handle)
{
    auto* self = static_cast<ExtCaptureItem*>(data);
    ToplevelInfo info;
    info.handle = handle;
    self->m_pendingToplevels.append(info);
    ext_foreign_toplevel_handle_v1_add_listener(handle, &s_toplevelHandleListener, self);
}

void ExtCaptureItem::onToplevelListFinished(void* data, ext_foreign_toplevel_list_v1*) {
    // The list won't send more toplevels.  We're watching ongoing events via
    // onToplevelDone / onToplevelClosed.
    Q_UNUSED(data)
}

void ExtCaptureItem::onToplevelAppId(void* data, ext_foreign_toplevel_handle_v1* handle, const char* app_id)
{
    auto* self = static_cast<ExtCaptureItem*>(data);
    for (auto& t : self->m_pendingToplevels) {
        if (t.handle == handle) {
            t.appId = QString::fromUtf8(app_id);
            return;
        }
    }
}

void ExtCaptureItem::onToplevelTitle(void* data, ext_foreign_toplevel_handle_v1* handle, const char* title)
{
    auto* self = static_cast<ExtCaptureItem*>(data);
    for (auto& t : self->m_pendingToplevels) {
        if (t.handle == handle) {
            t.title = QString::fromUtf8(title);
            emit self->windowsChanged();
            return;
        }
    }
}

void ExtCaptureItem::onToplevelIdentifier(void* data, ext_foreign_toplevel_handle_v1* handle, const char* identifier)
{
    auto* self = static_cast<ExtCaptureItem*>(data);
    for (auto& t : self->m_pendingToplevels) {
        if (t.handle == handle) {
            t.identifier = QString::fromUtf8(identifier);
            emit self->windowsChanged();
            return;
        }
    }
}

void ExtCaptureItem::setWindowId(const QString& id)
{
    if (m_windowId == id) return;
    m_windowId = id;
    emit windowIdChanged();

    if (m_waylandReady) {
        stopCapture();
        m_targetHandle = nullptr;

        for (const auto& t : m_pendingToplevels) {
            if (t.identifier == m_windowId) {
                m_targetHandle = t.handle;
                break;
            }
        }

        if (m_active && m_targetHandle) tryStartCapture();
    }
}

void ExtCaptureItem::onToplevelDone(void* data, ext_foreign_toplevel_handle_v1* handle)
{
    auto* self = static_cast<ExtCaptureItem*>(data);
    for (auto& t : self->m_pendingToplevels) {
        if (t.handle == handle && !t.matched) {
            if (!self->m_windowId.isEmpty() && t.identifier == self->m_windowId) {
                t.matched = true;
                self->m_targetHandle = handle;
                if (self->m_active && self->m_waylandReady)
                    self->tryStartCapture();
            }
            return;
        }
    }
}

void ExtCaptureItem::onToplevelClosed(void* data, ext_foreign_toplevel_handle_v1* handle)
{
    auto* self = static_cast<ExtCaptureItem*>(data);
    if (self->m_targetHandle == handle) {
        self->stopCapture();
        self->m_targetHandle = nullptr;
    }
    // Remove from pending list
    for (int i = self->m_pendingToplevels.size() - 1; i >= 0; --i) {
        if (self->m_pendingToplevels[i].handle == handle) {
            self->m_pendingToplevels.removeAt(i);
        }
    }
}

void ExtCaptureItem::tryStartCapture()
{
    if (!m_captureManager || !m_sourceManager || !m_targetHandle) return;
    if (m_session) return; // already running

    m_source = ext_foreign_toplevel_image_capture_source_manager_v1_create_source(m_sourceManager, m_targetHandle);

    m_session = ext_image_copy_capture_manager_v1_create_session(m_captureManager, m_source, 0u);

    ext_image_copy_capture_session_v1_add_listener(m_session, &s_sessionListener, this);

    // The session will fire buffer_size + dmabuf_format* + done events in a batch. Flush and dispatch.
    wl_display_flush(m_display);
}

void ExtCaptureItem::stopCapture()
{
    if (m_frame) {
        ext_image_copy_capture_frame_v1_destroy(m_frame);
        m_frame = nullptr;
    }
    if (m_session) {
        ext_image_copy_capture_session_v1_destroy(m_session);
        m_session = nullptr;
    }
    if (m_source) {
        ext_image_capture_source_v1_destroy(m_source);
        m_source = nullptr;
    }
    m_formatsReceived = false;

    if (m_running) {
        m_running = false;
        emit runningChanged();
    }
}

void ExtCaptureItem::onSessionBufferSize(void* data, ext_image_copy_capture_session_v1*, uint32_t w, uint32_t h)
{
    auto* self = static_cast<ExtCaptureItem*>(data);
    self->m_captureSize = QSize(static_cast<int>(w), static_cast<int>(h));
}

void ExtCaptureItem::onSessionShmFormat(void*, ext_image_copy_capture_session_v1*, uint32_t) {
    // We only use DMA-BUF. ignore SHM formats.
}

void ExtCaptureItem::onSessionDmabufDevice(void*, ext_image_copy_capture_session_v1*, wl_array* /*device*/) {
    // The device hint is optional; we already opened the render node.
}

void ExtCaptureItem::onSessionDmabufFormat(void* data, ext_image_copy_capture_session_v1*, uint32_t fmt, wl_array* modifiers)
{
    auto* self = static_cast<ExtCaptureItem*>(data);
    const auto* modifierValues = static_cast<const uint64_t*>(modifiers->data);
    const int modifierCount = static_cast<int>(modifiers->size / sizeof(uint64_t));
    for (int i = 0; i < modifierCount; ++i) {
        self->m_dmabufFormats.append({ fmt, modifierValues[i] });
    }
}

void ExtCaptureItem::onSessionDone(void* data, ext_image_copy_capture_session_v1*)
{
    // All constraints received.  Allocate buffers and request the first frame.
    auto* self = static_cast<ExtCaptureItem*>(data);
    self->m_formatsReceived = true;
    self->allocateBuffers();
    self->requestNextFrame();
}

void ExtCaptureItem::onSessionStopped(void* data, ext_image_copy_capture_session_v1*)
{
    auto* self = static_cast<ExtCaptureItem*>(data);
    qWarning() << "[ExtCapture] Session stopped by compositor";
    self->stopCapture();
}

void ExtCaptureItem::initGbm()
{
    // Open the first available render node
    for (int i = 128; i < 138 && m_drmFd < 0; ++i) {
        QString path = QStringLiteral("/dev/dri/renderD%1").arg(i);
        m_drmFd = open(path.toLocal8Bit().constData(), O_RDWR | O_CLOEXEC);
    }
    if (m_drmFd < 0) {
        qWarning() << "[ExtCapture] Failed to open DRM render node";
        return;
    }
    m_gbmDev = gbm_create_device(m_drmFd);
    if (!m_gbmDev) {
        qWarning() << "[ExtCapture] gbm_create_device failed";
        close(m_drmFd);
        m_drmFd = -1;
    }
}

void ExtCaptureItem::allocateBuffers()
{
    if (!m_gbmDev || m_captureSize.isEmpty()) return;

    uint32_t fmt      = DRM_FORMAT_XRGB8888;
    uint64_t modifier = DRM_FORMAT_MOD_LINEAR;

    for (const auto& fi : m_dmabufFormats) {
        if (fi.format == DRM_FORMAT_XRGB8888) {
            fmt      = fi.format;
            modifier = fi.modifier;
            break;
        }
    }

    for (int i = 0; i < POOL; ++i) {
        auto buf = std::make_unique<GbmBuffer>();
        if (!buf->allocate(m_gbmDev,
                           m_captureSize.width(),
                           m_captureSize.height(),
                           fmt, modifier)) {
            qWarning() << "[ExtCapture] Failed to allocate GBM buffer" << i;
            return;
        }
        createWaylandBuffer(buf.get());
        m_buffers[i] = std::move(buf);
    }
}

void ExtCaptureItem::createWaylandBuffer(GbmBuffer* buf)
{
    if (!m_dmabuf) return;

    zwp_linux_buffer_params_v1* params = zwp_linux_dmabuf_v1_create_params(m_dmabuf);

    // Add the single plane
    zwp_linux_buffer_params_v1_add(params,
                                   buf->fd(),
                                   0,                  // plane index
                                   buf->offset(),
                                   buf->stride(),
                                   static_cast<uint32_t>(buf->modifier() >> 32),
                                   static_cast<uint32_t>(buf->modifier() & 0xFFFFFFFF)
                                );

    wl_buffer* wlBuf = zwp_linux_buffer_params_v1_create_immed(params, buf->width(), buf->height(), buf->format(), 0 /* flags */);

    zwp_linux_buffer_params_v1_destroy(params);
    buf->setWaylandBuffer(wlBuf);
}

GbmBuffer* ExtCaptureItem::acquireCaptureBuffer()
{
    // Return a buffer that Qt is not currently reading from.
    for (int i = 0; i < POOL; ++i) {
        if (m_buffers[i] && !m_buffers[i]->inUse) {
            m_captureIdx = i;
            return m_buffers[i].get();
        }
    }
    return nullptr;
}

void ExtCaptureItem::requestNextFrame() {
    if (!m_session || m_frame || !m_formatsReceived) return;

    int target = -1;
    for (int i = 0; i < POOL; ++i) {
        if (!m_buffers[i]->inUse && !m_buffers[i]->ready && !m_buffers[i]->isCapturing) {
            target = i;
            break;
        }
    }

    if (target == -1) return;

    m_captureIdx = target;
    m_buffers[target]->isCapturing = true;
    
    m_frame = ext_image_copy_capture_session_v1_create_frame(m_session);
    ext_image_copy_capture_frame_v1_add_listener(m_frame, &s_frameListener, this);
    ext_image_copy_capture_frame_v1_attach_buffer(m_frame, m_buffers[target]->waylandBuffer());
    ext_image_copy_capture_frame_v1_capture(m_frame);
    wl_display_flush(m_display);
}

void ExtCaptureItem::onFrameTransform(void*, ext_image_copy_capture_frame_v1*, uint32_t) {}

void ExtCaptureItem::onFrameDamage(void*, ext_image_copy_capture_frame_v1*, int32_t, int32_t, int32_t, int32_t) {}

void ExtCaptureItem::onFramePresentationTime(void*, ext_image_copy_capture_frame_v1*, uint32_t, uint32_t, uint32_t) {}

void ExtCaptureItem::onFrameReady(void* data, ext_image_copy_capture_frame_v1* frame) {
    auto* self = static_cast<ExtCaptureItem*>(data);
    int idx = self->m_captureIdx;

    ext_image_copy_capture_frame_v1_destroy(frame);
    self->m_frame = nullptr;

    self->m_buffers[idx]->isCapturing = false;
    self->m_buffers[idx]->ready = true;

    {
        QMutexLocker lk(&self->m_sgMutex);
        self->m_pendingIdx = idx;
    }

    self->update();
}

void ExtCaptureItem::onFrameFailed(void* data, ext_image_copy_capture_frame_v1* frame, uint32_t reason)
{
    auto* self = static_cast<ExtCaptureItem*>(data);
    qWarning() << "[ExtCapture] Frame capture failed, reason:" << reason;
    ext_image_copy_capture_frame_v1_destroy(frame);
    self->m_frame = nullptr;
    // Retry after a brief pause (avoid tight loop on persistent error)
    QTimer::singleShot(200, self, &ExtCaptureItem::requestNextFrame);
}

QSGNode* ExtCaptureItem::updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*)
{
    auto* node = static_cast<QSGSimpleTextureNode*>(oldNode);
    int readyIdx = -1;

    {
        QMutexLocker lk(&m_sgMutex);
        readyIdx = m_pendingIdx;
        m_pendingBuffer = nullptr;
    }

    if (m_displayIdx >= 0) {
        m_buffers[m_displayIdx]->inUse = false;
    }

    if (readyIdx != -1) {
        m_displayIdx = readyIdx;
        m_buffers[m_displayIdx]->ready = false;
        m_buffers[m_displayIdx]->inUse = true;
    }

    if (!m_frame && m_active) {
        QMetaObject::invokeMethod(this, &ExtCaptureItem::requestNextFrame, Qt::QueuedConnection);
    }

    if (m_displayIdx == -1) return node;

    GbmBuffer* buf = m_buffers[m_displayIdx].get();
    if (!buf->qtTexture()) {
        if (!m_eglCreateImage) {
            QPlatformNativeInterface* ni = qGuiApp->platformNativeInterface();
            m_eglDisplay = static_cast<EGLDisplay>(ni->nativeResourceForIntegration(QByteArrayLiteral("egldisplay")));
            if (m_eglDisplay == EGL_NO_DISPLAY) m_eglDisplay = eglGetCurrentDisplay();

            m_eglCreateImage   = reinterpret_cast<void*>(eglGetProcAddress("eglCreateImageKHR"));
            m_eglDestroyImage  = reinterpret_cast<void*>(eglGetProcAddress("eglDestroyImageKHR"));
            m_glEGLImageTarget = reinterpret_cast<void*>(eglGetProcAddress("glEGLImageTargetTexture2DOES"));
        }

        auto fnCreateImage  = reinterpret_cast<PFNEGLCREATEIMAGEKHRPROC>(m_eglCreateImage);
        auto fnEGLTarget    = reinterpret_cast<PFNGLEGLIMAGETARGETTEXTURE2DOESPROC>(m_glEGLImageTarget);

        EGLint attribs[] = {
            EGL_WIDTH,                          buf->width(),
            EGL_HEIGHT,                         buf->height(),
            EGL_LINUX_DRM_FOURCC_EXT,           static_cast<EGLint>(buf->format()),
            EGL_DMA_BUF_PLANE0_FD_EXT,          buf->fd(),
            EGL_DMA_BUF_PLANE0_OFFSET_EXT,      0,
            EGL_DMA_BUF_PLANE0_PITCH_EXT,       static_cast<EGLint>(buf->stride()),
            EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT, static_cast<EGLint>(buf->modifier() & 0xFFFFFFFF),
            EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT, static_cast<EGLint>(buf->modifier() >> 32),
            EGL_NONE
        };

        buf->eglImage = fnCreateImage(m_eglDisplay, EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT, nullptr, attribs);
        
        if (buf->eglImage == EGL_NO_IMAGE_KHR) {
            qWarning() << "[ExtCapture] eglCreateImageKHR failed:" << eglGetError();
            return node;
        }

        GLuint texId = 0;
        glGenTextures(1, &texId);
        glBindTexture(GL_TEXTURE_2D, texId);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        fnEGLTarget(GL_TEXTURE_2D, static_cast<GLeglImageOES>(buf->eglImage));
        glBindTexture(GL_TEXTURE_2D, 0);

        // On crée la texture Qt qui "enveloppe" notre texture native
        // On ne la détruira que lors de la destruction du GbmBuffer
        QSGTexture* sgTex = QNativeInterface::QSGOpenGLTexture::fromNative(
            texId,
            window(),
            QSize(buf->width(), buf->height()),
            QQuickWindow::TextureHasAlphaChannel);
        
        buf->setQtTexture(sgTex);
    }

    if (!node) node = new QSGSimpleTextureNode;
    node->setTexture(buf->qtTexture());
    node->setRect(boundingRect());
    return node;
}

QVariantList ExtCaptureItem::windows() const
{
    QVariantList list;
    for (const auto& t : m_pendingToplevels) {
        if (t.identifier.isEmpty()) continue;
        QVariantMap map;
        map["id"] = t.identifier;
        map["appId"] = t.appId;
        map["title"] = t.title.isEmpty() ? t.appId : t.title;
        list << map;
    }
    return list;
}