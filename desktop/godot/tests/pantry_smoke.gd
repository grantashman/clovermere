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
    await create_timer(0.2).timeout

    scene._enter_interior("greenbriar-cottage", false)
    scene.player_position = Vector2(12.5, 8.5)
    scene._refresh_player_transform()
    scene._handle_interior_action()
    require(scene.gameplay_hud.management_panel.visible, "pantry interaction should open the Hearth Pantry panel")
    require(scene.gameplay_hud.management_mode == "cook", "pantry interaction should select the hearth tab")
    require(scene.gameplay_hud.management_content.get_child_count() > 0, "Hearth Pantry should render a cooking card")

    scene.day_state.energy = 60
    scene.day_state.inventory["timber"] = 1
    scene.day_state.inventory["herbs"] = 2
    scene._cook_recipe("hearth-tea")
    require(scene.day_state.energy == 85, "Hearth Tea should restore 25 energy in the live scene")
    require(scene.day_state.minute_of_day == 8 * 60 + 10, "live cooking should advance ten minutes")
    require(scene.day_state.inventory["timber"] == 0 and scene.day_state.inventory["herbs"] == 0, "live cooking should consume ingredients")
    require(scene.interaction_message.find("Hearth Tea") >= 0, "live cooking should report the cooked recipe")

    require(scene._save_game(), "cooking should save through the existing journey ledger")
    var file := FileAccess.open(scene.SAVE_PATH, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text()) if file != null else {}
    require(parsed is Dictionary, "cooking save should remain valid JSON")
    require(parsed is Dictionary and parsed.get("day_state", {}).get("energy", 0) == 85, "cooking energy should be persisted")
    require(parsed is Dictionary and parsed.get("day_state", {}).get("minute_of_day", 0) == 8 * 60 + 10, "cooking time should be persisted")

    if failures.is_empty():
        print("Godot Hearth Pantry smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
