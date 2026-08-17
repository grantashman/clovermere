extends Control
class_name ClovermereMinimap

const MAP_COLORS := {
    "g": Color("#4f7f4d"),
    "m": Color("#6b8758"),
    "t": Color("#284e3d"),
    "w": Color("#326b73"),
    "p": Color("#b18a58"),
    "d": Color("#9b754e"),
    "b": Color("#795445"),
    "s": Color("#36584b"),
    "h": Color("#1e3934"),
    "r": Color("#3d5d4b")
}

var world_size := Vector2i.ZERO
var player_tile := Vector2i.ZERO
var landmark_count := 0
var _grid: Array = []
var _buildings: Dictionary = {}
var _landmarks: Array = []

func _ready() -> void:
    custom_minimum_size = Vector2(232, 148)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(world, grid: Array, player_position: Vector2, buildings: Dictionary = {}) -> void:
    world_size = Vector2i(world.WORLD_WIDTH, world.WORLD_HEIGHT)
    player_tile = Vector2i(floori(player_position.x), floori(player_position.y))
    _grid = grid
    _buildings = buildings.duplicate(true)
    _landmarks = world.LANDMARKS.duplicate(true)
    landmark_count = _landmarks.size()
    queue_redraw()

func set_player_position(player_position: Vector2) -> void:
    player_tile = Vector2i(floori(player_position.x), floori(player_position.y))
    queue_redraw()

func _draw() -> void:
    var bounds := Rect2(Vector2.ZERO, size if size.x > 0.0 else Vector2(232, 148))
    draw_rect(bounds, Color("#0b1c16"), true)
    draw_rect(bounds, Color("#c5a86a"), false, 2.0)
    if world_size.x <= 0 or world_size.y <= 0 or _grid.is_empty():
        return
    var map_rect := Rect2(10, 10, bounds.size.x - 20, bounds.size.y - 20)
    var cell := Vector2(map_rect.size.x / float(world_size.x), map_rect.size.y / float(world_size.y))
    for y in range(world_size.y):
        if y >= _grid.size():
            break
        var row: Array = _grid[y]
        for x in range(world_size.x):
            if x >= row.size():
                break
            var tile := str(row[x])
            var color: Color = MAP_COLORS.get(tile, Color("#4f7f4d"))
            draw_rect(Rect2(map_rect.position + Vector2(x, y) * cell, cell + Vector2(0.45, 0.45)), color, true)
    for building_variant in _buildings.values():
        if not building_variant is Dictionary:
            continue
        var building: Dictionary = building_variant
        var rect := Rect2(map_rect.position + Vector2(float(building.get("x", 0)), float(building.get("y", 0))) * cell, Vector2(float(building.get("w", 1)), float(building.get("h", 1))) * cell)
        draw_rect(rect, Color("#c39b62"), true)
        draw_rect(rect, Color("#402f29"), false, 1.0)
    for landmark_variant in _landmarks:
        if not landmark_variant is Dictionary:
            continue
        var landmark: Dictionary = landmark_variant
        var landmark_pos := map_rect.position + Vector2(float(landmark.get("x", 0)) + float(landmark.get("w", 1)) * 0.5, float(landmark.get("y", 0)) + float(landmark.get("h", 1)) * 0.5) * cell
        draw_circle(landmark_pos, 2.0, Color("#d6bd72"))
    var player_pos := map_rect.position + (Vector2(player_tile) + Vector2(0.5, 0.5)) * cell
    draw_circle(player_pos, 3.2, Color("#f2df9d"))
    draw_circle(player_pos, 5.0, Color("#f2df9d", 0.35), false, 1.0)
