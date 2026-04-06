cmake_minimum_required(VERSION 3.21)

project(ResolveMediaConverter VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)

qt_standard_project_setup(REQUIRES 6.5)
qt_policy(SET QTP0004 NEW)

qt_add_executable(resolve-media-converter
    src/main.cpp
    src/core/ConversionManager.cpp
    src/core/ConversionQueueModel.cpp
    src/core/ConversionWorker.cpp
    src/core/LogModel.cpp
)

qt_add_qml_module(resolve-media-converter
    URI ResolveMediaConverter
    VERSION 1.0
    QML_FILES
        qml/Main.qml
)

target_include_directories(resolve-media-converter
    PRIVATE
        src
)

target_link_libraries(resolve-media-converter
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
        Qt6::QuickControls2
)

install(TARGETS resolve-media-converter
    BUNDLE DESTINATION .
    RUNTIME DESTINATION bin
)
