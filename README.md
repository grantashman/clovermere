# Clovermere

> A quiet life, shared.

Clovermere is an **original desktop-first Godot game**. The native client under [`desktop/godot`](./desktop/godot) is the sole supported release path and the canonical product target. The repository slug remains `hobbit-moon` for history and continuity; the product identity is Clovermere.

## Desktop release

The current Windows test build is published on [GitHub Releases](https://github.com/grantashman/hobbit-moon/releases). Download the latest `windows-x86_64.zip`, extract it, and run `Clovermere.exe`. Windows SmartScreen may show an unsigned-app warning while this remains an early test build.

The native client currently includes:

- Deterministic 240×160 explorable world with varied terrain, material-edge shading, organic life, landmarks, pixel-grid roads, six residents, and authored settlement buildings.
- Interactive timber, stone, ore, and herb nodes with persistent cut/mined/gathered world states and warm world-space lantern/player lighting.
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

# Verify click-to-move and building interaction
godot --headless --path desktop/godot --script res://tests/mouse_input_smoke.gd

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

1. **Make the solo loop satisfying** — movement, daily rhythm, interactions, gathering, gardening, cooking, and exploration.
2. **Deepen the village** — NPC schedules, interiors, relationships, useful buildings, seasonal events, and persistent world changes.
3. **Polish the desktop experience** — controller support, accessibility, audio, graphics settings, robust save slots, and platform packaging.
4. **Add shared play later** — only after the single-player desktop loop is enjoyable and stable.

## Naming and rights note

This is an original prototype inspired by cosy village-life games and pastoral village fiction. It is not affiliated with or endorsed by Tolkien Enterprises, Middle-earth Enterprises, Nintendo, ConcernedApe, or their respective rights holders. Any public or commercial release using third-party names, settings, or protected elements would require a separate rights review.
