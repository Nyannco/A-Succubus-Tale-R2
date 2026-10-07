vcpkg_from_github(
        OUT_SOURCE_PATH SOURCE_PATH
        REPO alandtse/CommonLibVR
        REF 94faaed0c60eddd8347767f2d4d29a97c93bde8c
        SHA512  d1753f0744608b9ecc60dc57b9d49fa6d846a45f208550fa734cb42e53dba79ee84147658c77bc4ad56fd7457a8d63b54b53a2c28e47f72572d71021abf9791b
        HEAD_REF ng
)
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH2
    REPO ValveSoftware/openvr
    REF ebdea152f8aac77e9a6db29682b81d762159df7e
    SHA512 4fb668d933ac5b73eb4e97eb29816176e500a4eaebe2480cd0411c95edfb713d58312036f15db50884a2ef5f4ca44859e108dec2b982af9163cefcfc02531f63
    HEAD_REF master
)

file(GLOB OPENVR_FILES "${SOURCE_PATH2}/*")

file(COPY ${OPENVR_FILES} DESTINATION "${SOURCE_PATH}/extern/openvr")

vcpkg_configure_cmake(
    SOURCE_PATH "${SOURCE_PATH}"
    PREFER_NINJA
    OPTIONS -DBUILD_TESTS=off -DSKSE_SUPPORT_XBYAK=on
)

vcpkg_install_cmake()
vcpkg_cmake_config_fixup(PACKAGE_NAME CommonLibSSE CONFIG_PATH lib/cmake)
vcpkg_copy_pdbs()

file(INSTALL "${SOURCE_PATH2}/headers/openvr.h" DESTINATION ${CURRENT_PACKAGES_DIR}/include)
file(GLOB CMAKE_CONFIGS "${CURRENT_PACKAGES_DIR}/share/CommonLibSSE/CommonLibSSE/*.cmake")
file(INSTALL ${CMAKE_CONFIGS} DESTINATION "${CURRENT_PACKAGES_DIR}/share/CommonLibSSE")
file(INSTALL "${SOURCE_PATH}/cmake/CommonLibSSE.cmake" DESTINATION "${CURRENT_PACKAGES_DIR}/share/CommonLibSSE")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/share/CommonLibSSE/CommonLibSSE")

file(
    INSTALL "${SOURCE_PATH}/licenses/LICENSE-MIT.txt"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
    RENAME copyright)

# local overlay fix: the upstream-generated CommonLibSSEConfig.cmake includes the
# targets file (which imports Microsoft::DirectXTK / spdlog::spdlog) BEFORE resolving
# dependencies, and omits directxtk entirely -- on modern CMake set_target_properties
# then fails on the undefined Microsoft::DirectXTK target. Rewrite the config so the
# dependencies are found first and directxtk is included.
file(WRITE "${CURRENT_PACKAGES_DIR}/share/CommonLibSSE/CommonLibSSEConfig.cmake"
[=[include(CMakeFindDependencyMacro)
find_dependency(spdlog CONFIG)
find_dependency(directxtk CONFIG)
include("${CMAKE_CURRENT_LIST_DIR}/CommonLibSSE-targets.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/CommonLibSSE.cmake")
]=])
