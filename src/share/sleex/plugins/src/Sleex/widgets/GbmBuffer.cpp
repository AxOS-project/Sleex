#include "GbmBuffer.hpp"
#include <QSGTexture>
#include <gbm.h>
#include <drm_fourcc.h>
#include <unistd.h>
#include <wayland-client.h>

bool GbmBuffer::allocate(gbm_device* dev,
                         int         width,
                         int         height,
                         uint32_t    format,
                         uint64_t    modifier)
{
    release();

    m_width    = width;
    m_height   = height;
    m_format   = format;
    m_modifier = modifier;

    if (modifier != DRM_FORMAT_MOD_INVALID && modifier != DRM_FORMAT_MOD_LINEAR) {
        const uint64_t mods[] = { modifier };
        m_bo = gbm_bo_create_with_modifiers2(dev, width, height, format, mods, 1,
                                             GBM_BO_USE_RENDERING | GBM_BO_USE_LINEAR);
    }
    if (!m_bo) {
        m_bo = gbm_bo_create(dev, width, height, format,
                             GBM_BO_USE_RENDERING | GBM_BO_USE_LINEAR);
    }
    if (!m_bo) return false;

    m_fd     = gbm_bo_get_fd(m_bo);
    m_stride = gbm_bo_get_stride(m_bo);

    return (m_fd >= 0);
}

GbmBuffer::~GbmBuffer()
{
    release();
}

GbmBuffer::GbmBuffer(GbmBuffer&& o) noexcept
    : m_bo(o.m_bo), m_fd(o.m_fd), m_stride(o.m_stride),
      m_format(o.m_format), m_modifier(o.m_modifier),
      m_width(o.m_width), m_height(o.m_height),
      m_wlBuffer(o.m_wlBuffer), m_qtTexture(o.m_qtTexture),
      eglImage(o.eglImage), inUse(o.inUse), ready(o.ready)
{
    o.m_bo       = nullptr;
    o.m_fd       = -1;
    o.m_wlBuffer = nullptr;
    o.m_qtTexture = nullptr;
    o.eglImage   = EGL_NO_IMAGE_KHR;
}

GbmBuffer& GbmBuffer::operator=(GbmBuffer&& o) noexcept
{
    if (this != &o) {
        release();
        m_bo       = o.m_bo;      o.m_bo       = nullptr;
        m_fd       = o.m_fd;      o.m_fd       = -1;
        m_stride   = o.m_stride;
        m_format   = o.m_format;
        m_modifier = o.m_modifier;
        m_width    = o.m_width;
        m_height   = o.m_height;
        m_wlBuffer = o.m_wlBuffer; o.m_wlBuffer = nullptr;
        m_qtTexture = o.m_qtTexture; o.m_qtTexture = nullptr;
        eglImage   = o.eglImage;   o.eglImage   = EGL_NO_IMAGE_KHR;
        inUse      = o.inUse;
        ready      = o.ready;
    }
    return *this;
}

void GbmBuffer::release()
{
    if (m_qtTexture) {
        delete m_qtTexture;
        m_qtTexture = nullptr;
    }
    
    if (m_wlBuffer) {
        wl_buffer_destroy(m_wlBuffer);
        m_wlBuffer = nullptr;
    }
    if (m_fd >= 0) {
        close(m_fd);
        m_fd = -1;
    }
    if (m_bo) {
        gbm_bo_destroy(m_bo);
        m_bo = nullptr;
    }
    inUse = false;
    ready = false;
}