# Clovermere — Godot desktop slice

This directory contains the canonical native desktop client. The former browser/Vite prototype has been retired as a release target; this Godot project is now the supported product and release path.

## Intended contract

- Godot 4.7.1
- Deterministic 240×160 world seeded by village identity
- Save schema v7 with legacy v5/v6 migration; resource recovery timing is persisted in `resource_states` alongside compatibility-preserved `world_changes` flags
- Continuous collision-safe movement
- 50%–200% camera zoom
- Layered terrain, authored pixel-grid path overlays, settlement, and six live resident actors with optional debug metrics
- Static world compositing through a one-shot `SubViewport` texture; terrain/buildings/resources remain cached while the player and resident actors animate independently
- A 75% native starting view for a more readable desktop composition; 50%–200% remains available
- Authored cottage, hall, workshop, garden, and barn facades with distinct roof, window, timber, chimney, and prop details
- Narrow orthogonal pixel-grid footpaths with tile shoulders, wear marks, and cached click-to-move routes
- Procedural interactive resource field: deterministic generated trees, stone, ore, herbs, and fishing spots are distributed across all four quadrants; click a node or press `E` nearby to work it, with clear/regrowth state saved in `world_changes` and `resource_states`
- First-day loop with Day 1/08:00 start, persisted carried inventory, automatic home storage on sleep, work time/energy costs, Greenbriar Cottage sleep, herb regrowth, and a compact day/energy/material HUD
- Timed resource actions with real progress, resource-specific work labels, player tool motion, impact feedback, cancellation, movement/right-click cancellation, and exact-once completion
- Hearth Pantry and Food & Fishing loop: Hearth Tea restores energy immediately; Riverside Stew (1 fish + 1 timber) and Garden Chowder (1 fish + 1 herb) are stored as meals, then eaten later for energy plus a one-use next-work effect. Meal inventory, effects, fish, cooking time, and resident fish feedback persist through save/load.
- Tinker Workshop recipes consume field-pack materials: Tinker’s Kit (3 timber + 2 stone + 1 ore) reduces work energy cost by 20%; Wayfarer’s Satchel (5 timber + 2 herbs) reduces work time by 20%; Hearthward Charm (2 stone + 2 herbs + 3 ore) raises maximum daily energy to 115. Sleeping at Greenbriar Cottage stores the field pack; `TAKE STORES` returns home materials at the cottage.
- Traditional PC-game HUD redesign: compact status card, `B` field-pack view, `C` workshop-recipes view, keyboard-accessible action bar, `T` resident dialogue, and a full-world minimap; the UI uses original forest-green, timber-brown, parchment, brass, and moss tones rather than protected LOTR/Tolkien assets or branding
- Enterable authored interiors: Greenbriar Cottage Hearth Room includes a hearth, bed, storage chest, Hearth Pantry cooking, and warm evening light; Tinker Workshop Workroom, Clovermere Hall Common Room, Herbalist's Garden Glasshouse, and Old Barn Loft are also enterable with distinct authored furniture and interaction points. A short transition blocks input, hides the exterior/minimap, and saves the exterior position plus interior location without changing schema 7.
- Village Memory: Alda Fen, Tobin Wren, and Orin Reed move through introduction → acquainted → trusted stages; each offers one material-backed favor with a persisted completion flag, a contextual dialogue response, and a small gameplay reward. Trusted residents offer one small later-day gift; completed favors mount Garden blooms, a Workshop brazier, and eastern lane markers in the authored benchmark. `T` remains the talk shortcut.
- Deterministic resident schedules: morning opening, role-specific work, evening strolling, and night resting; live route movement, idle/walk bob, role props, work-tool animation, impact sparks, and offset directional shadows
- Authored central-crossing benchmark layer with explicit terrain/contact/building/resource/foreground depth bands, stronger building contact shadows, cottage/workshop props, crossing accents, material cluster overlays, six role-specific resident sprites, and clock-driven cooler evening ambient lighting with warm facade window accents.
- Authored benchmark asset pack: hand-built pixel PNGs for Greenbriar Cottage, Tinker Workshop, Clovermere Hall, Herbalist's Garden, Old Barn, the crossing tree, boulder, foxglove patch, player, six role-specific residents, and meadow/forest-floor/village-verge material clusters, all using a locked Clovermere palette.
- Living resource states and ambient benchmark motion: tree stump/debris, tree sprout/young recovery stages, stone fragments/fractures, ore fragments/crystals, harvested herb stems, active-work pulses, herb regrowth sprouts, water shimmer, foliage sway, and restrained evening fireflies
- Resource recovery is deterministic and persistent: trees recover through felled → sprout → young → restored over three sleeps, stone/ore recover over two sleeps, and herbs retain their established next-day restoration. Cleared terrain receives resource-specific scars, fractures, or crystal cues.

- Terrain foundation pack at `assets/benchmark/`: three sparse grass variants, woodland and soil pockets, connectivity-selected path straights/corners/T-junctions/crossings, and registered water/bank tiles. The benchmark terrain is composited into one texture so it does not add thousands of live scene nodes; distant terrain remains procedural and cached
- Procedural resource field: deterministic generated trees, stone outcrops, ore seams, herbs, and fishing spots are distributed across all four world quadrants, avoid building footprints, and use an authored distant-resource overlay for readable silhouettes and clear states
- Material contact-edge shading and a separate world-space lighting compositor for window glows, player lantern radius, and future shadow/dusk expansion
- Mouse controls: left-click ground to walk, left-click a building to approach and interact, right-click to cancel or revisit, and mouse wheel to zoom
- Welcome/loading flow that opens before gameplay and defaults to fullscreen on desktop
- Pause menu with explicit Save Journey and Load Journey actions backed by `user://hobbit-moon-village-v2.json`
- Options page with persistent fullscreen, crisp pixel filtering, starting zoom, and launch-metrics settings

## Local commands

```bash
# World/save/movement contract test
godot --headless --path . --script res://tests/world_contract_test.gd

# Day-state contract
godot --headless --path . --script res://tests/day_state_test.gd

# Storage, recipe, minimap, traditional PC HUD, interior, Village Memory, and pantry contracts
godot --headless --path . --script res://tests/storage_recipe_test.gd
godot --headless --path . --script res://tests/minimap_test.gd
godot --headless --path . --script res://tests/gameplay_hud_test.gd
godot --headless --path . --script res://tests/interior_contract_test.gd
godot --headless --path . --script res://tests/interior_scene_test.gd
godot --headless --path . --script res://tests/interior_transition_smoke.gd
godot --headless --path . --script res://tests/all_buildings_interior_smoke.gd
godot --headless --path . --script res://tests/village_memory_test.gd
godot --headless --path . --script res://tests/village_memory_smoke.gd
godot --headless --path . --script res://tests/pantry_test.gd
godot --headless --path . --script res://tests/pantry_smoke.gd
godot --headless --path . --script res://tests/procedural_resource_test.gd
godot --headless --path . --script res://tests/procedural_resource_overlay_test.gd

# NPC actor, player-scale, and schedule contract tests
godot --headless --path . --script res://tests/npc_schedule_test.gd
godot --headless --path . --script res://tests/npc_actor_test.gd
godot --headless --path . --script res://tests/player_scale_test.gd

# Art asset, timed work, feedback, workshop, and benchmark contract tests
godot --headless --path . --script res://tests/art_asset_pack_test.gd
godot --headless --path . --script res://tests/facade_asset_test.gd
godot --headless --path . --script res://tests/terrain_asset_test.gd
godot --headless --path . --script res://tests/work_action_test.gd
godot --headless --path . --script res://tests/work_feedback_smoke.gd
godot --headless --path . --script res://tests/workshop_upgrade_test.gd
godot --headless --path . --script res://tests/benchmark_scene_test.gd
godot --headless --path . --script res://tests/visual_presentation_test.gd
godot --headless --path . --script res://tests/terrain_benchmark_test.gd
# Living resource states, active work visuals, evening ambience, and herb regrowth
godot --headless --path . --script res://tests/living_terrain_test.gd
godot --headless --path . --script res://tests/living_terrain_smoke.gd
# Deterministic destruction/regrowth and save-state smoke
godot --headless --path . --script res://tests/regrowth_state_test.gd
godot --headless --path . --script res://tests/regrowth_smoke.gd
# Day-state contract: clock, energy, inventory, sleep, and regrowth
godot --headless --path . --script res://tests/day_state_test.gd

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

The current art direction is a hybrid: deterministic procedural terrain remains outside the benchmark while the central crossing uses authored pixel assets. The terrain foundation adds sparse grass variants, a woodland pocket around the crossing oak, a soil pocket around Foxglove, and connectivity-selected square path tiles. Living terrain now adds authored intact/cleared resource states for trees, stone, ore, and herbs; active work pulses; short-lived herb regrowth sprouts after sleep; water shimmer; tree foliage sway; and three restrained evening fireflies. The authored field remains composited into one benchmark texture, while ambient/resource feedback uses one lightweight live benchmark node so the earlier scene-node performance regression does not return; the current Xvfb render smoke remains above the 45 FPS threshold. Launch now shows a Clovermere field-notes loading card, then a logo-led welcome screen before gameplay. The native window defaults to fullscreen; `F11` toggles window mode and the Options page persists the choice. Press `Esc` to close an open management panel, then pause, where Save Journey and Load Journey are available. Gameplay shows the current day, clock, energy, carried materials, home stores, a full-world minimap, and the compact action bar. Press `B` for the Field Pack, `C` for Workshop Recipes, and `Esc` to close either surface. Click a resource, press `E`, and wait through the visible timed action; movement or right-click cancels it. Visit Tinker Workshop to make any affordable recipe from carried or stored materials. Return to Greenbriar Cottage and press `E` to sleep; carried materials are deposited into home stores, energy resets, and recovery advances overnight. Residents now live outside the static cache: they move between home, work, village, and rest targets as the clock changes, with role-specific work animation and directional shadows. Evening uses cooler ambient ground against warm window and lantern light. Press `F` to reveal the live metrics panel. For a downloaded Windows build, extract the release ZIP and run `Clovermere.exe` directly.
