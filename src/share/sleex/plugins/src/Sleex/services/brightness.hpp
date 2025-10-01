#pragma once

#include <QObject>

namespace sleex::services {

class Brightness : public QObject {
    Q_OBJECT
    Q_PROPERTY(int value READ value WRITE setValue NOTIFY valueChanged)

public:
    explicit Brightness(QObject *parent = nullptr);

    int value() const;
    void setValue(int val);

signals:
    void valueChanged(int newValue);

private:
    int m_value;
};

} // namespace sleex::services
