extends Node2D

var world
var player_position := Vector2.ZERO
var elapsed := 0.0
var active := false
var lanterns: Array = []

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

func _process(delta: float) -> void:
    elapsed += delta
    if active:
        queue_redraw()

func _draw() -> void:
    if world == null:
        return
    draw_rect(Rect2(-4096, -4096, 8192, 8192), Color(0.03, 0.07, 0.055, 0.055), true)
    for index in lanterns.size():
        var pulse := 1.0 + sin(elapsed * 2.2 + float(index) * 0.7) * 0.035
        _draw_glow(lanterns[index], 58.0 * pulse, Color("#e6bd70"), 0.13)
    if active:
        _draw_glow(player_position, 82.0 + sin(elapsed * 2.8) * 3.0, Color("#f2d38a"), 0.18)
        draw_circle(player_position, 10.0, Color("#f6d994"), true, -1.0, false)

func _draw_glow(position: Vector2, radius: float, color: Color, strength: float) -> void:
    for ring in range(6, 0, -1):
        var ratio := float(ring) / 6.0
        var alpha := strength * (1.0 - ratio) * 0.7 + 0.012
        draw_circle(position, radius * ratio, Color(color.r, color.g, color.b, alpha), true, -1.0, false)
