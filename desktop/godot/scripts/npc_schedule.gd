extends RefCounted
class_name ClovermereNpcSchedule

const World = preload("res://scripts/world_contract.gd")

const ROLE_ACTIVITIES := {
    "herbalist": "gathering",
    "waykeeper": "patrolling",
    "gardener": "tending",
    "maker": "crafting",
    "courier": "delivering",
    "keeper": "stocking"
}

const ROLE_TARGETS := {
    "herbalist": Vector2i(126, 104),
    "waykeeper": Vector2i(138, 83),
    "gardener": Vector2i(128, 99),
    "maker": Vector2i(151, 86),
    "courier": Vector2i(141, 88),
    "keeper": Vector2i(157, 105)
}

static func resolve(npc: Dictionary, minute_of_day: int) -> Dictionary:
    var safe_minute := clampi(minute_of_day, 0, 23 * 60 + 59)
    var home := Vector2i(int(npc.get("x", World.START_TILE.x)), int(npc.get("y", World.START_TILE.y)))
    var role := str(npc.get("role", "keeper"))
    var work_target: Vector2i = ROLE_TARGETS.get(role, Vector2i(World.SETTLEMENT_ORIGIN.x + 30, World.SETTLEMENT_ORIGIN.y + 11))
    if safe_minute < 6 * 60 or safe_minute >= 20 * 60:
        return {"phase": "night", "activity": "resting", "target": home}
    if safe_minute < 10 * 60:
        return {"phase": "morning", "activity": "opening", "target": home + Vector2i(2, 0)}
    if safe_minute < 16 * 60:
        return {"phase": "work", "activity": ROLE_ACTIVITIES.get(role, "working"), "target": work_target}
    if safe_minute < 20 * 60:
        var stroll_target := Vector2i(World.SETTLEMENT_ORIGIN.x + 30, World.SETTLEMENT_ORIGIN.y + 11)
        if role == "courier":
            stroll_target = Vector2i(World.SETTLEMENT_ORIGIN.x + 55, World.SETTLEMENT_ORIGIN.y + 31)
        return {"phase": "evening", "activity": "strolling", "target": stroll_target}
    return {"phase": "night", "activity": "resting", "target": home}
