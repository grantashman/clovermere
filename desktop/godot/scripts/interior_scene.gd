extends Node2D
class_name ClovermereInteriorScene

const TILE_SIZE := 16.0

var building_id := ""
var interior_size := Vector2i.ZERO
var definition: Dictionary = {}
var minute_of_day := 8 * 60
var player_position := Vector2.ZERO

func configure(source: Dictionary) -> void:
    definition = source.duplicate(true)
    building_id = str(definition.get("location", ""))
    interior_size = Vector2i(int(definition.get("width", 0)), int(definition.get("height", 0)))
    queue_redraw()

func set_time(value: int) -> void:
    minute_of_day = clampi(value, 0, 23 * 60 + 59)
    queue_redraw()

func set_player_position(value: Vector2) -> void:
    player_position = value
    queue_redraw()

func interaction_world_position(interaction_id: String) -> Vector2:
    for interaction in definition.get("interactions", []):
        if interaction is Dictionary and str(interaction.get("id", "")) == interaction_id:
            return Vector2(float(interaction.get("x", 0)) + 0.5, float(interaction.get("y", 0)) + 0.5) * TILE_SIZE
    return Vector2(-1, -1)

func exit_world_position() -> Vector2:
    var exit_tile: Vector2i = definition.get("exit", Vector2i.ZERO)
    return Vector2(float(exit_tile.x) + 0.5, float(exit_tile.y) + 0.5) * TILE_SIZE

func furniture_ids() -> Array[String]:
    var result: Array[String] = []
    for interaction in definition.get("interactions", []):
        if interaction is Dictionary:
            result.append(str(interaction.get("id", "")))
    return result

func render_palette() -> Dictionary:
    return {
        "wall": Color(str(definition.get("wall_color", "#5b4939"))),
        "floor": Color(str(definition.get("floor_color", "#97704d"))),
        "rug": Color(str(definition.get("rug_color", "#5b5543"))),
        "accent": Color("#d9b866"),
        "ink": Color("#26352c"),
        "light": Color("#f2ca75")
    }

func _draw() -> void:
    if interior_size == Vector2i.ZERO:
        return
    var palette := render_palette()
    var room := Rect2(Vector2.ZERO, Vector2(interior_size) * TILE_SIZE)
    draw_rect(Rect2(-1000.0, -1000.0, 2000.0, 2000.0), Color("#17261f"), true)
    draw_rect(room.grow(20.0), Color("#17261f"), true)
    draw_rect(room, palette.floor, true)
    _draw_floorboards(room, palette)
    _draw_walls(room, palette)
    _draw_rug(palette)
    if building_id == "greenbriar-cottage":
        _draw_cottage(palette)
    elif building_id == "tinker-workshop":
        _draw_workshop(palette)
    _draw_exit(palette)
    _draw_time_lighting(palette)

func _draw_floorboards(room: Rect2, palette: Dictionary) -> void:
    var floor_shadow := Color(palette.floor, 0.28)
    for y in range(2, interior_size.y - 1, 2):
        draw_line(Vector2(1, y) * TILE_SIZE, Vector2(interior_size.x - 1, y) * TILE_SIZE, floor_shadow, 1.0)
    for x in range(2, interior_size.x - 1, 4):
        draw_line(Vector2(x, 1) * TILE_SIZE, Vector2(x, interior_size.y - 1) * TILE_SIZE, Color(palette.floor, 0.18), 1.0)
    draw_rect(Rect2(1, 1, room.size.x - 32, room.size.y - 32), Color("#e0b875", 0.05), true)

func _draw_walls(room: Rect2, palette: Dictionary) -> void:
    var wall: Color = palette.wall
    draw_rect(Rect2(0, 0, room.size.x, 2 * TILE_SIZE), wall, true)
    draw_rect(Rect2(0, 0, 2 * TILE_SIZE, room.size.y), wall, true)
    draw_rect(Rect2(room.size.x - 2 * TILE_SIZE, 0, 2 * TILE_SIZE, room.size.y), wall, true)
    draw_rect(Rect2(0, room.size.y - TILE_SIZE, room.size.x, TILE_SIZE), wall.darkened(0.16), true)
    for x in range(2, interior_size.x - 2, 3):
        draw_line(Vector2(x, 0) * TILE_SIZE, Vector2(x, 1.9) * TILE_SIZE, Color("#c09264", 0.48), 1.0)
    _draw_window(Vector2(8, 1) * TILE_SIZE, palette)
    if building_id == "tinker-workshop":
        _draw_window(Vector2(14, 1) * TILE_SIZE, palette)

func _draw_window(position: Vector2, palette: Dictionary) -> void:
    var glow: Color = palette.light if _is_evening() else Color("#a8c6a1")
    draw_rect(Rect2(position, Vector2(2, 1) * TILE_SIZE), Color("#263d35"), true)
    draw_rect(Rect2(position + Vector2(3, 3), Vector2(26, 10)), Color(glow, 0.85), true)
    draw_line(position + Vector2(16, 3), position + Vector2(16, 13), Color("#725541"), 2.0)
    draw_line(position + Vector2(3, 8), position + Vector2(29, 8), Color("#725541"), 2.0)

func _draw_rug(palette: Dictionary) -> void:
    var rug := Rect2(Vector2(5, 7) * TILE_SIZE, Vector2(8, 2) * TILE_SIZE)
    if building_id == "tinker-workshop":
        rug = Rect2(Vector2(4, 8) * TILE_SIZE, Vector2(12, 2) * TILE_SIZE)
    draw_rect(rug.grow(3), Color(palette.ink, 0.45), true)
    draw_rect(rug, palette.rug, true)
    draw_rect(Rect2(rug.position + Vector2(5, 5), rug.size - Vector2(10, 10)), palette.accent.darkened(0.25), false, 2.0)

func _draw_cottage(palette: Dictionary) -> void:
    _draw_hearth(interaction_world_position("hearth"), palette)
    _draw_bed(interaction_world_position("bed"), palette)
    _draw_chest(interaction_world_position("storage-chest"), palette)
    _draw_table(Vector2(8.5, 6.0) * TILE_SIZE, palette)
    _draw_shelf(Vector2(2.5, 2.5) * TILE_SIZE, 3, palette)
    _draw_potted_plant(Vector2(15.5, 8.0) * TILE_SIZE, palette)

func _draw_workshop(palette: Dictionary) -> void:
    _draw_workbench(interaction_world_position("workbench"), palette)
    _draw_forge(interaction_world_position("forge"), palette)
    _draw_tool_rack(interaction_world_position("tool-rack"), palette)
    _draw_shelf(Vector2(3.5, 2.5) * TILE_SIZE, 4, palette)
    _draw_crate(Vector2(15.5, 8.5) * TILE_SIZE, palette)
    _draw_crate(Vector2(17.0, 8.5) * TILE_SIZE, palette)

func _draw_hearth(position: Vector2, palette: Dictionary) -> void:
    draw_rect(Rect2(position - Vector2(22, 17), Vector2(44, 28)), Color(palette.ink, 0.65), true)
    draw_rect(Rect2(position - Vector2(19, 15), Vector2(38, 24)), Color("#6b4935"), true)
    draw_rect(Rect2(position - Vector2(12, 10), Vector2(24, 17)), Color("#2b2923"), true)
    draw_circle(position + Vector2(0, 1), 8.0, Color("#d46d3f"), true)
    draw_circle(position + Vector2(-2, -2), 5.0, Color("#f0c55f"), true)

func _draw_bed(position: Vector2, palette: Dictionary) -> void:
    draw_rect(Rect2(position - Vector2(27, 18), Vector2(54, 34)), Color(palette.ink, 0.55), true)
    draw_rect(Rect2(position - Vector2(24, 16), Vector2(48, 30)), Color("#624c45"), true)
    draw_rect(Rect2(position - Vector2(20, 12), Vector2(40, 22)), Color("#9cae7b"), true)
    draw_rect(Rect2(position - Vector2(20, 12), Vector2(12, 22)), Color("#d5c58e"), true)

func _draw_chest(position: Vector2, _palette: Dictionary) -> void:
    draw_rect(Rect2(position - Vector2(20, 14), Vector2(40, 27)), Color("#2a382e"), true)
    draw_rect(Rect2(position - Vector2(17, 11), Vector2(34, 21)), Color("#8b5d3e"), true)
    draw_line(position + Vector2(-17, 0), position + Vector2(17, 0), Color("#d0a663"), 2.0)
    draw_rect(Rect2(position - Vector2(2, -2), Vector2(4, 7)), Color("#e0bd67"), true)

func _draw_table(position: Vector2, palette: Dictionary) -> void:
    draw_rect(Rect2(position - Vector2(31, 10), Vector2(62, 19)), Color(palette.ink, 0.48), true)
    draw_rect(Rect2(position - Vector2(28, 8), Vector2(56, 14)), Color("#77513d"), true)
    for x in [-22, 22]:
        draw_rect(Rect2(position + Vector2(x - 3, 7), Vector2(6, 17)), Color("#4d3b32"), true)
    draw_circle(position + Vector2(-9, -2), 4.0, palette.accent, true)
    draw_circle(position + Vector2(8, 1), 3.0, Color("#9cae7b"), true)

func _draw_shelf(position: Vector2, shelves: int, palette: Dictionary) -> void:
    var height := float(shelves * 10 + 12)
    draw_rect(Rect2(position - Vector2(5, 0), Vector2(10, height)), Color("#3a332b"), true)
    for index in shelves:
        var y := position.y + float(index * 10)
        draw_rect(Rect2(position.x - 20, y, 40, 4), Color("#80563e"), true)
        draw_rect(Rect2(position.x - 14, y - 6, 5, 7), palette.accent.darkened(0.2), true)
        draw_rect(Rect2(position.x + 2, y - 8, 7, 9), Color("#728a61"), true)

func _draw_potted_plant(position: Vector2, palette: Dictionary) -> void:
    draw_rect(Rect2(position - Vector2(7, -2), Vector2(14, 12)), Color("#a66545"), true)
    draw_line(position, position + Vector2(-7, -14), palette.accent, 3.0)
    draw_line(position, position + Vector2(6, -16), Color("#87a969"), 3.0)

func _draw_workbench(position: Vector2, palette: Dictionary) -> void:
    draw_rect(Rect2(position - Vector2(35, 14), Vector2(70, 28)), Color(palette.ink, 0.62), true)
    draw_rect(Rect2(position - Vector2(32, 12), Vector2(64, 22)), Color("#704a36"), true)
    draw_rect(Rect2(position - Vector2(28, -4), Vector2(56, 6)), palette.accent.darkened(0.28), true)
    for x in [-25, 25]:
        draw_rect(Rect2(position + Vector2(x - 3, 5), Vector2(6, 16)), Color("#43362e"), true)
    draw_line(position + Vector2(-10, -7), position + Vector2(2, -19), Color("#d7bd78"), 3.0)
    draw_line(position + Vector2(6, -7), position + Vector2(18, -18), Color("#ac8257"), 3.0)

func _draw_forge(position: Vector2, palette: Dictionary) -> void:
    draw_rect(Rect2(position - Vector2(24, 19), Vector2(48, 37)), Color(palette.ink, 0.7), true)
    draw_rect(Rect2(position - Vector2(20, 16), Vector2(40, 30)), Color("#4b443b"), true)
    draw_rect(Rect2(position - Vector2(12, 8), Vector2(24, 16)), Color("#272822"), true)
    draw_circle(position + Vector2(0, 2), 8.0, Color("#c45f36"), true)
    draw_circle(position + Vector2(1, -1), 5.0, Color("#f1c259"), true)
    draw_line(position + Vector2(0, -20), position + Vector2(0, -32), Color("#39342d"), 5.0)
    if _is_evening():
        _draw_glow(position + Vector2(0, 3), 34.0, Color("#ec9e50"), 0.09)

func _draw_tool_rack(position: Vector2, palette: Dictionary) -> void:
    draw_rect(Rect2(position - Vector2(32, 15), Vector2(64, 10)), Color("#674937"), true)
    for index in 4:
        var x := position.x - 22 + float(index * 15)
        draw_line(Vector2(x, position.y - 5), Vector2(x + 4, position.y - 28), palette.accent, 3.0)
        draw_line(Vector2(x + 4, position.y - 28), Vector2(x + 12, position.y - 28), Color("#c77c52"), 3.0)

func _draw_crate(position: Vector2, _palette: Dictionary) -> void:
    draw_rect(Rect2(position - Vector2(12, 12), Vector2(24, 24)), Color("#3b352d"), true)
    draw_rect(Rect2(position - Vector2(9, 9), Vector2(18, 18)), Color("#936342"), true)
    draw_line(position + Vector2(-7, -7), position + Vector2(7, 7), Color("#c3945a"), 2.0)
    draw_line(position + Vector2(7, -7), position + Vector2(-7, 7), Color("#c3945a"), 2.0)

func _draw_exit(palette: Dictionary) -> void:
    var position := exit_world_position()
    draw_rect(Rect2(position - Vector2(12, 8), Vector2(24, 16)), Color("#2d342b"), true)
    draw_rect(Rect2(position - Vector2(8, 6), Vector2(16, 14)), palette.accent.darkened(0.35), true)
    draw_circle(position + Vector2(4, 1), 2.0, palette.accent, true)

func _draw_time_lighting(palette: Dictionary) -> void:
    if not _is_evening():
        return
    draw_rect(Rect2(Vector2.ZERO, Vector2(interior_size) * TILE_SIZE), Color("#16294a", 0.16), true)
    for interaction in definition.get("interactions", []):
        if interaction is Dictionary and str(interaction.get("id", "")) in ["hearth", "forge"]:
            _draw_glow(interaction_world_position(str(interaction.id)), 48.0, palette.light, 0.1)

func _draw_glow(position: Vector2, radius: float, color: Color, strength: float) -> void:
    for ring in range(5, 0, -1):
        var ratio := float(ring) / 5.0
        draw_circle(position, radius * ratio, Color(color.r, color.g, color.b, strength * (1.0 - ratio) + 0.01), true)

func _is_evening() -> bool:
    return minute_of_day >= 17 * 60 or minute_of_day < 6 * 60
