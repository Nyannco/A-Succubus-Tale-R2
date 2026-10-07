# A Succubus Tale R2

**Version 1.1.0** · English / 日本語 (see `README.ja.md`) · OStim-integrated succubus mod for Skyrim SE

**Nexus:** https://www.nexusmods.com/skyrimspecialedition/mods/194039 · **Source:** https://github.com/Nyannco/A-Succubus-Tale-R2

## Overview
**A Succubus Tale R2 (ASTR2)** is a succubus gameplay mod integrated with **[OStim NG](https://www.nexusmods.com/skyrimspecialedition/mods/OStim)**. You play as a succubus who seduces NPCs and drains their **Essence** through **OStim scenes** to grow in power — charming victims into servants, or raising the dead as your vassals.

Born from deep respect for **A Succubus Tale - Remake** (by ShMinitmMan, [Nexus mods/107235](https://www.nexusmods.com/skyrimspecialedition/mods/107235)); this is an OStim-integrated, feature-expanded take on it.

## From the author
This mod was born from respect and gratitude toward CaptainHubs' *A Succubus Tale* and ShMinitmMan's *A Succubus Tale - Remake*. Without those wonderful originals, this mod would not exist. My heartfelt thanks to them.

I originally made this mod for my own use and am releasing it as-is. I tried to keep the original features intact and bug-free, but there may be shortcomings. I'll address bugs as quickly as I can, so please feel free to leave a comment.
The new features are built quite a bit to my own taste. I'd be glad if you tune the power and growth values in the MCM to fit your own setup.
I hope you enjoy the succubus's tale.

## Main Features
- **Becoming a succubus & leveling** — Gather Essence to grow. Your max Magicka/Health/Stamina, their regeneration, and Speech rise automatically with level.
- **Essence drain** — Drain spells turn a target's health into Essence. You also drain during OStim orgasms, and can finish a scene to drain them dry. At higher levels an **area drain** siphons everyone around you at once.
- **Charm & Servantship** — Charm victims into OStim scenes. Build the bond through **5 tiers (Prey / Captive / Vassal / Thrall / Pet)**; Servant Sync also pulls in the game's own relationship rank.
- **Sweet Vassal** — Raise the dead as your vassal. At low level they rise as a reanimated thrall; from **Lv9** they return to life, able to join OStim scenes and follow you.
- **H-Skills** — Your proficiency in each act boosts arousal, Essence yield, relationships, spell power, and more.
- **Nightmare Embrace** — Visit sleeping targets within their dreams (success scales with level).
- **Sigils / Essence Shards / Sweet Elixirs** — Body sigils (marks that appear on the body), sealing Essence into Essence Shards, and stocking "embers" via Sweet Elixirs.
- **MCM menu** — Toggle features, tune power, check status, list servants, configure sigils, and more.

## Requirements
### Required
| MOD | Role | Tested version |
|---|---|---|
| **OStim NG (OStim Standalone)** | Core (scene launch, casting, act detection) | **7.5.1b** |
| **Pandora Behaviour Engine** | Animation behavior generation for OStim (behavior engine; required by OStim NG). OAR is required by Pandora, so it isn't listed separately | **5.0beta** (※Nemesis also works; author uses Pandora) |
| **OCum** | Essence drain bonus based on cum volume during OStim scenes | **4.1.1** |
| **OSL Aroused** | Arousal management | **2.8.2.0** |
| **Address Library for SKSE Plugins** | SKSE plugin base | **13.0.0.0** |
| **PapyrusUtil AE/SE** | Data storage & logging | **v4.6 (pinned)** (★latest v4.8 is for 1.7.104 — see note) |
| **UIExtensions** | Selection menus | **v1.2.0** (only release) |
| **SkyUI** | MCM | **5.2SE (pinned)** (★6.x untested — see note) |
| **powerofthree's Papyrus Extender (PO3)** | Nearby-NPC detection, shader removal | **5.10.0.1** |
| **RaceMenu (NiOverride / SKEE)** (AE) | Sigil/tattoo overlays (no sigils without it) | **skee64 0.4.19.16** |
| **SkyVault** | Data-storage base (persists Essence, etc.; **won't run without it**) | **1.1.0** |
| **SKSE64** | SKSE itself | **2.2.6** (for Skyrim 1.6.1170; see Compatibility) |

Follow each MOD's own Requirements for their prerequisites (JContainers / Address Library, etc.). Versions are measured on the author's MO2 setup; "latest recommended" means the newest version at install time. **SkyUI is pinned to 5.2SE** (the only stable SE version, and where ASTR2's MCM is verified); SkyUI 6.x (community) has reported RaceMenu/layout issues and is not recommended yet — **untested**. **PapyrusUtil is pinned to v4.6 for 1.6.1170** (latest v4.8 targets 1.7.104 and is harmful here). PO3 (5.10.0.1) is the tested version — 6.5.2+ also supports 1.6.1170 and is fine. RaceMenu (skee64 0.4.19.16) is the tested, stable version (0.4.20.0 exists, but staying on this is recommended).

### Recommended (strongly — for MCM display)
- **Full-screen MCM Menu for SkyUI** — Makes the MCM full-screen. **ASTR2 has many MCM options and the standard MCM can clip them off-screen**, so this is strongly recommended for comfortable use. Choose **Opt.4 "Full-screen"** during installation. *This is just what the author uses — any mod that similarly makes the MCM full-screen may work as a substitute.*

### Optional (enhances features)
- **SOS / TNG and other schlong mods** — Schlong display & futa casting (via OStim).
- **OStim animation/scene packs (Billyy, etc.)** — The more you install, the more scene variety you get (no crash without them).
- **OStim Community Resource (OCR)** — Provides the "kiss scene" (`OCR_FM_Kiss1`) played when reviving a Sweet Vassal to life. Without it, the kiss simply doesn't play and the target is revived directly; the mod still works fine.

## Installation
1. Install the required mods first (especially OStim NG) and confirm they work.
2. Install this mod with your mod manager (MO2 / Vortex).
3. **Pick your language in the installer (FOMOD)** — default is English. Choose Japanese to play in Japanese (works even on an English game). Leave it on English for English text.
4. Launch the game and check the MCM.

## Uninstall
Removing mods mid-playthrough isn't recommended in Skyrim, but if you must:
1. In MCM "Mod Config", turn succubus mode **OFF (become human)** — spells, perks, sigils, stat bonuses, vassals, etc. are removed.
2. **Save** in that state (ideally to a new slot).
3. Quit the game and remove this mod with your mod manager.
4. (Optional, for a cleaner removal) delete the data folder this mod created. A same-named folder in a different path belongs to another mod, so delete **only this one folder**:
   - `Data\SKSE\Plugins\StorageUtilData\ASuccubusTaleR2\` (all of it — `Records.json` = lifetime records / `Config.json` = settings backup)
   - Note: with **MO2**, this is usually inside **overwrite**, not the game's `Data` (`overwrite\SKSE\Plugins\StorageUtilData\ASuccubusTaleR2\`).
5. (Optional) In your **SKSE log folder** (the location from "How to Report a Bug" — shown under **File location** in the MCM), this mod may leave the following files. Delete them if you like (fine to leave them, too):
   - `ASTR2SKSE.log` (SKSE plugin log) / `ASTR2_BugReport.txt` (if you generated a bug report) / `ASTR2_CatalogDump.txt` (scene catalog)

## How to Play
### Getting started (becoming a succubus)
- **Start a new game and, on your first play with that save, a popup asking "Will you become a succubus?" appears automatically.** Accept it to awaken as a succubus.
- **If the popup doesn't appear, or you want to switch later, you can toggle succubus mode anytime from the MCM trigger.**

### What happens when you turn it off (become human)
Turning succubus mode OFF **does not discard your progress** — turn it back on and everything returns.
- **Kept (survives becoming human):** succubus level, XP, all records (lifetime totals, drain amounts, per-target records), servant relationships.
- **Temporarily off while human (returns when you re-awaken):** level-scaled stats (max Magicka/Health/Stamina, regen, Speech), skill-XP bonuses, succubus spells, sigil display, drain on-state. Current Essence resets to its default (400).

### Spells & abilities (by learn level)
| Lv | Spell (display name) | Type | Effect |
|---|---|---|---|
| 1 | Succubus Drain | Drain | Siphons a target's health into your Essence |
| 1 | Whisper Seduction | Charm (single) | Fills a target with desire, charming them |
| 1 | Servant Sync | Support | Pulls the game's own relationship rank into the servant bond |
| 2 | Arousing Lust | Support | Strengthens your next drain and primes them for charm |
| 2 | Create Shard | Craft | Seals Essence & Magicka into a crystal "Essence Shard" (★5 sizes) |
| 2 | Distill Essence | Craft | Distills a "Sweet Elixir" from Essence & Magicka (★5 sizes; stocks power "embers") |
| 2 | Nightmare Embrace | Special | Visits a sleeping target in their dream (success scales with level) |
| 2 | Sweet Vassal | Raise / Summon | Raises the dead as your vassal. **Lv2+ as a reanimated thrall; from Lv9 as a living being** |
| 2 | Ember Essence | Passive | Shows your stocked "ember" count (no casting; embers give extra power uses) |
| 3 | Consume Essence | Restore | Spends Essence to heal your wounds |
| 4 | Unleashed Fury | Buff (on/off) | Spends Essence per second to boost skills, magic resist, and damage reduction (recast to end) |
| 5 | Succubus Charm | Command | Temporarily turns a target into an ally (not beasts / existing followers) |
| 6 | Area Seduction | Charm (area) | Charms nearby targets at once |
| 7 | Succubus Weakness | Debuff | Carves a weakness, lowering magic resist (also raises drain power during OStim scenes) |
| 8 | Mass Seduction | Charm (mass) | Charms a wide area centered on you |
| 9 | Essence Flow | Restore (on/off) | Channels Essence to keep healing you as long as it flows |
| 9 | Reviving Grace ※conditional | Revive | Revives a reanimated vassal as a living being (learned at Lv9 while holding a fully-matured one) |
| 10 | Ravenous Drain | Drain (area) | Voraciously siphons the health of everyone around you into your Essence |

**Other abilities (auto-granted, no casting)**
- **Succubus Soul** — Raises max Magicka/Health/Stamina, regen, and Speech with level (level-scaled stats). Separate from the 18 above (a behind-the-scenes growth bonus, not shown in the spell list).

> ★"Multi-size" elements: **Essence Shard** (from Create Shard) and **Sweet Elixir** (from Distill Essence) each come in 5 sizes (Petty / Lesser / Common / Greater / Grand). **Seduction** has single / area / mass tiers. **Sweet Vassal** evolves from thrall to living being by level.

### Controls (hotkeys)
**No hotkeys are assigned by default.** Assign these in the MCM as you like:
- Show the Essence bar
- Show the XP bar
- Toggle drain on/off
- Show a target's HP bar

## MCM
- **Mod Config** — Toggle each feature (including the succubus-mode trigger)
- **Ability Config** — Sliders for power, cost, and growth rate
- **Status** — Level, Essence, passive buffs (max stats, regen, Speech, skill XP), records
- **Servants** — Your tamed NPCs listed by rank
- **Tattoo / Sigil** — Sigil display settings (self / NPCs)
- **H-Skills** — Proficiency per act
- **Debug** — Generate a bug-report file and other diagnostics
- Player settings support Export/Import (less re-setup on a new game)

## Known Issues / Notes
- **A scene may crash if an enemy walks up and attacks after it starts.** Scenes are guarded from starting while in combat or with enemies nearby, but **enemies that walk in after a scene has begun** aren't handled — a native crash can occur the moment such an enemy's attack lands on a scene actor. (Best used in private spots.)
- **Mixing in an old OStim version can cause freezes during scenes** → update OStim to the tested version (7.5.1b or newer).
- **Quest-critical NPCs cannot be raised by Sweet Vassal** (to prevent vanilla-script runaway and save corruption).
- **On Sweet Vassal (living) + a follower-management mod:** if you revive an NPC and then make them a follower with a separate follower-management mod, and that NPC is a **wild (normally hostile) one such as a bandit**, they **might reappear as an ally** at their usual respawn. **The cause isn't fully identified yet** (an interaction with follower-management mods is suspected but not confirmed). If it bothers you, go easy on reviving such wild NPCs and turning them into followers with other mods.

## How to Report a Bug
If you run into a problem, generating a diagnostic file from the MCM helps pin down the cause quickly.
1. Open the MCM → **Debug** page.
2. Press **Execute** on **Generate Bug Report**.
3. `ASTR2_BugReport.txt` is created in your **SKSE log folder**. **The exact path is shown under File location in the MCM right after you press it** (the folder name varies by setup, so check there).
4. Send that file along with a description of the problem (what you were doing when it happened).

It contains only what's needed to diagnose: your succubus state (awakened / level / Essence), key settings (body detection, etc.), the OStim version, and **which required mods are loaded** — no personal data.
Note: for a crash (CTD), please also attach a crash log (generated by Crash Logger SSE, etc., if you have one installed).

## Compatibility
This mod was **developed for the author's personal use and released as-is**, so **compatibility and conflicts with other mods aren't extensively tested**. It's built to coexist with OStim-family mods, but isn't guaranteed to work in every setup. If you suspect a conflict, isolate your environment to check (bug reports are welcome).

**Game version:** this mod supports both **1.6.1170** and **1.7.104** (the same file works on either). **1.6.1170** remains the recommended version. **1.7.104** has been checked in-game, but not thoroughly tested — if you run into a bug, a report would be appreciated. For prerequisite mods (OStim / SKSE / Address Library, etc.), use the versions listed in Requirements below for **1.6.1170**, and versions matching your setup for **1.7.104**.

## Planned for 1.2.0
The next update (1.2.0) is planned to add:
- **UBE body sigil support** — extend the sigil (lust mark), currently supporting 3BA bodies, to UBE bodies.
- **Healing magic tweaks** — rework how healing magic behaves.
- **Dual-cast power & cost tuning** — adjust the power and the Magicka / Essence cost when dual-casting.

*Contents and timing may change.*

## Credits / License
- **Respect to the originals:**
  - **A Succubus Tale** (original concept & author **CaptainHubs**)
  - **A Succubus Tale - Remake** (author **ShMinitmMan** / [Nexus mods/107235](https://www.nexusmods.com/skyrimspecialedition/mods/107235))
  - This mod was born from deep respect for these works. It is made and released **crediting the original author ShMinitmMan, within the "modification / improvement" permitted on the original's page** (Nexus permissions allow credited modification and re-upload).
- **The OStim NG team** — gratitude and respect for the wonderful OStim foundation.
- **Collaborating community:** everyone in the **NonbiriSkyrim** community (representative: **kota**) — heartfelt thanks for testing, information, and advice.
- **Libraries used:** CommonLibSSE-NG (MIT), OStim (GPL-3.0)
- **License:** distributed under **GPL-3.0** (due to OStim). Modification and redistribution are free as long as GPL-3.0 is followed (source must be made available). **The mod's source code is published on GitHub**: https://github.com/Nyannco/A-Succubus-Tale-R2 ★**If you build something on top of ASTR2, a quick heads-up to the author would be appreciated** (a request, not an obligation).
- Note: **Donation Points are disabled.** The original's permissions require the author's approval to earn Donation Points on a mod that uses the original's assets, and no reply has been received, so they're left off to be safe.
