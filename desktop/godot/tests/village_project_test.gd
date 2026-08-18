extends SceneTree

const VillageProject = preload("res://scripts/village_project.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var project = VillageProject.new()
    var state: Dictionary = project.default_state()
    require(project.project_id() == "village-commons", "the shared project should have a stable id")
    require(project.stage_count() == 3, "the shared project should have three authored stages")
    require(project.current_stage(state).get("id", "") == "foundation", "a new project should begin at foundation")

    var inventory := {"timber": 5, "stone": 3, "ore": 0, "herbs": 0, "fish": 0}
    var blocked: Dictionary = project.contribute(state, inventory, 1)
    require(not bool(blocked.get("ok", false)), "foundation should wait for a resident/request support point")
    project.record_support(state, "request", "garden-tonic")
    require(project.support_points(state) == 1, "request support should contribute to the shared project")
    var foundation: Dictionary = project.contribute(state, inventory, 1)
    require(bool(foundation.get("ok", false)), "foundation should accept materials after support exists")
    require(state.get("stage", -1) == 1, "foundation contribution should advance the project")
    require(inventory.get("timber", -1) == 0 and inventory.get("stone", -1) == 0, "foundation should consume exact materials")

    var duplicate_support: bool = project.record_support(state, "request", "garden-tonic")
    require(not duplicate_support, "the same request should not support the project twice")
    project.record_support(state, "favor", "alda-fen")
    var shelter_inventory := {"timber": 4, "stone": 0, "ore": 2, "herbs": 0, "fish": 0}
    var shelter: Dictionary = project.contribute(state, shelter_inventory, 2)
    require(bool(shelter.get("ok", false)), "shelter should accept its stage materials")
    require(state.get("stage", -1) == 2, "shelter contribution should advance the project")

    project.record_support(state, "request", "forge-supply")
    project.record_support(state, "request", "river-baskets")
    var finish_inventory := {"timber": 0, "stone": 0, "ore": 0, "herbs": 3, "fish": 1}
    var finished: Dictionary = project.contribute(state, finish_inventory, 3)
    require(bool(finished.get("ok", false)), "the final project stage should accept its materials")
    require(project.is_complete(state), "the shared project should become complete")
    require(project.consequence_flags(state).get("commons_complete", false), "completion should expose a visible commons consequence")

    var restored: Dictionary = project.from_dict(project.to_dict(state))
    require(project.is_complete(restored), "project completion should survive save/load normalization")
    require(project.support_points(restored) == 4, "support history should survive save/load normalization")

    if failures.is_empty():
        print("Godot Village Project contract: PASS")
        quit(0)
        return
    print("Godot Village Project contract: FAIL (%d)" % failures.size())
    for failure in failures:
        print(" - ", failure)
    quit(1)
