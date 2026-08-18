extends SceneTree

const DayState = preload("res://scripts/day_state.gd")
const VillageMemory = preload("res://scripts/village_memory.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var state = DayState.new()
    state.energy = 50
    state.inventory = {"timber": 1, "stone": 0, "ore": 0, "herbs": 1, "fish": 2}
    require(state.cooking_ids().has("riverside-stew"), "the pantry should expose a fish-based Riverside Stew")
    require(state.cooking_ids().has("garden-chowder"), "the pantry should expose an herb-and-fish Garden Chowder")

    var stew_preview: Dictionary = state.cooking_preview("riverside-stew")
    require(bool(stew_preview.get("craftable", false)), "Riverside Stew should be craftable from fish and timber")
    require(stew_preview.get("cost", {}).get("fish", 0) == 1, "Riverside Stew should require one fish")
    require(stew_preview.get("meal_id", "") == "riverside-stew", "Riverside Stew should produce a meal inventory item")
    var stew: Dictionary = state.cook_recipe("riverside-stew")
    require(bool(stew.get("ok", false)), "Riverside Stew cooking should succeed")
    require(state.meals.get("riverside-stew", 0) == 1, "cooking should add Riverside Stew to meal inventory")
    require(state.energy == 50, "cooking a meal should not consume energy before eating")

    var eat: Dictionary = state.eat_meal("riverside-stew")
    require(bool(eat.get("ok", false)), "Riverside Stew should be edible")
    require(state.meals.get("riverside-stew", 0) == 0, "eating should consume the meal item")
    require(state.energy == 80, "Riverside Stew should restore thirty energy")
    require(state.next_work_effects.get("energy_discount", 0.0) == 0.15, "Riverside Stew should reduce the next work energy cost")

    var work_preview: Dictionary = state.preview_work({"kind": "tree", "yield": "timber"})
    require(work_preview.get("energy", 0) == 15, "Riverside Stew should reduce the next tree work energy cost")
    state.work_resource({"kind": "tree", "yield": "timber"})
    require(state.next_work_effects.get("uses", 0) == 0, "the meal work effect should be consumed by one completed work action")
    require(state.preview_work({"kind": "tree", "yield": "timber"}).get("energy", 0) == 18, "base work energy should return after the meal effect is consumed")

    var chowder_preview: Dictionary = state.cooking_preview("garden-chowder")
    require(bool(chowder_preview.get("craftable", false)), "Garden Chowder should be craftable from fish and herbs")
    var chowder: Dictionary = state.cook_recipe("garden-chowder")
    require(bool(chowder.get("ok", false)), "Garden Chowder cooking should succeed")
    require(state.meals.get("garden-chowder", 0) == 1, "Garden Chowder should be stored as a meal")
    require(bool(state.eat_meal("garden-chowder").get("ok", false)), "Garden Chowder should be edible")
    require(state.next_work_effects.get("minutes_discount", 0.0) == 0.2, "Garden Chowder should shorten the next work action")
    require(state.preview_work({"kind": "tree", "yield": "timber"}).get("minutes", 0) == 24, "Garden Chowder should reduce tree work time to twenty-four minutes")

    var saved: Dictionary = state.to_dict()
    var restored = DayState.new()
    restored.from_dict(saved)
    require(restored.meals == state.meals, "meal inventory should survive save/load")
    require(restored.next_work_effects == state.next_work_effects, "meal effects should survive save/load")

    var memory = VillageMemory.new()
    var resident_state: Dictionary = memory.default_state()
    memory.mark_introduced(resident_state, "orin-reed", 1)
    var dialogue: Dictionary = memory.dialogue_for("orin-reed", resident_state, {"minute": 12 * 60, "day": 1, "inventory": {"fish": 1}})
    require(str(dialogue.get("text", "")).to_lower().find("fish") >= 0, "Orin should notice fish carried from the water")

    if failures.is_empty():
        print("Godot Food and Fishing contract: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
