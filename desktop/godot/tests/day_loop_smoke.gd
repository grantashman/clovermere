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

    require(scene.day_state.day == 1, "new journey should create a fresh day state")
    require(scene.day_state.minute_of_day == 480, "new journey should begin at 08:00")
    require(scene.day_label.text.contains("DAY 01"), "gameplay HUD should show the current day")
    require(scene.day_label.text.contains("08:00 AM"), "gameplay HUD should show the current clock")
    require(scene.gameplay_hud.resource_slots.size() == 5, "gameplay HUD should expose five icon-led material slots")
    require(scene.gameplay_hud.resource_slots[3].amount == 0, "herb slot should start empty")
    var herb: Dictionary = scene.world.resources()[5]
    var herb_id := str(herb.get("id", ""))
    var before_minute: int = scene.day_state.minute_of_day
    var herb_tile := Vector2i(int(herb.x), int(herb.y))
    var approach: Vector2i = scene.world.nearest_walkable(scene.grid, herb_tile + Vector2i(0, 1), 4)
    scene.player_position = Vector2(approach) + Vector2(0.5, 0.5)
    scene._refresh_player_transform()
    scene.command_interact_with_resource(str(herb.get("id", "")))
    scene._handle_resource_action()
    scene._process(3.5)
    require(scene.day_state.minute_of_day > before_minute, "working a resource in the scene should advance time")
    require(scene.day_state.inventory.get("herbs", 0) == 2, "working herbs in the scene should add herbs to inventory")
    require(scene.gameplay_hud.resource_slots[3].amount == 2, "gameplay HUD should update the herb icon slot after work")
    require(bool(scene.world_changes.get(herb_id, false)), "working a resource should mark it cleared")

    require(scene._save_game(), "the day loop should save through the native ledger")
    var saved_day: int = scene.day_state.day
    var saved_minute: int = scene.day_state.minute_of_day
    scene.day_state.day = 8
    scene.day_state.minute_of_day = 1200
    scene.day_state.inventory["herbs"] = 0
    require(scene._load_save(), "the day loop should load through the native ledger")
    require(scene.day_state.day == saved_day, "load should restore the saved day")
    require(scene.day_state.minute_of_day == saved_minute, "load should restore the saved clock")
    require(scene.day_state.inventory.get("herbs", 0) == 2, "load should restore the saved inventory")

    scene.player_position = Vector2(scene.world.SETTLEMENT_ORIGIN.x + 8.5, scene.world.SETTLEMENT_ORIGIN.y + 12.5)
    scene._refresh_player_transform()
    scene._handle_resource_action()
    require(scene.day_state.day == saved_day + 1, "sleeping should advance the day in the scene")
    require(scene.day_state.minute_of_day == 480, "sleeping should reset the clock to 08:00")
    require(scene.day_state.energy == 100, "sleeping should restore full energy in the scene")
    require(not bool(scene.world_changes.get(herb_id, true)), "sleeping should regrow gathered herbs in the scene")

    if failures.is_empty():
        print("Godot day-loop smoke: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
