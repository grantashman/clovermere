extends Node2D
class_name ClovermereNpcActor

const ArtAssetPack = preload("res://scripts/art_asset_pack.gd")

var npc: Dictionary = {}
var activity := "resting"
var route: Array = []
var cast_shadow := true
var shadow_offset := Vector2(4, 4)
var step_phase := 0.0
var walking := false
var facing := Vector2.RIGHT
var skin := Color("#d6a27a")
var hair := Color("#563d32")
var coat := Color("#7d8f5b")
var accent := Color("#d6b36d")
var uses_authored_art := false
var resident_asset_id := "resident"
var authored_texture: Texture2D

func set_facing_direction(direction: Vector2) -> void:
    if direction.length_squared() <= 0.001:
        return
    if absf(direction.x) >= 0.05:
        facing = Vector2.LEFT if direction.x < 0.0 else Vector2.RIGHT
    queue_redraw()

func walk_frame() -> int:
    return int(floor(step_phase / (PI * 0.5))) % 4

func idle_frame() -> int:
    return int(floor(step_phase * 0.5)) % 2
func set_npc(data: Dictionary) -> void:
    npc = data.duplicate(true)
    skin = Color(str(npc.get("skin", "#d6a27a")))
    hair = Color(str(npc.get("hair", "#563d32")))
    coat = Color(str(npc.get("coat", "#6b8159")))
    accent = Color(str(npc.get("accent", "#d6b36d")))
    resident_asset_id = ArtAssetPack.resident_asset_for(str(npc.get("id", "")))
    uses_authored_art = not resident_asset_id.is_empty()
    authored_texture = ArtAssetPack.texture_for(resident_asset_id) if uses_authored_art else null
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    queue_redraw()

func update_depth(base_z: int = 100) -> void:
    z_index = base_z + floori(position.y / 16.0)

func set_activity(next_activity: String) -> void:
    activity = next_activity
    queue_redraw()

func set_route(next_route: Array) -> void:
    route = next_route.duplicate()
    walking = not route.is_empty()
    queue_redraw()

func advance_navigation(delta: float, tile_size: float, speed_tiles_per_second: float) -> bool:
    if route.is_empty():
        walking = false
        return false
    var target_tile: Vector2i = route[0]
    var target := (Vector2(target_tile) + Vector2(0.5, 0.9)) * tile_size
    var distance := position.distance_to(target)
    var step := speed_tiles_per_second * tile_size * delta
    walking = true
    if distance <= step:
        facing = position.direction_to(target)
        set_facing_direction(facing)
        position = target
        route.pop_front()
        walking = not route.is_empty()
        queue_redraw()
        return true
    facing = position.direction_to(target)
    set_facing_direction(facing)
    position = position.move_toward(target, step)
    step_phase += delta * 9.0
    queue_redraw()
    return true

func _process(delta: float) -> void:
    if not walking:
        step_phase += delta * 2.5
    queue_redraw()

func _draw() -> void:
    var bob := sin(step_phase) * (0.8 if walking else 0.25)
    if cast_shadow:
        _draw_shadow(bob)
    if uses_authored_art and authored_texture != null:
        var mirror := -1.0 if facing.x < 0.0 else 1.0
        draw_set_transform(Vector2.ZERO, 0.0, Vector2(mirror, 1.0))
        draw_texture_rect(authored_texture, Rect2(-16, -24 + bob, 32, 48), false)
        _draw_role_prop(bob)
        _draw_stride_accents(bob)
        _draw_work_effect(bob)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        return
    draw_rect(Rect2(-6, -3 + bob, 12, 14), Color("#26362d"), true)
    draw_rect(Rect2(-5, -13 + bob, 10, 16), coat, true)
    draw_rect(Rect2(2, -12 + bob, 3, 13), coat.darkened(0.28), true)
    draw_rect(Rect2(-7, -10 + bob, 2, 8), coat.lightened(0.08), true)
    draw_rect(Rect2(-4, 9 + bob, 3, 3), Color("#4a3b34"), true)
    draw_rect(Rect2(1, 9 + bob, 3, 3), Color("#4a3b34"), true)
    draw_circle(Vector2(0, -18 + bob), 6.0, Color("#2a332b"), true, -1.0, false)
    draw_circle(Vector2(0, -18 + bob), 5.0, skin, true, -1.0, false)
    draw_rect(Rect2(-6, -23 + bob, 12, 3), hair, true)
    draw_rect(Rect2(-5, -25 + bob, 10, 3), hair, true)
    draw_rect(Rect2(-3, -19 + bob, 2, 2), Color("#2c2923"), true)
    draw_rect(Rect2(2, -19 + bob, 2, 2), Color("#2c2923"), true)
    draw_rect(Rect2(-3, -3 + bob, 6, 2), accent, true)
    _draw_stride_accents(bob)
    _draw_role_prop(bob)
    _draw_work_effect(bob)

func _draw_stride_accents(bob: float) -> void:
    var frame := walk_frame() if walking else idle_frame()
    var stride: Vector2 = [Vector2(-2, 0), Vector2(1, 1), Vector2(3, 0), Vector2(1, -1)][frame]
    draw_rect(Rect2(Vector2(-7, 8) + stride + Vector2(0, bob), Vector2(4, 3)), Color("#4a3b34", 0.88), true)
    draw_rect(Rect2(Vector2(2, 8) - stride + Vector2(0, bob), Vector2(4, 3)), Color("#382f2b", 0.88), true)
func _draw_shadow(bob: float) -> void:
    var shadow_points := PackedVector2Array([
        Vector2(-10, 7 + bob) + shadow_offset, Vector2(-6, 4 + bob) + shadow_offset, Vector2(5, 4 + bob) + shadow_offset,
        Vector2(11, 7 + bob) + shadow_offset, Vector2(5, 10 + bob) + shadow_offset, Vector2(-6, 10 + bob) + shadow_offset
    ])
    draw_colored_polygon(shadow_points, Color("#1b2c26", 0.78))

func _draw_role_prop(bob: float) -> void:
    var role := str(npc.get("role", ""))
    if role == "waykeeper":
        draw_rect(Rect2(8, -17 + bob, 2, 21), Color("#744f3d"), true)
        draw_rect(Rect2(8, -19 + bob, 6, 4), accent, true)
    elif role == "herbalist":
        draw_rect(Rect2(-11, -9 + bob, 4, 5), Color("#88b75a"), true)
        draw_rect(Rect2(-10, -11 + bob, 2, 3), accent, true)
    elif role == "maker":
        draw_rect(Rect2(7, -8 + bob, 5, 5), Color("#a56d4b"), true)
    elif role == "courier":
        draw_rect(Rect2(-11, -7 + bob, 5, 7), Color("#765346"), true)
        draw_rect(Rect2(-10, -6 + bob, 3, 4), accent, true)
    elif role == "keeper":
        draw_rect(Rect2(7, -9 + bob, 5, 6), Color("#b1a88b"), true)

func _draw_work_effect(bob: float) -> void:
    if activity not in ["gathering", "patrolling", "tending", "crafting", "delivering", "stocking"]:
        return
    if activity == "patrolling" or activity == "delivering":
        return
    var swing := sin(step_phase * 1.5) * 0.35 + 0.65
    var hand := Vector2(7, -6 + bob)
    var tool_end := hand + Vector2(7.0 * swing, -10.0 + 5.0 * swing)
    var tool_color := Color("#b1a88b") if activity == "gathering" else Color("#a56d4b")
    draw_line(hand, tool_end, Color("#744f3d"), 2.0, false)
    draw_rect(Rect2(tool_end - Vector2(3, 1), Vector2(7, 2)), tool_color, true)
    if int(floor(step_phase * 2.0)) % 4 == 0:
        draw_rect(Rect2(tool_end + Vector2(-4, -4), Vector2(2, 2)), Color("#f0d487"), true)
        draw_rect(Rect2(tool_end + Vector2(5, -1), Vector2(2, 2)), Color("#d7b576"), true)
