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
    require(anchors.has("greenbriar-cottage"), "benchmark should anchor Greenbriar Cottage")
    require(anchors.has("tinker-workshop"), "benchmark should anchor Tinker Workshop")
    require(anchors.has("central-crossing"), "benchmark should anchor the central crossing")
    require(anchors.has("alda-fen") and anchors.has("orin-reed"), "benchmark should identify two live resident anchors")
    require(anchors.has("oak-at-the-crossing"), "benchmark should identify the crossing tree resource")
    require(anchors.has("foxglove-patch"), "benchmark should identify the nearby herb resource")
    require(benchmark.benchmark_bounds().has_point(Vector2i(world.SETTLEMENT_ORIGIN.x + 30, world.SETTLEMENT_ORIGIN.y + 11)), "benchmark bounds should include the central crossing")
    require(benchmark.is_authored_area(Vector2i(world.SETTLEMENT_ORIGIN.x + 30, world.SETTLEMENT_ORIGIN.y + 11)), "central crossing should be inside the authored area")
    require(not benchmark.is_authored_area(Vector2i(10, 10)), "far terrain should remain outside the benchmark area")
    require(benchmark.art_sprites.has("cottage"), "benchmark should mount the authored cottage sprite")
    require(benchmark.art_sprites.has("workshop"), "benchmark should mount the authored workshop sprite")
    require(benchmark.art_sprites.has("hall"), "benchmark should mount the authored Hall sprite")
    require(benchmark.art_sprites.has("garden"), "benchmark should mount the authored Garden sprite")
    require(benchmark.art_sprites.has("barn"), "benchmark should mount the authored Barn sprite")
    require(benchmark.art_sprites.has("tree") and benchmark.art_sprites.has("stone") and benchmark.art_sprites.has("herb"), "benchmark should mount authored resource sprites")
    var road_tile := Vector2i(-1, -1)
    for y in benchmark.grid.size():
        for x in benchmark.grid[y].size():
            if str(benchmark.grid[y][x]) == "p":
                road_tile = Vector2i(x, y)
                break
        if road_tile.x >= 0:
            break
    require(road_tile.x >= 0 and benchmark.terrain_asset_for(road_tile).is_empty(), "benchmark should leave village roads to the organic dirt renderer")
    benchmark.set_consequence_flags({"garden_bloom": true, "forge_ember": true, "lane_markers": true})
    require(benchmark.active_consequence_flags().get("garden_bloom", false), "benchmark should expose the active garden consequence")
    require(benchmark.active_consequence_flags().get("forge_ember", false), "benchmark should expose the active forge consequence")
    require(benchmark.active_consequence_flags().get("lane_markers", false), "benchmark should expose the active lane-marker consequence")
    require(benchmark.has_method("set_consequence_flags"), "benchmark should accept persisted resident consequences")
    benchmark.free()

    if failures.is_empty():
        print("Godot benchmark scene contract: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
