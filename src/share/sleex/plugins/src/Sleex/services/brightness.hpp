#pragma once
#include <QObject>
#include <QtQml/qqmlregistration.h>

namespace sleex::services {

class Brightness : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(int value READ value NOTIFY valueChanged)

public:
    explicit Brightness(QObject *parent = nullptr);

    int value() const;
    Q_INVOKABLE void setValue(int v);

signals:
    void valueChanged();

private:
    void updateCurrentBrightness();
    int m_value;
};

} // namespace sleex::services