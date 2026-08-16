extends SceneTree

const DayState = preload("res://scripts/day_state.gd")
const WorkAction = preload("res://scripts/work_action.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var state = DayState.new()
    var action = WorkAction.new()
    var herb := {"id": "foxglove-patch", "kind": "herb", "yield": "herbs", "name": "Foxglove Patch"}
    var start: Dictionary = action.start(herb, state)
    require(bool(start.get("ok", false)), "a rested player should start a herb work action")
    require(action.status == "working", "started work should enter the working state")
    require(action.progress == 0.0, "new work should begin at zero progress")
    require(state.minute_of_day == 480, "starting work should not advance the clock")
    require(state.energy == 100, "starting work should not spend energy")

    action.advance(7.5)
    require(action.progress > 0.49 and action.progress < 0.51, "partial work should report half progress")
    require(state.inventory.get("herbs", 0) == 0, "partial work should not grant materials")
    require(state.minute_of_day == 480, "partial work should not advance the clock")

    action.advance(7.5)
    require(action.status == "completed", "finishing work should enter the completed state")
    require(state.inventory.get("herbs", 0) == 2, "finishing work should grant the typed yield once")
    require(state.minute_of_day == 495, "finishing herb work should advance the clock once")
    require(state.energy == 92, "finishing herb work should spend energy once")
    action.advance(20.0)
    require(state.inventory.get("herbs", 0) == 2, "completed work should not grant duplicate materials")
    require(state.minute_of_day == 495, "completed work should not advance the clock twice")

    var cancelled_state = DayState.new()
    var cancelled = WorkAction.new()
    require(bool(cancelled.start(herb, cancelled_state).get("ok", false)), "a second player should start work")
    cancelled.advance(4.0)
    cancelled.cancel()
    require(cancelled.status == "cancelled", "cancelled work should enter the cancelled state")
    cancelled.advance(30.0)
    require(cancelled_state.inventory.get("herbs", 0) == 0, "cancelled work should grant no materials")
    require(cancelled_state.minute_of_day == 480, "cancelled work should advance no time")
    require(cancelled_state.energy == 100, "cancelled work should spend no energy")

    var tired_state = DayState.new()
    tired_state.energy = 7
    var tired = WorkAction.new()
    var blocked: Dictionary = tired.start(herb, tired_state)
    require(not bool(blocked.get("ok", true)), "insufficient energy should block work start")
    require(tired.status == "idle", "blocked work should remain idle")

    if failures.is_empty():
        print("Godot work-action contract: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
