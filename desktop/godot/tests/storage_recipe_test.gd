extends SceneTree

const DayState = preload("res://scripts/day_state.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var state = DayState.new()
    require(state.storage.get("timber", -1) == 0, "new journeys should have empty home stores")
    state.inventory = {"timber": 8, "stone": 4, "ore": 2, "herbs": 5}
    var deposited: Dictionary = state.deposit_inventory()
    require(int(deposited.get("timber", 0)) == 8, "deposit should report carried timber")
    require(state.inventory.get("timber", -1) == 0, "deposit should clear carried timber")
    require(state.storage.get("timber", 0) == 8, "deposit should move timber into home stores")

    state.withdraw_storage({"timber": 2, "herbs": 1})
    require(state.inventory.get("timber", 0) == 2, "withdraw should return requested timber to the field pack")
    require(state.storage.get("timber", 0) == 6, "withdraw should subtract returned timber from home stores")
    require(state.storage.get("herbs", 0) == 4, "withdraw should subtract returned herbs from home stores")

    state.withdraw_storage(state.storage.duplicate(true))
    var kit_preview: Dictionary = state.recipe_preview("tinkers-kit")
    require(bool(kit_preview.get("craftable", false)), "the Tinker’s Kit should be craftable from returned home materials")
    var kit: Dictionary = state.craft_recipe("tinkers-kit")
    require(bool(kit.get("ok", false)), "crafting the Tinker’s Kit should succeed")
    require(state.has_upgrade("tinkers-kit"), "crafting should register the Tinker’s Kit")

    var satchel_preview: Dictionary = state.recipe_preview("wayfarers-satchel")
    require(bool(satchel_preview.get("craftable", false)), "the Wayfarer’s Satchel should be craftable with the test stock")
    var satchel: Dictionary = state.craft_recipe("wayfarers-satchel")
    require(bool(satchel.get("ok", false)), "crafting the Wayfarer’s Satchel should succeed")
    require(state.has_upgrade("wayfarers-satchel"), "crafting should register the Wayfarer’s Satchel")
    require(int(state.preview_work({"kind": "tree", "yield": "timber"}).get("minutes", 0)) == 24, "the satchel should reduce work time to twenty-four minutes")

    var charm_preview: Dictionary = state.recipe_preview("hearthward-charm")
    require(not bool(charm_preview.get("craftable", true)), "the Hearthward Charm should remain unavailable without enough ore")
    state.storage["ore"] = 5
    state.withdraw_storage({"ore": 5})
    require(bool(state.recipe_preview("hearthward-charm").get("craftable", false)), "the Hearthward Charm should become craftable when the field pack is sufficient")
    require(bool(state.craft_recipe("hearthward-charm").get("ok", false)), "crafting the Hearthward Charm should succeed")
    require(state.max_energy() == 115, "the Hearthward Charm should raise maximum energy")
    require(state.energy == 100, "crafting the charm should not silently change current energy")

    state.sleep_next_day({}, [])
    var saved = state.to_dict()
    var restored = DayState.new()
    restored.from_dict(saved)
    require(restored.storage.get("timber", 0) == state.storage.get("timber", -1), "home stores should round-trip through save data")
    require(restored.has_upgrade("wayfarers-satchel"), "the satchel should round-trip through save data")
    require(restored.has_upgrade("hearthward-charm"), "the charm should round-trip through save data")
    require(restored.max_energy() == 115, "saved energy capacity upgrades should remain active")
    require(restored.energy == 115, "saved post-sleep energy should preserve the expanded reserve")

    if failures.is_empty():
        print("Godot storage/recipe contract: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
