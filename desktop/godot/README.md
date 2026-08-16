# Hobbit Moon — Godot native slice

This directory contains the native desktop client under active migration. The browser/Vite client remains the hosted reference release while this slice proves the native renderer and movement loop.

## Intended contract

- Godot 4.7.1
- Deterministic 240×160 world seeded by village identity
- Save schema v6 with legacy v5 coordinate migration
- Continuous collision-safe movement
- 50%–200% camera zoom
- Layered terrain, smooth path overlays, settlement, and optional debug metrics
- Static world compositing through a one-shot `SubViewport` texture so the live frame only redraws the player, camera, and HUD
- A 75% native starting view for a more readable desktop composition; 50%–200% remains available
- Authored cottage, hall, workshop, garden, and barn facades with distinct roof, window, timber, chimney, and prop details
- Narrow curved footpaths with shoulders, wear marks, and cached click-to-move routes
- Mouse controls: left-click ground to walk, left-click a building to approach and interact, right-click to cancel or revisit, and mouse wheel to zoom

## Local commands

```bash
# World/save/movement contract test
godot --headless --path . --script res://tests/world_contract_test.gd

# Mouse click-to-move and building interaction smoke test
godot --headless --path . --script res://tests/mouse_input_smoke.gd

# Open the native slice
godot --path .

# Validate the project without opening a window
godot --headless --editor --quit --path .

# Rendered performance smoke test; expects at least 45 steady-state FPS
xvfb-run -a godot --path . --script res://tests/render_smoke.gd
```

The project intentionally starts without imported art assets. The current slice uses deterministic procedural pixel forms so renderer and pathing behavior can be measured before the production asset pack is introduced. The static world is composed behind a short loading veil on launch; gameplay then uses a single cached world texture instead of replaying thousands of tile primitives every frame. Press `F` to reveal the live metrics panel. For a downloaded Windows build, extract the release ZIP and run `HobbitMoon.exe` directly.
