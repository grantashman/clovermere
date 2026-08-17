extends SceneTree

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    get_root().add_child(scene)
    await create_timer(1.0).timeout

    var resident = scene.npc_actors.get("alda-fen")
    require(resident != null, "the benchmark should create the authored resident actor")
    require(scene.player != null, "the main scene should create the player actor")
    if resident != null and scene.player != null:
        require(scene.player.scale.x <= resident.scale.x, "the player should not be larger than an authored resident")
        require(scene.player.scale.y <= resident.scale.y, "the player height should match the resident scale")
        require(scene.player.scale.x > 0.0, "the player scale should remain visible")

    if failures.is_empty():
        print("Godot player-scale contract: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
