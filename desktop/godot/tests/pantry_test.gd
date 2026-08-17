extends SceneTree

const DayState = preload("res://scripts/day_state.gd")
const Interior = preload("res://scripts/interior_contract.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var state = DayState.new()
    state.energy = 60
    state.inventory = {"timber": 1, "stone": 0, "ore": 0, "herbs": 2}
    require(state.cooking_ids() == ["hearth-tea"], "Cottage pantry should expose the Hearth Tea recipe")
    var preview: Dictionary = state.cooking_preview("hearth-tea")
    require(bool(preview.get("craftable", false)), "Hearth Tea should be craftable from two herbs and one timber")
    require(preview.get("cost", {}).get("herbs", 0) == 2, "Hearth Tea should require two herbs")
    require(preview.get("energy", 0) == 25, "Hearth Tea should restore twenty-five energy")
    var cooked: Dictionary = state.cook_recipe("hearth-tea")
    require(bool(cooked.get("ok", false)), "Hearth Tea cooking should succeed")
    require(state.energy == 85, "Hearth Tea should restore energy without exceeding the reserve")
    require(state.minute_of_day == 8 * 60 + 10, "Cooking should take ten in-game minutes")
    require(state.inventory.get("herbs", 0) == 0 and state.inventory.get("timber", 0) == 0, "Cooking should consume its field-pack ingredients")
    require(not bool(state.cook_recipe("hearth-tea").get("ok", false)), "Cooking should fail when ingredients are missing")

    var saved: Dictionary = state.to_dict()
    var restored = DayState.new()
    restored.from_dict(saved)
    require(restored.energy == 85, "cooking energy should survive save/load")
    require(restored.minute_of_day == 8 * 60 + 10, "cooking time should survive save/load")

    var interiors = Interior.new()
    require("pantry" in interiors.interaction_ids("greenbriar-cottage"), "Cottage should expose a pantry interaction")
    require(interiors.interaction_at("greenbriar-cottage", Vector2i(12, 7)).get("action", "") == "cook", "pantry interaction should use the cooking action")

    if failures.is_empty():
        print("Godot Hearth Pantry contract: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
