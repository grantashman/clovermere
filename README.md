# Clovermere

> A quiet life, shared.

Clovermere is an **original desktop-first Godot game**. The native client under [`desktop/godot`](./desktop/godot) is the sole supported release path and the canonical product target. The GitHub repository is now [`grantashman/clovermere`](https://github.com/grantashman/clovermere); the former `hobbit-moon` slug is retained only in historical save keys and legacy reference material.

## Desktop release

The current Windows test build is published on [GitHub Releases](https://github.com/grantashman/clovermere/releases). Download the latest `windows-x86_64.zip`, extract it, and run `Clovermere.exe`. Windows SmartScreen may show an unsigned-app warning while this remains an early test build.

The native client currently includes:

- Deterministic 240×160 explorable world with varied terrain, material-edge shading, organic life, landmarks, pixel-grid roads, six live residents, and authored settlement buildings.
- Interactive timber, stone, ore, and herb nodes with persistent cut/mined/gathered world states and warm world-space lantern/player lighting.
- First-day loop: Day 1 at 08:00, work actions consume time and energy, materials enter a persisted inventory, Greenbriar Cottage advances the day, and herbs regrow overnight.
- Timed work loop: resource actions now show real progress, resource-specific labels, tool motion, impact feedback, cancellation, and exact-once inventory/time/energy completion.
- Tinker Workshop material sink: 3 timber + 2 stone + 1 ore creates a persisted Tinker’s Kit that reduces future work energy costs by 20%; the HUD shows `KIT READY` after purchase.
- Live resident layer: six role-specific NPC actors follow deterministic morning/work/evening/night schedules with route movement, idle/walk motion, role props, work-tool swings, impact sparks, and offset directional shadows.
- Authored central-crossing benchmark layer with stronger building contact shadows, cottage/workshop props, crossing accents, and clock-driven cooler evening ambient lighting.
- First authored benchmark asset pack: hand-built pixel PNGs for Greenbriar Cottage, Tinker Workshop, the crossing tree, boulder, foxglove patch, player, and two central residents, all using a locked Clovermere palette.
- Collision-safe keyboard movement and mouse click-to-move pathfinding.
- Contextual building interaction, target markers, camera tracking, and 50%–200% zoom.
- Field-notes loading and welcome screens before gameplay.
- Fullscreen-first desktop window behavior with `F11` toggle.
- Pause menu with explicit Save Journey and Load Journey actions.
- Persistent Options page for fullscreen, crisp pixel filtering, starting zoom, and launch metrics.
- Save schema 6 with migration from schema 5.
- Cached world rendering with verified steady-state performance around 144–145 FPS on the development host.

## Local Godot commands

```bash
# Run the deterministic world/save contract
godot --headless --path desktop/godot --script res://tests/world_contract_test.gd

# Run the day-state contract: clock, energy, inventory, sleep, and regrowth
godot --headless --path desktop/godot --script res://tests/day_state_test.gd

# Run NPC schedule and actor contracts
godot --headless --path desktop/godot --script res://tests/npc_schedule_test.gd
godot --headless --path desktop/godot --script res://tests/npc_actor_test.gd

# Run art asset, timed work, feedback, workshop, and benchmark contracts
godot --headless --path desktop/godot --script res://tests/art_asset_pack_test.gd
godot --headless --path desktop/godot --script res://tests/work_action_test.gd
godot --headless --path desktop/godot --script res://tests/work_feedback_smoke.gd
godot --headless --path desktop/godot --script res://tests/workshop_upgrade_test.gd
godot --headless --path desktop/godot --script res://tests/benchmark_scene_test.gd

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

1. **Make the solo loop satisfying** — movement, daily rhythm, timed work, useful materials, gathering, gardening, cooking, and exploration.
2. **Deepen the village** — NPC schedules, interiors, relationships, useful buildings, seasonal events, and persistent world changes.
3. **Polish the desktop experience** — controller support, accessibility, audio, graphics settings, robust save slots, and platform packaging.
4. **Add shared play later** — only after the single-player desktop loop is enjoyable and stable.

## Naming and rights note

This is an original prototype inspired by cosy village-life games and pastoral village fiction. It is not affiliated with or endorsed by Tolkien Enterprises, Middle-earth Enterprises, Nintendo, ConcernedApe, or their respective rights holders. Any public or commercial release using third-party names, settings, or protected elements would require a separate rights review.
