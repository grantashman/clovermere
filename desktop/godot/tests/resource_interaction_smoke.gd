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
    scene._complete_resource_interaction_for(resource)
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
