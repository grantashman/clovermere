extends SceneTree

const World = preload("res://scripts/world_contract.gd")
const Benchmark = preload("res://scripts/benchmark_scene.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var world = World.new()
    var benchmark = Benchmark.new()
    var anchors: Dictionary = benchmark.configure(world, world.build_grid({"name": "Clovermere", "landscape": "heath"}), {})
    require(anchors.has("central-crossing"), "benchmark should anchor the central crossing")
    require(benchmark.terrain_sprite != null and benchmark.terrain_sprite.texture != null, "benchmark should composite authored terrain into one texture")
    require(benchmark.terrain_sprites.size() > 100, "benchmark should mount a substantial authored terrain field")
    require(not benchmark.terrain_sprites.has(Vector2i(world.SETTLEMENT_ORIGIN.x + 30, world.SETTLEMENT_ORIGIN.y + 11)), "benchmark should leave the crossing to the organic road renderer")
    var crossing_asset: String = benchmark.terrain_sprites.get(Vector2i(world.SETTLEMENT_ORIGIN.x + 30, world.SETTLEMENT_ORIGIN.y + 11), "")
    require(crossing_asset.is_empty(), "central crossing should be rendered by the organic road graph, not a duplicate tile texture")
    var woodland_found := false
    var soil_found := false
    for asset_variant in benchmark.terrain_sprites.values():
        var asset_id: String = asset_variant
        woodland_found = woodland_found or asset_id == "woodland"
        soil_found = soil_found or asset_id == "soil"
    require(woodland_found, "benchmark should include an authored woodland pocket")
    require(soil_found, "benchmark should include an authored soil pocket")
    require(not benchmark.terrain_sprites.has(Vector2i(10, 10)), "far terrain should remain outside the authored field")
    benchmark.free()
    if failures.is_empty():
        print("Godot terrain benchmark contract: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
