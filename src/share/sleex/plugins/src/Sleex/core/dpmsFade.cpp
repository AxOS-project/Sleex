#include "dpmsFade.hpp"

#include <unistd.h>
#include <chrono>
#include <cstdlib>
#include <iostream>
#include <thread>

namespace {
sdbus::ServiceName destination("org.freedesktop.login1");
sdbus::ObjectPath objectPath("/org/freedesktop/login1");
constexpr const char* LOGIND_INTERFACE = "org.freedesktop.login1.Manager";
constexpr std::chrono::milliseconds FADE_DURATION{400};
}

SuspendFader::SuspendFader(QObject* parent) : QObject(parent) {}

SuspendFader::~SuspendFader() {
    stop();
}

void SuspendFader::start() {
    if (bus_) {
        return;
    }

    try {
        bus_ = sdbus::createSystemBusConnection();

        proxy_ = sdbus::createProxy(*bus_, 
                                    sdbus::ServiceName{"org.freedesktop.login1"}, 
                                    sdbus::ObjectPath{"/org/freedesktop/login1"});

        proxy_->uponSignal("PrepareForSleep")
              .onInterface("org.freedesktop.login1.Manager")
              .call([this](bool sleeping) {
                  onPrepareForSleep(sleeping);
              });

        acquireLock();
        bus_->enterEventLoopAsync();
    } catch (const sdbus::Error& e) {
        std::cerr << "SuspendFader init error: " << e.getMessage() << '\n';
        stop();
    }
}

void SuspendFader::stop() {
    if (bus_) {
        bus_->leaveEventLoop();
    }
    releaseLock();
    proxy_.reset();
    bus_.reset();
}

void SuspendFader::acquireLock() {
    if (lock_fd_ >= 0 || !proxy_) {
        return;
    }

    try {
        sdbus::UnixFd fd;
        proxy_->callMethod("Inhibit")
              .onInterface(LOGIND_INTERFACE)
              .withArguments("sleep", "Sleex", "Display fade animation", "delay")
              .storeResultsTo(fd);

        lock_fd_ = ::dup(fd.get());
    } catch (const sdbus::Error& e) {
        std::cerr << "Inhibit call failed: " << e.getMessage() << '\n';
    }
}

void SuspendFader::releaseLock() {
    if (lock_fd_ >= 0) {
        ::close(lock_fd_);
        lock_fd_ = -1;
    }
}

void SuspendFader::onPrepareForSleep(bool sleeping) {
    if (sleeping) {
        std::system("wlr-dpms off");
        std::this_thread::sleep_for(FADE_DURATION);
        releaseLock();
    } else {
        std::system("wlr-dpms on");
        acquireLock();
    }
}