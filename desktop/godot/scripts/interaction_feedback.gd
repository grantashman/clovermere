extends Node2D
class_name ClovermereInteractionFeedback

var action_label := ""
var progress := 0.0
var impact_flash := 0.0
var completion_kind := ""
var elapsed := 0.0

func begin_action(action, world_position: Vector2) -> void:
    action_label = _label_for(str(action.resource.get("kind", "resource")))
    progress = 0.0
    impact_flash = 0.0
    completion_kind = ""
    global_position = world_position
    visible = true
    queue_redraw()

func update_action(action, world_position: Vector2) -> void:
    if action == null:
        return
    progress = clampf(float(action.progress), 0.0, 1.0)
    global_position = world_position
    visible = true
    queue_redraw()

func complete_action(resource: Dictionary, world_position: Vector2) -> void:
    action_label = ""
    progress = 1.0
    completion_kind = str(resource.get("kind", "resource"))
    impact_flash = 0.45
    global_position = world_position
    visible = true
    queue_redraw()

func clear_action() -> void:
    action_label = ""
    progress = 0.0
    if impact_flash <= 0.0:
        visible = false
    queue_redraw()

func _process(delta: float) -> void:
    elapsed += delta
    if impact_flash > 0.0:
        impact_flash = maxf(0.0, impact_flash - delta)
        if impact_flash <= 0.0 and action_label.is_empty():
            visible = false
    if visible:
        queue_redraw()

func _draw() -> void:
    if not action_label.is_empty():
        draw_rect(Rect2(-42, -35, 84, 7), Color("#162a22"), true)
        draw_rect(Rect2(-40, -33, 80 * progress, 3), Color("#f0d487"), true)
        var swing := sin(elapsed * 15.0) * 5.0
        draw_line(Vector2(11 + swing, -8), Vector2(22 + swing, 8), Color("#b98357"), 2.0, false)
        draw_line(Vector2(22 + swing, 8), Vector2(28 + swing, 8), Color("#e2c187"), 2.0, false)
    if impact_flash > 0.0:
        var alpha := clampf(impact_flash / 0.45, 0.0, 1.0)
        var radius := 8.0 + (1.0 - alpha) * 7.0
        var effect_color := Color("#f0d487") if completion_kind in ["tree", "stone", "ore"] else Color("#d5e39b")
        for index in range(6):
            var angle := float(index) * TAU / 6.0
            var start := Vector2.from_angle(angle) * 3.0
            var finish := Vector2.from_angle(angle) * radius
            draw_line(start, finish, Color(effect_color, alpha), 2.0, false)

func _label_for(kind: String) -> String:
    if kind == "tree":
        return "CHOPPING TIMBER"
    if kind == "stone":
        return "MINING STONE"
    if kind == "ore":
        return "MINING ORE"
    if kind == "herb":
        return "GATHERING HERBS"
    return "WORKING"
