# Clovermere — Godot desktop slice

This directory contains the canonical native desktop client. The former browser/Vite prototype has been retired as a release target; this Godot project is now the supported product and release path.

## Intended contract

- Godot 4.7.1
- Deterministic 240×160 world seeded by village identity
- Save schema v6 with legacy v5 coordinate migration
- Continuous collision-safe movement
- 50%–200% camera zoom
- Layered terrain, authored pixel-grid path overlays, settlement, and six live resident actors with optional debug metrics
- Static world compositing through a one-shot `SubViewport` texture; terrain/buildings/resources remain cached while the player and resident actors animate independently
- A 75% native starting view for a more readable desktop composition; 50%–200% remains available
- Authored cottage, hall, workshop, garden, and barn facades with distinct roof, window, timber, chimney, and prop details
- Narrow orthogonal pixel-grid footpaths with tile shoulders, wear marks, and cached click-to-move routes
- Seven interactive resource nodes for timber, stone, ore, and herbs; click a node or press `E` nearby to work it, with cleared states saved in `world_changes`
- First-day loop with Day 1/08:00 start, persisted inventory, work time/energy costs, Greenbriar Cottage sleep, herb regrowth, and a compact day/energy/stores HUD
- Timed resource actions with real progress, resource-specific work labels, player tool motion, impact feedback, movement/right-click cancellation, and exact-once completion
- Tinker Workshop interaction with one persisted `Tinker’s Kit` recipe (3 timber + 2 stone + 1 ore) that reduces future work energy cost by 20%; `KIT READY` appears in the HUD after purchase
- Deterministic resident schedules: morning opening, role-specific work, evening strolling, and night resting; live route movement, idle/walk bob, role props, work-tool animation, impact sparks, and offset directional shadows
- Central-crossing benchmark overlay with building contact shadows, cottage/workshop props, crossing accents, resource contacts, and clock-driven cooler evening ambient lighting
- First authored benchmark asset pack at `assets/benchmark/`: hand-built pixel PNGs for the two benchmark buildings, three nearby resources, the player, and two central residents, generated from `tools/generate_benchmark_assets.py` and registered through `scripts/art_asset_pack.gd`
- Material contact-edge shading and a separate world-space lighting compositor for window glows, player lantern radius, and future shadow/dusk expansion
- Mouse controls: left-click ground to walk, left-click a building to approach and interact, right-click to cancel or revisit, and mouse wheel to zoom
- Welcome/loading flow that opens before gameplay and defaults to fullscreen on desktop
- Pause menu with explicit Save Journey and Load Journey actions backed by `user://hobbit-moon-village-v2.json`
- Options page with persistent fullscreen, crisp pixel filtering, starting zoom, and launch-metrics settings

## Local commands

```bash
# World/save/movement contract test
godot --headless --path . --script res://tests/world_contract_test.gd

# Day-state contract test
godot --headless --path . --script res://tests/day_state_test.gd

# NPC schedule and actor contract tests
godot --headless --path . --script res://tests/npc_schedule_test.gd
godot --headless --path . --script res://tests/npc_actor_test.gd

# Art asset, timed work, feedback, workshop, and benchmark contract tests
godot --headless --path . --script res://tests/art_asset_pack_test.gd
godot --headless --path . --script res://tests/work_action_test.gd
godot --headless --path . --script res://tests/work_feedback_smoke.gd
godot --headless --path . --script res://tests/workshop_upgrade_test.gd
godot --headless --path . --script res://tests/benchmark_scene_test.gd

# Mouse click-to-move and building interaction smoke test
godot --headless --path . --script res://tests/mouse_input_smoke.gd

# First-day resource/work/save/sleep smoke test
godot --headless --path . --script res://tests/day_loop_smoke.gd

# Live NPC creation, schedule transitions, and movement smoke test
godot --headless --path . --script res://tests/npc_live_smoke.gd

# Welcome/options/pause/save/load state-flow smoke test
godot --headless --path . --script res://tests/ui_flow_smoke.gd

# Open the native slice
godot --path .

# Validate the project without opening a window
godot --headless --editor --quit --path .

# Rendered performance smoke test; expects at least 45 steady-state FPS
xvfb-run -a godot --path . --script res://tests/render_smoke.gd
```

The current art direction is a hybrid: deterministic procedural terrain remains outside the benchmark while the central crossing uses a small authored pixel asset pack. The pack is deliberately narrow so palette, silhouette, scale, and contact-shadow decisions can be reviewed before expanding to the whole world. Launch now shows a Clovermere field-notes loading card, then a logo-led welcome screen before gameplay. The native window defaults to fullscreen; `F11` toggles window mode and the Options page persists the choice. Press `Esc` to pause, where Save Journey and Load Journey are available. Gameplay shows the current day, clock, energy, material stores, and the Tinker’s Kit state. Click a resource, press `E`, and wait through the visible timed action; movement or right-click cancels it. Visit Tinker Workshop with 3 timber, 2 stone, and 1 ore to make the kit. Return to Greenbriar Cottage and press `E` to sleep; herbs regrow overnight while cleared trees and stone remain cleared. Residents now live outside the static cache: they move between home, work, village, and rest targets as the clock changes, with role-specific work animation and directional shadows. Evening uses cooler ambient ground against warm window and lantern light. Gameplay uses a single cached world texture instead of replaying thousands of tile primitives every frame. Press `F` to reveal the live metrics panel. For a downloaded Windows build, extract the release ZIP and run `Clovermere.exe` directly.
