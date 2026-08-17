extends SceneTree

const ArtAssetPack = preload("res://scripts/art_asset_pack.gd")
const World = preload("res://scripts/world_contract.gd")
const Benchmark = preload("res://scripts/benchmark_scene.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    for asset_id in ["tree_stump", "tree_debris", "stone_fragments", "ore_fragments", "herb_stems", "water_shimmer_a", "water_shimmer_b"]:
        var path := ArtAssetPack.path_for(asset_id)
        require(not path.is_empty(), "%s should have a registered living-terrain path" % asset_id)
        require(FileAccess.file_exists(path), "%s should exist" % asset_id)
        require(ArtAssetPack.texture_for(asset_id) != null, "%s should import in Godot" % asset_id)

    var world = World.new()
    var benchmark = Benchmark.new()
    benchmark.configure(world, world.build_grid({"name": "Clovermere", "landscape": "heath"}), {})
    require(benchmark.resource_art_assets.get("oak-at-the-crossing", "") == "tree", "intact tree should use the authored tree sprite")
    require(benchmark.resource_art_assets.get("greycap-boulder", "") == "stone", "intact stone should use the authored stone sprite")
    require(benchmark.resource_art_assets.get("foxglove-patch", "") == "herb", "intact herb should use the authored herb sprite")

    benchmark.configure(world, world.build_grid({"name": "Clovermere", "landscape": "heath"}, {"oak-at-the-crossing": true, "greycap-boulder": true, "foxglove-patch": true}), {"oak-at-the-crossing": true, "greycap-boulder": true, "foxglove-patch": true})
    require(benchmark.resource_art_assets.get("oak-at-the-crossing", "") == "tree_stump", "cleared tree should use an authored stump state")
    require(benchmark.resource_art_assets.get("greycap-boulder", "") == "stone_fragments", "cleared stone should use authored fragments")
    require(benchmark.resource_art_assets.get("foxglove-patch", "") == "herb_stems", "cleared herbs should use authored stems")
    benchmark.configure(world, world.build_grid({"name": "Clovermere", "landscape": "heath"}, {"birch-by-the-lane": true}), {"birch-by-the-lane": true})
    require(benchmark.resource_art_assets.get("birch-by-the-lane", "") == "tree_debris", "a secondary cleared tree should use the felled debris variant")

    benchmark.set_time(1200)
    require(benchmark.fireflies_visible, "evening should enable subtle fireflies")
    var before_phase: float = benchmark.animation_phase
    benchmark._process(0.5)
    require(benchmark.animation_phase > before_phase, "living terrain animation should advance over time")
    benchmark.set_active_work("oak-at-the-crossing", 0.5)
    require(benchmark.active_resource_id == "oak-at-the-crossing", "active work should identify the resource being worked")
    require(is_equal_approx(benchmark.active_work_progress, 0.5), "active work should expose progress")
    benchmark.clear_active_work()
    require(benchmark.active_resource_id.is_empty(), "clearing active work should remove the transient resource state")

    if failures.is_empty():
        print("Godot living-terrain contract: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Godot living-terrain contract: FAIL (%d)" % failures.size())
    quit(1)
