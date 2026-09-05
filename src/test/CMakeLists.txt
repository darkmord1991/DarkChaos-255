#
# This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
#
# This file is free software; as a special exception the author gives
# unlimited permission to copy and/or distribute it, with or without
# modifications, as long as this notice is preserved.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY, to the extent permitted by law; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
CollectSourceFiles(
        ${CMAKE_CURRENT_SOURCE_DIR}
        PRIVATE_SOURCES
)

include_directories(
        "${CMAKE_CURRENT_SOURCE_DIR}/mocks"
)

add_executable(
        unit_tests
        ${PRIVATE_SOURCES}
)

target_link_libraries(
        unit_tests
        game
        gtest_main
        gmock_main
        game-interface
        # NOTE: this fork's `game` library calls into script-tree symbols
        # (DCAddon::DeathMarkers, BattlegroundBFG, BattlegroundHLBG), which
        # upstream's does not, so `game` alone does not link here. Adding
        # `scripts` resolves the symbols but drags in every AddSC_* global
        # constructor, and the binary then segfaults during static init before
        # gtest reaches main. Running this target needs the pure logic split
        # away from the script registration graph; it is not a link-list fix.
        # game links acore-core-interface PRIVATE, so its compile options do not
        # propagate here. Without it this target misses /utf-8 (fmt refuses to
        # build) and NOMINMAX (windows.h min/max macros break GridDefines.h),
        # and unit_tests does not compile on MSVC at all.
        acore-core-interface
)

# Add module test sources if any modules registered tests
get_property(MODULE_TEST_SOURCES GLOBAL PROPERTY ACORE_MODULE_TEST_SOURCES)
get_property(MODULE_TEST_INCLUDES GLOBAL PROPERTY ACORE_MODULE_TEST_INCLUDES)

if(MODULE_TEST_SOURCES)
    target_sources(unit_tests PRIVATE ${MODULE_TEST_SOURCES})
    message(STATUS "Added module tests to unit_tests target")
endif()

if(MODULE_TEST_INCLUDES)
    list(REMOVE_DUPLICATES MODULE_TEST_INCLUDES)
    target_include_directories(unit_tests PRIVATE ${MODULE_TEST_INCLUDES})
    message(STATUS "Added module test includes to unit_tests target")
endif()

# Link modules library to tests so module code is available
if(TARGET modules)
    target_link_libraries(unit_tests modules)
endif()

add_test(
        NAME
        unit
        COMMAND
        ${CMAKE_BINARY_DIR}/src/test/unit_tests
)
