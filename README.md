# Open Hyper AI Ch1 (OHA.Ch1) - Dota 2 Bot Scripts

**The most feature-rich custom bot script for Dota 2.** Play against bots that actually fight, farm, push, and use items intelligently.

> **To play:** Install this fork's `bots` folder, create a **Custom Lobby**, select **Local Host**, and select **Local Dev Script** for both teams. Generated bot names end with **".OHA.Ch1"**. The local lobby menu entry remains **Local Dev Script**.

[Upstream Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3246316298) | [GitHub](https://github.com/Ch1swill/dota2bot-OpenHyperAI) | [Feature Requests](https://github.com/Ch1swill/dota2bot-OpenHyperAI/issues?q=is%3Aissue+is%3Aopen+%5BFeature+request%5D)

![Screenshot](asset/images/steam-profile-screenshot.jpg)

---

## What Makes This Different

- **127 heroes supported** on Patch 7.41/7.41a - including Largo, Kez, Ringmaster, Invoker, Techies, Meepo, Lone Druid, and more
- **Bots actually play the game** - they lane, gank, push towers, defend, farm jungle, take Roshan, and use active items
- **Dynamic difficulty (FretBots mode)** - bots get unfair bonuses that scale with difficulty for a real challenge
- **Bots communicate** - they announce pushes, defends, Roshan, and respond to your pings with "On my way!" (in 4 languages)
- **10+ Game modes supported** - All pick, Turbo, All random, Captain mode, 1v1 mid, All Random Deathmatch, etc.
- **Customizable everything** - bot names, roles, hero picks, bans, item builds, skill builds, and more
- **AI Chatbot** - bots chat like real (toxic) players (requires FretBots mode)
- **All roles supported** - deterministic position 1-5 lane assignment

---

## Quick Start

1. Copy this fork's `bots` folder into `<Dota 2>/game/dota/scripts/vscripts/bots`, backing up existing scripts first.
2. Create a **Custom Lobby** with **Local Host** server.
3. Select **Local Dev Script** for both Radiant and Dire bots. The upstream Workshop entry loads the upstream version.
4. Start a new game - bots auto-pick and play.

### Automatic FretBots startup

After copying the `bots` folder, run this installer once from the repository root
in PowerShell, using your Dota 2 installation path:

```powershell
.\tools\install-fretbots-autostart.ps1 -DotaRoot 'D:\steam\steamapps\common\dota 2 beta'
```

It backs up the existing server initialization script, preserves its contents,
and adds the Ch1 startup hook and loader. Each new **Local Host** bot game on the
standard Dota map automatically runs `sv_cheats 1; script_reload_code bots/fretbots`
once after hero selection begins and bot slots are available. No per-game console
command is needed. If bots join after the initial selection/spawn events, an
independent server thinker checks every 0.5 seconds until startup is ready, then
removes itself. Re-running the installer updates the hook without duplicating it.

Set `Customize.Fretbots.Auto_Start = false` in your active `Customize/general.lua`
to disable automatic startup. If the setting is absent in an existing customization,
startup defaults to enabled. Dedicated servers, hero demo maps, and games without
bots do not run the command. If a Dota update replaces `game/gameinit.lua`, run the
installer again. FretBots difficulty and voting settings work as before.

For more about **FretBots mode** (harder bots, neutral items, chatbot):
[Upstream installation guide](https://github.com/forest0xia/dota2bot-OpenHyperAI/discussions/68)

---

## In-Game Commands

| Command | Description |
|---|---|
| `!pos X` | Swap your role with a bot (e.g., `!pos 2` for mid) |
| `!Xpos Y` | Reassign bot positions (e.g., `!3pos 5` = 3rd bot plays pos 5) |
| `!pick HERO` | Pick a hero (`!pick sniper`, or `/all !pick sniper` for enemy) |
| `!ban HERO` | Ban a hero from being picked |
| `!sp XX` | Set bot language (`en`, `zh`, `ru`, `ja`) |

Use [internal hero names](https://github.com/forest0xia/dota2bot-OpenHyperAI/discussions/71) if short names overlap (e.g., `!pick npc_dota_hero_keeper_of_the_light`). Batch commands work too: `!pick io; !ban sniper`.

### Ping orders

Ping directly on the target or its location. Allied bots prioritize the latest
human teammate's order at any distance:

| Ping location | Allied bot behavior |
|---|---|
| Empty ground, ordinary ping | Gather within 500 units |
| Visible enemy hero | Focus the hero; follow while visible |
| Roshan or the current Roshan pit | Travel to the pit and attack Roshan if present |
| Enemy tower | Push that tower; clear nearby enemy lane creeps while protection blocks attacks |
| Allied tower or allied hero | Approach and fight nearby enemy heroes and lane creeps |

A new target or ordinary ground ping replaces the previous order. Heroes lost
in fog are searched for briefly at their last seen position. Bots leave confirmed
empty pits and release defense after 15 seconds without a nearby attackable
threat. Temporarily blocked targets are approached, with a bounded wait if they
remain unattackable. Empty-ground warning pings do not create orders.

---

## Bot Roles & Positioning

Lobby slot order = position assignment (1-5):

| Position | Lane |
|---|---|
| Pos 1 (Carry) + Pos 5 (Hard Support) | Safe Lane |
| Pos 2 (Mid) | Mid Lane |
| Pos 3 (Offlane) + Pos 4 (Soft Support) | Offlane |

Customize picks, bans, and roles in [Customize/general.lua](bots/Customize/general.lua).

---

## Customization

| What | Where |
|---|---|
| General settings (picks, bans, names, roles) | [Customize/general.lua](bots/Customize/general.lua) |
| Per-hero settings (items, skills) | [Customize/hero/viper.lua](bots/Customize/hero/viper.lua) |
| FretBots difficulty tuning | [FretBots/SettingsDefault.lua](bots/FretBots/SettingsDefault.lua) |

**Permanent customization** (survives Workshop updates): Copy the `Customize` folder to `<Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/game/Customize>`.

---

## Game Modes

Supports most game modes (10+) . See [full compatibility discussion](https://github.com/forest0xia/dota2bot-OpenHyperAI/discussions/72).

---

## Offline / LAN Play

You can start a bot game directly from the console without network or clicking UI buttons — useful for offline play, LAN parties, or quick testing. See [play offline setup guide](https://github.com/forest0xia/dota2bot-OpenHyperAI/discussions/135).

---

## Developer Documentation

This project uses [Claude Code](https://claude.ai/claude-code) for AI-assisted development. The [CLAUDE.md](CLAUDE.md) file provides task-specific instructions for common operations like patch updates, hero fixes, and adding new heroes.

### Key Docs

| Document | Description |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Complete codebase architecture, file map, naming conventions, all systems explained |
| [docs/PATCH_UPDATE_GUIDE.md](docs/PATCH_UPDATE_GUIDE.md) | Step-by-step runbook for updating when a new Dota 2 patch drops |
| [docs/BOT_API_REFERENCE.md](docs/BOT_API_REFERENCE.md) | Comprehensive Valve bot scripting API reference with examples |
| [CLAUDE.md](CLAUDE.md) | AI coding assistant guide - common tasks, rules, and workflows |

### Internal Name References

Dota 2 bot scripts use internal code names for heroes, items, and abilities. These are different from the display names you see in-game. When updating builds or fixing bugs, always verify against authoritative sources:

| Resource | What It Contains |
|---|---|
| [Liquipedia Cheats Page (Item Names)](https://liquipedia.net/dota2/Cheats) | Authoritative list of `item_*` internal names for all items including neutral items |
| [d2vpkr npc_abilities.txt](https://raw.githubusercontent.com/dotabuff/d2vpk/master/dota_pak01/scripts/npc/npc_abilities.txt) | All ability internal names and KV data |
| [Dota 2 Patch Data API](https://www.dota2.com/datafeed/patchnoteslist?language=english) | Official patch notes in machine-readable format |
| [Modifier Names (Valve Wiki)](https://developer.valvesoftware.com/wiki/Dota_2_Workshop_Tools/Scripting/Built-In_Modifier_Names) | `modifier_*` names for buff/debuff detection |

### Project Structure

```
root: <Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts>
|
+-- bots/                  All bot Lua scripts
|   +-- hero_selection.lua     Hero picking/banning
|   +-- bot_generic.lua        Per-bot entry point
|   +-- ability_item_usage_generic.lua   Ability/item usage for all heroes
|   +-- item_purchase_generic.lua        Item purchase state machine
|   +-- mode_*_generic.lua     Mode scripts (farm, push, defend, roam, etc.)
|   +-- mode_assemble_generic.lua        Human ping response
|   |
|   +-- BotLib/            Per-hero builds (items, skills, ability logic)
|   |   +-- hero_axe.lua, hero_crystal_maiden.lua, ...
|   |
|   +-- FunLib/            Core libraries and utilities
|   |   +-- jmz_func.lua      Main utility library
|   |   +-- aba_item.lua      Item system
|   |   +-- aba_skill.lua     Skill/ability system
|   |   +-- aba_push.lua      Push logic
|   |   +-- aba_defend.lua    Defend logic
|   |   +-- localization.lua  Chat translations (en/zh/ru/ja)
|   |
|   +-- FretBots/          Enhanced difficulty mode
|   |   +-- SettingsDefault.lua    Difficulty tuning
|   |   +-- SettingsNeutralItemTable.lua   Neutral items + enchantments
|   |
|   +-- Customize/         User-editable settings
|       +-- general.lua    Team-level settings
|       +-- hero/          Per-hero overrides
|
+-- typescript/            TypeScript source for TS-generated Lua files
|   +-- bots/              TS versions (compiled to bots/ via tstl)
|   +-- post-process/      Post-compilation scripts
|
+-- game/                  Valve defaults + permanent customization location
|   +-- Customize/         Copy your Customize/ here to survive updates
|
+-- docs/                  Developer documentation
    +-- ARCHITECTURE.md
    +-- PATCH_UPDATE_GUIDE.md
    +-- BOT_API_REFERENCE.md
```

---

## Contribute

- Contributions welcome on [GitHub](https://github.com/forest0xia/dota2bot-OpenHyperAI)
- Custom item/skill builds don't need PRs - just tweak locally
- Future development is in **TypeScript** for better maintainability
- [Open feature requests](https://github.com/forest0xia/dota2bot-OpenHyperAI/issues?q=is%3Aissue+is%3Aopen+%5BFeature+request%5D)

---

## What's Next

- Current bot playstyle is limited by Valve's API. **We need ML/LLM bots like OpenAI Five!**
- Planned improvements:
  - Smarter laning, pushing, ganking
  - Stronger spell casting (Invoker, Rubick, Morphling, etc.)
  - Better support for bugged heroes (Dark Willow, IO, Lone Druid, Muerta, etc.)
  - Full game mode support + ongoing patch fixes
- [Feedback to Valve Dota2 bot team](https://www.reddit.com/r/DotA2/comments/1ezxpav/)

---

## Useful Resources

| Resource | Description |
|---|---|
| [Dota2 AI Development Tutorial](https://www.adamqqq.com/ai/dota2-ai-devlopment-tutorial.html) | Comprehensive guide by adamqqq |
| [Valve Bot Scripting Intro](https://developer.valvesoftware.com/wiki/Dota_Bot_Scripting) | Official Valve documentation |
| [Lua Bot APIs (moddota)](https://docs.moddota.com/lua_bots/) | Community API docs |
| [Liquipedia Cheats (Internal Names)](https://liquipedia.net/dota2/Cheats) | Item/hero/ability code names |
| [npc_abilities.txt](https://raw.githubusercontent.com/dotabuff/d2vpk/master/dota_pak01/scripts/npc/npc_abilities.txt) | Ability metadata |
| [Enums & APIs (moddota)](https://moddota.com/api/#!/vscripts/dotaunitorder_t) | Enum reference |
| [Modifier Names](https://developer.valvesoftware.com/wiki/Dota_2_Workshop_Tools/Scripting/Built-In_Modifier_Names) | Buff/debuff modifier names |

---

## Support

- Contribute on GitHub
- Or [buy me a coffee](https://github.com/forest0xia/dota2bot-OpenHyperAI/discussions/74)

---

## Credits

Built on top of Valve's default bots + contributions from many talented authors:

- New Beginner AI ([dota2jmz@163.com](mailto:dota2jmz@163.com))
- Tinkering About ([ryndrb](https://github.com/ryndrb/dota2bot))
- Ranked Matchmaking AI ([adamqqq](https://github.com/adamqqqplay/dota2ai))
- fretbots ([fretmute](https://github.com/fretmute/fretbots))
- BOT Experiment (Furiospuppy)
- ExtremePush ([insraq](https://github.com/insraq/dota2bots))
- And all other contributors who made bot games better
