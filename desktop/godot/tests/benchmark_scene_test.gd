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
    require(benchmark.art_sprites.has("tree") and benchmark.art_sprites.has("stone") and benchmark.art_sprites.has("herb"), "benchmark should mount authored resource sprites")
    benchmark.free()

    if failures.is_empty():
        print("Godot benchmark scene contract: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
