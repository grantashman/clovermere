extends SceneTree

const ArtAssetPack = preload("res://scripts/art_asset_pack.gd")
const World = preload("res://scripts/world_contract.gd")
const Benchmark = preload("res://scripts/benchmark_scene.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    for asset_id in ["hall", "garden", "barn"]:
        var path := ArtAssetPack.path_for(asset_id)
        require(not path.is_empty(), "%s should have a registered authored facade path" % asset_id)
        require(FileAccess.file_exists(path), "%s facade should exist at %s" % [asset_id, path])
        require(ArtAssetPack.texture_for(asset_id) != null, "%s facade should import in Godot" % asset_id)

    var world = World.new()
    var benchmark = Benchmark.new()
    benchmark.configure(world, world.build_grid({"name": "Clovermere", "landscape": "heath"}), {})
    require(benchmark.art_sprites.has("hall"), "benchmark should mount the authored Hall facade")
    require(benchmark.art_sprites.has("garden"), "benchmark should mount the authored Garden facade")
    require(benchmark.art_sprites.has("barn"), "benchmark should mount the authored Barn facade")
    require(benchmark.art_sprites.get("hall") != null, "Hall facade sprite should be live")
    require(benchmark.art_sprites.get("garden") != null, "Garden facade sprite should be live")
    require(benchmark.art_sprites.get("barn") != null, "Barn facade sprite should be live")

    if failures.is_empty():
        print("Godot authored facade contract: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        print("Godot authored facade contract: FAIL (%d)" % failures.size())
        quit(1)
