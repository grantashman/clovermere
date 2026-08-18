extends Control
class_name ClovermereHudArt

const DEEP := Color("#07130f")
const PANEL := Color("#0d2118")
const PANEL_MID := Color("#173326")
const EDGE := Color("#6f553d")
const EDGE_LIGHT := Color("#b18a55")
const BRASS := Color("#e6c878")
const BRASS_DIM := Color("#9b7a4d")
const MOSS := Color("#8da95f")

var management_visible := false
var dialogue_visible := false
var interaction_visible := false
var interior_mode := false
var active_surface := ""

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(false)
    custom_minimum_size = Vector2(1280, 720)
    queue_redraw()

func frame_kinds() -> Array[String]:
    return ["status", "location", "map", "action", "management", "dialogue", "interaction"]

func set_state(management: bool, dialogue: bool, interaction: bool, interior: bool, active: String) -> void:
    management_visible = management
    dialogue_visible = dialogue
    interaction_visible = interaction
    interior_mode = interior
    active_surface = active
    queue_redraw()

func _draw() -> void:
    _draw_frame(Rect2(24, 20, 330, 108), "status", BRASS)
    _draw_frame(Rect2(432, 20, 416, 42), "location", BRASS)
    _draw_frame(Rect2(1040, 20, 216, 136), "map", MOSS)
    _draw_frame(Rect2(430, 622, 420, 52), "action", BRASS)
    if management_visible:
        _draw_frame(Rect2(888, 180, 368, 440), "management", BRASS)
    if dialogue_visible:
        _draw_frame(Rect2(260, 486, 760, 112), "dialogue", EDGE_LIGHT)
    if interaction_visible:
        _draw_frame(Rect2(350, 578, 580, 38), "interaction", BRASS)
    if interior_mode:
        _draw_interior_marker()

func _draw_frame(rect: Rect2, kind: String, accent: Color) -> void:
    var shadow := rect
    shadow.position += Vector2(0, 4)
    draw_rect(shadow, Color(DEEP, 0.7), true)
    draw_rect(rect, Color(PANEL, 0.98), true)
    draw_rect(rect, Color(EDGE, 0.95), false, 2.0)
    var inner := rect.grow(-4)
    draw_rect(inner, Color(PANEL_MID, 0.22), false, 1.0)
    draw_line(rect.position + Vector2(12, 2), rect.position + Vector2(rect.size.x - 12, 2), accent, 1.0, false)
    draw_line(rect.position + Vector2(12, rect.size.y - 2), rect.position + Vector2(rect.size.x - 12, rect.size.y - 2), Color(BRASS_DIM, 0.65), 1.0, false)
    _draw_corner(rect.position + Vector2(5, 5), accent, false, false)
    _draw_corner(rect.position + Vector2(rect.size.x - 5, 5), accent, true, false)
    _draw_corner(rect.position + Vector2(5, rect.size.y - 5), accent, false, true)
    _draw_corner(rect.position + Vector2(rect.size.x - 5, rect.size.y - 5), accent, true, true)
    if kind == "status":
        draw_rect(Rect2(rect.position + Vector2(12, 34), Vector2(rect.size.x - 24, 1)), Color(EDGE_LIGHT, 0.7), true)
        draw_circle(rect.position + Vector2(rect.size.x - 14, 15), 2.0, accent)
    elif kind == "location":
        draw_line(rect.position + Vector2(64, rect.size.y - 7), rect.position + Vector2(rect.size.x - 64, rect.size.y - 7), Color(accent, 0.55), 1.0, false)
    elif kind == "map":
        draw_rect(Rect2(rect.position + Vector2(8, 8), rect.size - Vector2(16, 16)), Color(accent, 0.22), false, 1.0)
    elif kind == "management":
        draw_rect(Rect2(rect.position + Vector2(14, 54), Vector2(rect.size.x - 28, 1)), Color(EDGE_LIGHT, 0.7), true)
        draw_circle(rect.position + Vector2(rect.size.x - 17, 18), 2.0, accent)
    elif kind == "action":
        draw_line(rect.position + Vector2(18, 9), rect.position + Vector2(rect.size.x - 18, 9), Color(accent, 0.35), 1.0, false)
    elif kind == "dialogue":
        draw_rect(Rect2(rect.position + Vector2(14, 12), Vector2(4, rect.size.y - 24)), accent, true)
    elif kind == "interaction":
        draw_circle(rect.position + Vector2(18, rect.size.y * 0.5), 3.0, accent)
        draw_circle(rect.position + Vector2(rect.size.x - 18, rect.size.y * 0.5), 3.0, accent)

func _draw_corner(point: Vector2, color: Color, flip_x: bool, flip_y: bool) -> void:
    var sx := -1.0 if flip_x else 1.0
    var sy := -1.0 if flip_y else 1.0
    draw_line(point, point + Vector2(7.0 * sx, 0), color, 1.0, false)
    draw_line(point, point + Vector2(0, 7.0 * sy), color, 1.0, false)
    draw_rect(Rect2(point + Vector2(2.0 * sx, 2.0 * sy), Vector2(2, 2)), color, true)

func _draw_interior_marker() -> void:
    draw_rect(Rect2(442, 52, 396, 2), Color(BRASS, 0.2), true)
