# Clovermere presentation refresh — verification summary

This note records the bounded presentation slice implemented on the native desktop branch. It is intentionally separate from Windows package/runtime evidence.

## Scope

- Added original, project-owned drawn illustrations to the loading and welcome screens.
- Tightened the welcome screen layout so its actions, footer, focus state, and baseline 1280×720 composition remain readable.
- Refined the authored road renderer with deterministic village-road / building-footpath / field-trail width hierarchy, road shadows, junction dressing, and building doorstep cues.
- Added focused presentation contracts for the screen composition and road rendering seam.
- Registered the new screen contract in both native verification and Windows release workflows.

## Local evidence

Baseline project: Godot 4.7.1, GL Compatibility, 1280×720 viewport.

Commands and results:

```text
godot --headless --path desktop/godot --script res://tests/road_network_test.gd
Godot road network contract: PASS

godot --headless --path desktop/godot --script res://tests/screen_presentation_test.gd
Godot screen presentation contract: PASS

for path in desktop/godot/tests/*.gd; do
  godot --headless --path desktop/godot --script "res://tests/$(basename "$path")"
done
49 native Godot test scripts: PASS

npm run test
66 Node tests: PASS

npm run check
PASS (Node tests plus Vite build)

npm run build
PASS (Vite production build)

godot --headless --editor --quit --path desktop/godot
PASS (project import/editor validation)
git diff --check
PASS
```

The full native matrix included the existing scene/input/interior/resource contracts, the new road and screen contracts, and the render smoke. Render smoke reported `145.0 FPS, cache_mode=1` against its 45 FPS minimum.

Expected environment-only warnings were observed during native runs: Xvfb has no ALSA audio device, so Godot uses its dummy audio driver; existing headless scene tests report renderer/resource cleanup warnings at process exit while returning exit code 0.

## Visual evidence

Matched captures were produced with `xvfb-run` at 1280×720 and reviewed from the actual PNG pixels:

- `/tmp/clovermere-refresh/loading.png`
- `/tmp/clovermere-refresh/welcome.png`
- `/tmp/clovermere-refresh/gameplay-day.png`
- `/tmp/clovermere-refresh/gameplay-evening.png`

The loading and welcome compositions are fully visible at the supported baseline. The daytime and evening captures show the road shoulder hierarchy, marked junctions, doorstep connections, authored structures, resident grounding, and existing phase-aware lighting without a new blocking artifact.

## Platform boundary

Local Linux execution, headless rendering, CI workflow configuration, and any later Windows export/package inspection do not prove runtime behavior of the Windows binary. Fresh Windows runtime testing remains an explicit external gate for the exact release artifact.
