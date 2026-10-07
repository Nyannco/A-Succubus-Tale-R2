# ASuccubusTaleR2 native SKSE plugin
# - C++ プラグインのビルド設定（細かい設定は CMakePresets.json 側）
# - 出力 .dll の置き場所

cmake_minimum_required(VERSION 3.21)

# プロジェクト名 = 生成される .dll の名前（ここでは ASTR2SKSE.dll）
project(ASTR2SKSE VERSION 0.0.1 LANGUAGES CXX)

# ----------------------------------------------------------------------------
# ここから下は基本的にいじる必要はありません
# ----------------------------------------------------------------------------

# 出力先：環境変数 SKYRIM_MODS_FOLDER（MO2 の mods フォルダ）を設定しておくと、
# ビルド時に <その下>/ASuccubusTaleR2/SKSE/Plugins/ へ .dll を自動コピーします。
# 未設定の場合は自動コピーしません（build フォルダ内に .dll が出来ます）。
if(DEFINED ENV{SKYRIM_MODS_FOLDER})
    set(OUTPUT_FOLDER "$ENV{SKYRIM_MODS_FOLDER}/ASuccubusTaleR2")
endif()

# 直接 Skyrim の Data へ入れたい場合は SKYRIM_FOLDER を設定します（MO2 利用なら不要）
if(DEFINED ENV{SKYRIM_FOLDER} AND IS_DIRECTORY "$ENV{SKYRIM_FOLDER}/Data")
    set(OUTPUT_FOLDER "$ENV{SKYRIM_FOLDER}/Data")
endif()

# CommonLibSSE-NG を使った SKSE プラグインとして構成
find_package(CommonLibSSE CONFIG REQUIRED)
add_commonlibsse_plugin(${PROJECT_NAME} SOURCES src/plugin.cpp src/InputHandler.cpp src/HpBarFeed.cpp src/SceneCatalog.cpp src/Technique.cpp src/TechRank.cpp src/TechHud.cpp src/Localization.cpp src/InfoHtml.cpp src/VassalRaise.cpp src/SkillXpBoost.cpp src/FinisherEval.cpp src/PowerReset.cpp src/FactionReset.cpp src/VassalDeath.cpp src/Sigil.cpp src/ScenePreparing.cpp src/SceneLauncher.cpp src/SceneGuard.cpp src/ServantTier.cpp src/HDrain.cpp src/DrainMark.cpp src/Chronos.cpp src/LifeForceDecay.cpp src/VassalUpkeep.cpp src/ProbeDump.cpp src/BugReport.cpp src/HpBarHud.cpp src/WeaknessSigil.cpp src/BarNumbers.cpp src/VLoveHud.cpp src/CombatDrain.cpp src/Fury.cpp src/ServantRoster.cpp src/EssenceFlow.cpp src/NailLazy.cpp src/NailDesc.cpp src/SpellInfo.cpp src/ManaCost.cpp src/ShaderCompat.cpp)
# include パス＝ルート（PCH.h の在処）と src/（共有ヘッダ SuccLevel.h 等の在処）の両方。
#   ルートの PCH.h から src/ のヘッダを #include "…" で引くため src/ も要ります（src の .cpp 同士は自ディレクトリ相対で足りますが PCH.h はルートにあるため）。
target_include_directories(${PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_23)
target_precompile_headers(${PROJECT_NAME} PRIVATE PCH.h)

# nlohmann-json（ヘッダオンリー）＝OStimシーンJSONのパース用です。SceneCatalog.cpp が使います。
find_package(nlohmann_json CONFIG REQUIRED)
target_link_libraries(${PROJECT_NAME} PRIVATE nlohmann_json::nlohmann_json)

# MinHook＝関数"入口"を安全に横取りする定番フック（プロローグ保存/命令長解析内蔵）。
# CommonLibSSEのwrite_branch/callは"呼び出し箇所"専用なので、AddSkillExperienceの入口フックはこちらで行います。
find_package(minhook CONFIG REQUIRED)
target_link_libraries(${PROJECT_NAME} PRIVATE minhook::minhook)

# OUTPUT_FOLDER が決まっていれば、ビルド後に .dll（Debug は .pdb も）を自動コピー
if(DEFINED OUTPUT_FOLDER)
    set(DLL_FOLDER "${OUTPUT_FOLDER}/SKSE/Plugins")
    message(STATUS "SKSE plugin output folder: ${DLL_FOLDER}")

    add_custom_command(
        TARGET "${PROJECT_NAME}"
        POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${DLL_FOLDER}"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "$<TARGET_FILE:${PROJECT_NAME}>" "${DLL_FOLDER}/$<TARGET_FILE_NAME:${PROJECT_NAME}>"
        VERBATIM
    )

    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        add_custom_command(
            TARGET "${PROJECT_NAME}"
            POST_BUILD
            COMMAND "${CMAKE_COMMAND}" -E copy_if_different "$<TARGET_PDB_FILE:${PROJECT_NAME}>" "${DLL_FOLDER}/$<TARGET_PDB_FILE_NAME:${PROJECT_NAME}>"
            VERBATIM
        )
    endif()
endif()
