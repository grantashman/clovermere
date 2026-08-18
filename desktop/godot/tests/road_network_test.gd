extends SceneTree

const World = preload("res://scripts/world_contract.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _route_endpoint(route: Dictionary) -> Vector2:
    var points: Array = route.get("waypoints", [])
    return Vector2(points.back()) if not points.is_empty() else Vector2(-999, -999)

func _inside_building(tile: Vector2i, building: Dictionary) -> bool:
    return Rect2i(int(building.x), int(building.y), int(building.w), int(building.h)).has_point(tile)

func _initialize() -> void:
    var world = World.new()
    var village := {"name": "Clovermere", "landscape": "heath"}
    var routes: Array = world.path_routes(village)
    var buildings: Array = world.buildings()
    var landmarks: Array = world.LANDMARKS
    var ids := {}
    var building_targets := {}
    var landmark_targets := {}

    for route_variant in routes:
        var route: Dictionary = route_variant
        var route_id := str(route.get("id", ""))
        require(not route_id.is_empty(), "every road route should have a stable id")
        require(not ids.has(route_id), "road route ids should be unique")
        ids[route_id] = true
        require(route.has("from") and route.has("to"), "%s should declare its graph endpoints" % route_id)
        var points: Array = route.get("waypoints", [])
        require(points.size() >= 2, "%s should have a complete path" % route_id)
        for segment in range(points.size() - 1):
            var start := Vector2(points[segment])
            var finish := Vector2(points[segment + 1])
            var samples := maxi(1, ceili(start.distance_to(finish)))
            for sample in range(samples + 1):
                var position := start.lerp(finish, float(sample) / float(samples))
                var tile := Vector2i(roundi(position.x), roundi(position.y))
                for building in buildings:
                    require(not _inside_building(tile, building), "%s should not cross %s" % [route_id, str(building.id)])
        if route.has("building_id"):
            var building_id := str(route.get("building_id", ""))
            building_targets[building_id] = true
            var endpoint := Vector2i(roundi(_route_endpoint(route).x), roundi(_route_endpoint(route).y))
            for building in buildings:
                if str(building.id) == building_id:
                    require(not _inside_building(endpoint, building), "%s should stop outside its building footprint" % route_id)
        if route.has("landmark_id"):
            landmark_targets[str(route.get("landmark_id", ""))] = true

    for building in buildings:
        require(building_targets.has(str(building.id)), "%s should have one deliberate door approach" % building.id)
    for landmark in landmarks:
        require(landmark_targets.has(str(landmark.id)), "%s should have one deliberate trail target" % landmark.id)

    var grid: Array = world.build_grid(village)
    for route_variant in routes:
        var route: Dictionary = route_variant
        if str(route.get("kind", "")) != "village-road":
            continue
        var points: Array = route.get("waypoints", [])
        var endpoint := Vector2i(roundi(Vector2(points.back()).x), roundi(Vector2(points.back()).y))
        require(world.is_walkable(grid, endpoint), "%s should end on a walkable road cell" % str(route.id))

    require(routes.any(func(route): return str(route.get("from", "")) == "central-hub"), "road graph should have a central hub")
    require(routes.any(func(route): return str(route.get("from", "")) == "west-gate" or str(route.get("to", "")) == "west-gate"), "road graph should have a west settlement gate")

    if failures.is_empty():
        print("Godot road network contract: PASS")
        quit(0)
        return
    print("Godot road network contract: FAIL (%d)" % failures.size())
    for failure in failures:
        print(" - ", failure)
    quit(1)
