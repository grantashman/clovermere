extends SceneTree

const Atmosphere = preload("res://scripts/atmosphere.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var atmosphere = Atmosphere.new()
    require(atmosphere.phase_for(300) == "night", "pre-dawn should use the night phase")
    require(atmosphere.phase_for(420) == "dawn", "early morning should use the dawn phase")
    require(atmosphere.phase_for(720) == "day", "midday should use the day phase")
    require(atmosphere.phase_for(1020) == "dusk", "early evening should use the dusk phase")
    require(atmosphere.phase_for(1320) == "night", "late evening should use the night phase")
    var day: Dictionary = atmosphere.palette_for(720)
    var dusk: Dictionary = atmosphere.palette_for(1020)
    var night: Dictionary = atmosphere.palette_for(1320)
    require(float(dusk.get("light_strength", 0.0)) >= 0.4, "dusk should have visibly stronger warm local light")
    require(dusk.get("ambient", Color.WHITE) != day.get("ambient", Color.BLACK), "dusk should have a distinct ambient palette")
    require(night.get("ambient", Color.WHITE) != dusk.get("ambient", Color.BLACK), "night should have a distinct ambient palette")
    require(float(night.get("light_strength", 0.0)) > float(day.get("light_strength", 0.0)), "night should reserve stronger local light contrast")
    require(atmosphere.shadow_direction_for(720) != atmosphere.shadow_direction_for(1020), "shadow direction should move across the day")
    require(atmosphere.sun_position_for(720, Vector2(3840, 2560)).y < atmosphere.sun_position_for(1020, Vector2(3840, 2560)).y, "sun position should descend toward dusk")
    if failures.is_empty():
        print("Godot atmosphere presentation contract: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
