extends RefCounted
class_name ClovermereWorld

const WORLD_WIDTH := 240
const WORLD_HEIGHT := 160
const TILE_SIZE := 16.0
const SAVE_VERSION := 7
const SETTLEMENT_ORIGIN := Vector2i(108, 71)
const START_TILE := Vector2i(SETTLEMENT_ORIGIN.x + 14, SETTLEMENT_ORIGIN.y + 11)
const START_POSITION := Vector2(START_TILE.x + 0.5, START_TILE.y + 0.5)
const BLOCKED_TILES := {"t": true, "w": true, "r": true, "f": true, "b": true, "s": true, "h": true, "#": true}

const BUILDINGS := [
    {"id": "greenbriar-cottage", "name": "Greenbriar Cottage", "x": SETTLEMENT_ORIGIN.x + 4, "y": SETTLEMENT_ORIGIN.y + 5, "w": 8, "h": 6, "kind": "cottage", "wall": "#c89468", "roof": "#465647"},
    {"id": "clovermere-hall", "name": "Clovermere Hall", "x": SETTLEMENT_ORIGIN.x + 24, "y": SETTLEMENT_ORIGIN.y + 4, "w": 8, "h": 6, "kind": "hall", "wall": "#d0a16f", "roof": "#53654e"},
    {"id": "tinker-workshop", "name": "Tinker Workshop", "x": SETTLEMENT_ORIGIN.x + 39, "y": SETTLEMENT_ORIGIN.y + 7, "w": 9, "h": 7, "kind": "workshop", "wall": "#b9865c", "roof": "#3f5148"},
    {"id": "herbalists-garden", "name": "Herbalist's Garden", "x": SETTLEMENT_ORIGIN.x + 17, "y": SETTLEMENT_ORIGIN.y + 24, "w": 10, "h": 7, "kind": "garden", "wall": "#c99468", "roof": "#596a51"},
    {"id": "old-barn", "name": "Old Barn", "x": SETTLEMENT_ORIGIN.x + 45, "y": SETTLEMENT_ORIGIN.y + 26, "w": 9, "h": 7, "kind": "barn", "wall": "#ad7452", "roof": "#4a5148"}
]

const NPCS := [
    {"id": "alda-fen", "name": "Alda Fen", "role": "herbalist", "x": SETTLEMENT_ORIGIN.x + 13, "y": SETTLEMENT_ORIGIN.y + 13, "skin": "#d6a27a", "hair": "#563d32", "coat": "#7d8f5b", "accent": "#d6b36d"},
    {"id": "orin-reed", "name": "Orin Reed", "role": "waykeeper", "x": SETTLEMENT_ORIGIN.x + 34, "y": SETTLEMENT_ORIGIN.y + 12, "skin": "#bd875e", "hair": "#362f2b", "coat": "#526b78", "accent": "#c47c55"},
    {"id": "maeve-thorn", "name": "Maeve Thorn", "role": "gardener", "x": SETTLEMENT_ORIGIN.x + 13, "y": SETTLEMENT_ORIGIN.y + 23, "skin": "#e0b084", "hair": "#8a5b39", "coat": "#9b6b5a", "accent": "#d6c477"},
    {"id": "tobin-wren", "name": "Tobin Wren", "role": "maker", "x": SETTLEMENT_ORIGIN.x + 36, "y": SETTLEMENT_ORIGIN.y + 23, "skin": "#c99168", "hair": "#4a3630", "coat": "#6b8159", "accent": "#c78256"},
    {"id": "pella-moor", "name": "Pella Moor", "role": "courier", "x": SETTLEMENT_ORIGIN.x + 43, "y": SETTLEMENT_ORIGIN.y + 18, "skin": "#d7a47d", "hair": "#6c493b", "coat": "#7d607d", "accent": "#e0be77"},
    {"id": "bram-ash", "name": "Bram Ash", "role": "keeper", "x": SETTLEMENT_ORIGIN.x + 28, "y": SETTLEMENT_ORIGIN.y + 39, "skin": "#bb805b", "hair": "#302e2c", "coat": "#80664c", "accent": "#b9a267"}
]

const RESOURCE_NODES := [
    {"id": "oak-at-the-crossing", "name": "Oak at the Crossing", "kind": "tree", "x": SETTLEMENT_ORIGIN.x - 8, "y": SETTLEMENT_ORIGIN.y + 10, "yield": "timber"},
    {"id": "birch-by-the-lane", "name": "Birch by the Lane", "kind": "tree", "x": SETTLEMENT_ORIGIN.x + 61, "y": SETTLEMENT_ORIGIN.y + 15, "yield": "timber"},
    {"id": "old-ash-grove", "name": "Old Ash Grove", "kind": "tree", "x": SETTLEMENT_ORIGIN.x + 8, "y": SETTLEMENT_ORIGIN.y + 39, "yield": "timber"},
    {"id": "greycap-boulder", "name": "Greycap Boulder", "kind": "stone", "x": SETTLEMENT_ORIGIN.x + 58, "y": SETTLEMENT_ORIGIN.y + 38, "yield": "stone"},
    {"id": "ironroot-vein", "name": "Ironroot Vein", "kind": "ore", "x": SETTLEMENT_ORIGIN.x + 70, "y": SETTLEMENT_ORIGIN.y + 48, "yield": "ore"},
    {"id": "foxglove-patch", "name": "Foxglove Patch", "kind": "herb", "x": SETTLEMENT_ORIGIN.x + 10, "y": SETTLEMENT_ORIGIN.y + 28, "yield": "herbs"},
    {"id": "moonmint-patch", "name": "Moonmint Patch", "kind": "herb", "x": SETTLEMENT_ORIGIN.x + 55, "y": SETTLEMENT_ORIGIN.y + 22, "yield": "herbs"}
]

const LANDMARKS := [
    {"id": "apple-orchard", "name": "Apple Orchard", "x": 70, "y": 103, "w": 12, "h": 10},
    {"id": "willowmere", "name": "Willowmere", "x": 178, "y": 82, "w": 13, "h": 10},
    {"id": "stonecutters-hollow", "name": "Stonecutter's Hollow", "x": 178, "y": 125, "w": 14, "h": 11},
    {"id": "west-lookout", "name": "West Lookout", "x": 74, "y": 127, "w": 11, "h": 10}
]

func seed_from_text(value: String) -> int:
    var result := 2166136261
    for byte in value.to_utf8_buffer():
        result = int((result ^ int(byte)) * 16777619) & 0x7fffffff
    return result

func hash2d(x: int, y: int, seed: int) -> float:
    var value := x * 374761393 + y * 668265263 + seed * 1442695041
    value = (value ^ (value >> 13)) * 1274126177
    value = value ^ (value >> 16)
    return float(abs(value % 10000)) / 10000.0

func smooth_noise(x: int, y: int, scale: int, seed: int) -> float:
    var fx := float(x) / float(scale)
    var fy := float(y) / float(scale)
    var x0 := floori(fx)
    var y0 := floori(fy)
    var tx := fx - float(x0)
    var ty := fy - float(y0)
    var a := hash2d(x0, y0, seed)
    var b := hash2d(x0 + 1, y0, seed)
    var c := hash2d(x0, y0 + 1, seed)
    var d := hash2d(x0 + 1, y0 + 1, seed)
    var eased_x := tx * tx * (3.0 - 2.0 * tx)
    var eased_y := ty * ty * (3.0 - 2.0 * ty)
    return lerp(lerp(a, b, eased_x), lerp(c, d, eased_x), eased_y)

func path_routes(village: Dictionary = {}) -> Array:
    var seed := seed_from_text("%s:%s" % [village.get("name", "Clovermere"), village.get("landscape", "heath")])
    var ox := SETTLEMENT_ORIGIN.x
    var oy := SETTLEMENT_ORIGIN.y
    var routes: Array = [
        {"start": Vector2(ox + 5, oy + 11), "end": Vector2(ox + 67, oy + 11), "width": 1.0, "bend": 0.0, "bridge": false},
        {"start": Vector2(ox + 30, oy + 5), "end": Vector2(ox + 30, oy + 50), "width": 1.0, "bend": 0.0, "bridge": false},
        {"start": Vector2(ox + 14, oy + 6), "end": Vector2(ox + 14, oy + 18), "width": 1.0, "bend": 0.0, "bridge": false},
        {"start": Vector2(ox + 5, oy + 16), "end": Vector2(ox + 24, oy + 16), "width": 1.0, "bend": 0.0, "bridge": false},
        {"start": Vector2(ox + 30, oy + 31), "end": Vector2(ox + 67, oy + 31), "width": 1.0, "bend": 0.0, "bridge": true},
        {"start": Vector2(ox + 12, oy + 44), "end": Vector2(ox + 61, oy + 44), "width": 1.0, "bend": 0.0, "bridge": false}
    ]
    var trail_starts := [
        Vector2(ox + 12, oy + 16),
        Vector2(ox + 67, oy + 11),
        Vector2(ox + 61, oy + 44),
        Vector2(ox + 12, oy + 44)
    ]
    for index in LANDMARKS.size():
        var landmark: Dictionary = LANDMARKS[index]
        var target := Vector2(float(landmark.x), float(landmark.y))
        var start: Vector2 = trail_starts[index]
        routes.append({"start": start, "end": target, "width": 1.0, "bend": 0.0, "bridge": true})
    return routes

func buildings() -> Array:
    return BUILDINGS.duplicate(true)

func npcs() -> Array:
    return NPCS.duplicate(true)

func resources() -> Array:
    return RESOURCE_NODES.duplicate(true)

func building_at(tile: Vector2i) -> Dictionary:
    for building in BUILDINGS:
        var rect := Rect2i(int(building.x), int(building.y), int(building.w), int(building.h))
        if rect.has_point(tile):
            return building
    return {}

func resource_at(tile: Vector2i) -> Dictionary:
    for resource in RESOURCE_NODES:
        if Vector2i(int(resource.x), int(resource.y)) == tile:
            return resource
    return {}

func _inside(grid: Array, x: int, y: int) -> bool:
    return y >= 0 and y < grid.size() and x >= 0 and x < grid[y].size()

func _set_cell(grid: Array, x: int, y: int, tile: String) -> void:
    if x > 0 and y > 5 and x < WORLD_WIDTH - 1 and y < WORLD_HEIGHT - 1 and _inside(grid, x, y):
        grid[y][x] = tile

func _paint_corridor(grid: Array, start: Vector2, finish: Vector2, width: float, _bend: float, bridge: bool) -> void:
    var origin := Vector2i(roundi(start.x), roundi(start.y))
    var target := Vector2i(roundi(finish.x), roundi(finish.y))
    var pivot := Vector2i(target.x, origin.y)
    var cells: Array[Vector2i] = []
    var current := origin
    cells.append(current)
    while current.x != pivot.x:
        current.x += 1 if pivot.x > current.x else -1
        cells.append(current)
    while current.y != target.y:
        current.y += 1 if target.y > current.y else -1
        cells.append(current)
    var radius := 0 if width <= 1.0 else ceili(width * 0.5)
    for centre in cells:
        for offset_y in range(-radius, radius + 1):
            for offset_x in range(-radius, radius + 1):
                if maxi(abs(offset_x), abs(offset_y)) > radius:
                    continue
                var x := centre.x + offset_x
                var y := centre.y + offset_y
                if _inside(grid, x, y) and (bridge or grid[y][x] != "w"):
                    _set_cell(grid, x, y, "p")

func build_grid(village: Dictionary = {}, changes: Dictionary = {}) -> Array:
    var seed := seed_from_text("%s:%s" % [village.get("name", "Clovermere"), village.get("landscape", "heath")])
    var grid: Array = []
    for y in WORLD_HEIGHT:
        var row: Array = []
        for x in WORLD_WIDTH:
            if x < 1 or y < 1 or x >= WORLD_WIDTH - 1 or y >= WORLD_HEIGHT - 1:
                row.append("t")
            elif y <= 4:
                row.append("s")
            elif y == 5:
                row.append("h")
            else:
                var forest := smooth_noise(x + 18, y - 7, 17, seed + 11)
                var moisture := smooth_noise(x - 23, y + 31, 23, seed + 29)
                var ridge := smooth_noise(x + 61, y + 9, 11, seed + 47)
                if ridge < 0.16:
                    row.append("r")
                elif forest > 0.68:
                    row.append("t")
                elif moisture > 0.76 and forest < 0.54:
                    row.append("w")
                elif moisture > 0.54 or ridge > 0.71:
                    row.append("m")
                else:
                    row.append("g")
        grid.append(row)

    for y in range(7, WORLD_HEIGHT - 7):
        var centre := 176 + roundi(sin(float(y) / 15.0) * 6.0 + sin(float(y) / 31.0) * 4.0)
        for x in range(centre - 2, centre + 3):
            _set_cell(grid, x, y, "w")
    for ellipse in [[44, 38, 17, 12], [198, 39, 20, 14], [192, 124, 15, 10]]:
        for y in range(ellipse[1] - ellipse[3], ellipse[1] + ellipse[3] + 1):
            for x in range(ellipse[0] - ellipse[2], ellipse[0] + ellipse[2] + 1):
                var dx := float(x - ellipse[0]) / float(ellipse[2])
                var dy := float(y - ellipse[1]) / float(ellipse[3])
                if dx * dx + dy * dy <= 1.0:
                    _set_cell(grid, x, y, "w")

    var ox := SETTLEMENT_ORIGIN.x
    var oy := SETTLEMENT_ORIGIN.y
    for y in range(oy - 4, oy + 54):
        for x in range(ox - 4, ox + 65):
            _set_cell(grid, x, y, "g")
    for y in range(oy + 2, oy + 6):
        for x in range(ox + 11, ox + 15):
            _set_cell(grid, x, y, "w")
    for route in path_routes(village):
        _paint_corridor(grid, route.start, route.end, route.width, route.bend, route.bridge)
    _set_cell(grid, START_TILE.x, START_TILE.y, "p")
    _set_cell(grid, ox + 30, oy + 11, "p")
    for y in range(oy + 9, oy + 12):
        for x in range(ox + 5, ox + 12):
            _set_cell(grid, x, y, "d")

    for y in range(oy - 1, oy + 21):
        for x in range(ox - 1, ox + 32):
            if _inside(grid, x, y) and grid[y][x] == "w":
                grid[y][x] = "g"
    for building in BUILDINGS:
        for y in range(building.y, building.y + building.h):
            for x in range(building.x, building.x + building.w):
                _set_cell(grid, x, y, "b")
    for resource in RESOURCE_NODES:
        if bool(changes.get(str(resource.id), false)):
            _set_cell(grid, int(resource.x), int(resource.y), "g")
    return grid

func tile_at(grid: Array, tile: Vector2i) -> String:
    if not _inside(grid, tile.x, tile.y):
        return "t"
    return str(grid[tile.y][tile.x])

func is_walkable(grid: Array, tile: Vector2i) -> bool:
    return not BLOCKED_TILES.has(tile_at(grid, tile))

func nearest_walkable(grid: Array, target: Vector2i, max_radius: int = 8) -> Vector2i:
    if is_walkable(grid, target):
        return target
    for radius in range(1, max_radius + 1):
        var candidates: Array[Vector2i] = []
        for offset_y in range(-radius, radius + 1):
            for offset_x in range(-radius, radius + 1):
                if maxi(abs(offset_x), abs(offset_y)) != radius:
                    continue
                var candidate := target + Vector2i(offset_x, offset_y)
                if is_walkable(grid, candidate):
                    candidates.append(candidate)
        candidates.sort_custom(func(a: Vector2i, b: Vector2i): return a.distance_squared_to(target) < b.distance_squared_to(target))
        if not candidates.is_empty():
            return candidates[0]
    return target

func find_path(grid: Array, start: Vector2i, requested_goal: Vector2i) -> Array:
    var goal := nearest_walkable(grid, requested_goal)
    if not is_walkable(grid, start) or not is_walkable(grid, goal):
        return []
    if start == goal:
        return []
    var frontier: Array[Vector2i] = [start]
    var came_from := {}
    var cost_so_far := {start: 0}
    var directions := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
    while not frontier.is_empty():
        var best_index := 0
        for index in range(1, frontier.size()):
            var candidate: Vector2i = frontier[index]
            var best: Vector2i = frontier[best_index]
            var candidate_score: int = int(cost_so_far[candidate]) + abs(candidate.x - goal.x) + abs(candidate.y - goal.y)
            var best_score: int = int(cost_so_far[best]) + abs(best.x - goal.x) + abs(best.y - goal.y)
            if candidate_score < best_score:
                best_index = index
        var current: Vector2i = frontier[best_index]
        frontier.remove_at(best_index)
        if current == goal:
            break
        for direction in directions:
            var next: Vector2i = current + direction
            if not is_walkable(grid, next):
                continue
            var new_cost := int(cost_so_far[current]) + 1
            if not cost_so_far.has(next) or new_cost < int(cost_so_far[next]):
                cost_so_far[next] = new_cost
                came_from[next] = current
                if not frontier.has(next):
                    frontier.append(next)
    if not came_from.has(goal):
        return []
    var path: Array = []
    var current := goal
    while current != start:
        path.push_front(current)
        current = came_from[current]
    return path

func _can_occupy(grid: Array, position: Vector2) -> bool:
    for offset in [Vector2(-0.28, -0.28), Vector2(0.28, -0.28), Vector2(-0.28, 0.28), Vector2(0.28, 0.28)]:
        if not is_walkable(grid, Vector2i(floori(position.x + offset.x), floori(position.y + offset.y))):
            return false
    return true

func move_player(position: Vector2, direction: Vector2, delta_seconds: float, grid: Array, speed: float = 4.5) -> Vector2:
    if direction.length_squared() <= 0.0001 or delta_seconds <= 0.0:
        return position
    var travel := direction.normalized() * speed * delta_seconds
    var result := position
    var next_x := Vector2(position.x + travel.x, position.y)
    if _can_occupy(grid, next_x):
        result.x = next_x.x
    var next_y := Vector2(result.x, position.y + travel.y)
    if _can_occupy(grid, next_y):
        result.y = next_y.y
    return result

func normalize_save(source: Dictionary = {}) -> Dictionary:
    var version := int(source.get("version", 0))
    var raw_player: Dictionary = source.get("player", {}) if source.get("player", {}) is Dictionary else {}
    var raw_x := float(raw_player.get("x", 14.5))
    var raw_y := float(raw_player.get("y", 11.5))
    var player := Vector2(raw_x, raw_y)
    if version < 6:
        player += Vector2(SETTLEMENT_ORIGIN) + Vector2(0.5, 0.5)
    var result := source.duplicate(true)
    result["version"] = SAVE_VERSION
    result["player"] = player
    result["location"] = source.get("location", "village") if source.get("location", "village") in ["village", "home", "inn", "greenbriar-cottage", "tinker-workshop"] else "village"
    var raw_interior = source.get("interior", {})
    result["interior"] = raw_interior.duplicate(true) if raw_interior is Dictionary else {}
    var raw_changes = source.get("world_changes", {})
    result["world_changes"] = raw_changes.duplicate(true) if raw_changes is Dictionary else {}
    var raw_day_state = source.get("day_state", {})
    result["day_state"] = raw_day_state.duplicate(true) if raw_day_state is Dictionary else {}
    var raw_resource_states = source.get("resource_states", {})
    result["resource_states"] = raw_resource_states.duplicate(true) if raw_resource_states is Dictionary else {}
    var raw_resident_memory = source.get("resident_memory", {})
    result["resident_memory"] = raw_resident_memory.duplicate(true) if raw_resident_memory is Dictionary else {}
    return result
