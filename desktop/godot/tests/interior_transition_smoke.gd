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
    require(scene._in_interior(), "Cottage entry should switch the live scene to interior mode")
    require(scene.interior_scene.visible, "Cottage renderer should be visible after entry")
    require(not scene.benchmark_scene.visible, "Exterior benchmark should be hidden inside")
    require(not scene.gameplay_hud.minimap.visible, "Minimap should hide inside authored interiors")
    require(scene.player_position == scene.interior_contract.spawn_position("greenbriar-cottage"), "entry should place the player at the authored Cottage spawn")
    require(scene._is_near_home(), "Cottage interior should count as home for storage and sleep")

    scene.player_position = Vector2(8.5, 9.5)
    scene._handle_interior_action()
    require(scene.interaction_message.find("Home stores") >= 0 or scene.interaction_message.find("stores") >= 0, "Cottage storage interaction should use the existing home-store loop")

    scene._exit_interior(false)
    require(not scene._in_interior(), "exit should return to the exterior village")
    require(scene.benchmark_scene.visible, "exterior benchmark should return after exit")
    require(scene.gameplay_hud.minimap.visible, "minimap should return after leaving an interior")

    scene._enter_interior("tinker-workshop", false)
    require(scene._is_near_workshop(), "Workshop interior should count as the active crafting location")
    scene.player_position = Vector2(7.5, 6.5)
    scene._handle_interior_action()
    require(scene.gameplay_hud.management_panel.visible, "workbench interaction should open the recipe panel")
    require(scene.gameplay_hud.management_mode == "craft", "workbench interaction should select the crafting tab")
    scene.gameplay_hud.close_management()

    var npc_ids: Array = scene.npc_actors.keys()
    if not npc_ids.is_empty():
        var first_npc = scene.npc_actors.get(npc_ids[0])
        scene._exit_interior(false)
        scene.player_position = first_npc.position / 16.0
        scene._talk_to_nearest_npc()
        require(scene.gameplay_hud.dialogue_panel.visible, "talking to a resident should open the dialogue panel")
        require(scene.dialogue_flags.get(str(npc_ids[0]), false), "talking to a resident should set its persistent dialogue flag")
        scene.gameplay_hud.hide_dialogue()
        scene._enter_interior("tinker-workshop", false)

    scene.dialogue_flags["alda-fen"] = true
    require(scene._save_game(), "interior save should write through the existing save path")
    var file := FileAccess.open(scene.SAVE_PATH, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text()) if file != null else {}
    require(parsed is Dictionary and parsed.get("location", "") == "tinker-workshop", "interior save should preserve the current location")
    require(parsed is Dictionary and parsed.get("interior", {}).get("building_id", "") == "tinker-workshop", "interior save should preserve the building id")
    require(parsed is Dictionary and parsed.get("dialogue_flags", {}).get("alda-fen", false), "dialogue flags should persist in the existing save payload")

    scene._exit_interior(false)
    require(scene._load_save(), "saved interior journey should load")
    require(scene._in_interior(), "loading an interior save should restore interior mode")
    require(scene.interior_location == "tinker-workshop", "loading should restore the saved interior")
    require(scene.dialogue_flags.get("alda-fen", false), "loading should restore dialogue flags")

    if failures.is_empty():
        print("Godot interior transition smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
