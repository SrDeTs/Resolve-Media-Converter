cmake_minimum_required(VERSION 3.21)

project(ResolveMediaConverter VERSION 0.1.0 LANGUAGES CXX)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)

qt_standard_project_setup(REQUIRES 6.5)
if(POLICY QTP0004)
    qt_policy(SET QTP0004 NEW)
endif()

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
    RESOURCES
        Logo.png
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
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(FILES
    packaging/linux/io.github.srdets.ResolveMediaConverter.png
    DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/256x256/apps
    RENAME io.github.srdets.ResolveMediaConverter.png
)

install(FILES
    packaging/linux/io.github.srdets.ResolveMediaConverter.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
)

install(FILES
    packaging/linux/io.github.srdets.ResolveMediaConverter.metainfo.xml
    DESTINATION ${CMAKE_INSTALL_DATADIR}/metainfo
)

set(CPACK_PACKAGE_NAME "resolve-media-converter")
set(CPACK_PACKAGE_VENDOR "SrDeTs")
set(CPACK_PACKAGE_CONTACT "SrDeTs")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Converte audio de videos e arquivos de audio para FLAC com foco no DaVinci Resolve no Linux")
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_PACKAGE_INSTALL_DIRECTORY "Resolve Media Converter")
set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}-${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE")

set(CPACK_GENERATOR "DEB;RPM")
set(CPACK_PACKAGING_INSTALL_PREFIX "/usr")

set(CPACK_DEBIAN_FILE_NAME DEB-DEFAULT)
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "SrDeTs")
set(CPACK_DEBIAN_PACKAGE_SECTION "video")
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
set(CPACK_DEBIAN_PACKAGE_DEPENDS "ffmpeg")

set(CPACK_RPM_FILE_NAME RPM-DEFAULT)
set(CPACK_RPM_PACKAGE_LICENSE "MIT")
set(CPACK_RPM_PACKAGE_GROUP "Applications/Multimedia")
set(CPACK_RPM_PACKAGE_REQUIRES "ffmpeg")

include(CPack)
