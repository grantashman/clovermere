extends Node2D

var elapsed := 0.0

func _process(delta: float) -> void:
    elapsed += delta
    queue_redraw()

func _draw() -> void:
    var bob := sin(elapsed * 8.0) * 0.8
    draw_circle(Vector2(0, 5), 6.5, Color("#1c2923"), true, -1.0, false)
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
    draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 24, Color(0.84, 0.68, 0.34, 0.5), 1.0, false)
