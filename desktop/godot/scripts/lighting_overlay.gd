extends Node2D

const Atmosphere = preload("res://scripts/atmosphere.gd")

var world
var player_position := Vector2.ZERO
var elapsed := 0.0
var active := false
var lanterns: Array = []
var minute_of_day := 8 * 60
var atmosphere := Atmosphere.new()

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
    return atmosphere.palette_for(value).get("ambient", Color.TRANSPARENT)

func shadow_direction_for(value: int) -> Vector2:
    return atmosphere.shadow_direction_for(value)

func _draw() -> void:
    if world == null:
        return
    var palette: Dictionary = atmosphere.palette_for(minute_of_day)
    var ambient: Color = palette.get("ambient", Color.TRANSPARENT)
    var light_color: Color = palette.get("light_color", Color("#efc56d"))
    var light_strength: float = float(palette.get("light_strength", 0.1))
    draw_rect(Rect2(-4096, -4096, 8192, 8192), ambient, true)
    _draw_celestial_disc(palette)
    _draw_phase_haze(palette)
    for index in lanterns.size():
        var pulse := 1.0 + sin(elapsed * 2.2 + float(index) * 0.7) * 0.035
        _draw_glow(lanterns[index], 48.0 + light_strength * 46.0 * pulse, light_color, 0.10 + light_strength * 0.18)
    if active:
        _draw_glow(player_position, 68.0 + light_strength * 48.0 + sin(elapsed * 2.8) * 3.0, light_color, 0.14 + light_strength * 0.18)
        draw_circle(player_position, 8.0 + light_strength * 3.0, Color(light_color, 0.14 + light_strength * 0.32), true, -1.0, false)

func _draw_celestial_disc(palette: Dictionary) -> void:
    var visible := bool(palette.get("sun_visible", false)) or bool(palette.get("moon_visible", false))
    if not visible:
        return
    var world_size := Vector2(float(world.WORLD_WIDTH) * world.TILE_SIZE, float(world.WORLD_HEIGHT) * world.TILE_SIZE)
    var point: Vector2 = atmosphere.sun_position_for(minute_of_day, world_size)
    if bool(palette.get("moon_visible", false)):
        point = Vector2(world_size.x * 0.78, world_size.y * 0.14)
        draw_circle(point, 30.0, Color("#91b1c1", 0.025), true, -1.0, false)
        draw_circle(point, 10.0, Color("#c8d1bd", 0.42), true, -1.0, false)
        draw_circle(point + Vector2(3, -2), 8.0, Color("#aab9ae", 0.35), true, -1.0, false)
    else:
        var light_color: Color = palette.get("light_color", Color("#f1d08c"))
        draw_circle(point, 42.0, Color(light_color, 0.025), true, -1.0, false)
        draw_circle(point, 12.0, Color(light_color, 0.48), true, -1.0, false)

func _draw_phase_haze(palette: Dictionary) -> void:
    var phase := str(palette.get("phase", "day"))
    if phase not in ["dawn", "dusk"]:
        return
    var centre := Vector2(float(world.SETTLEMENT_ORIGIN.x + 30) * world.TILE_SIZE, float(world.SETTLEMENT_ORIGIN.y + 22) * world.TILE_SIZE)
    var color: Color = palette.get("light_color", Color("#e6a45e"))
    for ring in range(5, 0, -1):
        var ratio := float(ring) / 5.0
        draw_circle(centre, 180.0 + float(ring) * 110.0, Color(color, 0.012 + (1.0 - ratio) * 0.008), true, -1.0, false)

func _draw_glow(position: Vector2, radius: float, color: Color, strength: float) -> void:
    for ring in range(6, 0, -1):
        var ratio := float(ring) / 6.0
        var alpha := strength * (1.0 - ratio) * 0.7 + 0.012
        draw_circle(position, radius * ratio, Color(color.r, color.g, color.b, alpha), true, -1.0, false)
