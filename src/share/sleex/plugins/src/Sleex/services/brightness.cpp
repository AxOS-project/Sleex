#include "brightness.hpp"

namespace sleex::services {

// 50 is the default placeholder value
Brightness::Brightness(QObject *parent): QObject(parent), m_value(50) {}

int Brightness::value() const {
    return m_value;
}

void Brightness::setValue(int val) {
    if (m_value == val)
        return;

    m_value = val;
    emit valueChanged(m_value);
}

} // namespace sleex::services
