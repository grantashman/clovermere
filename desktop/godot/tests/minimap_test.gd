extends SceneTree

const Minimap = preload("res://scripts/minimap.gd")
const World = preload("res://scripts/world_contract.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var world = World.new()
    var grid: Array = world.build_grid({"name": "Clovermere", "landscape": "heath"}, {})
    var minimap = Minimap.new()
    minimap.configure(world, grid, World.START_POSITION, {"greenbriar-cottage": true})
    require(minimap.world_size == Vector2i(World.WORLD_WIDTH, World.WORLD_HEIGHT), "minimap should cover the full deterministic world")
    require(minimap.player_tile == Vector2i(floori(World.START_POSITION.x), floori(World.START_POSITION.y)), "minimap should track the player tile")
    require(minimap.landmark_count == world.LANDMARKS.size(), "minimap should include all authored landmarks")

    if failures.is_empty():
        print("Godot minimap contract: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
