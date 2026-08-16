extends SceneTree

const DayState = preload("res://scripts/day_state.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var state = DayState.new()
    state.inventory = {"timber": 3, "stone": 2, "ore": 1, "herbs": 0}
    var before: Dictionary = state.preview_work({"kind": "tree", "yield": "timber"})
    var purchase: Dictionary = state.purchase_upgrade("tinkers-kit")
    require(bool(purchase.get("ok", false)), "the Tinker’s Kit should be purchasable with its exact materials")
    require(state.has_upgrade("tinkers-kit"), "purchasing the kit should record the upgrade")
    require(state.inventory.get("timber", 0) == 0, "the kit should consume three timber")
    require(state.inventory.get("stone", 0) == 0, "the kit should consume two stone")
    require(state.inventory.get("ore", 0) == 0, "the kit should consume one ore")
    var after: Dictionary = state.preview_work({"kind": "tree", "yield": "timber"})
    require(int(before.get("energy", 0)) == 18, "the base timber energy cost should remain eighteen")
    require(int(after.get("energy", 0)) == 14, "the Tinker’s Kit should reduce timber energy cost to fourteen")
    state.energy = 14
    require(bool(state.preview_work({"kind": "tree", "yield": "timber"}).get("ok", false)), "the reduced cost should allow work with fourteen energy")
    var duplicate: Dictionary = state.purchase_upgrade("tinkers-kit")
    require(not bool(duplicate.get("ok", true)), "the Tinker’s Kit should not be purchasable twice")

    var restored = DayState.new()
    restored.from_dict(state.to_dict())
    require(restored.has_upgrade("tinkers-kit"), "the workshop upgrade should round-trip through save data")
    require(int(restored.preview_work({"kind": "tree", "yield": "timber"}).get("energy", 0)) == 14, "the saved upgrade should retain its work effect")

    var legacy = DayState.new()
    legacy.from_dict({"day": 4, "minute_of_day": 600, "energy": 80, "inventory": {"timber": 2}})
    require(not legacy.has_upgrade("tinkers-kit"), "schema-6 day state without upgrades should default safely")
    require(legacy.inventory.get("timber", 0) == 2, "legacy inventory should remain readable")

    var scene: Node = load("res://scenes/main.tscn").instantiate()
    get_root().add_child(scene)
    await create_timer(0.9).timeout
    scene._start_new_journey()
    scene.day_state.inventory = {"timber": 3, "stone": 2, "ore": 1, "herbs": 0}
    var workshop: Dictionary = {}
    for building_variant in scene.world.buildings():
        if str(building_variant.get("id", "")) == "tinker-workshop":
            workshop = building_variant
    var workshop_tile := Vector2i(int(workshop.x) + int(workshop.w) / 2, int(workshop.y) + int(workshop.h) + 1)
    var workshop_approach: Vector2i = scene.world.nearest_walkable(scene.grid, workshop_tile, 4)
    scene.player_position = Vector2(workshop_approach) + Vector2(0.5, 0.5)
    scene._refresh_player_transform()
    scene.command_interact_with_building("tinker-workshop")
    scene._handle_resource_action()
    require(scene.day_state.has_upgrade("tinkers-kit"), "E at the Tinker Workshop should purchase the kit")
    require(scene.interaction_message.contains("Tinker"), "the workshop should report the purchased upgrade")
    require(scene._save_game(), "the workshop upgrade should save through the journey ledger")
    scene.day_state.upgrades.clear()
    require(scene._load_save(), "the workshop upgrade should reload through the journey ledger")
    require(scene.day_state.has_upgrade("tinkers-kit"), "loading should restore the workshop upgrade")

    if failures.is_empty():
        print("Godot workshop upgrade contract: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
