# Glitch RNG — notes for Claude

Roblox aura-RNG game (like Sol's RNG) in a cyber / hacker / glitch theme. Luau + Rojo.
Reply to the user in Russian; in-game text is English. User's rule: **quality + detail**, nothing minimal.
Agents: at most 2 at a time, effort medium.

## Build
- `./tools/check.sh` — luau-lsp type check (must be clean).
- `./tools/build.sh` → `build/GlitchRNG.rbxlx`. Send that file to the user after every change (SendUserFile, attach).
- Git: branch `glitch-rng`; commit after every round of changes (user asked "делай гиты").

## Layout
- `src/shared/Config.lua` — ALL game data: palette, tiers (cutscene level 0..5), 40 auras (chance = 1 in N,
  optional biome), biomes, rigs (hand gear, crafted from auras), scripts (boost consumables), roll settings.
- `src/shared/RNG.lua` — roll algorithm (rarest→common, hit = luck/chance), formatting.
- `src/shared/AuraFX.lua` — client VFX: Attach(char, auraId), AttachRig(char, rigId), Burst(pos, auraId, scale).
- `src/shared/Sounds.lua` — sound ids by name (empty = silent).
- Server: `Main.server.lua` (remotes Request/Push, actions Roll/Equip/CraftRig/EquipRig/CraftScript/UseScript/Setting/Hello,
  Studio-only DebugBiome/DebugGive), `Data.lua` (DataStore + session lock), `Biome.lua` (ReplicatedStorage attrs Biome/BiomeEnds/BiomeNext),
  `Board.lua` (top rollers on map LeaderboardScreen), `Map.lua` (world built from parts at runtime).
- Client: `Main.client.lua`, `Ctx.lua` (Data, Changed, Request, Windows, Toast, Setting), `Roller.lua` (reel → Cutscene → reveal card),
  `Cutscene.lua` (tier cutscenes), `AuraRender.lua` (player attrs Aura/Rig → AuraFX), `Prompts.lua` (custom terminal prompts,
  attribute Kind Forge/Lab/Index), `Announce.lua`, `WorldFX.lua` (tag animation + biome lighting/weather), `Sfx.lua`,
  `UI/Kit.lua` (theme + panel/button/window helpers), `UI/Hud.lua`, `UI/Windows/*.lua` (each returns `function(): Kit.Window`;
  registered in Ctx.Windows by module name: Inventory, Index, Scripts, Settings, Forge, Lab).

## Audio
- `python3 tools/sfx.py [Names...]` synthesizes all sounds (numpy + ffmpeg, helpers in tools/audio/) → `build/sfx/*.ogg`.
- `python3 tools/upload_sounds.py` uploads them as Audio to group 34355563 and writes ids into Sounds.lua.
  Ask the user before uploading.

## Status (2026-11-04)
Playtested in Studio: server/rolls/biomes/cutscene/auras/windows all run without errors (map = 28.7k parts). All 25 sounds uploaded to group 34355563 (ids in Sounds.lua, build/sfx/ids.json).

## Studio testing (no mouse!)
- `python3 tools/reload.py [files]` pushes src/*.lua into the open Studio place (edit mode).
- `cd tools && python3 playtest.py <sec> - tests/smoke_client.lua` runs a playtest with client logs;
  `python3 tools/shot.py name --count N --every S` grabs Studio-window screenshots (run in background during play).
- The black square at the screen centre in screenshots is a Studio overlay (present even before/after play, not in game). Ignore it.
- Aura polish pass done 2026-11-04 (every aura has a sigil, root light, bigger silhouette; scale grows with tier).
- `tests/aura_gallery.lua` + `tools/gallery_sheets.py g <name>` = close-up of every aura → build/<name>_N.jpg.
