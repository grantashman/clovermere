extends SceneTree

const VillageMemory = preload("res://scripts/village_memory.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var memory = VillageMemory.new()
    var state: Dictionary = memory.default_state()
    var ids: Array[String] = memory.resident_ids()
    require(ids == ["alda-fen", "tobin-wren", "orin-reed"], "Village Memory should begin with the three core residents")
    require(state.get("alda-fen", {}).get("stage", -1) == 0, "fresh resident memory should start unintroduced")

    var context := {
        "location": "village",
        "minute": 9 * 60,
        "inventory": {"timber": 0, "stone": 0, "ore": 0, "herbs": 0},
        "work_active": false
    }
    var intro: Dictionary = memory.dialogue_for("alda-fen", state, context)
    require(intro.get("stage", -1) == 0, "first Alda conversation should use the introduction stage")
    require(str(intro.get("text", "")).find("Alda") >= 0 or str(intro.get("text", "")).find("garden") >= 0, "Alda introduction should be character-specific")

    memory.mark_introduced(state, "alda-fen", 1)
    var pending: Dictionary = memory.dialogue_for("alda-fen", state, context)
    require(pending.get("stage", -1) == 1, "introduced resident should advance to the acquainted stage")
    require(pending.get("favor_id", "") == "foxglove-gathering", "Alda should offer a named herb favor")
    require(not bool(pending.get("favor_ready", false)), "favor should not be ready without its materials")
    require(pending.get("cost", {}).get("herbs", 0) == 2, "Alda favor should require two herbs")

    context["inventory"] = {"timber": 0, "stone": 0, "ore": 0, "herbs": 2}
    var ready: Dictionary = memory.dialogue_for("alda-fen", state, context)
    require(bool(ready.get("favor_ready", false)), "Alda favor should become ready when the player carries two herbs")

    context["location"] = "greenbriar-cottage"
    context["work_active"] = true
    var working: Dictionary = memory.dialogue_for("alda-fen", state, context)
    require(working.get("location", "") == "greenbriar-cottage", "dialogue should retain the current location context")
    require(str(working.get("text", "")) != str(ready.get("text", "")), "dialogue should respond to the current work state")

    var completion: Dictionary = memory.complete_favor(state, "alda-fen", 2)
    require(bool(completion.get("ok", false)), "Alda favor should complete at the trusted threshold")
    require(state.get("alda-fen", {}).get("stage", -1) == 2, "completed favor should advance the relationship stage")
    require(state.get("alda-fen", {}).get("favor_completed", false), "completed favor should persist its completion flag")
    require(completion.get("reward", {}).get("energy", 0) == 10, "Alda favor should provide a useful immediate reward")

    var encoded: Dictionary = memory.to_dict(state)
    var restored: Dictionary = memory.from_dict(encoded)
    require(restored.get("alda-fen", {}).get("stage", -1) == 2, "relationship stage should survive normalization")
    require(restored.get("alda-fen", {}).get("favor_completed", false), "favor completion should survive normalization")
    require(restored.get("tobin-wren", {}).get("stage", -1) == 0, "unmet residents should remain unintroduced after save/load")

    var day_state = preload("res://scripts/day_state.gd").new()
    day_state.inventory["herbs"] = 2
    day_state.energy = 80
    require(day_state.can_afford({"herbs": 2}), "day state should report when a favor cost is affordable")
    require(day_state.spend_materials({"herbs": 2}), "day state should spend favor materials from the field pack")
    day_state.apply_reward({"energy": 10})
    require(day_state.energy == 90, "A favor energy reward should be applied without exceeding the reserve")

    if failures.is_empty():
        print("Godot Village Memory contract: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
