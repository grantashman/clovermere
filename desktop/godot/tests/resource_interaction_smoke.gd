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
    var resources: Array = scene.world.resources()
    require(resources.size() >= 7, "world should expose the authored resource roster")
    var resource: Dictionary = resources[0]
    var resource_id := str(resource.get("id", ""))
    var resource_tile := Vector2i(int(resource.x), int(resource.y))
    var approach: Vector2i = scene.world.nearest_walkable(scene.grid, resource_tile + Vector2i(0, 1), 4)
    scene.player_position = Vector2(approach) + Vector2(0.5, 0.5)
    scene._refresh_player_transform()
    scene.command_interact_with_resource(resource_id)
    require(not scene.pending_resource.is_empty(), "clicking a resource should retain a pending interaction at arrival")
    require(scene.active_work_action == null, "clicking a resource should not complete work before E")
    scene._handle_resource_action()
    require(scene.active_work_action != null, "pressing E near a resource should create a work action")
    require(scene.active_work_action.status == "working", "pressing E should enter the working state")
    require(not bool(scene.world_changes.get(resource_id, false)), "starting work should not clear the resource immediately")
    scene._process(0.5)
    require(not bool(scene.world_changes.get(resource_id, false)), "partial work should leave the resource intact")
    scene._process(7.0)
    require(bool(scene.world_changes.get(resource_id, false)), "working a resource should persist its cleared state")
    require(scene.world.tile_at(scene.grid, resource_tile) == "g", "cleared resource tiles should become walkable ground")
    require(scene._save_game(), "resource mutation should be writable to the journey ledger")
    scene.world_changes.clear()
    scene._refresh_world_state()
    require(scene._load_save(), "resource mutation should reload from the journey ledger")
    require(bool(scene.world_changes.get(resource_id, false)), "load should restore the cleared resource state")

    if failures.is_empty():
        print("Godot resource interaction smoke: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
