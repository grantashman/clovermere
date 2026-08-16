extends SceneTree

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    get_root().add_child(scene)
    await create_timer(1.0).timeout

    require(scene.npc_actors.size() == scene.world.npcs().size(), "every resident should have a live actor node")
    require(scene.npc_layer != null, "live residents should have a dedicated actor layer")
    var alda = scene.npc_actors.get("alda-fen")
    require(alda != null, "Alda Fen should be represented by a live actor")
    require(alda.activity == "opening", "the initial 08:00 schedule should show opening activity")

    scene._start_new_journey()
    scene.day_state.minute_of_day = 11 * 60
    scene._refresh_npc_schedules(true)
    require(alda.activity == "gathering", "Alda should gather during the work phase")
    require(alda.route.size() > 0, "Alda should receive a walk route to the work target")
    var initial_position: Vector2 = alda.position
    await create_timer(0.8).timeout
    require(alda.position.distance_to(initial_position) > 0.1, "live actors should move while a journey is active")

    scene.day_state.minute_of_day = 17 * 60
    scene._refresh_npc_schedules(true)
    require(alda.activity == "strolling", "Alda should stroll during the evening phase")
    scene.day_state.minute_of_day = 22 * 60
    scene._refresh_npc_schedules(true)
    require(alda.activity == "resting", "Alda should rest during the night phase")

    if failures.is_empty():
        print("Godot live NPC smoke: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
