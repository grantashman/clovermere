extends Node2D

var window_points: Array[Vector2] = []
var active := false
var phase := 0.0

func configure(points: Array[Vector2]) -> void:
    window_points = points.duplicate()
    queue_redraw()

func set_time(minutes: int) -> void:
    var normalized := posmod(minutes, 1440)
    var next_active := normalized >= 17 * 60 or normalized < 6 * 60
    if active == next_active:
        return
    active = next_active
    queue_redraw()

func _process(delta: float) -> void:
    if not active:
        return
    phase = fmod(phase + maxf(delta, 0.0), TAU)
    queue_redraw()

func _draw() -> void:
    if not active:
        return
    for index in window_points.size():
        var point: Vector2 = window_points[index]
        var flicker := 0.92 + sin(phase * 2.1 + float(index) * 1.7) * 0.06
        draw_circle(point + Vector2(1, 1), 11.0, Color("#efc56d", 0.045 * flicker))
        draw_rect(Rect2(point - Vector2(4, 3), Vector2(8, 6)), Color("#e5b866", 0.78 * flicker), true)
        draw_rect(Rect2(point - Vector2(1, 3), Vector2(2, 6)), Color("#76513c", 0.9), true)
        draw_rect(Rect2(point - Vector2(4, 1), Vector2(8, 2)), Color("#76513c", 0.9), true)
