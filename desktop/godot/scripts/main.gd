extends Node2D

const World = preload("res://scripts/world_contract.gd")
const WorldView = preload("res://scripts/world_view.gd")
const PlayerAvatar = preload("res://scripts/player_avatar.gd")
const TargetMarker = preload("res://scripts/target_marker.gd")

const SAVE_PATH := "user://hobbit-moon-village-v2.json"
const DEFAULT_VILLAGE := {"name": "Moonrise Hollow", "landscape": "heath"}
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1

var world = World.new()
var world_cache: SubViewport
var world_sprite: Sprite2D
var world_view: Node2D
var player: Node2D
var target_marker: Node2D
var camera: Camera2D
var grid: Array = []
var village: Dictionary = DEFAULT_VILLAGE.duplicate(true)
var player_position := World.START_POSITION
var camera_zoom := 0.75
var debug_visible := false
var save_elapsed := 0.0
var title_label: Label
var subtitle_label: Label
var debug_label: Label
var hint_label: Label
var loading_overlay: ColorRect
var interaction_panel: ColorRect
var interaction_label: Label
var movement_path: Array = []
var pending_building: Dictionary = {}
var interaction_message := ""
var interaction_timeout := 0.0

func _ready() -> void:
    grid = world.build_grid(village)
    _load_save()
    _build_world_cache()
    camera = Camera2D.new()
    camera.position_smoothing_enabled = false
    camera.zoom = Vector2(camera_zoom, camera_zoom)
    add_child(camera)
    player = PlayerAvatar.new()
    player.scale = Vector2(1.55, 1.55)
    player.z_index = 20
    add_child(player)
    player.position = player_position * World.TILE_SIZE
    camera.position = player.position
    camera.make_current()
    camera.reset_smoothing()
    _build_hud()
    _refresh_hud()
    call_deferred("_finish_loading")

func _finish_loading() -> void:
    await RenderingServer.frame_post_draw
    await get_tree().process_frame
    if loading_overlay != null:
        loading_overlay.visible = false

func _build_world_cache() -> void:
    world_cache = SubViewport.new()
    world_cache.name = "StaticWorldCache"
    world_cache.size = Vector2i(int(world.WORLD_WIDTH * World.TILE_SIZE), int(world.WORLD_HEIGHT * World.TILE_SIZE))
    world_cache.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
    world_cache.render_target_update_mode = SubViewport.UPDATE_ONCE
    world_cache.transparent_bg = false
    world_cache.handle_input_locally = false
    add_child(world_cache)

    world_view = WorldView.new()
    world_cache.add_child(world_view)
    world_view.configure(world, grid, village, null)

    world_sprite = Sprite2D.new()
    world_sprite.name = "StaticWorldTexture"
    world_sprite.texture = world_cache.get_texture()
    world_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    world_sprite.position = Vector2(world_cache.size) * 0.5
    world_sprite.z_index = -10
    add_child(world_sprite)

    target_marker = TargetMarker.new()
    target_marker.z_index = 8
    target_marker.visible = false
    add_child(target_marker)

func _process(delta: float) -> void:
    var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var next_position := player_position
    if direction.length_squared() > 0.0001:
        movement_path.clear()
        pending_building = {}
        target_marker.clear_target()
        next_position = world.move_player(player_position, direction, delta, grid)
    elif not movement_path.is_empty():
        var next_tile: Vector2i = movement_path[0]
        var destination := Vector2(next_tile) + Vector2(0.5, 0.5)
        if player_position.distance_to(destination) < 0.11:
            player_position = destination
            next_position = player_position
            movement_path.pop_front()
            if movement_path.is_empty() and not pending_building.is_empty():
                _complete_building_interaction()
        else:
            next_position = world.move_player(player_position, player_position.direction_to(destination), delta, grid, 5.0)
    if next_position != player_position:
        player_position = next_position
        player.position = player_position * World.TILE_SIZE
    camera.position = player.position
    save_elapsed += delta
    if save_elapsed >= 2.0:
        save_elapsed = 0.0
        _save_game()
    if Input.is_action_just_pressed("zoom_in"):
        _set_zoom(camera_zoom + ZOOM_STEP)
    if Input.is_action_just_pressed("zoom_out"):
        _set_zoom(camera_zoom - ZOOM_STEP)
    if Input.is_action_just_pressed("toggle_debug"):
        debug_visible = not debug_visible
        debug_label.visible = debug_visible
    if interaction_timeout > 0.0:
        interaction_timeout = maxf(0.0, interaction_timeout - delta)
        if interaction_timeout <= 0.0:
            interaction_message = ""
    _refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F11:
            get_window().mode = Window.MODE_FULLSCREEN if get_window().mode != Window.MODE_FULLSCREEN else Window.MODE_WINDOWED
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            _handle_world_click(get_global_mouse_position())
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            _handle_context_click(get_global_mouse_position())
        elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _set_zoom(camera_zoom + ZOOM_STEP)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _set_zoom(camera_zoom - ZOOM_STEP)

func _handle_world_click(world_position: Vector2) -> void:
    var tile := Vector2i(floori(world_position.x / World.TILE_SIZE), floori(world_position.y / World.TILE_SIZE))
    var building := world.building_at(tile)
    if not building.is_empty():
        _queue_building_interaction(building)
        return
    var goal := world.nearest_walkable(grid, tile, 10)
    _queue_path_to(goal, {})

func _handle_context_click(world_position: Vector2) -> void:
    var tile := Vector2i(floori(world_position.x / World.TILE_SIZE), floori(world_position.y / World.TILE_SIZE))
    var building := world.building_at(tile)
    if building.is_empty():
        movement_path.clear()
        pending_building = {}
        target_marker.clear_target()
        interaction_message = "Target cleared"
        interaction_timeout = 1.5
        return
    _queue_building_interaction(building)

func _queue_building_interaction(building: Dictionary) -> void:
    var candidates := [
        Vector2i(int(building.x) + int(building.w) / 2, int(building.y) + int(building.h) + 1),
        Vector2i(int(building.x) + int(building.w) / 2, int(building.y) - 1),
        Vector2i(int(building.x) - 1, int(building.y) + int(building.h) / 2),
        Vector2i(int(building.x) + int(building.w), int(building.y) + int(building.h) / 2)
    ]
    candidates = candidates.filter(func(candidate: Vector2i): return world.is_walkable(grid, candidate))
    candidates.sort_custom(func(a: Vector2i, b: Vector2i): return player_position.distance_squared_to(Vector2(a) + Vector2(0.5, 0.5)) < player_position.distance_squared_to(Vector2(b) + Vector2(0.5, 0.5)))
    if candidates.is_empty():
        interaction_message = "No clear approach to %s" % str(building.get("name", "that place"))
        interaction_timeout = 2.0
        return
    pending_building = building
    _queue_path_to(candidates[0], building)

func _queue_path_to(goal: Vector2i, building: Dictionary) -> void:
    var start := Vector2i(floori(player_position.x), floori(player_position.y))
    var route: Array = world.find_path(grid, start, goal)
    if route.is_empty() and start != goal:
        interaction_message = "That way is blocked"
        interaction_timeout = 2.0
        return
    movement_path = route
    pending_building = building
    target_marker.set_target((Vector2(goal) + Vector2(0.5, 0.5)) * World.TILE_SIZE)
    if building.is_empty():
        interaction_message = "Walking to marked ground"
    else:
        interaction_message = "Walking to %s" % str(building.get("name", "building"))
    interaction_timeout = 0.0
    _show_interaction_feedback()
    if movement_path.is_empty() and not pending_building.is_empty():
        _complete_building_interaction()

func _complete_building_interaction() -> void:
    var name := str(pending_building.get("name", "that place"))
    interaction_message = "Arrived at %s  ·  right-click to revisit" % name
    interaction_timeout = 4.0
    _show_interaction_feedback()
    pending_building = {}
    target_marker.clear_target()

func _show_interaction_feedback() -> void:
    if interaction_label == null or interaction_panel == null:
        return
    interaction_label.text = interaction_message
    interaction_label.visible = not interaction_message.is_empty()
    interaction_panel.visible = not interaction_message.is_empty()

func command_move_to_tile(tile: Vector2i) -> void:
    _queue_path_to(world.nearest_walkable(grid, tile, 10), {})

func command_click_world(world_position: Vector2) -> void:
    _handle_world_click(world_position)

func command_interact_with_building(building_id: String) -> void:
    for building in world.buildings():
        if str(building.get("id", "")) == building_id:
            _queue_building_interaction(building)
            return

func _set_zoom(value: float) -> void:
    camera_zoom = clampf(snappedf(value, ZOOM_STEP), ZOOM_MIN, ZOOM_MAX)
    camera.zoom = Vector2(camera_zoom, camera_zoom)

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 10
    add_child(layer)
    var panel := ColorRect.new()
    panel.position = Vector2(20, 20)
    panel.size = Vector2(340, 88)
    panel.color = Color(0.035, 0.08, 0.07, 0.94)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(panel)
    title_label = _label(layer, Vector2(38, 31), Vector2(290, 28), 22, Color("#f0d487"))
    subtitle_label = _label(layer, Vector2(39, 61), Vector2(290, 18), 12, Color("#b8c785"))
    debug_label = _label(layer, Vector2(39, 98), Vector2(350, 45), 11, Color("#d9e1c1"))
    debug_label.visible = debug_visible
    interaction_panel = ColorRect.new()
    interaction_panel.position = Vector2(20, 610)
    interaction_panel.size = Vector2(1240, 44)
    interaction_panel.color = Color(0.035, 0.08, 0.07, 0.84)
    interaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    interaction_panel.visible = false
    layer.add_child(interaction_panel)
    interaction_label = _label(layer, Vector2(30, 619), Vector2(1220, 26), 15, Color("#f0d487"))
    interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    interaction_label.visible = false
    hint_label = _label(layer, Vector2(30, 672), Vector2(1220, 24), 13, Color("#f0d487"))
    hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    loading_overlay = ColorRect.new()
    loading_overlay.position = Vector2.ZERO
    loading_overlay.size = Vector2(1280, 720)
    loading_overlay.color = Color("#132620")
    loading_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(loading_overlay)
    var loading_label := _label(loading_overlay, Vector2(0, 326), Vector2(1280, 40), 22, Color("#f0d487"))
    loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    loading_label.text = "Composing Moonrise Hollow…"

func _label(parent: Node, position: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.position = position
    label.size = size
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
    return label

func _refresh_hud() -> void:
    if title_label == null:
        return
    title_label.text = str(village.get("name", "Moonrise Hollow"))
    subtitle_label.text = "NATIVE FIELD SLICE  ·  GODOT 4.7.1  ·  %d%%" % roundi(camera_zoom * 100.0)
    var tile := Vector2i(floori(player_position.x), floori(player_position.y))
    var tile_name := world.tile_at(grid, tile)
    debug_label.text = "POS  %6.2f, %6.2f   TILE  %s\nFPS  %3d       F  toggle metrics" % [player_position.x, player_position.y, tile_name, Engine.get_frames_per_second()]
    hint_label.text = "Click ground  walk     Click a house  visit     Right-click  cancel/visit     Wheel  zoom     WASD  wander"
    interaction_label.text = interaction_message
    interaction_label.visible = not interaction_message.is_empty()
    interaction_panel.visible = not interaction_message.is_empty()

func _load_save() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return
    var normalized: Dictionary = world.normalize_save(parsed)
    village = normalized.get("village", village)
    grid = world.build_grid(village)
    var raw_player = normalized.get("player", World.START_POSITION)
    if raw_player is Vector2:
        player_position = raw_player
    elif raw_player is Dictionary:
        player_position = Vector2(float(raw_player.get("x", World.START_POSITION.x)), float(raw_player.get("y", World.START_POSITION.y)))

func _save_game() -> void:
    var payload := {
        "version": World.SAVE_VERSION,
        "village": village,
        "player": {"x": player_position.x, "y": player_position.y},
        "location": "village"
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(payload))

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        _save_game()
        get_tree().quit()
