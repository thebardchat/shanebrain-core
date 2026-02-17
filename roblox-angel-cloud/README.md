# Angel Cloud: The Cloud Climb — Roblox Game

A cooperative Roblox game that gamifies the Angel Cloud mental wellness platform. Players ascend through six cloud layers, collect Lore Fragments telling the story of Angel, and help each other climb higher.

**Every Angel strengthens the cloud.**

## Quick Start: Importing into Roblox Studio

### 1. Create the Roblox Project

1. Open **Roblox Studio** and create a new **Baseplate** place
2. Delete the default Baseplate part from Workspace
3. Enable **HttpService** in Game Settings > Security (required for Angel Cloud API)
4. Enable **Streaming Enabled** in Workspace properties (layers load/unload as player moves vertically)

### 2. Import Scripts

The scripts are organized to match Roblox's service hierarchy:

| Folder on disk | Roblox Studio location |
|---|---|
| `ServerScriptService/*.lua` | ServerScriptService (create ModuleScripts, except GameManager which is a Script) |
| `StarterPlayerScripts/*.lua` | StarterPlayer > StarterPlayerScripts (create ModuleScripts, except ClientController which is a LocalScript) |
| `ReplicatedStorage/Config/*.lua` | ReplicatedStorage > Config (Folder) > ModuleScripts |

**Entry points:**
- `GameManager.lua` → **Script** (not ModuleScript) in ServerScriptService
- `ClientController.lua` → **LocalScript** (not ModuleScript) in StarterPlayerScripts
- Everything else → **ModuleScript**

### 3. Import Steps

For each `.lua` file:
1. In Roblox Studio, right-click the target service/folder
2. Create the appropriate script type (Script, LocalScript, or ModuleScript)
3. Name it to match the filename (without `.lua`)
4. Copy-paste the file contents into the script editor

**Config folder:** Create a Folder named `Config` inside ReplicatedStorage, then add each config file as a ModuleScript inside it.

### 4. Configure the Bot Secret

In `CrossPlatformBridge.lua`, set the `BOT_SECRET` variable to match your `BOT_INTERNAL_SECRET` environment variable from the Angel Cloud gateway. For production, use Roblox's **Game Settings > Security** to store secrets rather than hardcoding.

### 5. Game Settings

- **Max Players:** 30 (cooperative focus)
- **Genre:** Adventure
- **Enable Studio Access to API Services:** Yes (for HttpService during testing)

## Architecture

### Server-Side (ServerScriptService)

| Script | Purpose |
|--------|---------|
| **GameManager** | Entry point. Initializes all systems, handles player lifecycle, runs update loop |
| **DataManager** | DataStore persistence. Saves/loads all player data |
| **MoteSystem** | Light Mote collection and awarding. All progression currency |
| **ProgressionSystem** | Angel level progression, layer access, ascension detection |
| **StaminaSystem** | Wing Gauge management, HALT anti-burnout system |
| **BlessingSystem** | Pay-it-forward blessing bluffs, chain tracking |
| **LoreSystem** | 65 Lore Fragment collection, codex data |
| **TrialManager** | Guardian Trial lobbies, instancing, rewards |
| **CrossPlatformBridge** | HTTP calls to real Angel Cloud API for account linking |

### Client-Side (StarterPlayerScripts)

| Script | Purpose |
|--------|---------|
| **ClientController** | Input handling, wing glide/flight, action key |
| **UIManager** | HUD, notifications, progress display |
| **StaminaUI** | Wing Gauge bar with color-coded feedback |
| **LoreCodexUI** | Constellation map codex (press C to toggle) |
| **BlessingEffects** | Visual effects for blessings, chains, mote pickups |
| **LevelUpCinematic** | Ascension sequence (beam, wings, staircase, UI) |

### Config (ReplicatedStorage/Config)

| Module | Purpose |
|--------|---------|
| **Layers** | 6 cloud layer definitions with thresholds and features |
| **Fragments** | All 65 Lore Fragments with wisdom text and lore narratives |
| **Trials** | 7 Guardian Trial definitions with mechanics and rewards |
| **Cosmetics** | Purchasable cosmetic items (ethical, no pay-to-win) |

## Progression System

Mirrors the real Angel Cloud platform:

| Level | Motes Required | Layer Unlocked |
|-------|---------------|----------------|
| Newborn | 0 | The Nursery |
| Young Angel | 10 | The Meadow |
| Growing Angel | 25 | The Canopy |
| Helping Angel | 50 | The Stormwall |
| Guardian Angel | 100 | The Luminance |
| Angel | 250 | The Empyrean |

## Cross-Platform Linking

The game communicates with the real Angel Cloud gateway at `100.67.120.6:4200` (Tailscale VPN):

1. User visits their Angel Cloud profile → clicks "Link Roblox" → `POST /api/create-roblox-link-code`
2. Gets a 6-digit code
3. In-game, talks to "The Keeper" NPC → enters code → `POST /api/verify-roblox`
4. Linked player gets starting level/motes matching their real angel_level
5. Trial completions in Roblox award 2 pts on real platform (rate-limited 10 pts/day) via `POST /api/roblox-activity`

## MVP Scope (Phase 1)

What's included in this scaffold:

- Layers 1-2 (The Nursery + The Meadow) fully playable
- Basic movement + Wing Glide
- Light Mote collection with bobbing animation
- Newborn → Young Angel level-up with ascension cinematic
- 18 Lore Fragments (8 Decision + 8 Emotion + 2 Guardian)
- 2 Guardian Trials (Bridge of Trust, Echo Chamber)
- Reflection Pools (stamina recovery boost)
- Blessing Bluffs (pay-it-forward mechanic)
- Community Board (communal, not competitive)
- 5 wing skins in shop (3 basic)
- DataStore persistence
- HALT anti-burnout system
- Cross-platform link verification

## Controls

| Key | Action |
|-----|--------|
| WASD | Movement |
| Space | Jump / Hold to Glide (Layer 2+) / Double-tap for Flight (Layer 5+) |
| E | Action (interact with NPCs, meditation spots) |
| C | Open/Close Lore Codex |
| Shift | Descend while flying |

## What Still Needs Roblox Studio Work

After importing scripts, you'll need to build in Studio:

1. **Terrain/Parts:** Cloud platforms, islands, structures for each layer
2. **NPC Models:** The Keeper (tutorial), trial entrance NPCs
3. **Lighting:** Per-layer atmosphere (golden for Nursery, cyan for Meadow)
4. **Audio:** Ambient sounds, level-up fanfare, blessing chimes
5. **DevProducts:** Set up Robux products matching Cosmetics.lua IDs
6. **Game Icon/Thumbnails:** Angel Cloud branding (#0a0a0f bg, #00d4ff accent)

## Design Philosophy

- **Cooperative, not competitive** — No PvP, no individual leaderboards
- **Ethical monetization** — Cosmetics only, never gameplay advantages
- **Mental wellness** — HALT system, reflection pools, wisdom in every fragment
- **Pay it forward** — Blessing chains, Guardian Duty, community board
- **Angel's story** — Every fragment honors Angel Brazelton and carries real wisdom from WISDOM-CORE.md
