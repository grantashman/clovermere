# Clovermere

> A quiet life, shared.

Clovermere is an **original desktop-first Godot game**. The native client under [`desktop/godot`](./desktop/godot) is the sole supported release path and the canonical product target. The GitHub repository is now [`grantashman/clovermere`](https://github.com/grantashman/clovermere); the former `hobbit-moon` slug is retained only in historical save keys and legacy reference material.

## Desktop release

The current Windows test build is published on [GitHub Releases](https://github.com/grantashman/clovermere/releases). Download the latest `windows-x86_64.zip`, extract it, and run `Clovermere.exe`. Windows SmartScreen may show an unsigned-app warning while this remains an early test build.

The native client currently includes:

- Deterministic 240×160 explorable world with varied terrain, material-edge shading, organic life, landmarks, pixel-grid roads, six live residents, and authored settlement buildings.
- Interactive timber, stone, ore, and herb nodes with persistent cut/mined/gathered world states and warm world-space lantern/player lighting.
- First-day loop: Day 1 at 08:00, timed work actions consume time and energy, materials enter a persisted carried pack, sleep at Greenbriar Cottage deposits the pack into home stores, and herbs regrow overnight.
- Tinker Workshop material sink: three persisted recipes consume field-pack materials; sleeping at Greenbriar Cottage stores the pack, and the Field Pack can return home stores at the cottage. Tinker’s Kit (3 timber + 2 stone + 1 ore) reduces work energy costs by 20%; Wayfarer’s Satchel (5 timber + 2 herbs) reduces work time by 20%; Hearthward Charm (2 stone + 2 herbs + 3 ore) raises the daily energy reserve to 115.
- Traditional PC-game HUD redesign: compact status card, carried/home-store ledger, toggleable pack and recipe panels, keyboard-accessible action bar, and a full-world minimap in an original forest/timber/parchment/brass pastoral high-fantasy visual language.
- Live resident layer: six role-specific NPC actors follow deterministic morning/work/evening/night schedules with route movement, idle/walk motion, role props, work-tool swings, impact sparks, and offset directional shadows.
- Authored central-crossing benchmark layer with stronger building contact shadows, cottage/workshop props, crossing accents, and clock-driven cooler evening ambient lighting.
- First authored benchmark asset pack: hand-built pixel PNGs for Greenbriar Cottage, Tinker Workshop, Clovermere Hall, Herbalist's Garden, Old Barn, the crossing tree, boulder, foxglove patch, player, and two central residents, all using a locked Clovermere palette.
- Living resource states: authored tree stumps/debris, tree sprout/young stages, stone fractures, ore crystals, harvested herb stems, active-work pulses, herb regrowth sprouts, water shimmer, foliage sway, and restrained evening fireflies.
- Persistent resource recovery: tree work moves through felled → sprout → young → restored over three sleeps; stone and ore recover over two sleeps; herbs retain next-day restoration. Recovery stage and timing are saved separately from the legacy `world_changes` flags.
- Terrain foundation pack: sparse grass variants, a woodland pocket, a Foxglove soil pocket, connectivity-selected path straights/corners/T-junctions/crossings, and registered water/bank transition tiles. The central terrain pass is composited into one texture; distant terrain remains procedural and cached.
- Collision-safe keyboard movement and mouse click-to-move pathfinding.
- Contextual building interaction, target markers, camera tracking, and 50%–200% zoom.
- Field-notes loading and welcome screens before gameplay.
- Fullscreen-first desktop window behavior with `F11` toggle.
- Pause menu with explicit Save Journey and Load Journey actions.
- Persistent Options page for fullscreen, crisp pixel filtering, starting zoom, and launch metrics.
- Save schema 7 with migration from schemas 5 and 6; resource recovery timing is persisted in `resource_states` while legacy `world_changes` flags remain compatible.
- Cached world rendering with verified steady-state performance above the 45 FPS acceptance threshold on the development host; the native-v0.10.0 recovery slice measured 52 FPS under Xvfb.

## Local Godot commands

```bash
# Run the deterministic world/save contract
godot --headless --path desktop/godot --script res://tests/world_contract_test.gd

# Run the deterministic resource destruction/regrowth contract
godot --headless --path desktop/godot --script res://tests/regrowth_state_test.gd
godot --headless --path desktop/godot --script res://tests/regrowth_smoke.gd

# Day-state contract: clock, energy, inventory, sleep, and regrowth
godot --headless --path desktop/godot --script res://tests/day_state_test.gd

# Storage, recipes, minimap, and traditional PC HUD contracts
godot --headless --path desktop/godot --script res://tests/storage_recipe_test.gd
godot --headless --path desktop/godot --script res://tests/minimap_test.gd
godot --headless --path desktop/godot --script res://tests/gameplay_hud_test.gd

# Run NPC schedule and actor contracts
godot --headless --path desktop/godot --script res://tests/npc_schedule_test.gd
godot --headless --path desktop/godot --script res://tests/npc_actor_test.gd

godot --headless --path desktop/godot --script res://tests/player_scale_test.gd

# Run art asset, timed work, feedback, workshop, and benchmark contracts
godot --headless --path desktop/godot --script res://tests/art_asset_pack_test.gd
godot --headless --path desktop/godot --script res://tests/facade_asset_test.gd
godot --headless --path desktop/godot --script res://tests/terrain_asset_test.gd
godot --headless --path desktop/godot --script res://tests/work_action_test.gd
godot --headless --path desktop/godot --script res://tests/work_feedback_smoke.gd
godot --headless --path desktop/godot --script res://tests/workshop_upgrade_test.gd
godot --headless --path desktop/godot --script res://tests/benchmark_scene_test.gd
godot --headless --path desktop/godot --script res://tests/terrain_benchmark_test.gd

# Verify click-to-move and building interaction
godot --headless --path desktop/godot --script res://tests/mouse_input_smoke.gd

# Verify resource work, save/load, and the first-day loop
godot --headless --path desktop/godot --script res://tests/day_loop_smoke.gd

# Verify live NPC creation, schedule transitions, and movement
godot --headless --path desktop/godot --script res://tests/npc_live_smoke.gd

# Verify welcome, options, pause, and save/load flow
godot --headless --path desktop/godot --script res://tests/ui_flow_smoke.gd

# Verify cached renderer performance
godot --headless --path desktop/godot --script res://tests/render_smoke.gd

# Validate the project without opening a window
godot --headless --editor --quit --path desktop/godot

# Open the game
godot --path desktop/godot
```

## Release and CI

Every push to `main` runs the desktop verification workflow. Tags matching `native-v*` build and publish the self-contained Windows release with embedded project data; no external `.pck` file is required.

The former browser prototype has been **retired as a release target**. GitHub Pages, Vercel configuration, browser CI, and browser deployment have been removed. The browser implementation remains in the repository temporarily as migration/reference material and is not built, tested, or published by the supported workflows. The root `index.html` is now a static desktop marketing/notice surface, not a playable web client.

## Product direction

The desktop roadmap is now:

1. **Make the solo loop satisfying** — movement, daily rhythm, timed work, useful materials, gathering, gardening, cooking, and exploration. The current native client includes authored terrain transitions and living resource states with ambient motion.
2. **Deepen the village** — NPC schedules, interiors, relationships, useful buildings, seasonal events, and persistent world changes.
3. **Polish the desktop experience** — controller support, accessibility, audio, graphics settings, robust save slots, and platform packaging.
4. **Add shared play later** — only after the single-player desktop loop is enjoyable and stable.

## Naming and rights note

This is an original prototype inspired by cosy village-life games and pastoral village fiction. It is not affiliated with or endorsed by Tolkien Enterprises, Middle-earth Enterprises, Nintendo, ConcernedApe, or their respective rights holders. Any public or commercial release using third-party names, settings, or protected elements would require a separate rights review.
