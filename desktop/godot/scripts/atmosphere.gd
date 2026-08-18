extends RefCounted
class_name ClovermereAtmosphere

const DAY_MINUTES := 1440
const WORLD_MINUTES := 840.0

func phase_for(value: int) -> String:
    var minute := posmod(value, DAY_MINUTES)
    if minute < 6 * 60 or minute >= 20 * 60:
        return "night"
    if minute < 8 * 60:
        return "dawn"
    if minute < 17 * 60:
        return "day"
    if minute < 20 * 60:
        return "dusk"
    return "night"

func palette_for(value: int) -> Dictionary:
    match phase_for(value):
        "dawn":
            return {
                "phase": "dawn",
                "ambient": Color(0.04, 0.06, 0.08, 0.12),
                "light_color": Color("#e9b875"),
                "light_strength": 0.18,
                "shadow_strength": 0.12,
                "shadow_direction": Vector2(-0.85, 0.55).normalized(),
                "sun_visible": true,
                "moon_visible": false
            }
        "dusk":
            return {
                "phase": "dusk",
                "ambient": Color(0.18, 0.05, 0.014, 0.24),
                "light_color": Color("#e6a45e"),
                "light_strength": 0.46,
                "shadow_strength": 0.10,
                "shadow_direction": Vector2(0.78, 0.62).normalized(),
                "sun_visible": true,
                "moon_visible": false
            }
        "night":
            return {
                "phase": "night",
                "ambient": Color(0.008, 0.025, 0.075, 0.46),
                "light_color": Color("#efc56d"),
                "light_strength": 0.38,
                "shadow_strength": 0.04,
                "shadow_direction": Vector2(0.2, 0.98).normalized(),
                "sun_visible": false,
                "moon_visible": true
            }
        _:
            return {
                "phase": "day",
                "ambient": Color(0.01, 0.035, 0.09, 0.035),
                "light_color": Color("#f1d08c"),
                "light_strength": 0.06,
                "shadow_strength": 0.19,
                "shadow_direction": Vector2(-0.35, 0.94).normalized(),
                "sun_visible": true,
                "moon_visible": false
            }

func shadow_direction_for(value: int) -> Vector2:
    return palette_for(value).get("shadow_direction", Vector2.DOWN)

func sun_position_for(value: int, world_size: Vector2) -> Vector2:
    var minute := posmod(value, DAY_MINUTES)
    var progress := clampf((float(minute) - 6.0 * 60.0) / WORLD_MINUTES, 0.0, 1.0)
    var arc := sin(progress * PI)
    return Vector2(world_size.x * (0.14 + progress * 0.72), world_size.y * (0.16 + (1.0 - arc) * 0.44))
