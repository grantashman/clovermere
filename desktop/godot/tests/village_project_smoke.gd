extends SceneTree

var scene: Node
var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    scene = load("res://scenes/main.tscn").instantiate()
    get_root().add_child(scene)
    await create_timer(0.9).timeout
    scene._start_new_journey()
    scene._enter_interior("clovermere-hall", false)
    scene.player_position = Vector2(9.5, 5.5)
    scene._refresh_player_transform()
    scene._handle_interior_action()
    require(scene.gameplay_hud.management_panel.visible, "Hall Town Table should open the project surface")
    require(scene.gameplay_hud.management_mode == "project", "Town Table should select the project surface")
    require(scene.gameplay_hud.management_content.get_child_count() > 0, "project surface should render the current stage")

    scene.village_project.record_support(scene.project_state, "request", "garden-tonic")
    scene.day_state.inventory["timber"] = 5
    scene.day_state.inventory["stone"] = 3
    scene._refresh_hud()
    scene._handle_project_action("contribute")
    require(scene.project_state.get("stage", 0) == 1, "Hall contribution should advance the project stage")
    require(scene.day_state.inventory.get("timber", -1) == 0, "Hall contribution should consume project timber")
    require(scene.benchmark_scene.active_consequence_flags().get("commons_foundation", false), "project stage should update the visible world consequence")

    require(scene._save_game(), "project contribution should save")
    require(scene._load_save(), "project contribution should load")
    require(scene.project_state.get("stage", 0) == 1, "project stage should survive save/load")

    if failures.is_empty():
        print("Godot Village Project smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
