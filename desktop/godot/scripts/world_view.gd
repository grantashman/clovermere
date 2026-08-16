extends Node2D

var world
var grid: Array = []
var village: Dictionary = {}
var camera: Camera2D
var world_seed := 0
var routes: Array = []
var world_changes: Dictionary = {}
const TILE := 16.0

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
    _draw_pixel_paths(bounds)
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
    _draw_material_edges(x, y, tile, origin)

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

func _draw_pixel_paths(bounds: Rect2) -> void:
    var min_x := maxi(0, floori(bounds.position.x / TILE) - 1)
    var min_y := maxi(0, floori(bounds.position.y / TILE) - 1)
    var max_x := mini(world.WORLD_WIDTH - 1, ceili(bounds.end.x / TILE) + 1)
    var max_y := mini(world.WORLD_HEIGHT - 1, ceili(bounds.end.y / TILE) + 1)
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            if not _is_path_tile(x, y):
                continue
            var origin := Vector2(float(x) * TILE, float(y) * TILE)
            var tile := str(grid[y][x])
            var base := COLORS.soil if tile == "d" else COLORS.path
            var horizontal := _is_path_tile(x - 1, y) or _is_path_tile(x + 1, y)
            var vertical := _is_path_tile(x, y - 1) or _is_path_tile(x, y + 1)
            var dark_rect := Rect2(origin + Vector2(4, 4), Vector2(8, 8))
            var road_rect := Rect2(origin + Vector2(5, 5), Vector2(6, 6))
            if horizontal and not vertical:
                dark_rect = Rect2(origin + Vector2(0, 4), Vector2(TILE, 8))
                road_rect = Rect2(origin + Vector2(0, 5), Vector2(TILE, 6))
            elif vertical and not horizontal:
                dark_rect = Rect2(origin + Vector2(4, 0), Vector2(8, TILE))
                road_rect = Rect2(origin + Vector2(5, 0), Vector2(6, TILE))
            draw_rect(dark_rect, COLORS.path_edge, true)
            draw_rect(road_rect, base, true)
            if tile == "d":
                draw_rect(Rect2(road_rect.position + Vector2(2, 2), Vector2(maxf(2.0, road_rect.size.x - 4.0), 1)), COLORS.path_light.darkened(0.28), true)
            else:
                var grain: float = world.hash2d(x, y, world_seed + 901)
                if horizontal and int(floori(grain * 10.0)) % 3 == 0:
                    draw_rect(Rect2(origin + Vector2(4, 7), Vector2(3, 1)), COLORS.path_light, true)
                elif vertical and int(floori(grain * 10.0)) % 3 == 0:
                    draw_rect(Rect2(origin + Vector2(7, 4), Vector2(1, 3)), COLORS.path_light, true)


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

func _draw_resources(bounds: Rect2) -> void:
    for resource in world.resources():
        var centre := Vector2((float(resource.x) + 0.5) * TILE, (float(resource.y) + 0.5) * TILE)
        if not bounds.grow(48.0).has_point(centre):
            continue
        var cleared := bool(world_changes.get(str(resource.id), false))
        _draw_resource(centre, str(resource.get("kind", "")), cleared)

func _draw_resource(centre: Vector2, kind: String, cleared: bool) -> void:
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
        else:
            draw_rect(Rect2(centre + Vector2(-7, 1), Vector2(14, 3)), COLORS.grass_dark, true)
            draw_rect(Rect2(centre + Vector2(-4, -4), Vector2(2, 5)), COLORS.grass_light, true)
        return
    if kind == "tree":
        draw_rect(Rect2(centre + Vector2(-3, -5), Vector2(6, 15)), COLORS.wood, true)
        draw_circle(centre + Vector2(-5, -6), 9.0, COLORS.tree_dark, true, -1.0, false)
        draw_circle(centre + Vector2(5, -8), 10.0, COLORS.tree, true, -1.0, false)
        draw_circle(centre + Vector2(0, -15), 7.0, COLORS.tree_light, true, -1.0, false)
        draw_rect(Rect2(centre + Vector2(-7, -10), Vector2(4, 2)), COLORS.moss_light, true)
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
    elif kind == "herb":
        for offset in [-5.0, 0.0, 5.0]:
            draw_line(centre + Vector2(offset, 5), centre + Vector2(offset - 1, -5), COLORS.grass_light, 1.0, false)
            draw_rect(Rect2(centre + Vector2(offset - 3, -7), Vector2(4, 3)), COLORS.flower, true)
