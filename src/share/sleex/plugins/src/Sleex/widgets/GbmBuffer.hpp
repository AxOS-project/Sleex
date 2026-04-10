#pragma once

#include <gbm.h>
#include <cstdint>
#include <EGL/egl.h>
#include <EGL/eglext.h>

struct wl_buffer;
class QSGTexture; // Forward declaration pour éviter d'inclure tout Qt ici

class GbmBuffer {
public:
    GbmBuffer() = default;

    bool allocate(gbm_device* dev,
                  int         width,
                  int         height,
                  uint32_t    format,
                  uint64_t    modifier);

    ~GbmBuffer();

    // Non-copyable, moveable
    GbmBuffer(const GbmBuffer&)            = delete;
    GbmBuffer& operator=(const GbmBuffer&) = delete;
    GbmBuffer(GbmBuffer&&) noexcept;
    GbmBuffer& operator=(GbmBuffer&&) noexcept;

    bool     isValid()   const { return m_bo != nullptr; }
    int      fd()        const { return m_fd; }
    uint32_t stride()    const { return m_stride; }
    uint32_t offset()    const { return 0; }
    uint32_t format()    const { return m_format; }
    uint64_t modifier()  const { return m_modifier; }
    int      width()     const { return m_width; }
    int      height()    const { return m_height; }

    wl_buffer* waylandBuffer() const        { return m_wlBuffer; }
    void       setWaylandBuffer(wl_buffer* b) { m_wlBuffer = b; }

    QSGTexture* qtTexture() const { return m_qtTexture; }
    void setQtTexture(QSGTexture* tex) { m_qtTexture = tex; }
    EGLImage eglImage = EGL_NO_IMAGE_KHR;

    // Ping-pong flags
    bool isCapturing = false;
    bool ready = false;
    bool inUse = false;
private:
    void release();

    gbm_bo* m_bo       = nullptr;
    int        m_fd       = -1;
    uint32_t   m_stride   = 0;
    uint32_t   m_format   = 0;
    uint64_t   m_modifier = 0;
    int        m_width    = 0;
    int        m_height   = 0;
    wl_buffer* m_wlBuffer = nullptr;
    QSGTexture* m_qtTexture = nullptr;
};