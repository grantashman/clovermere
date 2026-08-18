extends Node2D

var world
var grid: Array = []
var village: Dictionary = {}
var camera: Camera2D
var world_seed := 0
var routes: Array = []
var world_changes: Dictionary = {}
const TILE := 16.0

const TERRAIN_FAMILIES := ["meadow", "woodland", "wetland", "rocky", "village-verge"]
const BIOME_STAMP_IDS := ["northwest-meadow", "northeast-woodland", "southwest-wetland", "southeast-rock-shelf", "west-orchard-approach", "east-willow-approach"]

const COLORS := {
    "grass": Color("#5c954f"),
    "grass_light": Color("#88b75a"),
    "grass_dark": Color("#3d7047"),
    "moss": Color("#78975a"),
    "moss_light": Color("#a7bd6a"),
    "rock": Color("#777a6e"),
    "rock_light": Color("#a4a18a"),
    "rock_dark": Color("#4d5a55"),
    "water": Color("#4f9491"),
    "water_light": Color("#86c1ac"),
    "water_dark": Color("#326b73"),
    "path": Color("#b98958"),
    "path_light": Color("#d7b576"),
    "path_edge": Color("#765947"),
    "soil": Color("#875d4d"),
    "tree": Color("#2e6043"),
    "tree_light": Color("#578456"),
    "tree_dark": Color("#21453a"),
    "wood": Color("#744f3d"),
    "wood_light": Color("#a56d4b"),
    "wood_dark": Color("#513c35"),
    "wall": Color("#b27c55"),
    "wall_light": Color("#d3a072"),
    "wall_shadow": Color("#875b4b"),
    "roof": Color("#425747"),
    "roof_light": Color("#66785b"),
    "roof_dark": Color("#2d423b"),
    "roof_warm": Color("#765346"),
    "glass": Color("#9ed0c2"),
    "window_warm": Color("#e3c77d"),
    "stone_light": Color("#b1a88b"),
    "stone_dark": Color("#5d665e"),
    "flower": Color("#d6b06e"),
    "sky": Color("#92b9b1"),
    "hill": Color("#6c9369")
}

func configure(_world, _grid: Array, _village: Dictionary, _camera: Camera2D, _changes: Dictionary = {}) -> void:
    world = _world
    grid = _grid
    village = _village
    camera = _camera
    world_changes = _changes.duplicate(true)
    world_seed = world.seed_from_text("%s:%s" % [village.get("name", "Clovermere"), village.get("landscape", "heath")])
    routes = world.path_routes(village)
    queue_redraw()

func terrain_family_ids() -> Array[String]:
    return TERRAIN_FAMILIES.duplicate()

func terrain_family_for(tile: Vector2i) -> String:
    if world == null:
        return "meadow"
    var kind: String = str(world.tile_at(grid, tile))
    if kind == "w" or world.tile_at(grid, tile + Vector2i.RIGHT) == "w" or world.tile_at(grid, tile + Vector2i.DOWN) == "w":
        return "wetland"
    if kind == "r":
        return "rocky"
    var origin: Vector2i = world.SETTLEMENT_ORIGIN
    var dx: int = abs(tile.x - origin.x)
    var dy: int = abs(tile.y - origin.y)
    if dx <= 38 and dy <= 28:
        return "village-verge"
    if kind in ["t", "m"] or world.smooth_noise(tile.x + 19, tile.y - 13, 19, world_seed + 701) > 0.69:
        return "woodland"
    return "meadow"

func landmark_dressing_ids() -> Array[String]:
    return ["apple-orchard", "willowmere", "stonecutters-hollow", "west-lookout"]

func biome_stamp_ids() -> Array[String]:
    return BIOME_STAMP_IDS.duplicate()

func resource_variant_for(kind: String, variant: int) -> String:
    var suffix := posmod(variant, 3)
    if kind == "tree":
        return ["broadleaf", "silverbark", "pinewatch"][suffix]
    if kind == "stone":
        return ["boulder", "slab", "shale"][suffix]
    if kind == "ore":
        return ["ironroot", "blueglass", "coppermoss"][suffix]
    if kind == "herb":
        return ["stems", "flowering", "fern"][suffix]
    if kind == "fish":
        return ["reedpool", "silverflash", "deepbend"][posmod(variant, 2)]
    return "meadow"
func _visible_bounds() -> Rect2:
    if camera == null and world != null:
        return Rect2(0, 0, float(world.WORLD_WIDTH) * TILE, float(world.WORLD_HEIGHT) * TILE)
    if camera == null:
        return Rect2(0, 0, 1280, 720)
    var zoom_value := maxf(camera.zoom.x, 0.01)
    var size := get_viewport_rect().size / zoom_value
    return Rect2(camera.position - size * 0.5 - Vector2(64, 64), size + Vector2(128, 128))

func _draw() -> void:
    draw_rect(Rect2(-4096, -4096, 8192, 8192), Color("#304f45"), true)
    if world == null or grid.is_empty():
        return
    var bounds := _visible_bounds()
    var min_x := maxi(0, floori(bounds.position.x / TILE) - 1)
    var min_y := maxi(0, floori(bounds.position.y / TILE) - 1)
    var max_x := mini(world.WORLD_WIDTH - 1, ceili(bounds.end.x / TILE) + 1)
    var max_y := mini(world.WORLD_HEIGHT - 1, ceili(bounds.end.y / TILE) + 1)
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            _draw_tile(x, y, str(grid[y][x]))
    _draw_biome_stamps(bounds)
    _draw_pixel_paths(bounds)
    _draw_trailheads(bounds)
    _draw_structures(bounds)
    _draw_landmarks(bounds)
    _draw_resources(bounds)

func _draw_tile(x: int, y: int, tile: String) -> void:
    var origin := Vector2(float(x) * TILE, float(y) * TILE)
    var rect := Rect2(origin, Vector2(TILE, TILE))
    var grain: float = world.hash2d(x, y, world_seed + 181)
    if tile == "s":
        draw_rect(rect, COLORS.sky, true)
        draw_rect(Rect2(origin + Vector2(0, 12), Vector2(TILE, 4)), COLORS.sky.lightened(0.08), true)
        return
    if tile == "h":
        draw_rect(rect, COLORS.hill, true)
        draw_line(origin + Vector2(0, 12), origin + Vector2(16, 6), COLORS.grass_light, 2.0, false)
        return
    if tile == "g":
        draw_rect(rect, COLORS.grass, true)
        _draw_grass_marks(origin, grain)
    elif tile == "m":
        draw_rect(rect, COLORS.moss, true)
        _draw_grass_marks(origin, grain * 1.7)
        draw_rect(Rect2(origin + Vector2(1 + floori(grain * 4.0), 12), Vector2(6, 2)), COLORS.grass_dark, true)
        draw_rect(Rect2(origin + Vector2(4 + floori(grain * 5.0), 4 + floori(grain * 3.0)), Vector2(3, 2)), COLORS.moss_light, true)
    elif tile == "r":
        draw_rect(rect, COLORS.rock_dark, true)
        var rock_shift := Vector2(floori(grain * 4.0) - 2.0, floori(grain * 7.0) - 3.0)
        var rock_size := 4.5 + floori(grain * 3.0)
        draw_circle(origin + Vector2(8, 8) + rock_shift, rock_size, COLORS.rock, true, -1.0, false)
        draw_rect(Rect2(origin + Vector2(4, 4) + rock_shift * 0.45, Vector2(4 + floori(grain * 3.0), 2)), COLORS.rock_light, true)
        draw_rect(Rect2(origin + Vector2(4, 11) + rock_shift * 0.25, Vector2(7, 2)), COLORS.rock_dark, true)
    elif tile == "t":
        draw_rect(rect, COLORS.grass_dark, true)
        _draw_canopy(origin, grain)
    elif tile == "w":
        draw_rect(rect, COLORS.water, true)
        draw_rect(Rect2(origin + Vector2(1 + floori(grain * 4.0), 13), Vector2(5, 1)), COLORS.water_dark, true)
        if int(floori(grain * 10.0)) % 2 == 0:
            draw_rect(Rect2(origin + Vector2(2, 5), Vector2(6, 1)), COLORS.water_light, true)
            draw_rect(Rect2(origin + Vector2(10, 9), Vector2(4, 1)), COLORS.water_light, true)
        else:
            draw_rect(Rect2(origin + Vector2(7, 2), Vector2(5, 1)), COLORS.water_light, true)
    elif tile == "p":
        draw_rect(rect, COLORS.grass, true)
        _draw_grass_marks(origin, grain * 0.7)
    elif tile == "d":
        draw_rect(rect, COLORS.soil, true)
        for row in [3, 8, 13]:
            draw_rect(Rect2(origin + Vector2(1, row), Vector2(14, 1)), COLORS.path_light.darkened(0.15), true)
            draw_rect(Rect2(origin + Vector2(4, row - 2), Vector2(2, 2)), COLORS.grass_light, true)
            draw_rect(Rect2(origin + Vector2(10, row - 1), Vector2(2, 2)), COLORS.grass_light, true)
    elif tile == "b":
        draw_rect(rect, COLORS.wood.darkened(0.1), true)
        draw_rect(Rect2(origin + Vector2(1, 2), Vector2(14, 12)), COLORS.wall.darkened(0.2), true)
    else:
        draw_rect(rect, COLORS.grass, true)
    _draw_family_dressing(x, y, tile, origin, grain)
    _draw_material_edges(x, y, tile, origin)

func _draw_family_dressing(x: int, y: int, tile: String, origin: Vector2, grain: float) -> void:
    var family := terrain_family_for(Vector2i(x, y))
    var detail := int(floori(grain * 100.0)) % 5
    if family == "meadow" and tile in ["g", "p"]:
        if detail == 0:
            draw_line(origin + Vector2(3, 15), origin + Vector2(5, 10), COLORS.grass_light, 1.0, false)
            draw_line(origin + Vector2(5, 15), origin + Vector2(7, 11), COLORS.grass_light, 1.0, false)
        elif detail == 1:
            draw_rect(Rect2(origin + Vector2(11, 7), Vector2(2, 2)), COLORS.flower, true)
    elif family == "woodland" and tile in ["g", "m", "t"]:
        draw_rect(Rect2(origin + Vector2(1 + detail, 13), Vector2(5, 2)), COLORS.tree_dark, true)
        if detail % 2 == 0:
            draw_rect(Rect2(origin + Vector2(10, 4 + detail), Vector2(3, 2)), COLORS.tree_light, true)
    elif family == "wetland":
        if tile != "w" and detail in [0, 2, 4]:
            draw_line(origin + Vector2(3, 15), origin + Vector2(4, 7), COLORS.grass_light, 1.0, false)
            draw_line(origin + Vector2(6, 15), origin + Vector2(7, 9), COLORS.moss_light, 1.0, false)
        elif tile == "w" and detail % 2 == 0:
            draw_rect(Rect2(origin + Vector2(3, 3 + detail), Vector2(6, 1)), COLORS.water_light, true)
    elif family == "rocky":
        draw_rect(Rect2(origin + Vector2(2, 12), Vector2(5, 2)), COLORS.rock_dark, true)
        if detail % 2 == 0:
            draw_rect(Rect2(origin + Vector2(10, 5), Vector2(3, 2)), COLORS.rock_light, true)
    elif family == "village-verge" and tile in ["g", "m", "p"]:
        draw_rect(Rect2(origin + Vector2(1, 14), Vector2(14, 1)), COLORS.grass_dark, true)
        if detail == 0:
            draw_rect(Rect2(origin + Vector2(12, 4), Vector2(2, 4)), COLORS.wood_dark, true)
            draw_rect(Rect2(origin + Vector2(10, 4), Vector2(6, 2)), COLORS.path_light, true)
func _draw_material_edges(x: int, y: int, tile: String, origin: Vector2) -> void:
    if tile in ["s", "h", "b", "p", "d"]:
        return
    var right: String = world.tile_at(grid, Vector2i(x + 1, y))
    var below: String = world.tile_at(grid, Vector2i(x, y + 1))
    if tile == "w":
        if right != "w":
            draw_rect(Rect2(origin + Vector2(14, 0), Vector2(2, TILE)), COLORS.water_dark, true)
        if below != "w":
            draw_rect(Rect2(origin + Vector2(0, 14), Vector2(TILE, 2)), COLORS.water_dark, true)
    elif tile == "g" and right in ["m", "r", "w"]:
        draw_rect(Rect2(origin + Vector2(14, 2), Vector2(2, 12)), COLORS.grass_dark, true)
    elif tile == "g" and below in ["m", "r", "w"]:
        draw_rect(Rect2(origin + Vector2(2, 14), Vector2(12, 2)), COLORS.grass_dark, true)
    elif tile == "m" and right == "g":
        draw_rect(Rect2(origin + Vector2(14, 1), Vector2(2, 14)), COLORS.moss_light.darkened(0.28), true)
    elif tile == "r" and below == "g":
        draw_rect(Rect2(origin + Vector2(2, 14), Vector2(12, 2)), COLORS.rock_dark, true)

func _draw_grass_marks(origin: Vector2, grain: float) -> void:
    var variant := int(floori(grain * 100.0)) % 4
    if variant == 0:
        draw_rect(Rect2(origin + Vector2(2, 4), Vector2(3, 1)), COLORS.grass_light, true)
        draw_line(origin + Vector2(5, 15), origin + Vector2(6, 11), COLORS.grass_light, 1.0, false)
    elif variant == 1:
        draw_rect(Rect2(origin + Vector2(10, 10), Vector2(3, 1)), COLORS.grass_dark, true)
    elif variant == 2:
        draw_line(origin + Vector2(8, 15), origin + Vector2(9, 11), COLORS.grass_light, 1.0, false)

func _draw_canopy(origin: Vector2, grain: float) -> void:
    var variant := int(floori(grain * 100.0)) % 4
    var centre := origin + Vector2(8, 7)
    draw_rect(Rect2(origin + Vector2(1, 13), Vector2(14, 3)), Color("#20372f"), true)
    draw_rect(Rect2(origin + Vector2(6, 9), Vector2(4, 7)), COLORS.wood, true)
    draw_circle(centre + Vector2(-3 + variant, 1), 6.5, COLORS.tree_dark, true, -1.0, false)
    draw_circle(centre + Vector2(3, -2 + variant % 2), 5.5, COLORS.tree, true, -1.0, false)
    draw_circle(centre + Vector2(-1, -4), 4.0, COLORS.tree_light, true, -1.0, false)
    if variant == 0 or variant == 3:
        draw_rect(Rect2(origin + Vector2(2, 6), Vector2(3, 2)), COLORS.tree_light, true)
    else:
        draw_rect(Rect2(origin + Vector2(10, 4), Vector2(3, 2)), COLORS.tree_light, true)

func _is_path_tile(x: int, y: int) -> bool:
    if y < 0 or y >= grid.size() or x < 0 or x >= grid[y].size():
        return false
    var tile := str(grid[y][x])
    return tile == "p" or tile == "d"

func _draw_biome_stamps(bounds: Rect2) -> void:
    var stamps := [
        {"id": "northwest-meadow", "center": Vector2(42, 38) * TILE, "size": Vector2(90, 52) * TILE, "kind": "meadow"},
        {"id": "northeast-woodland", "center": Vector2(198, 34) * TILE, "size": Vector2(74, 48) * TILE, "kind": "woodland"},
        {"id": "southwest-wetland", "center": Vector2(48, 128) * TILE, "size": Vector2(86, 44) * TILE, "kind": "wetland"},
        {"id": "southeast-rock-shelf", "center": Vector2(201, 125) * TILE, "size": Vector2(64, 54) * TILE, "kind": "rocky"},
        {"id": "west-orchard-approach", "center": Vector2(72, 104) * TILE, "size": Vector2(70, 42) * TILE, "kind": "orchard"},
        {"id": "east-willow-approach", "center": Vector2(180, 82) * TILE, "size": Vector2(72, 48) * TILE, "kind": "willow"}
    ]
    for stamp_variant in stamps:
        var stamp: Dictionary = stamp_variant
        var rect := Rect2(stamp.center - stamp.size * 0.5, stamp.size)
        if not bounds.grow(96.0).intersects(rect):
            continue
        match str(stamp.kind):
            "meadow": _draw_meadow_stamp(rect)
            "woodland": _draw_woodland_stamp(rect)
            "wetland": _draw_wetland_stamp(rect)
            "rocky": _draw_rocky_stamp(rect)
            "orchard": _draw_orchard_stamp(rect)
            "willow": _draw_willow_stamp(rect)

func _draw_meadow_stamp(rect: Rect2) -> void:
    draw_rect(rect.grow(-8.0), Color(COLORS.grass_light, 0.08), true)
    for index in range(8):
        var point := rect.position + Vector2(18 + (index * 37) % int(rect.size.x - 36), 16 + (index * 29) % int(rect.size.y - 30))
        draw_line(point, point + Vector2(4, -12), COLORS.grass_light, 2.0, false)
        draw_rect(Rect2(point + Vector2(3, -15), Vector2(5, 3)), COLORS.flower, true)
    draw_rect(Rect2(rect.position + Vector2(12, rect.size.y - 18), Vector2(rect.size.x - 24, 4)), Color(COLORS.path_edge, 0.28), true)

func _draw_woodland_stamp(rect: Rect2) -> void:
    draw_rect(rect.grow(-4.0), Color(COLORS.tree_dark, 0.22), true)
    for index in range(9):
        var point := rect.position + Vector2(18 + (index * 31) % int(rect.size.x - 32), rect.size.y - 26 - (index * 19) % int(rect.size.y - 34))
        _draw_distant_tree(point, 0.85 + float(index % 3) * 0.12, index % 3)
    draw_rect(Rect2(rect.position + Vector2(12, rect.size.y - 12), Vector2(rect.size.x - 24, 4)), COLORS.grass_dark, true)

func _draw_wetland_stamp(rect: Rect2) -> void:
    for index in range(11):
        var point := rect.position + Vector2(12 + (index * 27) % int(rect.size.x - 24), 18 + (index * 17) % int(rect.size.y - 30))
        draw_line(point, point + Vector2(3, -14), COLORS.grass_light, 1.5, false)
        draw_line(point + Vector2(6, 0), point + Vector2(8, -10), COLORS.moss_light, 1.0, false)
        if index % 3 == 0:
            draw_rect(Rect2(point + Vector2(10, -5), Vector2(7, 3)), COLORS.water_light, true)
            draw_rect(Rect2(point + Vector2(12, -4), Vector2(3, 1)), COLORS.grass_light, true)

func _draw_rocky_stamp(rect: Rect2) -> void:
    var shelf_color := Color(COLORS.rock_dark, 0.42)
    var shelf_light := Color(COLORS.rock, 0.56)
    var shelf_one := Rect2(rect.position + Vector2(0, rect.size.y * 0.58), Vector2(rect.size.x * 0.45, rect.size.y * 0.26))
    var shelf_two := Rect2(rect.position + Vector2(rect.size.x * 0.32, rect.size.y * 0.36), Vector2(rect.size.x * 0.34, rect.size.y * 0.22))
    var shelf_three := Rect2(rect.position + Vector2(rect.size.x * 0.68, rect.size.y * 0.18), Vector2(rect.size.x * 0.30, rect.size.y * 0.28))
    for shelf in [shelf_one, shelf_two, shelf_three]:
        draw_rect(shelf, shelf_color, true)
        draw_rect(Rect2(shelf.position + Vector2(0, 4), Vector2(shelf.size.x, 4)), shelf_light, true)
        draw_line(shelf.position + Vector2(8, shelf.size.y - 5), shelf.end - Vector2(12, 5), COLORS.rock_dark, 2.0, false)
    for index in range(10):
        var point := rect.position + Vector2(16 + (index * 29) % int(rect.size.x - 24), 12 + (index * 23) % int(rect.size.y - 24))
        draw_colored_polygon(PackedVector2Array([
            point + Vector2(-8, 6), point + Vector2(-4, -5), point + Vector2(4, -8), point + Vector2(9, 2), point + Vector2(5, 8)
        ]), COLORS.rock)
        draw_rect(Rect2(point + Vector2(-3, -5), Vector2(6, 2)), COLORS.rock_light, true)

func _draw_orchard_stamp(rect: Rect2) -> void:
    draw_rect(Rect2(rect.position + Vector2(12, rect.size.y * 0.48), Vector2(rect.size.x - 24, 5)), Color(COLORS.grass_dark, 0.6), true)
    for index in range(5):
        var point := rect.position + Vector2(20 + index * 31, rect.size.y * 0.42 + (index % 2) * 20)
        _draw_distant_tree(point, 0.72, index % 2)
        draw_circle(point + Vector2(8, -11), 3.0, COLORS.flower, true, -1.0, false)
    draw_rect(Rect2(rect.position + Vector2(10, rect.size.y * 0.58), Vector2(rect.size.x - 20, 4)), COLORS.wood_dark, true)

func _draw_willow_stamp(rect: Rect2) -> void:
    _draw_ellipse(rect.position + rect.size * Vector2(0.5, 0.55), Vector2(rect.size.x * 0.38, rect.size.y * 0.28), COLORS.water)
    for index in range(6):
        var point := rect.position + Vector2(16 + index * 28, rect.size.y * 0.45 + (index % 3) * 14)
        draw_line(point, point + Vector2(-4, -28), COLORS.wood, 3.0, false)
        draw_line(point + Vector2(-3, -18), point + Vector2(-18, -34), COLORS.grass_light, 2.0, false)
        draw_line(point + Vector2(0, -20), point + Vector2(15, -38), COLORS.moss_light, 2.0, false)
    draw_rect(Rect2(rect.position + Vector2(10, rect.size.y * 0.75), Vector2(rect.size.x - 20, 4)), COLORS.path_edge, true)

func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
    var points := PackedVector2Array()
    for index in range(24):
        var angle := TAU * float(index) / 24.0
        points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
    draw_colored_polygon(points, color)

func _draw_distant_tree(point: Vector2, scale_value: float, variant: int) -> void:
    var trunk_height := 34.0 * scale_value
    draw_rect(Rect2(point + Vector2(-3, -trunk_height * 0.25), Vector2(6, trunk_height)), COLORS.wood, true)
    var canopy := COLORS.tree if variant == 0 else COLORS.tree_light if variant == 1 else COLORS.moss_light
    draw_circle(point + Vector2(-13, -trunk_height * 0.75), 18.0 * scale_value, COLORS.tree_dark, true, -1.0, false)
    draw_circle(point + Vector2(11, -trunk_height * 0.82), 20.0 * scale_value, canopy, true, -1.0, false)
    draw_circle(point + Vector2(0, -trunk_height), 14.0 * scale_value, COLORS.tree_light, true, -1.0, false)
    draw_rect(Rect2(point + Vector2(-11, -trunk_height * 0.9), Vector2(7, 3)), COLORS.grass_light, true)
func _draw_pixel_paths(bounds: Rect2) -> void:
    if routes.is_empty():
        return
    for route_variant in routes:
        var route: Dictionary = route_variant
        var waypoints: Array = route.get("waypoints", [])
        if waypoints.size() < 2:
            continue
        var points := _smooth_route_points(waypoints)
        var route_bounds := Rect2(points[0], Vector2.ZERO)
        for point in points:
            route_bounds = route_bounds.expand(point)
        if not bounds.grow(64.0).intersects(route_bounds):
            continue
        var kind := str(route.get("kind", "field-trail"))
        var edge_width := 13.0 if kind == "village-road" else 7.0
        var dirt_width := 7.0 if kind == "village-road" else 4.0
        var edge_color := Color(COLORS.path_edge, 0.62 if kind == "village-road" else 0.48)
        var dirt_color := Color(COLORS.path, 0.84 if kind == "village-road" else 0.68)
        draw_polyline(points, edge_color, edge_width, true)
        draw_polyline(points, dirt_color, dirt_width, true)
        for point_index in range(points.size()):
            draw_circle(points[point_index], dirt_width * 0.5, dirt_color, true, -1.0, false)
        if kind == "village-road":
            for point_index in range(points.size() - 1):
                var segment_start: Vector2 = points[point_index]
                var segment_end: Vector2 = points[point_index + 1]
                var segment_length := segment_start.distance_to(segment_end)
                var stone_count := maxi(1, floori(segment_length / 42.0))
                for stone_index in range(stone_count):
                    var ratio := float(stone_index + 1) / float(stone_count + 1)
                    var stone_point := segment_start.lerp(segment_end, ratio)
                    var grain: float = world.hash2d(point_index * 13 + stone_index, int(stone_point.y), world_seed + 1701)
                    draw_rect(Rect2(stone_point + Vector2(-1.0, -1.0), Vector2(2, 1)), COLORS.path_light.darkened(0.22 + grain * 0.25), true)

func _smooth_route_points(waypoints: Array) -> PackedVector2Array:
    var points := PackedVector2Array()
    for segment in range(waypoints.size() - 1):
        var start := Vector2(waypoints[segment])
        var finish := Vector2(waypoints[segment + 1])
        var distance := maxi(1, ceili(start.distance_to(finish)))
        for sample in range(distance):
            var ratio := float(sample) / float(distance)
            points.append(start.lerp(finish, ratio) * TILE + Vector2(8, 8))
    points.append(Vector2(waypoints[-1]) * TILE + Vector2(8, 8))
    return points

func _draw_trailheads(bounds: Rect2) -> void:
    for route_variant in routes:
        var route: Dictionary = route_variant
        if str(route.get("kind", "")) != "field-trail":
            continue
        var points: Array = route.get("waypoints", [])
        if points.is_empty():
            continue
        var start := Vector2(points[0]) * TILE + Vector2(8, 8)
        if not bounds.grow(24.0).has_point(start):
            continue
        draw_rect(Rect2(start + Vector2(-2, -8), Vector2(4, 10)), COLORS.wood_dark, true)
        draw_rect(Rect2(start + Vector2(-6, -10), Vector2(12, 4)), COLORS.path_edge, true)
        draw_rect(Rect2(start + Vector2(-4, -9), Vector2(8, 2)), COLORS.path_light, true)

func _draw_structures(bounds: Rect2) -> void:
    for building in world.buildings():
        var rect := Rect2(float(building.x) * TILE, float(building.y) * TILE, float(building.w) * TILE, float(building.h) * TILE)
        if not bounds.grow(64.0).intersects(rect):
            continue
        _draw_building(rect, building)

func _draw_building(rect: Rect2, building: Dictionary) -> void:
    var wall_color := Color(str(building.get("wall", "#b27c55")))
    var roof_color := Color(str(building.get("roof", "#425747")))
    var kind := str(building.get("kind", "cottage"))
    var body := Rect2(rect.position + Vector2(6, 17), rect.size - Vector2(12, 23))
    var roof_base_y := rect.position.y + 19.0
    var eave_left := rect.position.x + 2.0
    var eave_right := rect.end.x - 2.0
    var roof_peak := rect.position + Vector2(rect.size.x * 0.5, 1)

    draw_rect(Rect2(rect.position + Vector2(2, 13), rect.size + Vector2(0, 6)), Color("#263a32"), true)
    draw_rect(Rect2(rect.position + Vector2(4, 15), rect.size - Vector2(8, 14)), COLORS.stone_dark, true)
    draw_rect(body, wall_color.darkened(0.18), true)
    draw_rect(Rect2(body.position + Vector2(3, 3), body.size - Vector2(6, 6)), wall_color, true)

    var roof_points := PackedVector2Array([
        Vector2(eave_left - 4, roof_base_y),
        roof_peak,
        Vector2(eave_right + 4, roof_base_y),
        Vector2(eave_right - 2, roof_base_y + 8),
        Vector2(eave_left + 2, roof_base_y + 8)
    ])
    draw_colored_polygon(roof_points, roof_color.darkened(0.12))
    draw_colored_polygon(PackedVector2Array([
        Vector2(eave_left, roof_base_y - 2), roof_peak + Vector2(0, 3), Vector2(eave_right, roof_base_y - 2),
        Vector2(eave_right - 2, roof_base_y + 3), Vector2(eave_left + 2, roof_base_y + 3)
    ]), roof_color)
    draw_line(Vector2(eave_left - 2, roof_base_y + 5), Vector2(eave_right + 2, roof_base_y + 5), COLORS.wood_dark, 2.0, false)
    for stripe in range(1, 6):
        var x := rect.position.x + float(stripe) * rect.size.x / 6.0
        var top := roof_peak.lerp(Vector2(x, roof_base_y), abs(x - roof_peak.x) / maxf(1.0, rect.size.x * 0.5))
        draw_line(top + Vector2(0, 4), Vector2(x, roof_base_y + 4), roof_color.lightened(0.16), 1.0, false)

    var door_x := body.position.x + body.size.x * 0.5 - 5.0
    draw_rect(Rect2(door_x - 2, body.end.y - 1, 14, 5), COLORS.wood_dark, true)
    draw_rect(Rect2(door_x, body.end.y - 19, 10, 19), COLORS.wood, true)
    draw_rect(Rect2(door_x + 2, body.end.y - 16, 6, 16), COLORS.wood_light, true)
    draw_circle(Vector2(door_x + 7, body.end.y - 9), 1.2, COLORS.window_warm, true, -1.0, false)
    draw_rect(Rect2(door_x - 3, body.end.y - 21, 16, 3), COLORS.wood_dark, true)

    _draw_window(body.position + Vector2(9, 11), kind == "hall")
    _draw_window(Vector2(body.end.x - 23, body.position.y + 11), kind == "workshop")
    draw_rect(Rect2(body.position.x + 3, body.position.y + 2, 3, body.size.y - 4), COLORS.wood_dark, true)
    draw_rect(Rect2(body.end.x - 6, body.position.y + 2, 3, body.size.y - 4), COLORS.wood_dark, true)
    draw_rect(Rect2(body.position.x + 3, body.position.y + body.size.y * 0.42, body.size.x - 6, 2), COLORS.wood_dark, true)

    draw_rect(Rect2(rect.end.x - 22, rect.position.y + 9, 9, 15), COLORS.wood_dark, true)
    draw_rect(Rect2(rect.end.x - 20, rect.position.y + 7, 6, 13), COLORS.stone_light, true)
    draw_rect(Rect2(rect.end.x - 23, rect.position.y + 6, 12, 3), COLORS.stone_dark, true)

    if kind == "cottage":
        draw_rect(Rect2(rect.position + Vector2(4, rect.size.y - 13), Vector2(22, 8)), COLORS.wood_dark, true)
        draw_rect(Rect2(rect.position + Vector2(6, rect.size.y - 12), Vector2(18, 5)), COLORS.wood_light, true)
        draw_rect(Rect2(rect.position + Vector2(4, rect.size.y - 4), Vector2(7, 3)), COLORS.flower, true)
        draw_rect(Rect2(rect.position + Vector2(rect.size.x - 13, rect.size.y - 4), Vector2(7, 3)), COLORS.flower, true)
    elif kind == "hall":
        draw_colored_polygon(PackedVector2Array([
            Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y - 5),
            Vector2(rect.position.x + rect.size.x * 0.5 + 18, rect.position.y + 15),
            Vector2(rect.position.x + rect.size.x * 0.5 - 18, rect.position.y + 15)
        ]), roof_color.darkened(0.22))
        draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.5 - 2, 5), Vector2(4, 11)), COLORS.roof_light, true)
        draw_rect(Rect2(rect.position + Vector2(6, rect.size.y - 11), Vector2(4, 8)), COLORS.wood_dark, true)
        draw_rect(Rect2(rect.end - Vector2(10, 11), Vector2(4, 8)), COLORS.wood_dark, true)
        draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.5 - 2, rect.size.y - 18), Vector2(4, 5)), COLORS.window_warm, true)
    elif kind == "garden":
        draw_rect(Rect2(rect.position + Vector2(2, rect.size.y - 13), Vector2(27, 9)), COLORS.soil, true)
        for row in [0.0, 4.0, 8.0]:
            draw_rect(Rect2(rect.position + Vector2(4, rect.size.y - 12 + row), Vector2(22, 1)), COLORS.path_light.darkened(0.24), true)
        for flower_x in [6.0, 14.0, 22.0]:
            draw_line(rect.position + Vector2(flower_x, rect.size.y - 5), rect.position + Vector2(flower_x, rect.size.y - 15), COLORS.grass_dark, 1.0, false)
            draw_rect(Rect2(rect.position + Vector2(flower_x - 2, rect.size.y - 17), Vector2(4, 3)), COLORS.flower, true)
        draw_rect(Rect2(rect.end - Vector2(15, 20), Vector2(11, 3)), COLORS.wood_dark, true)
        draw_rect(Rect2(rect.end - Vector2(14, 28), Vector2(2, 11)), COLORS.wood_dark, true)
        draw_rect(Rect2(rect.end - Vector2(5, 28), Vector2(2, 11)), COLORS.wood_dark, true)
        draw_line(rect.end - Vector2(14, 25), rect.end - Vector2(5, 18), COLORS.grass_light, 1.0, false)
    elif kind == "workshop":
        draw_rect(Rect2(rect.position + Vector2(4, rect.size.y - 14), Vector2(26, 9)), COLORS.wood_dark, true)
        draw_rect(Rect2(rect.position + Vector2(6, rect.size.y - 12), Vector2(22, 4)), COLORS.wood_light, true)
        draw_rect(Rect2(rect.position + Vector2(8, rect.size.y - 8), Vector2(6, 3)), COLORS.stone_light, true)
        draw_rect(Rect2(rect.end - Vector2(14, 13), Vector2(8, 8)), COLORS.wood_dark, true)
        draw_rect(Rect2(rect.end - Vector2(12, 11), Vector2(4, 4)), COLORS.rock_light, true)
        draw_line(rect.position + Vector2(rect.size.x - 7, 12), rect.position + Vector2(rect.size.x + 3, 3), COLORS.wood_light, 2.0, false)
    elif kind == "barn":
        draw_rect(Rect2(rect.position + Vector2(5, 24), Vector2(rect.size.x - 10, rect.size.y - 27)), COLORS.wall_shadow, true)
        draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.5 - 12, 28), Vector2(24, rect.size.y - 31)), COLORS.wood_dark, true)
        draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.5 - 10, 30), Vector2(9, rect.size.y - 35)), COLORS.wood_light, true)
        draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.5 + 1, 30), Vector2(9, rect.size.y - 35)), COLORS.wall, true)
        draw_line(rect.position + Vector2(rect.size.x * 0.5, 30), rect.position + Vector2(rect.size.x * 0.5, rect.size.y - 4), COLORS.wood_dark, 2.0, false)
        draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.5 - 5, 16), Vector2(10, 7)), COLORS.window_warm, true)
        draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.5 - 1, 16), Vector2(2, 7)), COLORS.wood_dark, true)

func _draw_window(position: Vector2, warm: bool) -> void:
    draw_rect(Rect2(position - Vector2(2, 2), Vector2(14, 14)), COLORS.wood_dark, true)
    draw_rect(Rect2(position, Vector2(10, 10)), COLORS.window_warm if warm else COLORS.glass, true)
    draw_line(position + Vector2(5, 0), position + Vector2(5, 10), COLORS.wood, 1.0, false)
    draw_line(position + Vector2(0, 5), position + Vector2(10, 5), COLORS.wood, 1.0, false)
    draw_rect(Rect2(position + Vector2(1, 1), Vector2(3, 2)), Color("#f5e5aa") if warm else Color("#c2eee0"), true)

func _draw_landmarks(bounds: Rect2) -> void:
    for landmark in world.LANDMARKS:
        var rect := Rect2(float(landmark.x) * TILE, float(landmark.y) * TILE, float(landmark.w) * TILE, float(landmark.h) * TILE)
        if not bounds.grow(64.0).intersects(rect):
            continue
        var centre := rect.position + rect.size * 0.5
        var id: String = landmark.id
        if id == "apple-orchard":
            draw_rect(Rect2(rect.position + Vector2(8, rect.size.y - 22), Vector2(rect.size.x - 16, 8)), COLORS.grass_dark, true)
            for offset in [Vector2(-38, -12), Vector2(-12, -20), Vector2(16, -8), Vector2(42, -18)]:
                draw_rect(Rect2(centre + offset + Vector2(-2, 8), Vector2(4, 14)), COLORS.wood, true)
                draw_circle(centre + offset, 12.0, COLORS.tree_dark, true, -1.0, false)
                draw_circle(centre + offset + Vector2(-4, -4), 8.0, COLORS.tree, true, -1.0, false)
                draw_circle(centre + offset + Vector2(3, -7), 4.0, COLORS.tree_light, true, -1.0, false)
        elif id == "willowmere":
            draw_circle(centre, minf(rect.size.x, rect.size.y) * 0.33, COLORS.water_dark, true, -1.0, false)
            draw_circle(centre + Vector2(0, -2), minf(rect.size.x, rect.size.y) * 0.27, COLORS.water, true, -1.0, false)
            draw_line(centre + Vector2(-18, -3), centre + Vector2(17, -3), COLORS.water_light, 2.0, false)
            draw_line(centre + Vector2(-10, 7), centre + Vector2(12, 7), COLORS.water_light, 1.0, false)
            for offset in [Vector2(-42, -14), Vector2(38, 8)]:
                draw_rect(Rect2(centre + offset + Vector2(-2, 3), Vector2(4, 18)), COLORS.wood, true)
                draw_circle(centre + offset, 11.0, COLORS.tree_dark, true, -1.0, false)
                draw_circle(centre + offset + Vector2(3, -4), 7.0, COLORS.tree_light, true, -1.0, false)
        elif id == "stonecutters-hollow":
            draw_colored_polygon(PackedVector2Array([
                centre + Vector2(-50, 27), centre + Vector2(-26, -16), centre + Vector2(0, 6),
                centre + Vector2(24, -26), centre + Vector2(52, 27)
            ]), COLORS.rock_dark)
            for offset in [Vector2(-36, 15), Vector2(-8, 1), Vector2(18, 12), Vector2(39, 18)]:
                draw_circle(centre + offset, 8.0, COLORS.rock, true, -1.0, false)
                draw_rect(Rect2(centre + offset + Vector2(-4, -5), Vector2(7, 2)), COLORS.rock_light, true)
        else:
            draw_colored_polygon(PackedVector2Array([
                centre + Vector2(-52, 26), centre + Vector2(-34, -4), centre + Vector2(-8, -25),
                centre + Vector2(22, -7), centre + Vector2(51, 26)
            ]), COLORS.hill)
            draw_line(centre + Vector2(1, 9), centre + Vector2(1, -34), COLORS.wood, 3.0, false)
            draw_colored_polygon(PackedVector2Array([
                centre + Vector2(2, -33), centre + Vector2(25, -25), centre + Vector2(2, -16)
            ]), COLORS.path_light)
    _draw_landmark_dressing(bounds)

func _draw_landmark_dressing(bounds: Rect2) -> void:
    for landmark in world.LANDMARKS:
        var rect := Rect2(float(landmark.x) * TILE, float(landmark.y) * TILE, float(landmark.w) * TILE, float(landmark.h) * TILE)
        if not bounds.grow(64.0).intersects(rect):
            continue
        var centre := rect.position + rect.size * 0.5
        var id := str(landmark.get("id", ""))
        if id == "apple-orchard":
            for x in range(int(rect.position.x) + 14, int(rect.end.x) - 10, 22):
                draw_line(Vector2(x, rect.end.y - 16), Vector2(x, rect.end.y - 48), COLORS.wood_dark, 3.0, false)
                draw_rect(Rect2(x - 8, rect.end.y - 50, 16, 4), COLORS.wood_light, true)
                draw_rect(Rect2(x - 5, rect.end.y - 47, 10, 2), COLORS.path_edge, true)
            draw_rect(Rect2(rect.position + Vector2(8, rect.size.y - 10), Vector2(rect.size.x - 16, 3)), COLORS.wood_dark, true)
        elif id == "willowmere":
            for x in range(int(rect.position.x) + 12, int(rect.end.x) - 12, 18):
                draw_line(Vector2(x, rect.end.y - 10), Vector2(x - 2, rect.end.y - 34), COLORS.grass_dark, 2.0, false)
                draw_line(Vector2(x, rect.end.y - 28), Vector2(x - 8, rect.end.y - 42), COLORS.grass_light, 1.0, false)
                draw_line(Vector2(x, rect.end.y - 25), Vector2(x + 8, rect.end.y - 38), COLORS.moss_light, 1.0, false)
            draw_rect(Rect2(centre + Vector2(-32, 22), Vector2(64, 3)), COLORS.wood_dark, true)
        elif id == "stonecutters-hollow":
            for offset in [Vector2(-42, 18), Vector2(-18, 8), Vector2(10, 15), Vector2(34, 6)]:
                draw_rect(Rect2(centre + offset - Vector2(5, 6), Vector2(10, 12)), COLORS.rock_dark, true)
                draw_rect(Rect2(centre + offset - Vector2(3, 8), Vector2(6, 3)), COLORS.rock_light, true)
            draw_rect(Rect2(centre + Vector2(-14, 14), Vector2(28, 3)), COLORS.wood_dark, true)
        elif id == "west-lookout":
            draw_rect(Rect2(centre + Vector2(-3, -20), Vector2(6, 44)), COLORS.wood_dark, true)
            draw_rect(Rect2(centre + Vector2(-18, -23), Vector2(34, 4)), COLORS.wood_light, true)
            draw_rect(Rect2(centre + Vector2(-1, -50), Vector2(3, 27)), COLORS.wood, true)
            draw_colored_polygon(PackedVector2Array([
                centre + Vector2(2, -49), centre + Vector2(25, -42), centre + Vector2(2, -36)
            ]), COLORS.path_light)
func _draw_resources(bounds: Rect2) -> void:
    for resource in world.resources(village):
        var centre := Vector2((float(resource.x) + 0.5) * TILE, (float(resource.y) + 0.5) * TILE)
        if not bounds.grow(48.0).has_point(centre):
            continue
        var cleared := bool(world_changes.get(str(resource.id), false))
        _draw_resource(centre, str(resource.get("kind", "")), cleared, int(resource.get("variant", 0)))

func _draw_resource(centre: Vector2, kind: String, cleared: bool, variant: int = 0) -> void:
    draw_rect(Rect2(centre + Vector2(-9, 7), Vector2(18, 4)), Color("#26372e"), true)
    if cleared:
        if kind == "tree":
            draw_rect(Rect2(centre + Vector2(-4, -3), Vector2(8, 9)), COLORS.wood_dark, true)
            draw_rect(Rect2(centre + Vector2(-3, -5), Vector2(6, 3)), COLORS.wood_light, true)
            draw_rect(Rect2(centre + Vector2(6, 2), Vector2(5, 3)), COLORS.grass_light, true)
        elif kind in ["stone", "ore"]:
            draw_rect(Rect2(centre + Vector2(-6, -2), Vector2(12, 7)), COLORS.rock_dark, true)
            draw_rect(Rect2(centre + Vector2(-4, -4), Vector2(8, 4)), COLORS.rock, true)
            draw_rect(Rect2(centre + Vector2(-2, -3), Vector2(3, 1)), COLORS.rock_light, true)
        elif kind == "fish":
            draw_rect(Rect2(centre + Vector2(-7, -2), Vector2(14, 5)), COLORS.water_dark, true)
            draw_colored_polygon(PackedVector2Array([centre + Vector2(7, 0), centre + Vector2(12, -5), centre + Vector2(12, 5)]), COLORS.water_light)
            draw_rect(Rect2(centre + Vector2(-3, -1), Vector2(2, 2)), COLORS.window_warm, true)
        else:
            draw_rect(Rect2(centre + Vector2(-7, 1), Vector2(14, 3)), COLORS.grass_dark, true)
            draw_rect(Rect2(centre + Vector2(-4, -4), Vector2(2, 5)), COLORS.grass_light, true)
        return
    if kind == "tree":
        var canopy: Color = [COLORS.tree, COLORS.tree_light, COLORS.moss_light][posmod(variant, 3)]
        draw_rect(Rect2(centre + Vector2(-3, -5), Vector2(6, 15)), COLORS.wood, true)
        draw_circle(centre + Vector2(-5, -6), 10.0, COLORS.tree_dark, true, -1.0, false)
        draw_circle(centre + Vector2(5, -8), 11.0, canopy, true, -1.0, false)
        draw_circle(centre + Vector2(0, -16), 8.0, COLORS.tree_light, true, -1.0, false)
        draw_rect(Rect2(centre + Vector2(-8, -10), Vector2(4, 2)), COLORS.moss_light, true)
        draw_rect(Rect2(centre + Vector2(5, -14), Vector2(3, 2)), COLORS.grass_light, true)
    elif kind == "stone":
        draw_colored_polygon(PackedVector2Array([
            centre + Vector2(-9, 5), centre + Vector2(-6, -5), centre + Vector2(1, -9), centre + Vector2(9, -3), centre + Vector2(7, 6)
        ]), COLORS.rock_dark)
        draw_colored_polygon(PackedVector2Array([
            centre + Vector2(-5, 1), centre + Vector2(-3, -4), centre + Vector2(2, -6), centre + Vector2(5, -2), centre + Vector2(3, 2)
        ]), COLORS.rock)
        draw_rect(Rect2(centre + Vector2(-2, -5), Vector2(4, 2)), COLORS.rock_light, true)
    elif kind == "ore":
        draw_colored_polygon(PackedVector2Array([
            centre + Vector2(-9, 6), centre + Vector2(-6, -4), centre + Vector2(0, -8), centre + Vector2(8, -2), centre + Vector2(6, 7)
        ]), COLORS.rock_dark)
        draw_rect(Rect2(centre + Vector2(-3, -4), Vector2(3, 3)), Color("#9bb6a0"), true)
        draw_rect(Rect2(centre + Vector2(2, 0), Vector2(3, 3)), Color("#6f9c8b"), true)
        draw_rect(Rect2(centre + Vector2(-1, 4), Vector2(2, 2)), Color("#bdd5ad"), true)
    elif kind == "fish":
        var fish_color := COLORS.water_light if posmod(variant, 2) == 0 else COLORS.moss_light
        draw_arc(centre + Vector2(0, 2), 13.0, 0.15, 2.95, 12, Color(fish_color, 0.5), 1.0, false)
        draw_arc(centre + Vector2(0, 2), 8.0, 0.25, 2.9, 10, Color(fish_color, 0.72), 1.0, false)
        draw_rect(Rect2(centre + Vector2(-8, -3), Vector2(16, 6)), COLORS.water_dark, true)
        draw_colored_polygon(PackedVector2Array([centre + Vector2(8, 0), centre + Vector2(14, -6), centre + Vector2(14, 6)]), fish_color)
        draw_rect(Rect2(centre + Vector2(-4, -2), Vector2(3, 3)), COLORS.window_warm, true)
    elif kind == "herb":
        for offset in [-5.0, 0.0, 5.0]:
            draw_line(centre + Vector2(offset, 5), centre + Vector2(offset - 1, -5), COLORS.grass_light, 1.0, false)
            draw_rect(Rect2(centre + Vector2(offset - 3, -7), Vector2(4, 3)), COLORS.flower, true)
