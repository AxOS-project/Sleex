#include <QQmlExtensionPlugin>

/**
 * @brief Qt QML extension plugin entry point for the `Sleex.Fhtc` module.
 */
class SleexFhtcPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    /**
     * @brief Registers QML types for the `Sleex.Fhtc` module URI.
     *
     * Actual type registration is performed automatically by Qt's generated QML type
     * registration from `QML_NAMED_ELEMENT` and `QML_SINGLETON` macros.
     *
     * @param uri The QML module URI (`"Sleex.Fhtc"`).
     */
    void registerTypes(const char *uri) override
    {
        Q_UNUSED(uri)
    }
};

#include "plugin.moc"
