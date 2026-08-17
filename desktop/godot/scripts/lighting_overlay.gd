extends Node2D

var world
var player_position := Vector2.ZERO
var elapsed := 0.0
var active := false
var lanterns: Array = []
var minute_of_day := 8 * 60

func configure(_world) -> void:
    world = _world
    lanterns.clear()
    if world == null:
        return
    for building in world.buildings():
        lanterns.append(Vector2((float(building.x) + float(building.w) * 0.5) * world.TILE_SIZE, (float(building.y) + float(building.h) * 0.72) * world.TILE_SIZE))
    queue_redraw()

func set_player_position(value: Vector2, is_active: bool) -> void:
    player_position = value
    active = is_active
    queue_redraw()

func set_time(value: int) -> void:
    minute_of_day = clampi(value, 0, 23 * 60 + 59)
    queue_redraw()

func _process(delta: float) -> void:
    elapsed += delta
    if active:
        queue_redraw()

func ambient_color_for(value: int) -> Color:
    var minute := posmod(value, 1440)
    if minute >= 17 * 60 or minute < 6 * 60:
        var night_strength := 0.38 if minute >= 20 * 60 or minute < 5 * 60 else 0.24
        return Color(0.008, 0.025, 0.075, night_strength)
    if minute < 8 * 60:
        return Color(0.02, 0.05, 0.08, 0.12)
    if minute >= 15 * 60:
        return Color(0.06, 0.035, 0.02, 0.09)
    return Color(0.01, 0.035, 0.09, 0.045)

func shadow_direction_for(value: int) -> Vector2:
    var minute := posmod(value, 1440)
    if minute < 10 * 60:
        return Vector2(-0.85, 0.55).normalized()
    if minute < 16 * 60:
        return Vector2(-0.35, 0.94).normalized()
    if minute < 20 * 60:
        return Vector2(0.78, 0.62).normalized()
    return Vector2(0.2, 0.98).normalized()

func _draw() -> void:
    if world == null:
        return
    var ambient := ambient_color_for(minute_of_day)
    var shadow_direction := shadow_direction_for(minute_of_day)
    draw_rect(Rect2(-4096, -4096, 8192, 8192), ambient, true)
    for index in lanterns.size():
        var pulse := 1.0 + sin(elapsed * 2.2 + float(index) * 0.7) * 0.035
        _draw_glow(lanterns[index] + shadow_direction * 2.0, 58.0 * pulse, Color("#e6bd70"), 0.13)
    if active:
        _draw_glow(player_position, 82.0 + sin(elapsed * 2.8) * 3.0, Color("#f2d38a"), 0.18)
        draw_circle(player_position, 10.0, Color("#f6d994"), true, -1.0, false)

func _draw_glow(position: Vector2, radius: float, color: Color, strength: float) -> void:
    for ring in range(6, 0, -1):
        var ratio := float(ring) / 6.0
        var alpha := strength * (1.0 - ratio) * 0.7 + 0.012
        draw_circle(position, radius * ratio, Color(color.r, color.g, color.b, alpha), true, -1.0, false)
