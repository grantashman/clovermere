extends SceneTree

const Schedule = preload("res://scripts/npc_schedule.gd")
const World = preload("res://scripts/world_contract.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var world = World.new()
    var npc: Dictionary = world.npcs()[0]
    var morning: Dictionary = Schedule.resolve(npc, 8 * 60)
    var work: Dictionary = Schedule.resolve(npc, 11 * 60)
    var evening: Dictionary = Schedule.resolve(npc, 17 * 60)
    var night: Dictionary = Schedule.resolve(npc, 22 * 60)

    require(morning.get("phase", "") == "morning", "08:00 should resolve to the morning phase")
    require(morning.get("activity", "") == "opening", "morning should use opening activity")
    require(work.get("phase", "") == "work", "11:00 should resolve to the work phase")
    require(work.get("activity", "") == "gathering", "Alda Fen's work should be gathering")
    require(work.get("target", Vector2i(-1, -1)) != morning.get("target", Vector2i(-2, -2)), "work should route an NPC to a different target")
    require(evening.get("phase", "") == "evening", "17:00 should resolve to the evening phase")
    require(evening.get("activity", "") == "strolling", "evening should use strolling activity")
    require(night.get("phase", "") == "night", "22:00 should resolve to the night phase")
    require(night.get("activity", "") == "resting", "night should use resting activity")
    require(night.get("target", Vector2i(-1, -1)) == Vector2i(int(npc.x), int(npc.y)), "night should return an NPC to their home tile")

    for candidate in world.npcs():
        var decision: Dictionary = Schedule.resolve(candidate, 11 * 60)
        require(not str(decision.get("activity", "")).is_empty(), "every resident needs a work activity")
        require(decision.get("target", Vector2i(-1, -1)) is Vector2i, "every schedule decision needs a tile target")

    if failures.is_empty():
        print("Godot NPC schedule contract: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
