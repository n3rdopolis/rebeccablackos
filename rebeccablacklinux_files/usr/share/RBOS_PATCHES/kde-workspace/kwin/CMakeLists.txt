########### configure tests ###############
include(CMakeDependentOption)

option(KWIN_BUILD_DECORATIONS "Enable building of KWin decorations." ON)
option(KWIN_BUILD_OXYGEN "Enable building of default decoration Oxygen" ON)
option(KWIN_BUILD_KCMS "Enable building of KWin configuration modules." ON)
option(KWIN_MOBILE_EFFECTS "Only build effects relevant for mobile devices" OFF)
option(KWIN_BUILD_TABBOX "Enable building of KWin Tabbox functionality" ON)
option(KWIN_BUILD_SCREENEDGES "Enable building of KWin with screen edge support" ON)
option(KWIN_BUILD_SCRIPTING "Enable building of KWin with scripting support" ON)
option(KWIN_BUILD_KAPPMENU "Enable building of KWin with application menu support" ON)
option(KWIN_BUILD_XRENDER_COMPOSITING "Enable building of KWin with XRender Compositing support" ON)
option(KWIN_BUILD_OPENGL_1_COMPOSITING "Enable support for OpenGL 1.x, automatically disabled when building for OpenGL ES 2.0" ON)
option(KWIN_BUILD_ACTIVITIES "Enable building of KWin with kactivities support" OFF)
option(KWIN_PLASMA_ACTIVE "Enable building KWin for Plasma Active." OFF)

# Binary name of KWin
set(KWIN_NAME "kwin")

if(KWIN_PLASMA_ACTIVE)
    set(KWIN_BUILD_DECORATIONS OFF)
    set(KWIN_BUILD_KCMS OFF)
    set(KWIN_BUILD_SCREENEDGES OFF)
    set(KWIN_BUILD_SCRIPTING ON)
    set(KWIN_BUILD_XRENDER_COMPOSITING OFF)
    set(KWIN_MOBILE_EFFECTS ON)
    set(KWIN_BUILD_WITH_OPENGLES ON)
    set(KWIN_NAME "kwinactive")
endif()

cmake_dependent_option(KWIN_BUILD_KAPPMENU "Build without appmenu support" ON "KWIN_BUILD_DECORATIONS" FALSE)

# for things that are also used by kwin libraries
configure_file(libkwineffects/kwinconfig.h.cmake ${CMAKE_CURRENT_BINARY_DIR}/libkwineffects/kwinconfig.h )


########### global ###############

include_directories(BEFORE
    ${CMAKE_CURRENT_BINARY_DIR}/libkdecorations
    ${CMAKE_CURRENT_BINARY_DIR}/libkwineffects
    ${CMAKE_CURRENT_BINARY_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/libkwineffects
    ${CMAKE_CURRENT_SOURCE_DIR}/libkdecorations
    ${CMAKE_CURRENT_SOURCE_DIR}/effects
    ${CMAKE_CURRENT_SOURCE_DIR}/tabbox
    )

add_subdirectory( libkdecorations )

add_definitions(-DKDE_DEFAULT_DEBUG_AREA=1212)


ecm_install_icons( ${ICON_INSTALL_DIR} )


