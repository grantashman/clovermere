extends SceneTree

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    get_root().add_child(scene)
    await create_timer(0.9).timeout
    scene._start_new_journey()

    var tree: Dictionary = scene.world.resources()[1]
    var tree_id := str(tree.get("id", ""))
    var tree_tile := Vector2i(int(tree.x), int(tree.y))
    var approach: Vector2i = scene.world.nearest_walkable(scene.grid, tree_tile + Vector2i(0, 1), 4)
    scene.player_position = Vector2(approach) + Vector2(0.5, 0.5)
    scene._refresh_player_transform()
    scene.command_interact_with_resource(tree_id)
    scene._handle_resource_action()
    scene._process(7.0)
    require(bool(scene.world_changes.get(tree_id, false)), "completed tree work should keep the tree unavailable")
    require(scene.resource_states.get(tree_id, {}).get("stage", "") == "felled", "tree work should persist the felled stage")
    require(scene.benchmark_scene.resource_art_assets.get(tree_id, "") == "tree_debris", "secondary trees should show felled debris")
    require(scene._save_game(), "tree recovery state should save through the native ledger")
    scene.world_changes.clear()
    scene.resource_states.clear()
    scene._refresh_world_state()
    require(scene._load_save(), "tree recovery state should reload through the native ledger")
    require(scene.resource_states.get(tree_id, {}).get("stage", "") == "felled", "load should restore the felled stage")

    var home := Vector2(scene.world.SETTLEMENT_ORIGIN.x + 8.5, scene.world.SETTLEMENT_ORIGIN.y + 12.5)
    scene.player_position = home
    scene._refresh_player_transform()
    scene._handle_resource_action()
    require(scene.day_state.day == 2, "first sleep should advance to day two")
    require(scene.resource_states.get(tree_id, {}).get("stage", "") == "sprout", "day two should show the tree sprout stage")
    require(scene.benchmark_scene.resource_art_assets.get(tree_id, "") == "tree_sprout", "day two should mount tree sprout art")

    scene._handle_resource_action()
    require(scene.day_state.day == 3, "second sleep should advance to day three")
    require(scene.resource_states.get(tree_id, {}).get("stage", "") == "young", "day three should show the young tree stage")
    require(scene.benchmark_scene.resource_art_assets.get(tree_id, "") == "tree_young", "day three should mount young tree art")

    scene._handle_resource_action()
    require(scene.day_state.day == 4, "third sleep should advance to day four")
    require(not bool(scene.world_changes.get(tree_id, true)), "tree should restore after its recovery budget")
    require(not scene.resource_states.has(tree_id), "restored tree should not retain transient state")
    require(scene.benchmark_scene.resource_art_assets.get(tree_id, "") == "tree", "restored tree should mount intact art")

    if failures.is_empty():
        print("Godot regrowth smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Godot regrowth smoke: FAIL (%d)" % failures.size())
    quit(1)
