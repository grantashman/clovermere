extends SceneTree

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    get_root().add_child(scene)
    await create_timer(0.9).timeout

    require(scene.gameplay_hud != null, "gameplay should expose a dedicated PC HUD layer")
    require(scene.gameplay_hud.minimap != null, "gameplay HUD should expose a minimap")
    require(scene.gameplay_hud.pack_button != null, "gameplay HUD should expose a pack shortcut")
    require(scene.gameplay_hud.craft_button != null, "gameplay HUD should expose a craft shortcut")
    require(scene.gameplay_hud.status_panel.size.y <= 120.0, "persistent status HUD should stay compact")
    require(scene.gameplay_hud.action_bar != null, "gameplay HUD should expose a centered quickslot bar")
    require(scene.gameplay_hud.location_panel != null, "gameplay HUD should expose a lightweight location ribbon")
    require(scene.gameplay_hud.action_bar.position.x > 300.0, "quickslot bar should be centered rather than pinned to the lower-left")
    require(scene.gameplay_hud.management_panel.position.x >= 860.0, "management drawer should remain an optional side surface")
    require(scene.gameplay_hud.layer > scene.ui.layer, "dialogue HUD should render above transient UI toasts")
    require(scene.ui.has_method("dismiss_toast"), "UI shell should expose transient-toast dismissal for modal dialogue")
    require(scene.gameplay_hud.has_method("set_interior_mode"), "gameplay HUD should expose an interior mode")
    require(not scene.gameplay_hud.management_panel.visible, "management panel should be hidden until requested")

    scene._start_new_journey()
    scene.interaction_message = "Entering Cottage"
    scene.gameplay_hud.interaction_label.text = "Entering Cottage"
    scene.gameplay_hud.interaction_panel.visible = true
    scene.gameplay_hud.open_pack()
    require(scene.interaction_message.is_empty(), "opening a management surface should clear the source interaction message")
    require(not scene.gameplay_hud.interaction_panel.visible, "opening a management surface should clear the interaction banner")
    require(scene.gameplay_hud.management_panel.visible, "pack command should open the management panel")
    require(scene.gameplay_hud.management_mode == "pack", "pack command should select the pack tab")
    scene.gameplay_hud.open_crafting()
    require(scene.gameplay_hud.management_mode == "craft", "craft command should select the craft tab")
    scene.gameplay_hud.open_cooking()
    require(scene.gameplay_hud.management_mode == "cook", "cooking command should select the hearth tab")
    require(scene.gameplay_hud.has_signal("meal_requested"), "cooking HUD should expose meal eating")
    require(scene.gameplay_hud.management_content.get_child_count() >= 3, "cooking HUD should show Hearth Tea and the two meal recipes")
    scene.gameplay_hud.show_dialogue("Alda Fen", "A quiet line.")
    require(not scene.gameplay_hud.interaction_panel.visible, "dialogue should clear the interaction banner")
    scene.gameplay_hud.hide_dialogue()
    scene.gameplay_hud.close_management()
    require(not scene.gameplay_hud.management_panel.visible, "management panel should close cleanly")

    if failures.is_empty():
        print("Godot gameplay HUD contract: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
