extends Control
class_name ClovermereUiIllustration

const DEEP := Color("#10251d")
const SKY := Color("#477568")
const FIELD := Color("#6b9c5a")
const FIELD_DARK := Color("#3d7047")
const PATH := Color("#b98958")
const PATH_LIGHT := Color("#d7b576")
const PATH_EDGE := Color("#765947")
const ROOF := Color("#3c4f45")
const WALL := Color("#c58a5d")
const TIMBER := Color("#704936")
const BRASS := Color("#e0bb6c")

var mode := "welcome"

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    queue_redraw()

func configure(next_mode: String) -> void:
    mode = next_mode
    queue_redraw()

func _draw() -> void:
    var width := maxf(size.x, 420.0)
    var height := maxf(size.y, 72.0)
    var frame := Rect2(Vector2(8, 6), Vector2(width - 16, height - 12))
    draw_rect(frame, DEEP, true)
    draw_rect(Rect2(frame.position + Vector2(2, 2), frame.size - Vector2(4, 4)), Color("#1b3b2d"), true)
    if mode == "loading":
        _draw_loading(frame)
    else:
        _draw_welcome(frame)
    draw_line(frame.position + Vector2(0, frame.size.y - 1), frame.end - Vector2(0, 1), Color(BRASS, 0.68), 1.0, false)

func _draw_welcome(frame: Rect2) -> void:
    var horizon := frame.position.y + frame.size.y * 0.48
    draw_rect(Rect2(frame.position, Vector2(frame.size.x, frame.size.y * 0.52)), SKY, true)
    draw_rect(Rect2(Vector2(frame.position.x, horizon), Vector2(frame.size.x, frame.end.y - horizon)), FIELD, true)
    draw_colored_polygon(PackedVector2Array([
        Vector2(frame.position.x, horizon + 10),
        Vector2(frame.position.x + frame.size.x * 0.18, horizon - 18),
        Vector2(frame.position.x + frame.size.x * 0.38, horizon + 5),
        Vector2(frame.position.x + frame.size.x * 0.62, horizon - 24),
        Vector2(frame.end.x, horizon + 2),
        Vector2(frame.end.x, frame.end.y),
        Vector2(frame.position.x, frame.end.y)
    ]), Color("#5d8b68"))
    draw_circle(frame.position + Vector2(frame.size.x * 0.84, 24), 11.0, Color(BRASS, 0.9), true, -1.0, false)
    draw_line(frame.position + Vector2(frame.size.x * 0.08, frame.end.y - 22), frame.end - Vector2(frame.size.x * 0.08, 28), PATH_EDGE, 10.0, true)
    draw_line(frame.position + Vector2(frame.size.x * 0.08, frame.end.y - 22), frame.end - Vector2(frame.size.x * 0.08, 28), PATH, 6.0, true)
    _draw_cottage(frame.position + Vector2(frame.size.x * 0.55, horizon - 5), 0.92)
    _draw_clover(frame.position + Vector2(34, horizon - 5))
    for index in range(7):
        var x := frame.position.x + 74.0 + index * 38.0
        var y := frame.end.y - 13.0 - float(index % 2) * 4.0
        draw_line(Vector2(x, y), Vector2(x + 2, y - 10), FIELD_DARK, 1.0, false)
        draw_rect(Rect2(Vector2(x + 1, y - 12), Vector2(4, 2)), Color(BRASS, 0.72), true)

func _draw_loading(frame: Rect2) -> void:
    draw_rect(frame, Color("#142b22"), true)
    var stripe_width := frame.size.x * 0.58
    draw_rect(Rect2(frame.position + Vector2(18, 16), Vector2(stripe_width, 3)), Color(BRASS, 0.65), true)
    draw_rect(Rect2(frame.position + Vector2(18, 28), Vector2(frame.size.x - 36, 2)), Color(FIELD_DARK, 0.8), true)
    draw_colored_polygon(PackedVector2Array([
        frame.position + Vector2(20, frame.size.y - 20),
        frame.position + Vector2(frame.size.x * 0.34, frame.size.y - 46),
        frame.position + Vector2(frame.size.x * 0.64, frame.size.y - 28),
        frame.position + Vector2(frame.size.x - 20, frame.size.y - 52),
        frame.end - Vector2(20, 12),
        frame.position + Vector2(20, frame.size.y - 12)
    ]), Color("#315d47"))
    _draw_clover(frame.position + Vector2(frame.size.x - 42, 38))
    var road_start := frame.position + Vector2(22, frame.size.y - 22)
    var road_end := frame.position + Vector2(frame.size.x - 22, frame.size.y - 30)
    draw_line(road_start, road_end, PATH_EDGE, 8.0, true)
    draw_line(road_start, road_end, PATH, 4.0, true)
    for index in range(5):
        var marker := road_start.lerp(road_end, float(index + 1) / 6.0)
        draw_rect(Rect2(marker + Vector2(-2, -1), Vector2(4, 2)), PATH_LIGHT, true)

func _draw_cottage(origin: Vector2, scale_value: float) -> void:
    var body := Rect2(origin + Vector2(-30, -2) * scale_value, Vector2(60, 27) * scale_value)
    draw_rect(Rect2(body.position + Vector2(0, 6), body.size + Vector2(0, 5)), Color(TIMBER, 0.55), true)
    draw_rect(body, WALL, true)
    draw_colored_polygon(PackedVector2Array([
        origin + Vector2(-38, 0) * scale_value,
        origin + Vector2(0, -23) * scale_value,
        origin + Vector2(38, 0) * scale_value,
        origin + Vector2(30, 8) * scale_value,
        origin + Vector2(-30, 8) * scale_value
    ]), ROOF)
    draw_line(origin + Vector2(-30, 8) * scale_value, origin + Vector2(30, 8) * scale_value, TIMBER, 2.0, false)
    draw_rect(Rect2(origin + Vector2(-5, 10) * scale_value, Vector2(10, 15) * scale_value), TIMBER, true)
    draw_rect(Rect2(origin + Vector2(-19, 9) * scale_value, Vector2(9, 8) * scale_value), Color("#9bcbb9"), true)
    draw_rect(Rect2(origin + Vector2(10, 9) * scale_value, Vector2(9, 8) * scale_value), Color("#9bcbb9"), true)
    draw_rect(Rect2(origin + Vector2(20, -16) * scale_value, Vector2(4, 17) * scale_value), TIMBER, true)

func _draw_clover(origin: Vector2) -> void:
    for offset in [Vector2(-6, 0), Vector2(6, 0), Vector2(0, -6), Vector2(0, 6)]:
        draw_circle(origin + offset, 6.0, Color(BRASS, 0.94), true, -1.0, false)
    draw_circle(origin, 4.0, Color("#6f8c59"), true, -1.0, false)
    draw_line(origin + Vector2(0, 5), origin + Vector2(0, 16), FIELD_DARK, 2.0, false)
