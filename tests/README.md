# Bot decision regression tests

Run from the repository root with Lua 5.1 or newer:

```sh
lua tests/turbo_push_regression.lua
lua tests/assemble_ping_regression.lua
lua tests/fretbots_autostart_regression.lua
lua tests/bkb_usage_regression.lua
lua tests/engagement_safety_regression.lua
```

If Lua is unavailable, use the temporary Fengari runner:

```sh
npx --yes --package=fengari-node-cli@0.1.0 fengari tests/turbo_push_regression.lua
npx --yes --package=fengari-node-cli@0.1.0 fengari tests/assemble_ping_regression.lua
npx --yes --package=fengari-node-cli@0.1.0 fengari tests/fretbots_autostart_regression.lua
npx --yes --package=fengari-node-cli@0.1.0 fengari tests/bkb_usage_regression.lua
npx --yes --package=fengari-node-cli@0.1.0 fengari tests/engagement_safety_regression.lua
```

The tests load the shipped Lua files with a simulated Dota bot API. They cover
empty Tormentor pits, stale teammate states, group counts, waiting deadlines and
retry cooldowns in Turbo and normal modes, active Tormentor combat, late-game
push desire, movement during a cache TTL, and the existing health, solo-push,
numbers and base-defense safety gates. An optional argument selects a different
`bots` directory, allowing the same scenarios to run against an older snapshot.

The assembly suite covers ground pings across the map, journeys beyond the ping
recency window, redirection, arrival, mode interruptions, multiple human slots,
respawning and action pauses. It also covers hero focus and loss of vision,
illusion filtering, protected and hidden towers, moving allied heroes, defense
leashes and completion, visible/unseen/absent Roshan, retasking, and the actual
hero ability-context helpers. Ground and target orders receive absolute mode
priority; empty-ground warning pings do not create assembly orders.

The bot Ping API exposes a location rather than a target entity ID. Target orders
choose the closest visible hero/objective within 250 units, with known tower
locations and the current Roshan pit as additional anchors. When targets overlap,
ping as close to the intended target's center as possible. Target recognition
accepts either reported ping flag; empty-ground collection requires a normal ping.

The FretBots startup suite loads the actual `game/gameinit.lua` hook and loader
with a simulated server API. It covers early startup, late player slots,
per-match/reentrant dispatch, script reloads, manual startup, opt-out settings,
client/bot/dedicated VMs, demo maps, human-only games, error handling, and cleanup.
It covers the `start` host map used by GC-created local lobbies, including early
initialization and late bot slots. These three cases fail with the old `dota`-only guard.
It also models late bot insertion without further events, native thinker startup
and removal, a nil custom-game mode entity on the standard map, and the higher
numeric IDs of map-loading/player-draft states. These reproduce gaps in the
original event-only startup logic.
Its optional argument selects a different `game` directory, including the installed
game scripts.

The BKB suite loads the full shipped `ability_item_usage_generic.lua` module and
calls its real `ItemUsageThink` entry point with a simulated bot API. It covers
spell/projectile defense outside attack/retreat modes, reflection/shield buffs,
close combat against two heroes, and deterministic BKB priority in all six
inventory positions. It also checks cooldowns, backpack/swap delays, invisibility,
existing immunity, disables and spell queues. No other item is suppressed when
BKB is unavailable or has no reason to activate. These are decision/dispatch
checks, not an in-engine reproduction of a particular hero diving into a team.
The optional argument selects a different `bots` directory for baseline checks.

The engagement suite loads the real safety module, `jmz_func`, waiting mode and
hero cast dispatchers. It covers a healthy solo dive, distant/unavailable backup,
arrival timing, gathered-team release, illusions/fog/clones, backing away, blocked
terrain, and guards for health, channels, queues, Rupture and forced combat.
All four Magnus blink combos and both Spirit Breaker initiation spells are
checked before queueing, with supported casts still allowed. Team roam's early
yield and Ping pause/resume are covered too. These are API simulations.

On 2026-10-17 an agent-owned offline game also loaded the actual waiting mode.
Temporary instrumentation observed one bot with one ready ally (itself) versus
two visible enemies in mode 19, then two ready allies versus two enemies in mode
1. This confirms native selection and release, rather than just calling Lua
GetDesire directly. A controlled server fixture did not complete; the engine
evidence came from the ordinary offline game. Temporary instrumentation and
fixtures were removed afterward. Specific hero combat in a Custom Lobby remains
an in-game validation item.

Run the installer checks in PowerShell:

```powershell
.\tests\fretbots_install_regression.ps1
```

They create a fake Dota installation under `node_modules/.cache` and verify that
initial installation, repeat installation, and replacement of an older hook
preserve existing initialization code, backups, line endings, and customization.

On 2026-10-15, the installed startup hook was also checked in the actual Dota 2
engine over two consecutive offline bot games in one client session (the second
launched with `map dota gamemode 23`). The VConsole driver selected a hero and
observed exactly one `Starting Fretbots mode` message and the welcome notification
per game. It did not send `sv_cheats` or a FretBots reload command. The original
late-insertion case failed before the fix; the startup suite now uses the native
state constants and a nil game-mode entity to preserve that coverage.

On 2026-10-17, a reproduction through **Play Dota → Custom Lobby → Create →
Local Host → Turbo** failed with the old map guard. After accepting the lobby's
`start` host map, two new lobbies in one normal client session each produced
exactly one automatic-dispatch message, one `Starting Fretbots mode` message,
the FretBots welcome notification and difficulty voting. No startup command was
entered through the console. The first lobby also reached pregame and completed
difficulty/ally-scale selection (2 / 0.5). This verifies startup, not the remaining
push/Ping gameplay checks below; the engine log also contained opaque script
runtime errors during pregame, without a traceback identifying their source.

For TypeScript changes, compile and regenerate `bots/FunLib/aba_push.lua` before
running the tests. The repository currently needs `npm ci --legacy-peer-deps`
because its locked TSTL and TypeScript peer versions differ.

These tests do not run the game engine. Verify in a Turbo local lobby that:

- With the startup installer applied, start a new **Local Host** game with bots
  and select **Local Dev Script** for both teams. FretBots starts once after hero
  selection begins without a console command, and its difficulty/voting setup
  appears as before. Repeat with a second new match to check startup again.
  In an offline bot game, select your hero so the engine creates the bot slots;
  startup should follow without waiting for another state transition.
- A healthy, formed group progresses along a lane after 18 minutes when its team
  is not outnumbered and its Ancient is safe.
- Bots leave an empty Tormentor pit after observing that the objective is gone.
- Bots stop waiting for an incomplete Tormentor group after 45 seconds (90 seconds
  in normal mode), and may try again after a 60-second retry cooldown.
- Active Tormentor combat continues, and bots still defend their base or retreat
  when their health or numbers make pushing unsafe.
- An allied human's ordinary ground ping brings bots from across the map, even
  when the journey takes more than a few seconds. A newer ground ping changes
  their destination, and they return to other activities within 500 units of it.
- A visible enemy hero ping makes bots attack the hero, including ability use;
  loss of vision sends them only to the last seen location and ends the search
  after eight seconds there.
- An enemy tower ping initiates a push, including when the tower is initially
  hidden/protected; an allied tower or hero ping sends defensive support. Defense
  ends after 15 quiet seconds and does not chase attackers beyond the anchor area.
- A Roshan/pit ping makes bots approach and attack the present Roshan, and a
  confirmed empty pit or dead objective releases the order.
- A ready BKB in an active slot responds to an incoming spell while pushing,
  defending or following a ground ping, including under Lotus reflection or a
  spell shield. In close combat against two visible heroes it takes priority
  over ordinary items. Check hero-specific initiation queues separately: this
  BKB change preserves those queues; engagement checks apply before initiation.
- A healthy bot approaching multiple visible enemies waits for actual support.
  Teammates gathering nearby or arriving at the fight release the wait; teammates
  who are far away, retreating or disabled do not. A single enemy remains eligible
  for a solo pickoff. Ping orders resume after waiting, and Magnus/Spirit Breaker
  do not initiate into an unsupported group.
