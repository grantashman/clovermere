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

    var alda = scene.npc_actors.get("alda-fen")
    require(alda != null, "Alda should exist in the live resident roster")
    if alda != null:
        scene.player_position = alda.position / 16.0
        scene._refresh_player_transform()
        scene._talk_to_nearest_npc()
        require(scene.gameplay_hud.dialogue_panel.visible, "first resident talk should open the dialogue panel")
        require(scene.resident_memory.get("alda-fen", {}).get("stage", 0) == 1, "first resident talk should mark Alda as acquainted")

        scene.day_state.energy = 80
        scene.day_state.inventory["herbs"] = 2
        scene._talk_to_nearest_npc()
        require(scene.resident_memory.get("alda-fen", {}).get("stage", 0) == 2, "ready Alda favor should advance her to trusted")
        require(scene.resident_memory.get("alda-fen", {}).get("favor_completed", false), "ready Alda favor should persist completion")
        require(scene.day_state.inventory.get("herbs", 0) == 0, "completed favor should spend the required herbs")
        require(scene.day_state.energy == 90, "completed Alda favor should apply the tonic reward")

    require(scene._save_game(), "Village Memory should save through the existing journey ledger")
    var file := FileAccess.open(scene.SAVE_PATH, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text()) if file != null else {}
    require(parsed is Dictionary, "saved journey should remain valid JSON")
    if parsed is Dictionary:
        require(parsed.get("resident_memory", {}).get("alda-fen", {}).get("stage", 0) == 2, "saved journey should contain Alda's relationship stage")

    scene.resident_memory = scene.village_memory.default_state()
    require(scene._load_save(), "Village Memory journey should reload")
    require(scene.resident_memory.get("alda-fen", {}).get("stage", 0) == 2, "loading should restore Alda's relationship stage")

    if failures.is_empty():
        print("Godot Village Memory smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
