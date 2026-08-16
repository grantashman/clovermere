extends SceneTree

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    get_root().add_child(scene)
    await create_timer(1.0).timeout
    scene._start_new_journey()
    require(scene.benchmark_scene != null, "the native scene should mount the benchmark layer")
    var herb: Dictionary = scene.world.resources()[5]
    var herb_tile := Vector2i(int(herb.x), int(herb.y))
    var approach: Vector2i = scene.world.nearest_walkable(scene.grid, herb_tile + Vector2i(0, 1), 4)
    scene.player_position = Vector2(approach) + Vector2(0.5, 0.5)
    scene._refresh_player_transform()
    scene.command_interact_with_resource(str(herb.get("id", "")))
    scene._handle_resource_action()

    require(scene.interaction_feedback != null, "the scene should create a dedicated work feedback layer")
    require(scene.interaction_feedback.visible, "work feedback should be visible while an action is active")
    require(scene.interaction_feedback.action_label == "GATHERING HERBS", "herb work should use a resource-specific action label")
    require(scene.player.work_active, "the player should enter a tool-work animation state")
    scene._process(0.5)
    require(scene.interaction_feedback.progress > 0.0, "work feedback should follow real action progress")
    require(scene.interaction_feedback.progress < 1.0, "partial work feedback should not report completion")
    require(scene.player.tool_kind == "herb", "herb work should select the gathering tool animation")

    scene._process(3.0)
    require(not scene.player.work_active, "completed work should clear the player tool animation")
    require(scene.interaction_feedback.impact_flash > 0.0, "completed work should trigger a short impact effect")
    require(scene.interaction_feedback.action_label == "", "completed work should clear the active action label")

    var tree: Dictionary = scene.world.resources()[0]
    var tree_tile := Vector2i(int(tree.x), int(tree.y))
    var tree_approach: Vector2i = scene.world.nearest_walkable(scene.grid, tree_tile + Vector2i(0, 1), 4)
    scene.player_position = Vector2(tree_approach) + Vector2(0.5, 0.5)
    scene._refresh_player_transform()
    scene.command_interact_with_resource(str(tree.get("id", "")))
    scene._handle_resource_action()
    require(scene.player.work_active, "a second resource should start a new work animation")
    scene.command_move_to_tile(Vector2i(scene.world.SETTLEMENT_ORIGIN.x + 30, scene.world.SETTLEMENT_ORIGIN.y + 11))
    require(not scene.player.work_active, "changing movement targets should cancel work animation")
    require(not scene.interaction_feedback.visible, "cancelling work should hide the active progress feedback")

    if failures.is_empty():
        print("Godot work-feedback smoke: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
