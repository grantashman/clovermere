extends Node2D
class_name ClovermereLivingWorldFx

const Atmosphere = preload("res://scripts/atmosphere.gd")

const BRASS := Color("#e1bf70")
const BRASS_SOFT := Color("#d7b576")
const LEAF := Color("#91b961")
const LEAF_LIGHT := Color("#c4d983")
const WATER := Color("#86c1ac")
const WATER_DARK := Color("#326b73")
const WOOD := Color("#704936")
const WOOD_LIGHT := Color("#b77950")
const PARCHMENT := Color("#d9c89b")
const EMBER := Color("#efaa5b")

var world
var village: Dictionary = {}
var consequence_flags: Dictionary = {}
var world_changes: Dictionary = {}
var atmosphere := Atmosphere.new()
var minute_of_day := 480
var animation_phase := 0.0
var _active_phase := "day"
var anchors: Dictionary = {}

func configure(_world, _village: Dictionary = {}, _consequence_flags: Dictionary = {}, _world_changes: Dictionary = {}) -> void:
    world = _world
    village = _village.duplicate(true)
    consequence_flags = _consequence_flags.duplicate(true)
    world_changes = _world_changes.duplicate(true)
    _build_anchors()
    queue_redraw()

func ambient_anchor_ids() -> Array[String]:
    return ["commons", "hall", "workshop", "garden", "barn", "pond", "orchard", "willowmere", "lookout"]

func location_prop_ids() -> Array[String]:
    return ["commons_seating", "hall_posters", "workshop_crates", "garden_drying_rack", "barn_straw", "pond_reeds", "orchard_crates", "willowmere_reeds", "lookout_flag"]

func effects_for_phase(phase: String) -> Array[String]:
    match phase:
        "dawn":
            return ["mist", "pollen", "bird-glint"]
        "dusk":
            return ["ember", "moth", "leaf-drift"]
        "night":
            return ["firefly", "moth", "window-glow"]
        _:
            return ["pollen", "leaf-drift", "water-spark"]

func resident_idle_variant(npc_id: String, minute: int) -> String:
    var variants := ["watching", "sorting", "resting", "watering", "mending"]
    var seed := 0
    for value in npc_id.to_utf8_buffer():
        seed = (seed * 31 + int(value)) % 997
    var phase := posmod(minute / 30, variants.size())
    return variants[posmod(seed + phase, variants.size())]

func set_consequence_flags(flags: Dictionary) -> void:
    consequence_flags = flags.duplicate(true)
    queue_redraw()

func set_time(minutes: int) -> void:
    minute_of_day = posmod(minutes, 1440)
    _active_phase = atmosphere.phase_for(minute_of_day)
    queue_redraw()

func active_phase_name() -> String:
    return _active_phase

func active_phase() -> String:
    return _active_phase

func _process(delta: float) -> void:
    animation_phase = fmod(animation_phase + maxf(delta, 0.0), TAU)
    queue_redraw()

func _build_anchors() -> void:
    anchors.clear()
    if world == null:
        return
    var origin: Vector2 = Vector2(world.SETTLEMENT_ORIGIN)
    anchors["commons"] = origin + Vector2(30, 26)
    anchors["hall"] = origin + Vector2(30, 13)
    anchors["workshop"] = origin + Vector2(48, 17)
    anchors["garden"] = origin + Vector2(20, 32)
    anchors["barn"] = origin + Vector2(45, 33)
    anchors["pond"] = origin + Vector2(16, 22)
    for landmark_variant in world.LANDMARKS:
        var landmark: Dictionary = landmark_variant
        var centre := Vector2(float(landmark.get("x", 0)) + float(landmark.get("w", 1)) * 0.5, float(landmark.get("y", 0)) + float(landmark.get("h", 1)) * 0.5)
        match str(landmark.get("id", "")):
            "apple-orchard": anchors["orchard"] = centre
            "willowmere": anchors["willowmere"] = centre
            "west-lookout": anchors["lookout"] = centre

func _point(anchor_id: String) -> Vector2:
    return Vector2(anchors.get(anchor_id, Vector2.ZERO)) * 16.0

func _draw() -> void:
    if world == null or anchors.is_empty():
        return
    _draw_location_props()
    _draw_ambient_particles()

func _draw_location_props() -> void:
    _draw_commons()
    _draw_hall_board()
    _draw_workshop_crates()
    _draw_garden_rack()
    _draw_barn_straw()
    _draw_pond_reeds()
    _draw_orchard_crates()
    _draw_willowmere_reeds()
    _draw_lookout_flag()

func _draw_commons() -> void:
    var point := _point("commons")
    if bool(consequence_flags.get("commons_foundation", false)):
        draw_rect(Rect2(point + Vector2(-52, 18), Vector2(104, 6)), Color(WOOD, 0.9), true)
        draw_rect(Rect2(point + Vector2(-46, 14), Vector2(92, 4)), Color(WOOD_LIGHT, 0.75), true)
    _draw_bench(point + Vector2(-36, -2), -1.0)
    _draw_bench(point + Vector2(18, 10), 1.0)
    draw_rect(Rect2(point + Vector2(-3, -30), Vector2(6, 27)), WOOD, true)
    draw_rect(Rect2(point + Vector2(-10, -34), Vector2(20, 6)), Color(BRASS, 0.75), true)
    if bool(consequence_flags.get("commons_shelter", false)):
        draw_rect(Rect2(point + Vector2(-36, -48), Vector2(72, 5)), WOOD, true)
        draw_colored_polygon(PackedVector2Array([point + Vector2(-42, -42), point + Vector2(0, -64), point + Vector2(42, -42)]), Color("#53654e"))
    if bool(consequence_flags.get("commons_complete", false)):
        for index in range(5):
            var flower := point + Vector2(-38 + index * 19, 31 + (index % 2) * 4)
            draw_line(flower, flower + Vector2(0, -7), LEAF, 1.0, false)
            draw_circle(flower + Vector2(-2, -8), 2.0, BRASS_SOFT)
            draw_circle(flower + Vector2(2, -8), 2.0, LEAF_LIGHT)

func _draw_bench(point: Vector2, facing: float) -> void:
    draw_rect(Rect2(point + Vector2(-18, -2), Vector2(36, 5)), WOOD_LIGHT, true)
    draw_rect(Rect2(point + Vector2(-15, 3), Vector2(4, 9)), WOOD, true)
    draw_rect(Rect2(point + Vector2(11, 3), Vector2(4, 9)), WOOD, true)
    draw_line(point + Vector2(-16, -7), point + Vector2(16, -7), WOOD, 3.0, false)

func _draw_hall_board() -> void:
    var point := _point("hall") + Vector2(70, 28)
    draw_rect(Rect2(point + Vector2(-10, 0), Vector2(20, 26)), WOOD, true)
    draw_rect(Rect2(point + Vector2(-8, 3), Vector2(16, 15)), PARCHMENT, true)
    draw_rect(Rect2(point + Vector2(-5, 6), Vector2(10, 1)), WOOD, true)
    draw_rect(Rect2(point + Vector2(-5, 10), Vector2(7, 1)), WOOD, true)
    draw_rect(Rect2(point + Vector2(-2, 26), Vector2(4, 8)), WOOD, true)

func _draw_workshop_crates() -> void:
    var point := _point("workshop") + Vector2(56, 26)
    for offset in [Vector2.ZERO, Vector2(14, -5), Vector2(28, 0)]:
        draw_rect(Rect2(point + offset, Vector2(13, 12)), WOOD, true)
        draw_line(point + offset + Vector2(2, 2), point + offset + Vector2(11, 10), WOOD_LIGHT, 1.0, false)
        draw_line(point + offset + Vector2(11, 2), point + offset + Vector2(2, 10), WOOD_LIGHT, 1.0, false)
    if _active_phase in ["dusk", "night"]:
        var ember := point + Vector2(5, -13)
        draw_circle(ember, 8.0, Color(EMBER, 0.10))
        draw_rect(Rect2(ember + Vector2(-2, -2), Vector2(4, 4)), Color(EMBER, 0.72), true)

func _draw_garden_rack() -> void:
    var point := _point("garden") + Vector2(0, 30)
    draw_rect(Rect2(point + Vector2(-22, 0), Vector2(44, 4)), WOOD, true)
    for index in range(4):
        var herb := point + Vector2(-18 + index * 12, -2)
        draw_line(herb, herb + Vector2(-2, -13), LEAF, 1.0, false)
        draw_line(herb, herb + Vector2(3, -10), LEAF_LIGHT, 1.0, false)
        draw_rect(Rect2(herb + Vector2(-4, -16), Vector2(8, 3)), Color("#c8d487", 0.68), true)

func _draw_barn_straw() -> void:
    var point := _point("barn") + Vector2(20, 30)
    draw_rect(Rect2(point, Vector2(24, 15)), Color("#b88954"), true)
    for index in range(3):
        draw_line(point + Vector2(4 + index * 7, 3), point + Vector2(7 + index * 7, 12), Color("#e0bd72"), 1.0, false)

func _draw_pond_reeds() -> void:
    var point := _point("pond")
    for index in range(5):
        var reed := point + Vector2(-28 + index * 14, 12 + (index % 2) * 5)
        draw_line(reed, reed + Vector2(-3, -18), LEAF, 1.0, false)
        draw_line(reed + Vector2(2, 0), reed + Vector2(6, -15), LEAF_LIGHT, 1.0, false)
    var ripple := 9.0 + sin(animation_phase * 2.0) * 2.0
    draw_arc(point + Vector2(5, 5), ripple, 0.1, 2.9, 12, Color(WATER, 0.60), 1.0, false)
    draw_arc(point + Vector2(5, 5), ripple + 6.0, 0.2, 2.7, 12, Color(WATER, 0.34), 1.0, false)

func _draw_orchard_crates() -> void:
    if not anchors.has("orchard"):
        return
    var point := _point("orchard") + Vector2(-26, 18)
    draw_rect(Rect2(point, Vector2(18, 13)), WOOD, true)
    draw_rect(Rect2(point + Vector2(3, 3), Vector2(12, 7)), Color("#c89058"), true)
    draw_circle(point + Vector2(7, 5), 2.5, Color("#c86e49"))
    draw_circle(point + Vector2(12, 6), 2.5, Color("#dca05b"))

func _draw_willowmere_reeds() -> void:
    if not anchors.has("willowmere"):
        return
    var point := _point("willowmere") + Vector2(-30, 16)
    for index in range(6):
        var reed := point + Vector2(index * 10, (index % 3) * 5)
        draw_line(reed, reed + Vector2(-4, -20), LEAF, 1.0, false)
        draw_line(reed + Vector2(3, 0), reed + Vector2(7, -16), LEAF_LIGHT, 1.0, false)
    draw_arc(point + Vector2(29, 15), 13.0, 0.2, 2.9, 12, Color(WATER, 0.52), 1.0, false)

func _draw_lookout_flag() -> void:
    if not anchors.has("lookout"):
        return
    var point := _point("lookout") + Vector2(0, -20)
    draw_line(point, point + Vector2(0, -31), WOOD, 2.0, false)
    draw_colored_polygon(PackedVector2Array([point + Vector2(1, -30), point + Vector2(24, -25), point + Vector2(1, -19)]), Color("#bd704e"))

func _draw_ambient_particles() -> void:
    var phase_effects := effects_for_phase(_active_phase)
    if "pollen" in phase_effects:
        for index in range(12):
            var base := _point("garden") + Vector2(float((index * 37) % 100) - 48.0, float((index * 19) % 48) - 22.0)
            var drift := Vector2(sin(animation_phase * 0.8 + index) * 5.0, cos(animation_phase * 0.7 + index * 0.4) * 4.0)
            draw_rect(Rect2(base + drift, Vector2(2, 2)), Color(BRASS_SOFT, 0.44), true)
    if "leaf-drift" in phase_effects:
        for index in range(7):
            var base := _point("orchard" if index % 2 == 0 and anchors.has("orchard") else "commons") + Vector2(float((index * 41) % 110) - 55.0, -18.0 - float((index * 13) % 30))
            var drift := Vector2(sin(animation_phase * 0.9 + index) * 8.0, fmod(animation_phase * 4.0 + float(index * 7), 20.0))
            draw_rect(Rect2(base + drift, Vector2(3, 2)), Color(LEAF_LIGHT, 0.60), true)
    if "water-spark" in phase_effects:
        var pond := _point("pond")
        for index in range(4):
            var spark := pond + Vector2(-20 + index * 13, -5 + sin(animation_phase * 1.5 + index) * 4.0)
            draw_rect(Rect2(spark, Vector2(3, 1)), Color(WATER, 0.54), true)
    if "ember" in phase_effects:
        var workshop := _point("workshop") + Vector2(60, 10)
        for index in range(4):
            var ember := workshop + Vector2(sin(animation_phase * 1.2 + index) * 8.0, -float(index * 6) - fmod(animation_phase * 8.0 + index * 3.0, 18.0))
            draw_rect(Rect2(ember, Vector2(2, 2)), Color(EMBER, 0.70), true)
    if "firefly" in phase_effects:
        for anchor_id in ["commons", "garden", "willowmere", "lookout"]:
            if not anchors.has(anchor_id):
                continue
            var base := _point(anchor_id)
            var index := ambient_anchor_ids().find(anchor_id)
            var orbit := animation_phase * (0.7 + float(maxi(index, 0)) * 0.03) + float(index)
            var point := base + Vector2(cos(orbit) * 22.0, -16.0 + sin(orbit * 1.7) * 12.0)
            draw_circle(point + Vector2(2, 2), 5.0, Color(BRASS, 0.09), true)
            draw_rect(Rect2(point, Vector2(3, 3)), Color(BRASS, 0.78), true)
    if "moth" in phase_effects:
        var hall := _point("hall") + Vector2(74, 10)
        var moth := hall + Vector2(sin(animation_phase * 1.4) * 18.0, -10.0 + cos(animation_phase * 1.1) * 7.0)
        draw_rect(Rect2(moth, Vector2(3, 2)), Color(PARCHMENT, 0.72), true)
        draw_rect(Rect2(moth + Vector2(-3, 1), Vector2(3, 1)), Color(PARCHMENT, 0.36), true)
        draw_rect(Rect2(moth + Vector2(3, 1), Vector2(3, 1)), Color(PARCHMENT, 0.36), true)
