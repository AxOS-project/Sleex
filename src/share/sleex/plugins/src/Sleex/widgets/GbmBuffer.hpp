#pragma once

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <cstdint>
#include <gbm.h>

struct wl_buffer;
class QSGTexture;

/**
 * @brief RAII wrapper around a GBM buffer object (`gbm_bo`), its DMA-BUF file descriptor,
 *        associated Wayland `wl_buffer`, and Qt Scene Graph `QSGTexture`.
 *
 * Used by `ExtCaptureItem` for zero-copy double-buffered DMA-BUF frame capture via
 * `ext-image-copy-capture-v1` and `zwp_linux_dmabuf_v1`.
 */
class GbmBuffer
{
public:
    /**
     * @brief Constructs an unallocated `GbmBuffer`.
     */
    GbmBuffer() = default;

    /**
     * @brief Allocates a GBM buffer object with the given dimensions, DRM format, and modifier.
     * @param dev Pointer to an initialized `gbm_device`.
     * @param width Buffer width in pixels.
     * @param height Buffer height in pixels.
     * @param format DRM FourCC pixel format (e.g. `DRM_FORMAT_XRGB8888`).
     * @param modifier DRM format modifier (e.g. `DRM_FORMAT_MOD_LINEAR`).
     * @return `true` if allocation and DMA-BUF FD export succeeded, `false` otherwise.
     */
    bool allocate(gbm_device *dev,
                  int width,
                  int height,
                  uint32_t format,
                  uint64_t modifier);

    /**
     * @brief Destroys the `GbmBuffer` and releases its texture, `wl_buffer`, FD, and `gbm_bo`.
     */
    ~GbmBuffer();

    GbmBuffer(const GbmBuffer &) = delete;
    GbmBuffer &operator=(const GbmBuffer &) = delete;

    /**
     * @brief Move-constructs a `GbmBuffer`, transferring ownership of native resources.
     * @param other Source `GbmBuffer` to move from.
     */
    GbmBuffer(GbmBuffer &&other) noexcept;

    /**
     * @brief Move-assigns a `GbmBuffer`, releasing existing resources and taking ownership from `other`.
     * @param other Source `GbmBuffer` to move from.
     * @return Reference to `*this`.
     */
    GbmBuffer &operator=(GbmBuffer &&other) noexcept;

    /**
     * @brief Checks whether the underlying GBM buffer object is allocated.
     * @return `true` if valid, `false` otherwise.
     */
    bool isValid() const { return m_bo != nullptr; }

    /**
     * @brief Returns the exported DMA-BUF file descriptor for plane 0.
     * @return File descriptor integer, or `-1` if unallocated.
     */
    int fd() const { return m_fd; }

    /**
     * @brief Returns the row stride in bytes for plane 0.
     * @return Stride in bytes.
     */
    uint32_t stride() const { return m_stride; }

    /**
     * @brief Returns the byte offset for plane 0.
     * @return Byte offset (`0`).
     */
    uint32_t offset() const { return 0; }

    /**
     * @brief Returns the DRM FourCC pixel format of the buffer.
     * @return DRM format code.
     */
    uint32_t format() const { return m_format; }

    /**
     * @brief Returns the DRM format modifier of the buffer.
     * @return 64-bit DRM format modifier.
     */
    uint64_t modifier() const { return m_modifier; }

    /**
     * @brief Returns the width of the buffer in pixels.
     * @return Width in pixels.
     */
    int width() const { return m_width; }

    /**
     * @brief Returns the height of the buffer in pixels.
     * @return Height in pixels.
     */
    int height() const { return m_height; }

    /**
     * @brief Returns the Wayland `wl_buffer` wrapping this DMA-BUF.
     * @return Pointer to `wl_buffer`, or `nullptr` if not yet created.
     */
    wl_buffer *waylandBuffer() const { return m_wlBuffer; }

    /**
     * @brief Assigns the Wayland `wl_buffer` created from this DMA-BUF.
     * @param b Pointer to the `wl_buffer`.
     */
    void setWaylandBuffer(wl_buffer *b) { m_wlBuffer = b; }

    /**
     * @brief Returns the cached Qt Scene Graph texture wrapping this buffer's `EGLImage`.
     * @return Pointer to `QSGTexture`, or `nullptr` if not yet created on the render thread.
     */
    QSGTexture *qtTexture() const { return m_qtTexture; }

    /**
     * @brief Stores the Qt Scene Graph texture wrapping this buffer's `EGLImage`.
     * @param tex Pointer to the `QSGTexture` (owned by `GbmBuffer`).
     */
    void setQtTexture(QSGTexture *tex) { m_qtTexture = tex; }

    EGLImage eglImage = EGL_NO_IMAGE_KHR;

    bool isCapturing = false;
    bool ready = false;
    bool inUse = false;

private:
    /**
     * @brief Releases the `QSGTexture`, `wl_buffer`, DMA-BUF file descriptor, and `gbm_bo`.
     */
    void release();

    gbm_bo *m_bo = nullptr;
    int m_fd = -1;
    uint32_t m_stride = 0;
    uint32_t m_format = 0;
    uint64_t m_modifier = 0;
    int m_width = 0;
    int m_height = 0;
    wl_buffer *m_wlBuffer = nullptr;
    QSGTexture *m_qtTexture = nullptr;
};
