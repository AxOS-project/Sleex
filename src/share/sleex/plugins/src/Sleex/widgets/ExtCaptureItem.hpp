#pragma once

#include <QQuickItem>
#include <QSize>
#include <QMutex>
#include <QString>
#include <QList>

#include <wayland-client.h>
#include <gbm.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>

#include <array>
#include <memory>

struct ext_image_copy_capture_manager_v1;
struct ext_image_copy_capture_session_v1;
struct ext_image_copy_capture_frame_v1;
struct ext_image_capture_source_v1;
struct ext_image_copy_capture_source_v1;
struct ext_foreign_toplevel_list_v1;
struct ext_foreign_toplevel_handle_v1;
struct ext_foreign_toplevel_image_capture_source_manager_v1;
struct zwp_linux_dmabuf_v1;
struct zwp_linux_buffer_params_v1;

class GbmBuffer;
class QSGTexture;

// ---------------------------------------------------------------------------
// ExtCaptureItem
//
// QML usage:
//   import Sleex.ExtCapture
//
//   ExtCaptureItem {
//       anchors.fill: parent
//       appId: "firefox"
//       active: true
//   }
// ---------------------------------------------------------------------------
class ExtCaptureItem : public QQuickItem
{
    Q_OBJECT
    QML_ELEMENT

    // The identifier of the window to capture, typically in the form "appId:instanceId". Updated when the session is active.
    Q_PROPERTY(QString windowId READ windowId WRITE setWindowId NOTIFY windowIdChanged)
    // App title 
    Q_PROPERTY(QVariantList windows READ windows NOTIFY windowsChanged)
    // Set to true to start capturing.
    Q_PROPERTY(bool    active  READ active  WRITE setActive NOTIFY activeChanged)
    // Read-only: true once the session is live and frames are flowing.
    Q_PROPERTY(bool    running READ running NOTIFY runningChanged)

public:
    explicit ExtCaptureItem(QQuickItem* parent = nullptr);
    ~ExtCaptureItem() override;

    QString windowId() const { return m_windowId; }
    void setWindowId(const QString& id);
    QVariantList windows() const;
    QStringList availableAppIds() const;
    bool    active() const { return m_active; }
    bool    running() const { return m_running; }

    void setAppId(const QString& id);
    void setActive(bool active);

protected:
    // called by the Scene Graph render thread.
    QSGNode* updatePaintNode(QSGNode* old, UpdatePaintNodeData*) override;
    void componentComplete() override;

signals:
    void windowIdChanged();
    void windowsChanged();
    void activeChanged();
    void runningChanged();

private:
    void initWayland();
    void initGbm();
    void tryStartCapture();
    void stopCapture();
    void requestNextFrame();
    void allocateBuffers();
    void createWaylandBuffer(GbmBuffer* buf);

    // Returns the buffer that is not currently in use by Qt.
    GbmBuffer* acquireCaptureBuffer();

    QString m_windowId;
    bool    m_active  = false;
    bool    m_running = false;
    bool    m_waylandReady = false;

    // Capture geometry (set by session::buffer_size event)
    QSize   m_captureSize;

    // Supported DMA-BUF formats reported by the session
    struct FormatInfo { uint32_t format; uint64_t modifier; };
    QList<FormatInfo> m_dmabufFormats;
    bool m_formatsReceived = false;

    wl_display*  m_display  = nullptr;
    wl_registry* m_registry = nullptr;

    ext_image_copy_capture_manager_v1*                     m_captureManager  = nullptr;
    ext_foreign_toplevel_image_capture_source_manager_v1*  m_sourceManager   = nullptr;
    ext_foreign_toplevel_list_v1*                          m_toplevelList    = nullptr;
    zwp_linux_dmabuf_v1*                                   m_dmabuf          = nullptr;

    ext_image_capture_source_v1*       m_source  = nullptr;
    ext_image_copy_capture_session_v1* m_session = nullptr;
    ext_image_copy_capture_frame_v1*   m_frame   = nullptr;

    // The toplevel handle we want to capture
    ext_foreign_toplevel_handle_v1* m_targetHandle = nullptr;
    // Temporary per-toplevel state during discovery
    struct ToplevelInfo {
        ext_foreign_toplevel_handle_v1* handle = nullptr;
        QString appId;
        QString title;
        QString identifier;
        bool matched = false;
    };
    QList<ToplevelInfo> m_pendingToplevels;

    int        m_drmFd    = -1;
    gbm_device* m_gbmDev  = nullptr;

    int m_pendingIdx = -1;

    // Double-buffering: one buffer captured by compositor, one displayed by Qt.
    static constexpr int POOL = 2;
    std::array<std::unique_ptr<GbmBuffer>, POOL> m_buffers;
    int m_captureIdx = 0; // index of the buffer we last sent to the compositor
    int m_displayIdx = -1;// index of the buffer ready for Qt to display

    // Qt Scene Graph (render thread side)
    // Protected by m_sgMutex.
    QMutex      m_sgMutex;
    GbmBuffer*  m_pendingBuffer  = nullptr; // written by Wayland CB, read by SG
    EGLDisplay  m_eglDisplay     = EGL_NO_DISPLAY;
    // EGL/GL extension function pointers, resolved once (stored as void* to
    // avoid pulling gl2ext.h into a MOC-parsed header).
    void* m_eglCreateImage    = nullptr;   // PFNEGLCREATEIMAGEKHRPROC
    void* m_eglDestroyImage   = nullptr;   // PFNEGLDESTROYIMAGEKHRPROC
    void* m_glEGLImageTarget  = nullptr;   // PFNGLEGLIMAGETARGETTEXTURE2DOESPROC

public:
    static void onRegistryGlobal(void*, wl_registry*, uint32_t name,
                                 const char* iface, uint32_t version);
    static void onRegistryGlobalRemove(void*, wl_registry*, uint32_t name);

    // ext_foreign_toplevel_list
    static void onToplevelListToplevel(void*, ext_foreign_toplevel_list_v1*,
                                       ext_foreign_toplevel_handle_v1* handle);
    static void onToplevelListFinished(void*, ext_foreign_toplevel_list_v1*);

    // ext_foreign_toplevel_handle
    static void onToplevelAppId(void*, ext_foreign_toplevel_handle_v1*, const char* app_id);
    static void onToplevelTitle(void*, ext_foreign_toplevel_handle_v1*, const char* title);
    static void onToplevelIdentifier(void*, ext_foreign_toplevel_handle_v1*, const char* id);
    static void onToplevelDone(void*, ext_foreign_toplevel_handle_v1*);
    static void onToplevelClosed(void*, ext_foreign_toplevel_handle_v1*);

    // ext_image_copy_capture_session
    static void onSessionBufferSize(void*, ext_image_copy_capture_session_v1*,
                                    uint32_t w, uint32_t h);
    static void onSessionShmFormat(void*, ext_image_copy_capture_session_v1*, uint32_t fmt);
    static void onSessionDmabufDevice(void*, ext_image_copy_capture_session_v1*,
                                      wl_array* device);
    static void onSessionDmabufFormat(void*, ext_image_copy_capture_session_v1*,
                                      uint32_t fmt, wl_array* modifiers);
    static void onSessionDone(void*, ext_image_copy_capture_session_v1*);
    static void onSessionStopped(void*, ext_image_copy_capture_session_v1*);

    // ext_image_copy_capture_frame
    static void onFrameTransform(void*, ext_image_copy_capture_frame_v1*, uint32_t transform);
    static void onFrameDamage(void*, ext_image_copy_capture_frame_v1*,
                              int32_t x, int32_t y, int32_t w, int32_t h);
    static void onFramePresentationTime(void*, ext_image_copy_capture_frame_v1*,
                                        uint32_t tv_sec_hi, uint32_t tv_sec_lo, uint32_t tv_nsec);
    static void onFrameReady(void*, ext_image_copy_capture_frame_v1*);
    static void onFrameFailed(void*, ext_image_copy_capture_frame_v1*, uint32_t reason);
};