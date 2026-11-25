#pragma once

#include <QList>
#include <QMutex>
#include <QQuickItem>
#include <QSize>
#include <QString>
#include <QVariantList>

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <gbm.h>
#include <wayland-client.h>

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

/**
 * @brief Qt Quick item that captures live Wayland window contents via
 *        `ext-image-copy-capture-v1`, `ext-foreign-toplevel-list-v1`, and `zwp_linux_dmabuf_v1`.
 *
 * Designed as a zero-copy GPU DMA-BUF replacement for `ScreencopyView` in `DockApps.qml`
 * and `OverviewWindow.qml`. Matches windows by their `ext-foreign-toplevel-list-v1`
 * handle identifier (`windowId`, exposed by `fht-compositor` IPC as `"wayland-id"`).
 */
class ExtCaptureItem : public QQuickItem
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString windowId READ windowId WRITE setWindowId NOTIFY windowIdChanged)
    Q_PROPERTY(QVariantList windows READ windows NOTIFY windowsChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(bool hasContent READ hasContent NOTIFY hasContentChanged)
    Q_PROPERTY(QSize constraintSize READ constraintSize WRITE setConstraintSize NOTIFY constraintSizeChanged)

public:
    /**
     * @brief Constructs an `ExtCaptureItem` and enables scene graph rendering (`ItemHasContents`).
     * @param parent Optional parent `QQuickItem`.
     */
    explicit ExtCaptureItem(QQuickItem *parent = nullptr);

    /**
     * @brief Stops any active capture session and frees Wayland/GBM resources.
     */
    ~ExtCaptureItem() override;

    /**
     * @brief Returns the `ext-foreign-toplevel-list-v1` identifier of the target window.
     * @return Target window identifier string.
     */
    QString windowId() const { return m_windowId; }

    /**
     * @brief Sets the target `ext-foreign-toplevel-list-v1` window identifier to capture.
     * @param id Foreign toplevel handle identifier (from `fht-compositor` `"wayland-id"`).
     */
    void setWindowId(const QString &id);

    /**
     * @brief Returns the list of currently discovered foreign toplevels (`id`, `appId`, `title`).
     * @return List of `QVariantMap` entries.
     */
    QVariantList windows() const;

    /**
     * @brief Returns whether frame capture is requested to be active.
     * @return `true` if active, `false` otherwise.
     */
    bool active() const { return m_active; }

    /**
     * @brief Enables or disables live window capture.
     * @param active `true` to start capturing, `false` to stop.
     */
    void setActive(bool active);

    /**
     * @brief Returns whether a capture session is currently live and configured.
     * @return `true` once session constraints are received and capture is running.
     */
    bool running() const { return m_running; }

    /**
     * @brief Returns whether at least one captured frame is available for display.
     * @return `true` if a valid frame has been captured, `false` otherwise.
     */
    bool hasContent() const { return m_hasContent; }

    /**
     * @brief Returns the maximum bounding box used to compute aspect-preserving implicit size.
     * @return Constraint `QSize`.
     */
    QSize constraintSize() const { return m_constraintSize; }

    /**
     * @brief Sets the maximum bounding size used to compute `implicitWidth` and `implicitHeight`.
     * @param size Maximum `QSize` constraint.
     */
    void setConstraintSize(const QSize &size);

protected:
    /**
     * @brief Synchronizes the latest captured DMA-BUF frame into a `QSGSimpleTextureNode`.
     * @param old Existing scene graph node from the previous frame, or `nullptr`.
     * @param data Scene graph update data.
     * @return Updated `QSGNode` pointer.
     */
    QSGNode *updatePaintNode(QSGNode *old, UpdatePaintNodeData *data) override;

    /**
     * @brief Initializes Wayland protocol bindings and GBM device once QML properties are bound.
     */
    void componentComplete() override;

signals:
    /**
     * @brief Emitted when `windowId` changes.
     */
    void windowIdChanged();

    /**
     * @brief Emitted when the discovered foreign toplevel list changes.
     */
    void windowsChanged();

    /**
     * @brief Emitted when `active` changes.
     */
    void activeChanged();

    /**
     * @brief Emitted when `running` changes.
     */
    void runningChanged();

    /**
     * @brief Emitted when `hasContent` changes.
     */
    void hasContentChanged();

    /**
     * @brief Emitted when `constraintSize` changes.
     */
    void constraintSizeChanged();

private:
    /**
     * @brief Binds the Wayland display and registry from Qt's native Wayland platform interface.
     */
    void initWayland();

    /**
     * @brief Opens a DRM render node (`/dev/dri/renderD*`) and creates a `gbm_device`.
     */
    void initGbm();

    /**
     * @brief Resolves `m_targetHandle` for `m_windowId` and starts an `ext-image-copy-capture-v1` session.
     */
    void tryStartCapture();

    /**
     * @brief Destroys the active frame, capture session, and capture source.
     */
    void stopCapture();

    /**
     * @brief Allocates and submits the next frame capture request using an idle pool buffer.
     */
    void requestNextFrame();

    /**
     * @brief Allocates the double-buffered GBM pool matching the session's buffer size and format.
     */
    void allocateBuffers();

    /**
     * @brief Creates a `wl_buffer` from a `GbmBuffer` via `zwp_linux_dmabuf_v1`.
     * @param buf Target `GbmBuffer`.
     */
    void createWaylandBuffer(GbmBuffer *buf);

    /**
     * @brief Recomputes `implicitWidth` and `implicitHeight` from `m_captureSize` and `m_constraintSize`.
     */
    void updateImplicitSize();

    QString m_windowId;
    bool m_active = false;
    bool m_running = false;
    bool m_hasContent = false;
    bool m_waylandReady = false;

    QSize m_captureSize;
    QSize m_constraintSize;

    struct FormatInfo {
        uint32_t format;
        uint64_t modifier;
    };
    QList<FormatInfo> m_dmabufFormats;
    bool m_formatsReceived = false;

    wl_display *m_display = nullptr;
    wl_registry *m_registry = nullptr;

    ext_image_copy_capture_manager_v1 *m_captureManager = nullptr;
    ext_foreign_toplevel_image_capture_source_manager_v1 *m_sourceManager = nullptr;
    ext_foreign_toplevel_list_v1 *m_toplevelList = nullptr;
    zwp_linux_dmabuf_v1 *m_dmabuf = nullptr;

    ext_image_capture_source_v1 *m_source = nullptr;
    ext_image_copy_capture_session_v1 *m_session = nullptr;
    ext_image_copy_capture_frame_v1 *m_frame = nullptr;

    ext_foreign_toplevel_handle_v1 *m_targetHandle = nullptr;

    struct ToplevelInfo {
        ext_foreign_toplevel_handle_v1 *handle = nullptr;
        QString appId;
        QString title;
        QString identifier;
    };
    QList<ToplevelInfo> m_pendingToplevels;

    int m_drmFd = -1;
    gbm_device *m_gbmDev = nullptr;

    int m_pendingIdx = -1;

    static constexpr int POOL = 2;
    std::array<std::unique_ptr<GbmBuffer>, POOL> m_buffers;
    int m_captureIdx = 0;
    int m_displayIdx = -1;

    QMutex m_sgMutex;
    GbmBuffer *m_pendingBuffer = nullptr;
    EGLDisplay m_eglDisplay = EGL_NO_DISPLAY;
    void *m_eglCreateImage = nullptr;
    void *m_eglDestroyImage = nullptr;
    void *m_glEGLImageTarget = nullptr;

public:
    /**
     * @brief Wayland registry global advertisement callback.
     */
    static void onRegistryGlobal(void *data, wl_registry *registry, uint32_t name,
                                 const char *iface, uint32_t version);

    /**
     * @brief Wayland registry global removal callback.
     */
    static void onRegistryGlobalRemove(void *data, wl_registry *registry, uint32_t name);

    /**
     * @brief Callback invoked when a new foreign toplevel handle is advertised.
     */
    static void onToplevelListToplevel(void *data, ext_foreign_toplevel_list_v1 *list,
                                       ext_foreign_toplevel_handle_v1 *handle);

    /**
     * @brief Callback invoked when the foreign toplevel list finishes sending events.
     */
    static void onToplevelListFinished(void *data, ext_foreign_toplevel_list_v1 *list);

    /**
     * @brief Callback invoked when a foreign toplevel reports or updates its `app_id`.
     */
    static void onToplevelAppId(void *data, ext_foreign_toplevel_handle_v1 *handle, const char *app_id);

    /**
     * @brief Callback invoked when a foreign toplevel reports or updates its `title`.
     */
    static void onToplevelTitle(void *data, ext_foreign_toplevel_handle_v1 *handle, const char *title);

    /**
     * @brief Callback invoked when a foreign toplevel reports its unique `identifier`.
     */
    static void onToplevelIdentifier(void *data, ext_foreign_toplevel_handle_v1 *handle, const char *id);

    /**
     * @brief Callback invoked when all pending state changes for a foreign toplevel have been sent.
     */
    static void onToplevelDone(void *data, ext_foreign_toplevel_handle_v1 *handle);

    /**
     * @brief Callback invoked when a foreign toplevel has been closed.
     */
    static void onToplevelClosed(void *data, ext_foreign_toplevel_handle_v1 *handle);

    /**
     * @brief Callback invoked when the capture session announces buffer dimensions.
     */
    static void onSessionBufferSize(void *data, ext_image_copy_capture_session_v1 *session,
                                    uint32_t w, uint32_t h);

    /**
     * @brief Callback invoked when the capture session announces an SHM format (unused).
     */
    static void onSessionShmFormat(void *data, ext_image_copy_capture_session_v1 *session, uint32_t fmt);

    /**
     * @brief Callback invoked when the capture session announces a DMA-BUF device.
     */
    static void onSessionDmabufDevice(void *data, ext_image_copy_capture_session_v1 *session,
                                      wl_array *device);

    /**
     * @brief Callback invoked when the capture session announces supported DMA-BUF formats and modifiers.
     */
    static void onSessionDmabufFormat(void *data, ext_image_copy_capture_session_v1 *session,
                                      uint32_t fmt, wl_array *modifiers);

    /**
     * @brief Callback invoked when all session constraint events have been sent.
     */
    static void onSessionDone(void *data, ext_image_copy_capture_session_v1 *session);

    /**
     * @brief Callback invoked when the capture session is stopped by the compositor.
     */
    static void onSessionStopped(void *data, ext_image_copy_capture_session_v1 *session);

    /**
     * @brief Callback invoked when a captured frame reports its buffer transform.
     */
    static void onFrameTransform(void *data, ext_image_copy_capture_frame_v1 *frame, uint32_t transform);

    /**
     * @brief Callback invoked when a captured frame reports damaged regions.
     */
    static void onFrameDamage(void *data, ext_image_copy_capture_frame_v1 *frame,
                              int32_t x, int32_t y, int32_t w, int32_t h);

    /**
     * @brief Callback invoked when a captured frame reports its presentation timestamp.
     */
    static void onFramePresentationTime(void *data, ext_image_copy_capture_frame_v1 *frame,
                                        uint32_t tv_sec_hi, uint32_t tv_sec_lo, uint32_t tv_nsec);

    /**
     * @brief Callback invoked when a captured frame is ready for rendering.
     */
    static void onFrameReady(void *data, ext_image_copy_capture_frame_v1 *frame);

    /**
     * @brief Callback invoked when a frame capture attempt fails.
     */
    static void onFrameFailed(void *data, ext_image_copy_capture_frame_v1 *frame, uint32_t reason);
};
