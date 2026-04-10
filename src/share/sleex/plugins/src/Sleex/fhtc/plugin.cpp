#include <QQmlExtensionPlugin>

class SleexFhtcPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override {
        // QML_ELEMENT and QML_SINGLETON macros handle registration automatically
        Q_UNUSED(uri)
    }
};

#include "plugin.moc"