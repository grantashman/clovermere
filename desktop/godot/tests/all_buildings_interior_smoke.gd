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

    for building_id in ["greenbriar-cottage", "clovermere-hall", "tinker-workshop", "herbalists-garden", "old-barn"]:
        scene._enter_interior(building_id, false)
        require(scene._in_interior(), "%s should enter as a live interior" % building_id)
        require(scene.interior_scene.visible, "%s interior renderer should be visible" % building_id)
        require(scene.interior_scene.building_id == building_id, "%s renderer should retain its building id" % building_id)
        require(scene.interior_scene.furniture_ids().size() >= 3, "%s should expose at least three useful interior points" % building_id)
        scene._exit_interior(false)
        require(not scene._in_interior(), "%s should exit back to the village" % building_id)
        require(scene.benchmark_scene.visible, "%s exit should restore the exterior benchmark" % building_id)

    if failures.is_empty():
        print("Godot all-building interior smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
