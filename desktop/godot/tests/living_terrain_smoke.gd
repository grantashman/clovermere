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
    var oak: Dictionary = scene.world.resources()[0]
    var oak_id := str(oak.get("id", ""))
    var oak_tile := Vector2i(int(oak.x), int(oak.y))
    var approach: Vector2i = scene.world.nearest_walkable(scene.grid, oak_tile + Vector2i(0, 1), 4)
    scene.player_position = Vector2(approach) + Vector2(0.5, 0.5)
    scene._refresh_player_transform()
    scene.command_interact_with_resource(oak_id)
    scene._handle_resource_action()
    require(scene.benchmark_scene.active_resource_id == oak_id, "scene work should activate the benchmark resource visual")
    scene._process(0.4)
    require(scene.benchmark_scene.active_work_progress > 0.0 and scene.benchmark_scene.active_work_progress < 1.0, "partial scene work should expose transient progress")
    scene._process(6.0)
    require(bool(scene.world_changes.get(oak_id, false)), "completed scene work should clear the resource")
    require(scene.benchmark_scene.resource_art_assets.get(oak_id, "") == "tree_stump", "completed tree work should mount the authored stump state")
    require(scene.benchmark_scene.active_resource_id.is_empty(), "completed scene work should clear the transient active visual")

    var herb: Dictionary = scene.world.resources()[5]
    var herb_id := str(herb.get("id", ""))
    var herb_tile := Vector2i(int(herb.x), int(herb.y))
    var herb_approach: Vector2i = scene.world.nearest_walkable(scene.grid, herb_tile + Vector2i(0, 1), 4)
    scene.player_position = Vector2(herb_approach) + Vector2(0.5, 0.5)
    scene._refresh_player_transform()
    scene.command_interact_with_resource(herb_id)
    scene._handle_resource_action()
    scene._process(3.5)
    require(bool(scene.world_changes.get(herb_id, false)), "herb work should clear the herb")
    scene.player_position = Vector2(scene.world.SETTLEMENT_ORIGIN.x + 8.5, scene.world.SETTLEMENT_ORIGIN.y + 12.5)
    scene._refresh_player_transform()
    scene._handle_resource_action()
    require(scene.benchmark_scene.regrowth_resource_ids.has(herb_id), "sleep should begin the herb regrowth visual")
    require(scene.benchmark_scene.resource_art_assets.get(herb_id, "") == "herb", "regrown herbs should remount the intact authored herb")

    if failures.is_empty():
        print("Godot living-terrain smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Godot living-terrain smoke: FAIL (%d)" % failures.size())
    quit(1)
