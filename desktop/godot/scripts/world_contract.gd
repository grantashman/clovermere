extends RefCounted
class_name HobbitMoonWorld

const WORLD_WIDTH := 240
const WORLD_HEIGHT := 160
const TILE_SIZE := 16.0
const SAVE_VERSION := 6
const SETTLEMENT_ORIGIN := Vector2i(108, 71)
const START_TILE := Vector2i(SETTLEMENT_ORIGIN.x + 14, SETTLEMENT_ORIGIN.y + 11)
const START_POSITION := Vector2(START_TILE.x + 0.5, START_TILE.y + 0.5)
const BLOCKED_TILES := {"t": true, "w": true, "r": true, "f": true, "b": true, "s": true, "h": true}

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
    var seed := seed_from_text("%s:%s" % [village.get("name", "Moonrise Hollow"), village.get("landscape", "heath")])
    var ox := SETTLEMENT_ORIGIN.x
    var oy := SETTLEMENT_ORIGIN.y
    var routes: Array = [
        {"start": Vector2(ox + 5, oy + 11), "end": Vector2(ox + 67, oy + 11), "width": 1.0, "bend": 2.5, "bridge": false},
        {"start": Vector2(ox + 30, oy + 5), "end": Vector2(ox + 30, oy + 50), "width": 1.0, "bend": -2.5, "bridge": false},
        {"start": Vector2(ox + 14, oy + 6), "end": Vector2(ox + 14, oy + 18), "width": 1.0, "bend": 1.5, "bridge": false},
        {"start": Vector2(ox + 5, oy + 16), "end": Vector2(ox + 24, oy + 16), "width": 1.0, "bend": -1.5, "bridge": false},
        {"start": Vector2(ox + 30, oy + 31), "end": Vector2(ox + 67, oy + 31), "width": 1.0, "bend": -3.0, "bridge": true},
        {"start": Vector2(ox + 12, oy + 44), "end": Vector2(ox + 61, oy + 44), "width": 1.0, "bend": -2.5, "bridge": false}
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
        var bend := float(round((hash2d(landmark.x, landmark.y, seed + 73) - 0.5) * 28.0))
        routes.append({"start": start, "end": target, "width": 1.0, "bend": bend, "bridge": true})
    return routes

func _inside(grid: Array, x: int, y: int) -> bool:
    return y >= 0 and y < grid.size() and x >= 0 and x < grid[y].size()

func _set_cell(grid: Array, x: int, y: int, tile: String) -> void:
    if x > 0 and y > 5 and x < WORLD_WIDTH - 1 and y < WORLD_HEIGHT - 1 and _inside(grid, x, y):
        grid[y][x] = tile

func _paint_corridor(grid: Array, start: Vector2, finish: Vector2, width: float, bend: float, bridge: bool) -> void:
    var distance := start.distance_to(finish)
    var samples := maxi(1, ceili(distance * 4.0))
    var direction := (finish - start).normalized()
    var normal := Vector2(-direction.y, direction.x)
    var radius := maxf(0.7, width * 0.78)
    var previous := Vector2i(-999, -999)
    for step in samples + 1:
        var t := float(step) / float(samples)
        var point := start.lerp(finish, t) + normal * bend * sin(t * PI)
        var centre := Vector2i(roundi(point.x), roundi(point.y))
        for offset_y in range(-ceili(radius), ceili(radius) + 1):
            for offset_x in range(-ceili(radius), ceili(radius) + 1):
                if Vector2(offset_x, offset_y).length() <= radius + 0.2:
                    var x := centre.x + offset_x
                    var y := centre.y + offset_y
                    if _inside(grid, x, y) and (bridge or grid[y][x] != "w"):
                        _set_cell(grid, x, y, "p")
        if previous.x > -900 and (centre.x != previous.x or centre.y != previous.y):
            if _inside(grid, centre.x, previous.y):
                _set_cell(grid, centre.x, previous.y, "p")
            if _inside(grid, previous.x, centre.y):
                _set_cell(grid, previous.x, centre.y, "p")
        previous = centre

func build_grid(village: Dictionary = {}) -> Array:
    var seed := seed_from_text("%s:%s" % [village.get("name", "Moonrise Hollow"), village.get("landscape", "heath")])
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
    var buildings := [
        {"x": ox + 4, "y": oy + 5, "w": 8, "h": 6},
        {"x": ox + 24, "y": oy + 4, "w": 8, "h": 6},
        {"x": ox + 39, "y": oy + 7, "w": 9, "h": 7},
        {"x": ox + 17, "y": oy + 24, "w": 10, "h": 7},
        {"x": ox + 45, "y": oy + 26, "w": 9, "h": 7}
    ]
    for building in buildings:
        for y in range(building.y, building.y + building.h):
            for x in range(building.x, building.x + building.w):
                _set_cell(grid, x, y, "b")
    return grid

func tile_at(grid: Array, tile: Vector2i) -> String:
    if not _inside(grid, tile.x, tile.y):
        return "t"
    return str(grid[tile.y][tile.x])

func is_walkable(grid: Array, tile: Vector2i) -> bool:
    return not BLOCKED_TILES.has(tile_at(grid, tile))

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
    if version < SAVE_VERSION:
        player += Vector2(SETTLEMENT_ORIGIN) + Vector2(0.5, 0.5)
    var result := source.duplicate(true)
    result["version"] = SAVE_VERSION
    result["player"] = player
    result["location"] = "village" if source.get("location", "village") not in ["home", "inn"] else source.get("location")
    return result
