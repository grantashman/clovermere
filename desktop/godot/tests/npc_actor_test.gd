extends SceneTree

const Actor = preload("res://scripts/npc_actor.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var actor = Actor.new()
    actor.set_npc({
        "id": "alda-fen",
        "name": "Alda Fen",
        "role": "herbalist",
        "skin": "#d6a27a",
        "hair": "#563d32",
        "coat": "#7d8f5b",
        "accent": "#d6b36d"
    })
    actor.position = Vector2(1.5, 1.5) * 16.0
    actor.set_activity("gathering")
    actor.set_route([Vector2i(2, 1), Vector2i(3, 1)])
    require(actor.activity == "gathering", "actor should expose its current work activity")
    require(actor.cast_shadow, "live NPC actors should cast directional shadows")
    require(actor.shadow_offset.x > 0.0 and actor.shadow_offset.y > 0.0, "actor shadow should be offset toward the light direction")
    require(actor.step_phase == 0.0, "new actors should begin at a stable animation phase")
    var moved: bool = actor.advance_navigation(0.2, 16.0, 2.0)
    require(moved, "an actor with a route should advance")
    require(actor.position.x > 24.0, "actor movement should follow the route in world pixels")
    require(actor.route.size() == 2, "partial route movement should preserve remaining route tiles")
    actor.set_activity("resting")
    require(actor.activity == "resting", "actor activity should change when schedule phase changes")

    actor.free()
    if failures.is_empty():
        print("Godot NPC actor contract: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
