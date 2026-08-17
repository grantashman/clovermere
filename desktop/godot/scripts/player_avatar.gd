extends Node2D

const ArtAssetPack = preload("res://scripts/art_asset_pack.gd")

var elapsed := 0.0
var work_active := false
var tool_kind := ""
var work_progress := 0.0
var uses_authored_art := true
var authored_texture: Texture2D

func _ready() -> void:
    authored_texture = ArtAssetPack.texture_for("player")
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func begin_work(kind: String) -> void:
    work_active = true
    tool_kind = kind
    work_progress = 0.0
    queue_redraw()

func update_work(progress: float) -> void:
    work_progress = clampf(progress, 0.0, 1.0)
    queue_redraw()

func clear_work() -> void:
    work_active = false
    tool_kind = ""
    work_progress = 0.0
    queue_redraw()

func _process(delta: float) -> void:
    elapsed += delta
    queue_redraw()

func _draw_shadow(bob: float) -> void:
    var points := PackedVector2Array([
        Vector2(-10, 7 + bob), Vector2(-6, 4 + bob), Vector2(5, 4 + bob),
        Vector2(11, 7 + bob), Vector2(5, 10 + bob), Vector2(-6, 10 + bob)
    ])
    draw_colored_polygon(points, Color("#1b2c26", 0.78))

func _draw() -> void:
    var bob := sin(elapsed * 8.0) * 0.8
    _draw_shadow(bob)
    if uses_authored_art and authored_texture != null:
        draw_texture_rect(authored_texture, Rect2(-16, -24 + bob, 32, 48), false)
        if work_active:
            var swing := sin(elapsed * 15.0) * 5.0
            var tool_color := Color("#d7b06c") if tool_kind == "herb" else Color("#b98459")
            draw_line(Vector2(7 + swing, -1 + bob), Vector2(17 + swing, 11 + bob), Color("#714b35"), 2.0, false)
            draw_line(Vector2(17 + swing, 11 + bob), Vector2(23 + swing, 10 + bob), tool_color, 2.0, false)
        draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 24, Color(0.84, 0.68, 0.34, 0.5), 1.0, false)
        return
    draw_colored_polygon(PackedVector2Array([
        Vector2(-9, 7), Vector2(-5, 4), Vector2(5, 4), Vector2(11, 7), Vector2(5, 10), Vector2(-5, 10)
    ]), Color("#1c2923"))
    draw_rect(Rect2(-5, -2 + bob, 10, 12), Color("#6c7f58"), true)
    draw_rect(Rect2(-7, 0 + bob, 14, 5), Color("#738d62"), true)
    draw_circle(Vector2(0, -6 + bob), 6.0, Color("#d9a274"), true, -1.0, false)
    draw_rect(Rect2(-6, -10 + bob, 12, 4), Color("#5b3d32"), true)
    draw_rect(Rect2(-7, -8 + bob, 2, 4), Color("#5b3d32"), true)
    draw_rect(Rect2(5, -8 + bob, 2, 4), Color("#5b3d32"), true)
    draw_rect(Rect2(-3, -6 + bob, 2, 2), Color("#2c2923"), true)
    draw_rect(Rect2(2, -6 + bob, 2, 2), Color("#2c2923"), true)
    draw_rect(Rect2(-7, 9 + bob, 5, 2), Color("#3b4e3b"), true)
    draw_rect(Rect2(2, 9 + bob, 5, 2), Color("#3b4e3b"), true)
    if work_active:
        var swing := sin(elapsed * 15.0) * 5.0
        var tool_color := Color("#d7b06c") if tool_kind == "herb" else Color("#b98459")
        draw_line(Vector2(7 + swing, -1 + bob), Vector2(17 + swing, 11 + bob), Color("#714b35"), 2.0, false)
        draw_line(Vector2(17 + swing, 11 + bob), Vector2(23 + swing, 10 + bob), tool_color, 2.0, false)
    draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 24, Color(0.84, 0.68, 0.34, 0.5), 1.0, false)
