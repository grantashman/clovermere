extends Button
class_name ClovermereHudButton

var glyph := ""
var active := false

func _ready() -> void:
    focus_mode = Control.FOCUS_ALL
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    queue_redraw()

func set_glyph(value: String) -> void:
    glyph = value
    queue_redraw()

func set_active(value: bool) -> void:
    active = value
    queue_redraw()

func _draw() -> void:
    if glyph.is_empty():
        return
    var centre := Vector2(14, size.y * 0.5)
    var ink := Color("#f0d487") if active or has_focus() else Color("#a7bd6a")
    if glyph == "pack":
        draw_rect(Rect2(centre + Vector2(-6, -6), Vector2(12, 12)), Color(ink, 0.22), true)
        draw_rect(Rect2(centre + Vector2(-6, -6), Vector2(12, 12)), ink, false, 1.5)
        draw_line(centre + Vector2(-3, -8), centre + Vector2(3, -8), ink, 2.0, false)
        draw_line(centre + Vector2(-3, -3), centre + Vector2(3, -3), ink, 1.0, false)
    elif glyph == "craft":
        draw_line(centre + Vector2(-7, 6), centre + Vector2(6, -7), ink, 2.0, false)
        draw_line(centre + Vector2(-6, -6), centre + Vector2(6, 6), ink, 1.5, false)
        draw_circle(centre + Vector2(6, -7), 2.5, ink)
    elif glyph == "hearth":
        draw_colored_polygon(PackedVector2Array([centre + Vector2(-7, 5), centre + Vector2(-5, -2), centre + Vector2(0, -7), centre + Vector2(5, -2), centre + Vector2(7, 5)]), Color(ink, 0.75))
        draw_rect(Rect2(centre + Vector2(-3, 0), Vector2(6, 5)), ink, false, 1.0)
    elif glyph == "project":
        draw_rect(Rect2(centre + Vector2(-7, -6), Vector2(14, 12)), Color(ink, 0.22), true)
        draw_rect(Rect2(centre + Vector2(-7, -6), Vector2(14, 12)), ink, false, 1.5)
        draw_rect(Rect2(centre + Vector2(-4, -2), Vector2(8, 2)), ink, true)
        draw_rect(Rect2(centre + Vector2(-4, 2), Vector2(5, 2)), ink, true)
    elif glyph == "board":
        draw_rect(Rect2(centre + Vector2(-7, -7), Vector2(14, 14)), Color(ink, 0.22), true)
        draw_rect(Rect2(centre + Vector2(-7, -7), Vector2(14, 14)), ink, false, 1.5)
        draw_rect(Rect2(centre + Vector2(-4, -3), Vector2(8, 2)), ink, true)
        draw_rect(Rect2(centre + Vector2(-4, 1), Vector2(6, 2)), ink, true)
    elif glyph == "menu":
        for offset in [-5.0, 0.0, 5.0]:
            draw_line(centre + Vector2(-7, offset), centre + Vector2(7, offset), ink, 1.5, false)
    if active:
        draw_rect(Rect2(Vector2(5, size.y - 4), Vector2(size.x - 10, 2)), Color("#f0d487"), true)
