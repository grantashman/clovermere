extends SceneTree

const World = preload("res://scripts/world_contract.gd")
const Overlay = preload("res://scripts/procedural_resource_overlay.gd")

func _initialize() -> void:
    var world = World.new()
    var overlay = Overlay.new()
    get_root().add_child(overlay)
    overlay.configure(world, {"name": "Clovermere", "landscape": "heath"}, {})
    if overlay.resource_count < 50:
        push_error("procedural overlay should mount distant generated resources")
        quit(1)
        return
    if overlay.resource_sprites.is_empty():
        push_error("procedural overlay should mount authored tree sprites for generated trees")
        quit(1)
        return
    if not overlay.visible:
        push_error("procedural resource overlay should be visible in the exterior")
        quit(1)
        return
    print("Godot procedural resource overlay: PASS")
    quit(0)
