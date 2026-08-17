extends SceneTree

const Interior = preload("res://scripts/interior_contract.gd")
const World = preload("res://scripts/world_contract.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _init() -> void:
    var interiors = Interior.new()
    var world = World.new()

    require(interiors.location_ids().has("greenbriar-cottage"), "Cottage should expose an enterable interior")
    require(interiors.location_ids().has("tinker-workshop"), "Workshop should expose an enterable interior")
    require(interiors.transition_seconds() > 0.0, "interior entry should have a non-zero transition")

    for building_id in ["greenbriar-cottage", "tinker-workshop"]:
        var definition: Dictionary = interiors.definition_for(building_id)
        require(not definition.is_empty(), "%s should have an interior definition" % building_id)
        require(int(definition.get("width", 0)) >= 16, "%s should have a readable interior width" % building_id)
        require(int(definition.get("height", 0)) >= 10, "%s should have a readable interior height" % building_id)
        var grid: Array = interiors.build_grid(building_id)
        require(grid.size() == int(definition.height), "%s grid height should match its definition" % building_id)
        require(grid[0].size() == int(definition.width), "%s grid width should match its definition" % building_id)
        require(not interiors.is_walkable(grid, Vector2i(0, 0)), "%s wall corners should be blocked" % building_id)
        var spawn: Vector2 = interiors.spawn_position(building_id)
        require(interiors.is_walkable(grid, Vector2i(floori(spawn.x), floori(spawn.y))), "%s spawn should be walkable" % building_id)
        require(interiors.is_walkable(grid, interiors.exit_tile(building_id)), "%s exit should be walkable" % building_id)
        require(not interiors.interaction_ids(building_id).is_empty(), "%s should expose useful interaction points" % building_id)

    require(interiors.interaction_at("greenbriar-cottage", Vector2i(4, 5)).get("id", "") == "hearth", "Cottage should expose a hearth interaction")
    require(interiors.interaction_at("greenbriar-cottage", Vector2i(8, 9)).get("id", "") == "storage-chest", "Cottage should expose a storage chest")
    require(interiors.interaction_at("tinker-workshop", Vector2i(7, 5)).get("id", "") == "workbench", "Workshop should expose a workbench")
    require(interiors.interaction_at("tinker-workshop", Vector2i(11, 5)).get("id", "") == "forge", "Workshop should expose a forge")

    var legacy: Dictionary = world.normalize_save({"version": 7, "player": {"x": World.START_POSITION.x, "y": World.START_POSITION.y}})
    require(legacy.get("location", "") == "village", "legacy saves should remain outside after normalization")
    require(legacy.get("interior", {}) is Dictionary, "legacy saves should gain an empty interior state")
    var enter_state: Dictionary = interiors.enter_state("greenbriar-cottage")
    require(enter_state.get("location", "") == "greenbriar-cottage", "entering should identify the interior location")
    require(enter_state.get("transition", "") == "enter", "entering should begin an enter transition")
    var exit_state: Dictionary = interiors.exit_state()
    require(exit_state.get("location", "") == "village", "exiting should return to the village")
    require(exit_state.get("transition", "") == "exit", "exiting should begin an exit transition")

    var alda_dialogue: Dictionary = interiors.dialogue_for("alda-fen", "village", 9 * 60)
    require(not alda_dialogue.is_empty(), "Alda should have contextual dialogue")
    require(str(alda_dialogue.get("speaker", "")) == "Alda Fen", "dialogue should identify the speaker")
    require(not str(alda_dialogue.get("text", "")).is_empty(), "dialogue should provide readable text")

    if failures.is_empty():
        print("Godot interior contract: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
