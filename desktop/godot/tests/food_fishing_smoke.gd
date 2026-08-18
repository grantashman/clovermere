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
    require(scene.gameplay_hud.management_mode == "cook", "the pantry should open the cooking panel")

    scene.day_state.energy = 50
    scene.day_state.inventory["fish"] = 2
    scene.day_state.inventory["timber"] = 1
    scene._cook_recipe("riverside-stew")
    require(scene.day_state.meals.get("riverside-stew", 0) == 1, "live cooking should add Riverside Stew")
    require(scene.interaction_message.find("prepared") >= 0, "live meal cooking should report a prepared meal")
    scene._eat_meal("riverside-stew")
    require(scene.day_state.energy == 80, "live eating should restore Riverside Stew energy")
    require(scene.day_state.next_work_effects.get("uses", 0) == 1, "live eating should arm a one-use work effect")
    require(scene.day_state.preview_work({"kind": "tree", "yield": "timber"}).get("energy", 0) == 15, "live meal effect should reduce the next work energy cost")

    scene._exit_interior(false)
    var orin = scene.npc_actors.get("orin-reed")
    require(orin != null, "Orin should remain available for fishing feedback")
    if orin != null:
        scene.player_position = orin.position / 16.0
        scene._refresh_player_transform()
        scene.day_state.inventory["fish"] = 1
        scene._talk_to_nearest_npc()
        scene.gameplay_hud.hide_dialogue()
        scene._talk_to_nearest_npc()
        require(scene.gameplay_hud.dialogue_text.text.to_lower().find("fish") >= 0, "Orin should acknowledge fish carried from the water")

    require(scene._save_game(), "food and fishing state should save")
    var file := FileAccess.open(scene.SAVE_PATH, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text()) if file != null else {}
    require(parsed is Dictionary and parsed.get("day_state", {}).get("meals", {}).has("riverside-stew"), "saved state should include meal inventory")
    require(parsed is Dictionary and parsed.get("day_state", {}).get("next_work_effects", {}).get("uses", 0) == 1, "saved state should include meal work effects")

    if failures.is_empty():
        print("Godot Food and Fishing smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
