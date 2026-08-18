extends SceneTree

const LivingWorldFx = preload("res://scripts/living_world_fx.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var fx = LivingWorldFx.new()
    var anchors: Array[String] = fx.ambient_anchor_ids()
    for required in ["commons", "hall", "workshop", "garden", "barn", "pond", "orchard", "willowmere", "lookout"]:
        require(required in anchors, "%s should have an authored ambient anchor" % required)
    require(fx.effects_for_phase("day").has("pollen"), "day should carry soft pollen movement")
    require(fx.effects_for_phase("dusk").has("ember"), "dusk should carry warm ember movement")
    require(fx.effects_for_phase("night").has("firefly"), "night should carry firefly movement")
    require(fx.effects_for_phase("night").has("moth"), "night should carry moth movement")
    require(fx.location_prop_ids().has("commons_seating"), "the commons should have authored seating props")
    require(fx.location_prop_ids().has("pond_reeds"), "the pond should have authored reed props")
    var first_variant: String = fx.resident_idle_variant("alda-fen", 720)
    require(first_variant in ["watching", "sorting", "resting", "watering", "mending"], "resident idle variant should be authored")
    require(first_variant == fx.resident_idle_variant("alda-fen", 720), "resident idle variant should be deterministic")
    require(fx.resident_idle_variant("alda-fen", 720) != fx.resident_idle_variant("tobin-wren", 720) or fx.resident_idle_variant("alda-fen", 720) == "resting", "residents should not all share one idle cue")
    fx.set_time(1320)
    require(fx.active_phase() == "night", "living-world FX should track the active time phase")
    if failures.is_empty():
        print("Godot living-world presentation contract: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
