#include <QCoreApplication>
#include <QDebug>
#include <QLocale>
#include <QQmlEngine>
#include <QQmlEngineExtensionPlugin>
#include <QTranslator>

class SleexCorePlugin final : public QQmlEngineExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlEngineExtensionInterface_iid)

public:
    void initializeEngine(QQmlEngine *engine, const char *uri) override {
        Q_UNUSED(engine)
        Q_UNUSED(uri)

        if (translationInstalled) {
            return;
        }

        const QLocale locale = QLocale::system();

        qInfo().noquote()
            << "[Sleex Core] Initializing translations for locale"
            << locale.name();

        if (!translator.load(
                locale,
                QStringLiteral("sleex"),
                QStringLiteral("_"),
                QStringLiteral(":/i18n"))) {
            qInfo().noquote()
                << "[Sleex Core] No translation available for"
                << locale.name()
                << "- using the source language.";
            return;
        }

        translationInstalled =
            QCoreApplication::installTranslator(&translator);

        if (translationInstalled) {
            qInfo().noquote()
                << "[Sleex Core] Translation installed for"
                << locale.name();
        } else {
            qWarning().noquote()
                << "[Sleex Core] Translation catalog loaded,"
                << "but installation failed.";
        }
    }

private:
    QTranslator translator;
    bool translationInstalled = false;
};

#include "plugin.moc"
