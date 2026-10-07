# THIRD_PARTY — ASuccubusTaleR2 (ASTR2)

## Origin and License

ASTR2 (A Succubus Tale R2) is a derivative work in the "A Succubus Tale" remake lineage. Its Papyrus scripts and C++ SKSE plugin (ASTR2Native) are implemented from scratch for this project (created with the assistance of an AI — Claude / Anthropic — while design and decisions were made by nyannco / NonbiriSkyrim). It is licensed under **GPL-3.0**, and the source is bundled and published.

- **Credit chain:** original concept **CaptainHubs** (A Succubus Tale) → remake **ShMinitmMan** (A Succubus Tale - Remake, Nexus mods/107235) → **ASTR2**. The original's Nexus page explicitly permits "modification / feature improvement, with credit (and without soliciting donations)."
- Any assets inherited from the original or the remake credit their source. All C++/Papyrus implementation code is new; no other mod's implementation code or art is used.
- Donation Points are disabled.

## Required dependency mods (installed separately by the user; not bundled with this mod)

The following are prerequisite mods you install yourself from Nexus, etc. ASTR2 only calls each mod's public API/functions; it does not redistribute their implementations (DLLs or scripts). For required versions, see the bundled README (Requirements).

- **OStim NG** (license GPL-3.0) … the core. Handles scene launch, casting, act detection, and more.
- **SkyVault** (by nyannco; required) … the data-storage base.
- **PapyrusUtil SE** / **UIExtensions** / **OSL Aroused** / **SkyUI** (MCM) / **powerofthree's Papyrus Extender** / **RaceMenu** (NiOverride / SKEE; sigil/tattoo rendering)
- Underlying base: **SKSE64** / **Address Library for SKSE Plugins**
- Recommended (MCM display; strongly recommended): **Full-screen MCM Menu for SkyUI** (choose Opt.4 "Full-screen" at install) … ASTR2 has many MCM options and the standard MCM clips them off-screen.
- Optional (works without them): **OCum** (cum-volume bonus) / **SOS・TNG** (schlongs / futa)

## Bundled public API headers (for integration; only those permitted for distribution)

Only the **integration headers** used to build our own DLL (ASTR2Native) are bundled. We do not bundle any mod's implementation DLL (API headers are distributable; implementations are not redistributed).

- **OstimNG-API-Thread.h / OStimThreadsAPI.h** — OStim NG's public integration API ("for any mod" — intended to be distributed to and used by mod developers). OStim itself is GPL-3.0, and ASTR2 is an **independent implementation** that calls the API (not a copy of its implementation code).
- **SkeeInterface.h** — the integration interface for RaceMenu (SKEE / NiOverride) (sigil/tattoo rendering).
- **SkyVaultAPI.h** — the integration header for SkyVault (by nyannco; a separate mod).

## Build dependencies (linked into our DLL; full texts bundled in `LICENSES/`)

`vcpkg.json` directly specifies three (commonlibsse-ng / nlohmann-json / minhook), but the "grand-dependencies" CommonLibSSE-NG uses internally (fmt / spdlog / rapidcsv / xbyak / DirectXMath / DirectXTK) are also embedded in the distributed DLL. **Nine licenses require display**, listed below. Each copyright is generated automatically at build time under `vcpkg_installed/…/share/<lib>/copyright` (no internet needed), and their full texts are copied into `LICENSES/`.

| Library | License | Copyright | Use |
|---|---|---|---|
| CommonLibSSE-NG | MIT | Ryan-rsm-McKenzie | SKSE plugin base |
| fmt | MIT | Victor Zverovich | String formatting (CommonLib grand-dep) |
| spdlog | MIT | Gabi Melman | Logging (CommonLib grand-dep) |
| nlohmann/json | MIT | Niels Lohmann | JSON storage |
| rapidcsv | BSD 3-Clause | Kristofer Berggren | CSV reading (CommonLib grand-dep) |
| xbyak | BSD 3-Clause | MITSUNARI Shigeo | JIT assembler (CommonLib grand-dep) |
| DirectXMath | MIT | Microsoft Corporation | Math library (CommonLib grand-dep) |
| DirectXTK | MIT | Microsoft Corporation | DirectX Tool Kit (CommonLib grand-dep) |
| MinHook | BSD 2-Clause | Tsuda Kageyu | Function hooking (real-number display on item/spell cards) |

Both MIT and BSD require reproducing the copyright notice when distributing binaries, so bundling them in `LICENSES/` is mandatory.

## AI-assistance disclosure & test environment

- The implementation was created with the assistance of an AI (Claude / Anthropic); design, verification, and decisions were made by **nyannco (NonbiriSkyrim)**. This disclosure is retained upon publication.
- The primary test environment is Skyrim SE **1.6.1170** (the stable build). **1.7.104** was checked in-game but not thoroughly tested. GOG / VR are untested.

## References

- A Succubus Tale (concept, CaptainHubs) / A Succubus Tale - Remake (ShMinitmMan, Nexus mods/107235)
- OStim NG (public API, GPL-3.0)
- Collaborating community = **NonbiriSkyrim** (representative, kota)
- Reference template = Outfit Gallery - Visual Outfit Manager (KotaNoS, GPL-3.0, Nexus mods/193410)
- **ASTR2 source code = published on GitHub** (GPL-3.0 source-availability obligation): https://github.com/Nyannco/A-Succubus-Tale-R2
