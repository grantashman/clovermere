extends SceneTree

const GameplayHud = preload("res://scripts/gameplay_hud.gd")
const HudArt = preload("res://scripts/hud_art.gd")
const ResourceSlot = preload("res://scripts/hud_resource_slot.gd")
const HudButton = preload("res://scripts/hud_button.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var hud = GameplayHud.new()
    require(hud.has_method("set_active_surface"), "HUD should expose active-surface state")
    require(hud.has_method("set_hud_frame_state"), "HUD should expose authored frame state")
    require(hud.has_signal("project_action"), "HUD should expose village project actions")
    hud.set_active_surface("project")
    require(hud.management_mode == "project", "HUD should support the village project surface")
    require(hud.has_method("resource_slot_kinds"), "HUD should expose icon-led resource slot kinds")
    require(hud.resource_slot_kinds() == ["timber", "stone", "ore", "herbs", "fish"], "HUD resource order should be stable")

    var art = HudArt.new()
    require(art.has_method("frame_kinds"), "HUD art should expose authored frame families")
    require(art.frame_kinds().has("status"), "HUD art should define a status frame")
    require(art.frame_kinds().has("management"), "HUD art should define a management frame")
    require(art.frame_kinds().has("action"), "HUD art should define an action frame")

    var slot = ResourceSlot.new()
    require(slot.has_method("set_resource"), "resource slot should accept resource state")
    slot.set_resource("fish", 7, 3)
    require(slot.resource_kind == "fish", "resource slot should preserve its resource kind")
    require(slot.amount == 7, "resource slot should preserve carried amount")
    require(slot.stored_amount == 3, "resource slot should preserve stored amount")

    var button = HudButton.new()
    require(button.has_method("set_glyph"), "HUD button should expose authored glyphs")
    require(button.has_method("set_active"), "HUD button should expose active state")
    button.set_glyph("pack")
    button.set_active(true)
    require(button.glyph == "pack", "HUD button should preserve glyph identity")
    require(button.active, "HUD button should preserve active state")

    hud.free()
    art.free()
    slot.free()
    button.free()
    if failures.is_empty():
        print("Godot HUD presentation contract: PASS")
        quit(0)
        return
    print("Godot HUD presentation contract: FAIL (%d)" % failures.size())
    for failure in failures:
        print(" - ", failure)
    quit(1)
