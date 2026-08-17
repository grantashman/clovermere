extends SceneTree

const InteriorScene = preload("res://scripts/interior_scene.gd")
const Interior = preload("res://scripts/interior_contract.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _init() -> void:
    var scene = InteriorScene.new()
    get_root().add_child(scene)
    var interiors = Interior.new()
    var cottage: Dictionary = interiors.definition_for("greenbriar-cottage")
    scene.configure(cottage)

    require(scene.building_id == "greenbriar-cottage", "interior renderer should retain its building id")
    require(scene.interior_size == Vector2i(18, 12), "Cottage renderer should use the contract interior size")
    require(scene.has_method("interaction_world_position"), "interior renderer should expose furniture positions")
    require(scene.has_method("exit_world_position"), "interior renderer should expose its exit position")
    require(scene.interaction_world_position("hearth") == Vector2(4.5, 5.5) * interiors.TILE_SIZE, "hearth should have an authored world position")
    require(scene.exit_world_position() == Vector2(9.5, 10.5) * interiors.TILE_SIZE, "exit should have an authored world position")
    require(scene.render_palette().has("wall"), "interior renderer should expose a locked wall palette")
    require(scene.render_palette().has("floor"), "interior renderer should expose a locked floor palette")
    require(scene.render_palette().has("accent"), "interior renderer should expose an accent palette")

    scene.configure(interiors.definition_for("tinker-workshop"))
    require(scene.building_id == "tinker-workshop", "renderer should switch between authored interiors")
    require(scene.interaction_world_position("workbench") == Vector2(7.5, 5.5) * interiors.TILE_SIZE, "workbench should have an authored world position")
    require(scene.furniture_ids().has("forge"), "workshop should expose a forge render element")

    if failures.is_empty():
        print("Godot interior renderer contract: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
