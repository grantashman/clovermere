extends Control
class_name ClovermereHudResourceSlot

const DEEP := Color("#091711")
const EDGE := Color("#5a4635")
const EDGE_LIGHT := Color("#a57e4f")
const PARCHMENT := Color("#e7d6a7")
const BRASS := Color("#f0d487")
const MOSS := Color("#a7bd6a")
const WOOD := Color("#a5794d")
const WATER := Color("#7db8ae")
const ROCK := Color("#a0a58d")
const HERB := Color("#8fb963")

var resource_kind := "timber"
var amount := 0
var stored_amount := 0
var variant := 0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    custom_minimum_size = Vector2(54, 30)
    queue_redraw()

func set_resource(kind: String, carried: int, stored: int = 0, resource_variant: int = 0) -> void:
    resource_kind = kind
    amount = carried
    stored_amount = stored
    variant = resource_variant
    queue_redraw()

func _draw() -> void:
    var rect := Rect2(Vector2.ZERO, size if size.x > 0.0 else Vector2(54, 30))
    draw_rect(rect, Color(DEEP, 0.88), true)
    draw_rect(rect, Color(EDGE, 0.9), false, 1.0)
    draw_line(rect.position + Vector2(3, 2), rect.position + Vector2(rect.size.x - 3, 2), Color(EDGE_LIGHT, 0.65), 1.0, false)
    var centre := Vector2(14, rect.size.y * 0.52)
    _draw_icon(centre, resource_kind, variant)
    var font := ThemeDB.fallback_font
    var label := _short_name(resource_kind)
    draw_string(font, Vector2(36, 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(PARCHMENT, 0.82))
    draw_string(font, Vector2(28, 23), "%02d" % amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, PARCHMENT)
    if stored_amount > 0:
        draw_string(font, Vector2(42, 23), "+%02d" % stored_amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, MOSS)

func _short_name(kind: String) -> String:
    return {"timber": "TIM", "stone": "STN", "ore": "ORE", "herbs": "HRB", "fish": "FSH"}.get(kind, kind.left(3).to_upper())

func _draw_icon(centre: Vector2, kind: String, resource_variant: int) -> void:
    if kind == "timber":
        draw_rect(Rect2(centre + Vector2(-2, -8), Vector2(5, 16)), WOOD, true)
        draw_line(centre + Vector2(-5, -5), centre + Vector2(2, -10), MOSS, 2.0, false)
        draw_line(centre + Vector2(2, -10), centre + Vector2(6, -7), MOSS, 2.0, false)
    elif kind == "stone":
        draw_colored_polygon(PackedVector2Array([centre + Vector2(-8, 5), centre + Vector2(-5, -5), centre + Vector2(1, -8), centre + Vector2(8, -3), centre + Vector2(6, 6)]), ROCK)
        draw_line(centre + Vector2(-3, -3), centre + Vector2(2, 2), Color(DEEP, 0.7), 1.0, false)
    elif kind == "ore":
        draw_colored_polygon(PackedVector2Array([centre + Vector2(-7, 5), centre + Vector2(-4, -7), centre + Vector2(2, -8), centre + Vector2(8, -2), centre + Vector2(5, 6)]), Color("#5c776f"))
        draw_rect(Rect2(centre + Vector2(-2, -4), Vector2(3, 5)), Color("#c8dfb4"), true)
        draw_rect(Rect2(centre + Vector2(3, 1), Vector2(3, 3)), Color("#8fb8a1"), true)
    elif kind == "herbs":
        var leaf := Color("#a7c96b") if resource_variant % 2 == 0 else HERB
        draw_line(centre + Vector2(0, 7), centre + Vector2(-1, -7), HERB, 2.0, false)
        draw_rect(Rect2(centre + Vector2(-7, -4), Vector2(6, 3)), leaf, true)
        draw_rect(Rect2(centre + Vector2(2, -7), Vector2(6, 3)), leaf, true)
        draw_rect(Rect2(centre + Vector2(-6, 1), Vector2(5, 3)), leaf, true)
    elif kind == "fish":
        var fish_color := WATER if resource_variant % 2 == 0 else Color("#8dbd9a")
        draw_rect(Rect2(centre + Vector2(-7, -2), Vector2(14, 5)), fish_color, true)
        draw_colored_polygon(PackedVector2Array([centre + Vector2(7, 0), centre + Vector2(12, -6), centre + Vector2(12, 6)]), fish_color)
        draw_rect(Rect2(centre + Vector2(-4, -1), Vector2(2, 2)), BRASS, true)
