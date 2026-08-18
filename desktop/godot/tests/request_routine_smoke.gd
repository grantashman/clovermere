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

    scene._enter_interior("clovermere-hall", false)
    scene.player_position = Vector2(4.5, 5.5)
    scene._refresh_player_transform()
    scene._handle_interior_action()
    require(scene.gameplay_hud.management_panel.visible, "Hall notice board should open the request surface")
    require(scene.gameplay_hud.management_mode == "requests", "Hall notice board should select the request board")
    require(scene.gameplay_hud.management_content.get_child_count() == 3, "request board should show three rotating cards")

    var first_request: Dictionary = scene.request_board.board_cards(scene.request_state, scene.day_state.day, scene.day_state.inventory)[0]
    scene._handle_request_action(str(first_request.get("id", "")), "accept")
    require(not str(scene.request_state.get("accepted_id", "")).is_empty(), "board action should accept one request")
    require(scene.request_state.get("accepted_day", 0) == scene.day_state.day, "accepted request should store its day")

    scene._exit_interior(false)
    var accepted: Dictionary = scene.request_board.accepted_request(scene.request_state, scene.day_state.day)
    var requester_id := str(accepted.get("requester", ""))
    var requester = scene.npc_actors.get(requester_id)
    require(requester != null, "accepted request should point to a live resident")
    var cost: Dictionary = accepted.get("cost", {})
    for material_variant in cost.keys():
        scene.day_state.inventory[str(material_variant)] = int(cost[material_variant])
    scene.player_position = requester.position / 16.0
    scene._refresh_player_transform()
    scene._talk_to_nearest_npc()
    require(scene.request_state.get("completed_ids", {}).has(str(accepted.get("id", ""))), "talking to the requester with materials should complete the request")
    require(str(scene.request_state.get("accepted_id", "")) == "", "completed request should clear the active request")
    require(scene.request_board.consequence_flags(scene.request_state).size() == 1, "completed request should create a visible consequence flag")

    require(scene._save_game(), "request completion should save through the existing ledger")
    require(scene._load_save(), "request completion should load through the existing ledger")
    require(scene.request_state.get("completed_ids", {}).has(str(accepted.get("id", ""))), "request completion should survive save/load")

    if failures.is_empty():
        print("Godot Requests & Routine smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
