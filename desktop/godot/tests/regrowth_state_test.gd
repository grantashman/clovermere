extends SceneTree

const DayState = preload("res://scripts/day_state.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var state = DayState.new()
    var changes := {"birch-by-the-lane": false}
    var states: Dictionary = {}
    var tree := {"id": "birch-by-the-lane", "kind": "tree", "yield": "timber"}
    var stone := {"id": "greycap-boulder", "kind": "stone", "yield": "stone"}
    var ore := {"id": "ironroot-vein", "kind": "ore", "yield": "ore"}
    var herb := {"id": "foxglove-patch", "kind": "herb", "yield": "herbs"}

    state.mark_resource_cleared(tree, changes, states, 1)
    require(bool(changes["birch-by-the-lane"]), "cleared tree should preserve the legacy world-change flag")
    require(states["birch-by-the-lane"].get("stage", "") == "felled", "tree should begin in the felled regrowth stage")
    require(int(states["birch-by-the-lane"].get("days_remaining", 0)) == 3, "tree should have a three-day recovery budget")

    state.advance_regrowth(changes, states, [tree], 2)
    require(states["birch-by-the-lane"].get("stage", "") == "sprout", "tree should enter sprout stage after the first recovery day")
    require(int(states["birch-by-the-lane"].get("days_remaining", 0)) == 2, "tree sprout should retain two recovery days")
    state.advance_regrowth(changes, states, [tree], 3)
    require(states["birch-by-the-lane"].get("stage", "") == "young", "tree should enter young stage before restoration")
    state.advance_regrowth(changes, states, [tree], 4)
    require(not bool(changes["birch-by-the-lane"]), "tree should become interactable when recovery completes")
    require(not states.has("birch-by-the-lane"), "restored tree should clear its transient state")

    state.mark_resource_cleared(stone, changes, states, 4)
    state.mark_resource_cleared(ore, changes, states, 4)
    require(states["greycap-boulder"].get("stage", "") == "depleted", "stone should begin depleted")
    require(states["ironroot-vein"].get("stage", "") == "depleted", "ore should begin depleted")
    state.advance_regrowth(changes, states, [stone, ore], 5)
    require(states["greycap-boulder"].get("stage", "") == "fractures", "stone should expose fractures during recovery")
    require(states["ironroot-vein"].get("stage", "") == "crystals", "ore should expose crystals during recovery")
    state.advance_regrowth(changes, states, [stone, ore], 6)
    require(not bool(changes["greycap-boulder"]), "stone should restore after two recovery days")
    require(not bool(changes["ironroot-vein"]), "ore should restore after two recovery days")

    state.mark_resource_cleared(herb, changes, states, 6)
    state.advance_regrowth(changes, states, [herb], 7)
    require(not bool(changes["foxglove-patch"]), "herbs should remain next-day regrowth compatible")
    require(not states.has("foxglove-patch"), "herb recovery should not leave stale state")

    if failures.is_empty():
        print("Godot regrowth-state contract: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Godot regrowth-state contract: FAIL (%d)" % failures.size())
    quit(1)
