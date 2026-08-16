extends SceneTree

const World = preload("res://scripts/world_contract.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _init() -> void:
    var world = World.new()
    var village := {"name": "Moonrise Hollow", "landscape": "heath"}
    var first: Array = world.build_grid(village)
    var second: Array = world.build_grid(village)

    require(first.size() == World.WORLD_HEIGHT, "world height should be 160")
    require(first[0].size() == World.WORLD_WIDTH, "world width should be 240")
    require(first == second, "same village seed should generate the same world")
    var terrain := {}
    for row in first:
        for tile in row:
            terrain[tile] = true
    for tile in ["g", "m", "r", "t", "w", "p", "b"]:
        require(terrain.has(tile), "world should contain terrain tile %s" % tile)
    require(first[World.START_TILE.y][World.START_TILE.x] == "p", "spawn should sit on a path")

    var migrated: Dictionary = world.normalize_save({"version": 5, "player": {"x": 14, "y": 11}})
    require(migrated.version == 6, "legacy save should migrate to version 6")
    require(migrated.player == World.START_POSITION, "legacy local coordinates should migrate to centred world coordinates")

    var walkable := world.move_player(World.START_POSITION, Vector2.RIGHT, 0.25, first)
    require(walkable.x > World.START_POSITION.x, "continuous movement should advance by elapsed time")
    var blocked := world.move_player(Vector2(1.5, 1.5), Vector2.LEFT, 2.0, first)
    require(blocked.x >= 1.0, "movement should stop at the world border")

    var routes: Array = world.path_routes(village)
    require(routes.size() >= 10, "settlement should expose authored local and destination routes")
    require(routes.any(func(route): return abs(float(route.bend)) > 0.0), "routes should include organic bends")

    if failures.is_empty():
        print("Godot world contract: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
