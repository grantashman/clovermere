extends Node2D

var world
var grid: Array = []
var village: Dictionary = {}
var camera: Camera2D
var world_seed := 0
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
    "wall": Color("#b27c55"),
    "roof": Color("#425747"),
    "roof_light": Color("#66785b"),
    "sky": Color("#92b9b1"),
    "hill": Color("#6c9369")
}

func configure(_world, _grid: Array, _village: Dictionary, _camera: Camera2D) -> void:
    world = _world
    grid = _grid
    village = _village
    camera = _camera
    world_seed = world.seed_from_text("%s:%s" % [village.get("name", "Moonrise Hollow"), village.get("landscape", "heath")])
    queue_redraw()

func _visible_bounds() -> Rect2:
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
    _draw_smooth_paths()
    _draw_structures(bounds)
    _draw_landmarks(bounds)

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
        draw_rect(Rect2(origin + Vector2(0, 11), Vector2(TILE, 5)), COLORS.grass_dark, true)
        _draw_grass_marks(origin, grain * 1.7)
        draw_rect(Rect2(origin + Vector2(5 + floori(grain * 4.0), 4), Vector2(3, 2)), COLORS.moss_light, true)
    elif tile == "r":
        draw_rect(rect, COLORS.rock_dark, true)
        draw_circle(origin + Vector2(8, 8), 6.0, COLORS.rock, true, -1.0, false)
        draw_rect(Rect2(origin + Vector2(5, 4), Vector2(5, 2)), COLORS.rock_light, true)
        draw_rect(Rect2(origin + Vector2(4, 11), Vector2(7, 2)), COLORS.rock_dark, true)
    elif tile == "t":
        draw_rect(rect, COLORS.grass_dark, true)
        draw_rect(Rect2(origin + Vector2(7, 8), Vector2(3, 8)), COLORS.wood, true)
        draw_circle(origin + Vector2(8, 6), 8.0, COLORS.tree_dark, true, -1.0, false)
        draw_circle(origin + Vector2(5, 4), 5.0, COLORS.tree, true, -1.0, false)
        draw_rect(Rect2(origin + Vector2(2, 5), Vector2(4, 2)), COLORS.tree_light, true)
        draw_rect(Rect2(origin + Vector2(10, 2), Vector2(3, 2)), COLORS.tree_light, true)
    elif tile == "w":
        draw_rect(rect, COLORS.water_dark, true)
        draw_rect(Rect2(origin + Vector2(0, 3), Vector2(TILE, 8)), COLORS.water, true)
        if int(floori(grain * 10.0)) % 2 == 0:
            draw_rect(Rect2(origin + Vector2(2, 5), Vector2(6, 1)), COLORS.water_light, true)
            draw_rect(Rect2(origin + Vector2(10, 9), Vector2(4, 1)), COLORS.water_light, true)
        else:
            draw_rect(Rect2(origin + Vector2(7, 2), Vector2(5, 1)), COLORS.water_light, true)
    elif tile == "p":
        draw_rect(rect, COLORS.path, true)
        draw_rect(Rect2(origin + Vector2(0, 0), Vector2(TILE, 2)), COLORS.path_edge, true)
        if int(floori(grain * 17.0)) % 3 == 0:
            draw_rect(Rect2(origin + Vector2(3, 6), Vector2(4, 1)), COLORS.path_light, true)
        if int(floori(grain * 31.0)) % 4 == 0:
            draw_rect(Rect2(origin + Vector2(10, 12), Vector2(3, 1)), COLORS.path_edge, true)
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

func _draw_grass_marks(origin: Vector2, grain: float) -> void:
    var variant := int(floori(grain * 100.0)) % 4
    draw_rect(Rect2(origin + Vector2(2 + variant, 3), Vector2(3, 1)), COLORS.grass_light, true)
    draw_rect(Rect2(origin + Vector2(11 - variant, 10), Vector2(2, 1)), COLORS.grass_dark, true)
    if variant == 1 or variant == 3:
        draw_line(origin + Vector2(7, 15), origin + Vector2(8, 11), COLORS.grass_light, 1.0, false)

func _route_points(route: Dictionary) -> PackedVector2Array:
    var points := PackedVector2Array()
    var start: Vector2 = route.start * TILE
    var finish: Vector2 = route.end * TILE
    var direction := (finish - start).normalized()
    var normal := Vector2(-direction.y, direction.x)
    var bend := float(route.bend) * TILE
    var samples := maxi(12, ceili(start.distance_to(finish) / TILE * 2.0))
    for step in samples + 1:
        var t := float(step) / float(samples)
        points.append(start.lerp(finish, t) + normal * bend * sin(t * PI))
    return points

func _draw_smooth_paths() -> void:
    for index in world.path_routes(village).size():
        var route: Dictionary = world.path_routes(village)[index]
        var points := _route_points(route)
        draw_polyline(points, COLORS.path_edge, 22.0, false)
        draw_polyline(points, COLORS.path, 16.0, false)
        draw_polyline(points, COLORS.path_light.darkened(0.08), 2.0, false)
        for step in range(2, points.size() - 1, 5):
            var mark := points[step]
            if (index + step) % 3 == 0:
                draw_rect(Rect2(mark + Vector2(-2, -1), Vector2(4, 2)), COLORS.path_light, true)
            elif (index + step) % 5 == 0:
                draw_rect(Rect2(mark + Vector2(1, 1), Vector2(2, 1)), COLORS.path_edge, true)

func _draw_structures(bounds: Rect2) -> void:
    var ox: int = world.SETTLEMENT_ORIGIN.x
    var oy: int = world.SETTLEMENT_ORIGIN.y
    var buildings := [
        {"x": ox + 4, "y": oy + 5, "w": 8, "h": 6, "roof": COLORS.roof},
        {"x": ox + 24, "y": oy + 4, "w": 8, "h": 6, "roof": COLORS.roof_light},
        {"x": ox + 39, "y": oy + 7, "w": 9, "h": 7, "roof": COLORS.roof},
        {"x": ox + 17, "y": oy + 24, "w": 10, "h": 7, "roof": COLORS.roof_light},
        {"x": ox + 45, "y": oy + 26, "w": 9, "h": 7, "roof": COLORS.roof}
    ]
    for building in buildings:
        var rect := Rect2(float(building.x) * TILE, float(building.y) * TILE, float(building.w) * TILE, float(building.h) * TILE)
        if not bounds.grow(64.0).intersects(rect):
            continue
        draw_rect(Rect2(rect.position + Vector2(0, 6), rect.size), Color("#273a32"), true)
        draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size - Vector2(6, 5)), COLORS.wall, true)
        var roof_points := PackedVector2Array([
            rect.position + Vector2(-5, 8),
            rect.position + Vector2(rect.size.x * 0.5, -5),
            rect.position + Vector2(rect.size.x + 5, 8),
            rect.position + Vector2(rect.size.x - 1, 13),
            rect.position + Vector2(1, 13)
        ])
        draw_colored_polygon(roof_points, building.roof)
        draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.5 - 4, rect.size.y - 17), Vector2(8, 17)), COLORS.wood, true)
        draw_rect(Rect2(rect.position + Vector2(9, rect.size.y - 21), Vector2(7, 5)), COLORS.water_light, true)
        draw_rect(Rect2(rect.position + Vector2(rect.size.x - 16, rect.size.y - 21), Vector2(7, 5)), COLORS.water_light, true)

func _draw_landmarks(bounds: Rect2) -> void:
    for landmark in world.LANDMARKS:
        var rect := Rect2(float(landmark.x) * TILE, float(landmark.y) * TILE, float(landmark.w) * TILE, float(landmark.h) * TILE)
        if not bounds.grow(64.0).intersects(rect):
            continue
        draw_rect(Rect2(rect.position + Vector2(0, 6), rect.size), Color(0.11, 0.19, 0.16, 0.35), true)
        draw_rect(Rect2(rect.position + Vector2(4, 4), rect.size - Vector2(8, 8)), COLORS.grass_dark, true)
        draw_circle(rect.position + rect.size * 0.5, minf(rect.size.x, rect.size.y) * 0.24, COLORS.tree_light, true, -1.0, false)
