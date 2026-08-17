extends SceneTree

const World = preload("res://scripts/world_contract.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _init() -> void:
    var world = World.new()
    var village := {"name": "Clovermere", "landscape": "heath"}
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
    require(migrated.version == 7, "legacy save should migrate to version 7")
    require(migrated.player == World.START_POSITION, "legacy local coordinates should migrate to centred world coordinates")
    require(migrated.resource_states is Dictionary, "legacy saves should gain an empty resource-state map")
    require(migrated.resident_memory is Dictionary, "legacy saves should gain an empty resident-memory map")
    var schema_six: Dictionary = world.normalize_save({"version": 6, "player": {"x": World.START_POSITION.x, "y": World.START_POSITION.y}})
    require(schema_six.player == World.START_POSITION, "schema-6 world coordinates should not be offset during schema-7 migration")

    var walkable := world.move_player(World.START_POSITION, Vector2.RIGHT, 0.25, first)
    require(walkable.x > World.START_POSITION.x, "continuous movement should advance by elapsed time")
    var blocked := world.move_player(Vector2(1.5, 1.5), Vector2.LEFT, 2.0, first)
    require(blocked.x >= 1.0, "movement should stop at the world border")

    var routes: Array = world.path_routes(village)
    require(routes.size() >= 10, "settlement should expose authored local and destination routes")
    require(routes.all(func(route): return is_zero_approx(float(route.bend))), "desktop routes should stay on the authored pixel grid")
    require(world.buildings().size() == 5, "settlement should expose five authored buildings")
    require(world.npcs().size() >= 6, "settlement should expose a visible resident roster")
    require(world.resources().size() >= 7, "settlement should expose harvestable timber, stone, ore, and herbs")
    var cleared_grid: Array = world.build_grid(village, {"oak-at-the-crossing": true})
    require(world.tile_at(cleared_grid, Vector2i(World.SETTLEMENT_ORIGIN.x - 8, World.SETTLEMENT_ORIGIN.y + 10)) == "g", "cleared resources should restore walkable ground")
    var path_to_lane: Array = world.find_path(first, World.START_TILE, Vector2i(World.SETTLEMENT_ORIGIN.x + 62, World.SETTLEMENT_ORIGIN.y + 11))
    require(not path_to_lane.is_empty(), "walkable settlement lanes should be pathfindable")
    require(world.building_at(Vector2i(World.SETTLEMENT_ORIGIN.x + 5, World.SETTLEMENT_ORIGIN.y + 6)).get("id", "") == "greenbriar-cottage", "building hit testing should identify authored structures")

    if failures.is_empty():
        print("Godot world contract: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
