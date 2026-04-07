#include "core/ConversionManager.h"

#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QCoreApplication>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStringList>
#include <QTextStream>

namespace {

constexpr auto kAppName = "Resolve Media Converter";
constexpr auto kAppVersion = "0.1.0";

int printHelp()
{
    QTextStream out(stdout);
    out << kAppName << '\n';
    out << "Uso: resolve-media-converter [opcoes]\n\n";
    out << "Opcoes:\n";
    out << "  --help       Exibe esta ajuda e sai.\n";
    out << "  --version    Exibe a versao do aplicativo e sai.\n";
    out << "  --verbose    Exibe logs detalhados no terminal durante a execucao.\n";
    return 0;
}

int printVersion()
{
    QTextStream out(stdout);
    out << kAppName << ' ' << kAppVersion << '\n';
    return 0;
}

bool hasArgument(const QStringList &arguments, const QString &option)
{
    return arguments.contains(option);
}

} // namespace

int main(int argc, char *argv[])
{
    QStringList rawArguments;
    rawArguments.reserve(argc);
    for (int i = 0; i < argc; ++i) {
        rawArguments << QString::fromLocal8Bit(argv[i]);
    }

    if (hasArgument(rawArguments, QStringLiteral("--help")) || hasArgument(rawArguments, QStringLiteral("-h"))) {
        return printHelp();
    }

    if (hasArgument(rawArguments, QStringLiteral("--version")) || hasArgument(rawArguments, QStringLiteral("-v"))) {
        return printVersion();
    }

    QGuiApplication app(argc, argv);
    app.setApplicationName(QString::fromLatin1(kAppName));
    app.setApplicationVersion(QString::fromLatin1(kAppVersion));
    app.setOrganizationName(QStringLiteral("Codex"));
    app.setOrganizationDomain(QStringLiteral("local.codex"));
    app.setWindowIcon(QIcon(QStringLiteral(":/qt/qml/ResolveMediaConverter/Logo.png")));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Resolve Media Converter: corrige incompatibilidades de audio para o DaVinci Resolve no Linux."));

    const QCommandLineOption verboseOption(QStringList{QStringLiteral("verbose")},
                                           QStringLiteral("Exibe logs detalhados no terminal durante a execucao."));
    parser.addOption(verboseOption);
    parser.process(app);

    QQuickStyle::setStyle(QStringLiteral("Basic"));

    qmlRegisterUncreatableType<ConversionManager>("ResolveMediaConverter", 1, 0, "SelectionMode", QStringLiteral("Enums only"));

    ConversionManager manager;
    manager.setVerboseLogging(parser.isSet(verboseOption));

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
