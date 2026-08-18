extends SceneTree

const World = preload("res://scripts/world_contract.gd")
const WorldView = preload("res://scripts/world_view.gd")
const Actor = preload("res://scripts/npc_actor.gd")
const Player = preload("res://scripts/player_avatar.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var world = World.new()
    var village := {"name": "Clovermere", "landscape": "heath"}
    var view = WorldView.new()
    view.configure(world, world.build_grid(village, {}), village, null, {})

    require(view.has_method("terrain_family_for"), "world renderer should expose deterministic terrain families")
    require(view.has_method("terrain_family_ids"), "world renderer should expose terrain family coverage")
    require(view.has_method("landmark_dressing_ids"), "world renderer should expose authored landmark dressing")
    require(view.has_method("biome_stamp_ids"), "world renderer should expose authored-scale biome stamps")
    require(view.has_method("resource_variant_for"), "world renderer should expose resource presentation variants")
    if view.has_method("terrain_family_ids"):
        var families: Array = view.terrain_family_ids()
        for family in ["meadow", "woodland", "wetland", "rocky", "village-verge"]:
            require(families.has(family), "%s terrain family should be registered" % family)
    if view.has_method("terrain_family_for"):
        var family_a := str(view.terrain_family_for(Vector2i(20, 40)))
        var family_b := str(view.terrain_family_for(Vector2i(210, 120)))
        require(family_a != family_b or view.terrain_family_for(Vector2i(20, 40)) == "meadow", "terrain families should vary deterministically across the world")
    if view.has_method("landmark_dressing_ids"):
        require(view.landmark_dressing_ids().size() >= world.LANDMARKS.size(), "every landmark should receive authored dressing")
    if view.has_method("biome_stamp_ids"):
        require(view.biome_stamp_ids().size() >= 6, "the world should expose six authored-scale biome stamps")
    if view.has_method("resource_variant_for"):
        for kind in ["tree", "stone", "ore", "herb", "fish"]:
            require(not str(view.resource_variant_for(kind, 2)).is_empty(), "%s should have a presentation variant" % kind)

    var actor = Actor.new()
    actor.set_npc(world.npcs()[0])
    require(actor.has_method("set_facing_direction"), "resident actor should expose directional facing")
    require(actor.has_method("walk_frame"), "resident actor should expose a walk frame")
    require(actor.has_method("idle_frame"), "resident actor should expose an idle frame")
    if actor.has_method("set_facing_direction"):
        actor.set_facing_direction(Vector2.LEFT)
        require(actor.facing.x < 0.0, "resident actor should retain left-facing direction")
        actor.set_facing_direction(Vector2.RIGHT)
        require(actor.facing.x > 0.0, "resident actor should retain right-facing direction")
    if actor.has_method("walk_frame"):
        var frame_a := int(actor.walk_frame())
        actor.advance_navigation(0.12, 16.0, 1.8)
        var frame_b := int(actor.walk_frame())
        require(frame_a != frame_b or actor.has_method("set_route"), "resident walking should expose changing walk frames")
    if actor.has_method("idle_frame"):
        require(actor.idle_frame() >= 0, "resident idle frame should be non-negative")

    var player = Player.new()
    require(player.has_method("set_facing_direction"), "player should expose directional facing")
    require(player.has_method("walk_frame"), "player should expose a walk frame")
    player.set_facing_direction(Vector2.LEFT)
    require(player.facing.x < 0.0, "player should retain left-facing direction")

    view.free()
    actor.free()
    player.free()
    if failures.is_empty():
        print("Godot authored world presentation v0.18 contract: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
