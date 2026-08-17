extends SceneTree

const World = preload("res://scripts/world_contract.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var world = World.new()
    var village := {"name": "Clovermere", "landscape": "heath"}
    var first: Array = world.resources(village)
    var second: Array = world.resources(village)
    require(first == second, "procedural resources should be deterministic for the same village")
    require(first.size() >= 60, "the world should expose a broad generated resource roster")

    var counts := {"tree": 0, "stone": 0, "ore": 0, "herb": 0, "fish": 0}
    var quadrant_counts: Dictionary = {}
    for quadrant in 4:
        quadrant_counts[quadrant] = {"tree": 0, "stone": 0, "ore": 0, "herb": 0, "fish": 0}
    var ids: Dictionary = {}
    for resource_variant in first:
        var resource: Dictionary = resource_variant
        var resource_id := str(resource.get("id", ""))
        var kind := str(resource.get("kind", ""))
        var tile := Vector2i(int(resource.get("x", -1)), int(resource.get("y", -1)))
        require(not ids.has(resource_id), "generated resources should have unique ids")
        ids[resource_id] = true
        require(world.building_at(tile).is_empty(), "%s should not spawn inside a building" % resource_id)
        require(counts.has(kind), "%s should use a supported resource kind" % resource_id)
        if counts.has(kind):
            counts[kind] += 1
            var quadrant := (0 if tile.x < World.WORLD_WIDTH / 2 else 1) + (0 if tile.y < World.WORLD_HEIGHT / 2 else 2)
            quadrant_counts[quadrant][kind] += 1
            if kind == "fish":
                var grid: Array = world.build_grid(village, {})
                require(world.tile_at(grid, tile) == "w", "%s fish spot should sit on water" % resource_id)

    for kind in counts.keys():
        require(int(counts[kind]) >= 8, "%s should be distributed across the world" % kind)
        for quadrant in 4:
            require(int(quadrant_counts[quadrant][kind]) >= 1, "%s should appear in every world quadrant" % kind)

    var fish_state = preload("res://scripts/day_state.gd").new()
    var fish_work: Dictionary = fish_state.work_resource({"kind": "fish", "yield": "fish"})
    require(bool(fish_work.get("ok", false)), "a rested player should be able to fish")
    require(fish_state.inventory.get("fish", 0) == 2, "fishing should add fish to the field pack")
    require(fish_state.minute_of_day == 8 * 60 + 30, "fishing should advance the clock by thirty minutes")

    if failures.is_empty():
        print("Godot procedural resource contract: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
