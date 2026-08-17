extends SceneTree

const World = preload("res://scripts/world_contract.gd")
const ArtAssetPack = preload("res://scripts/art_asset_pack.gd")
const Benchmark = preload("res://scripts/benchmark_scene.gd")
const Actor = preload("res://scripts/npc_actor.gd")
const Lighting = preload("res://scripts/lighting_overlay.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var world = World.new()
    var pack = ArtAssetPack.new()
    require(pack.has_method("resident_asset_ids"), "art pack should expose resident-specific authored profiles")
    require(pack.has_method("resident_asset_for"), "art pack should resolve an authored asset for every resident")
    if pack.has_method("resident_asset_ids"):
        var resident_ids: Array = pack.resident_asset_ids()
        require(resident_ids.size() == world.npcs().size(), "every resident should have one authored profile")
        for npc_variant in world.npcs():
            var npc: Dictionary = npc_variant
            var asset_id: String = str(pack.resident_asset_for(str(npc.get("id", ""))))
            require(not asset_id.is_empty(), "%s should resolve to an authored resident asset" % str(npc.get("id", "")))
            require(FileAccess.file_exists(pack.path_for(asset_id)), "%s authored resident asset should exist" % asset_id)

    var benchmark = Benchmark.new()
    benchmark.configure(world, world.build_grid({"name": "Clovermere", "landscape": "heath"}), {})
    require(benchmark.lighting_accents != null, "benchmark should mount a separate facade-light accent layer")
    if benchmark.lighting_accents != null:
        require(benchmark.lighting_accents.z_index > int(benchmark.depth_layers().get("building", 0)), "facade lights should render above building sprites")
    require(benchmark.has_method("depth_layers"), "benchmark should expose explicit depth bands")
    require(benchmark.has_method("terrain_cluster_asset_ids"), "benchmark should expose mounted terrain clusters")
    if benchmark.has_method("depth_layers"):
        var layers: Dictionary = benchmark.depth_layers()
        require(int(layers.get("terrain", 0)) < int(layers.get("building", 0)), "terrain should render behind buildings")
        require(int(layers.get("building", 0)) < int(layers.get("resource", 0)), "resources should render above building bodies")
        require(int(layers.get("resource", 0)) < int(layers.get("foreground", 0)), "foreground accents should render above resources")
    if benchmark.has_method("terrain_cluster_asset_ids"):
        require(benchmark.terrain_cluster_asset_ids().size() >= 3, "authored area should use at least three material cluster families")

    var actor = Actor.new()
    actor.set_npc(world.npcs()[2])
    require(actor.uses_authored_art, "every live resident should use authored art")
    require(actor.authored_texture != null, "resident actor should load its authored texture")
    require(actor.has_method("update_depth"), "resident actor should expose y-based depth sorting")
    if actor.has_method("update_depth"):
        actor.position = Vector2(40, 80)
        actor.update_depth(100)
        var shallow_depth: int = actor.z_index
        actor.position.y = 128
        actor.update_depth(100)
        require(actor.z_index > shallow_depth, "resident depth should increase lower in the world")

    var lighting = Lighting.new()
    require(lighting.has_method("ambient_color_for"), "lighting should expose time-aware ambient colour")
    require(lighting.has_method("shadow_direction_for"), "lighting should expose time-aware shadow direction")
    if lighting.has_method("ambient_color_for"):
        require(lighting.ambient_color_for(720).a < lighting.ambient_color_for(1200).a, "evening ambient treatment should be stronger than daytime")
    if lighting.has_method("shadow_direction_for"):
        require(lighting.shadow_direction_for(720) != lighting.shadow_direction_for(1200), "shadow direction should change across the day")

    benchmark.free()
    actor.free()
    lighting.free()

    if failures.is_empty():
        print("Godot visual presentation contract: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
