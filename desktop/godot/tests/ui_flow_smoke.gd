extends SceneTree

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    get_root().add_child(scene)
    await create_timer(0.9).timeout

    require(not scene.game_started, "native scene should open at the welcome screen")
    require(scene.ui.current_page == "welcome", "welcome screen should appear after loading")
    require(scene.ui.welcome_continue != null, "welcome screen should expose continue control")
    require(scene.ui.options_screen != null, "options screen should be built with the welcome flow")

    scene.ui.show_options("welcome")
    require(scene.ui.current_page == "options", "options should open from welcome")
    scene.ui._back_from_options()
    require(scene.ui.current_page == "welcome", "options back should return to welcome")

    scene._start_new_journey()
    require(scene.game_started, "new journey should enter gameplay")
    require(scene.ui.current_page == "game", "new journey should hide menu overlays")
    var saved_position: Vector2 = scene.player_position
    require(scene._save_game(), "save command should write a journey ledger")
    scene.player_position = Vector2(1.0, 1.0)
    require(scene._load_save(), "load command should read the journey ledger")
    require(scene.player_position.distance_to(saved_position) < 0.01, "load should restore the saved player position")

    scene._pause_journey()
    require(not scene.game_started, "pause should stop gameplay updates")
    require(scene.ui.current_page == "pause", "pause should show the pause menu")
    scene.ui.show_options("pause")
    require(scene.ui.current_page == "options", "options should open from pause")
    scene.ui._back_from_options()
    require(scene.ui.current_page == "pause", "options back should return to pause")
    scene._resume_journey()
    require(scene.game_started, "resume should re-enter gameplay")

    if failures.is_empty():
        print("Godot UI flow smoke: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
