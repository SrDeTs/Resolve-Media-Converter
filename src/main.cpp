#include "core/ConversionManager.h"

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("Resolve Media Converter"));
    app.setOrganizationName(QStringLiteral("Codex"));
    app.setOrganizationDomain(QStringLiteral("local.codex"));

    QQuickStyle::setStyle(QStringLiteral("Basic"));

    qmlRegisterUncreatableType<ConversionManager>("ResolveMediaConverter", 1, 0, "SelectionMode", QStringLiteral("Enums only"));

    ConversionManager manager;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("conversionManager"), &manager);

    const QUrl url(QStringLiteral("qrc:/qt/qml/ResolveMediaConverter/qml/Main.qml"));
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
