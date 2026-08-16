extends SceneTree

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    get_root().add_child(scene)
    await create_timer(0.35).timeout

    var start: Vector2 = scene.player_position
    scene.command_click_world(Vector2(142.5, 85.5) * 16.0)
    require(not scene.movement_path.is_empty(), "clicking walkable ground should create a movement path")
    require(scene.target_marker.active, "click movement should show a target marker")

    scene.command_interact_with_building("greenbriar-cottage")
    require(not scene.pending_building.is_empty() or scene.interaction_message.contains("Arrived"), "building command should queue or immediately complete a building interaction")
    require(not scene.movement_path.is_empty() or scene.interaction_message.contains("Arrived"), "building command should route to an approach tile")
    require(scene.player_position == start, "queueing a click should not teleport the player")

    if failures.is_empty():
        print("Godot mouse input smoke: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
