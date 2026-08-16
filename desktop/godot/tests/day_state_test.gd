extends SceneTree

const DayState = preload("res://scripts/day_state.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var state = DayState.new()
    require(state.day == 1, "a new journey should begin on day one")
    require(state.minute_of_day == 480, "a new journey should begin at 08:00")
    require(state.energy == 100, "a new journey should begin with full energy")
    require(state.inventory.get("timber", 0) == 0, "a new journey should begin with empty stores")

    var timber_result: Dictionary = state.work_resource({"kind": "tree", "yield": "timber"})
    require(bool(timber_result.get("ok", false)), "a rested player should be able to chop timber")
    require(state.minute_of_day == 510, "chopping timber should advance the clock by thirty minutes")
    require(state.energy == 82, "chopping timber should spend eighteen energy")
    require(state.inventory.get("timber", 0) == 3, "chopping timber should add three timber")

    state.energy = 5
    var blocked_result: Dictionary = state.work_resource({"kind": "ore", "yield": "ore"})
    require(not bool(blocked_result.get("ok", true)), "an exhausted player should not start a costly work action")
    require(state.minute_of_day == 510, "a blocked work action should not advance the clock")
    require(state.inventory.get("ore", 0) == 0, "a blocked work action should not add materials")

    var changes := {"foxglove-patch": true, "oak-at-the-crossing": true}
    state.sleep_next_day(changes, [
        {"id": "foxglove-patch", "kind": "herb"},
        {"id": "oak-at-the-crossing", "kind": "tree"}
    ])
    require(state.day == 2, "sleeping should advance to the next day")
    require(state.minute_of_day == 480, "a new day should start at 08:00")
    require(state.energy == 100, "sleeping should restore full energy")
    require(not bool(changes.get("foxglove-patch", true)), "herbs should regrow overnight")
    require(bool(changes.get("oak-at-the-crossing", false)), "felled trees should remain cleared overnight")

    var restored = DayState.new()
    restored.from_dict(state.to_dict())
    require(restored.day == state.day, "day state should round-trip through a save dictionary")
    require(restored.minute_of_day == state.minute_of_day, "clock should round-trip through a save dictionary")
    require(restored.energy == state.energy, "energy should round-trip through a save dictionary")
    require(restored.inventory.get("timber", 0) == 3, "inventory should round-trip through a save dictionary")

    if failures.is_empty():
        print("Godot day-state contract: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
