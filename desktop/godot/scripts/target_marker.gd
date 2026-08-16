extends Node2D

var active := false
var elapsed := 0.0

func set_target(world_position: Vector2) -> void:
    position = world_position
    active = true
    visible = true
    queue_redraw()

func clear_target() -> void:
    active = false
    visible = false
    queue_redraw()

func _process(delta: float) -> void:
    if not active:
        return
    elapsed += delta
    queue_redraw()

func _draw() -> void:
    if not active:
        return
    var pulse := 7.0 + sin(elapsed * 5.0) * 1.5
    draw_arc(Vector2.ZERO, pulse, 0.0, TAU, 24, Color("#f0d487"), 1.5, false)
    draw_arc(Vector2.ZERO, pulse + 3.0, 0.2, 1.1, 8, Color(0.94, 0.83, 0.53, 0.45), 1.0, false)
    draw_line(Vector2(-3, 0), Vector2(3, 0), Color("#f0d487"), 1.0, false)
    draw_line(Vector2(0, -3), Vector2(0, 3), Color("#f0d487"), 1.0, false)
