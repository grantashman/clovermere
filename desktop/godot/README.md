# Hobbit Moon — Godot native slice

This directory contains the native desktop client under active migration. The browser/Vite client remains the hosted reference release while this slice proves the native renderer and movement loop.

## Intended contract

- Godot 4.7.1
- Deterministic 240×160 world seeded by village identity
- Save schema v6 with legacy v5 coordinate migration
- Continuous collision-safe movement
- 50%–200% camera zoom
- Layered terrain, smooth path overlays, settlement, and debug metrics

## Local commands

```bash
# World/save/movement contract test
godot --headless --path . --script res://tests/world_contract_test.gd

# Open the native slice
godot --path .

# Validate the project without opening a window
godot --headless --editor --quit --path .
```

The project intentionally starts without imported art assets. The current slice uses deterministic procedural pixel forms so renderer and pathing behavior can be measured before the production asset pack is introduced. For a downloaded Windows build, extract the release ZIP and run `HobbitMoon.exe` directly.
