extends Node2D

const World = preload("res://scripts/world_contract.gd")
const WorldView = preload("res://scripts/world_view.gd")
const PlayerAvatar = preload("res://scripts/player_avatar.gd")
const TargetMarker = preload("res://scripts/target_marker.gd")
const UiShell = preload("res://scripts/ui_shell.gd")
const LightingOverlay = preload("res://scripts/lighting_overlay.gd")


const SAVE_PATH := "user://hobbit-moon-village-v2.json"
const SETTINGS_PATH := "user://hobbit-moon-settings.cfg"
const DEFAULT_VILLAGE := {"name": "Clovermere", "landscape": "heath"}
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1

var world = World.new()
var world_cache: SubViewport
var world_sprite: Sprite2D
var world_view: Node2D
var lighting_overlay: Node2D
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
var gameplay_hud: CanvasLayer
var movement_path: Array = []
var pending_building: Dictionary = {}
var pending_resource: Dictionary = {}
var world_changes: Dictionary = {}
var interaction_message := ""
var interaction_timeout := 0.0
var ui: CanvasLayer
var game_started := false
var settings: Dictionary = {
    "fullscreen": true,
    "crisp_pixels": true,
    "show_metrics": false,
    "zoom": 0.75
}

func _ready() -> void:
    _load_settings()
    _apply_window_mode(bool(settings.get("fullscreen", true)))
    grid = world.build_grid(village, world_changes)
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
    _build_ui()
    _refresh_hud()
    call_deferred("_finish_loading")

func _finish_loading() -> void:
    await get_tree().create_timer(0.65).timeout
    await get_tree().process_frame
    await get_tree().process_frame
    if loading_overlay != null:
        loading_overlay.visible = false
    if ui != null:
        ui.show_welcome(_has_save())
    game_started = false

func _build_ui() -> void:
    ui = UiShell.new()
    add_child(ui)
    ui.new_journey_requested.connect(_start_new_journey)
    ui.continue_requested.connect(_continue_journey)
    ui.save_requested.connect(_on_save_requested)
    ui.load_requested.connect(_on_load_requested)
    ui.resume_requested.connect(_resume_journey)
    ui.options_requested.connect(_on_options_requested)
    ui.main_menu_requested.connect(_return_to_welcome)
    ui.quit_requested.connect(_quit_to_desktop)
    ui.fullscreen_changed.connect(_on_fullscreen_changed)
    ui.pixel_filter_changed.connect(_on_pixel_filter_changed)
    ui.zoom_changed.connect(_on_zoom_changed)
    ui.debug_changed.connect(_on_debug_changed)
    ui.configure(settings, _has_save(), camera_zoom)
    ui.show_loading()
    _set_gameplay_hud_visible(false)

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
    world_view.configure(world, grid, village, null, world_changes)

    world_sprite = Sprite2D.new()
    world_sprite.name = "StaticWorldTexture"
    world_sprite.texture = world_cache.get_texture()
    world_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    world_sprite.position = Vector2(world_cache.size) * 0.5
    world_sprite.z_index = -10
    add_child(world_sprite)

    lighting_overlay = LightingOverlay.new()
    lighting_overlay.name = "WorldLighting"
    lighting_overlay.z_index = 5
    add_child(lighting_overlay)
    lighting_overlay.configure(world)

    target_marker = TargetMarker.new()
    target_marker.z_index = 8
    target_marker.visible = false
    add_child(target_marker)

func _process(delta: float) -> void:
    if lighting_overlay != null:
        lighting_overlay.set_player_position(player.position if player != null else Vector2.ZERO, game_started)
    if not game_started:
        _refresh_hud()
        return
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
            if movement_path.is_empty() and not pending_resource.is_empty():
                _complete_resource_interaction()
            elif movement_path.is_empty() and not pending_building.is_empty():
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
            _show_interaction_feedback()
    _refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F11:
            _on_fullscreen_changed(get_window().mode != Window.MODE_FULLSCREEN)
        elif event.keycode == KEY_ESCAPE:
            if game_started:
                _pause_journey()
            elif ui != null and ui.current_page == "options":
                ui._back_from_options()
            elif ui != null and ui.current_page == "pause":
                _resume_journey()
        elif event.keycode == KEY_ENTER and not game_started and ui != null and ui.current_page == "welcome":
            if _has_save():
                _continue_journey()
        elif event.keycode == KEY_E and game_started:
            _handle_resource_action()
    elif event is InputEventMouseButton and event.pressed:
        if not game_started:
            return
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
    var resource := world.resource_at(tile)
    if not resource.is_empty() and not bool(world_changes.get(str(resource.id), false)):
        _queue_resource_interaction(resource)
        return
    var goal := world.nearest_walkable(grid, tile, 10)
    _queue_path_to(goal, {})

func _handle_context_click(world_position: Vector2) -> void:
    var tile := Vector2i(floori(world_position.x / World.TILE_SIZE), floori(world_position.y / World.TILE_SIZE))
    var building := world.building_at(tile)
    var resource := world.resource_at(tile)
    if not resource.is_empty() and not bool(world_changes.get(str(resource.id), false)):
        _queue_resource_interaction(resource)
        return
    if building.is_empty():
        movement_path.clear()
        pending_building = {}
        pending_resource = {}
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
    _queue_path_to(candidates[0], building, {})

func _queue_resource_interaction(resource: Dictionary) -> void:
    var origin := Vector2i(int(resource.x), int(resource.y))
    var candidates := [origin + Vector2i(0, 1), origin + Vector2i(0, -1), origin + Vector2i(-1, 0), origin + Vector2i(1, 0)]
    candidates = candidates.filter(func(candidate: Vector2i): return world.is_walkable(grid, candidate))
    candidates.sort_custom(func(a: Vector2i, b: Vector2i): return player_position.distance_squared_to(Vector2(a) + Vector2(0.5, 0.5)) < player_position.distance_squared_to(Vector2(b) + Vector2(0.5, 0.5)))
    if candidates.is_empty():
        interaction_message = "No clear approach to %s" % str(resource.get("name", "that resource"))
        interaction_timeout = 2.0
        return
    _queue_path_to(candidates[0], {}, resource)

func _queue_path_to(goal: Vector2i, building: Dictionary, resource: Dictionary = {}) -> void:
    var start := Vector2i(floori(player_position.x), floori(player_position.y))
    var route: Array = world.find_path(grid, start, goal)
    if route.is_empty() and start != goal:
        interaction_message = "That way is blocked"
        interaction_timeout = 2.0
        return
    movement_path = route
    pending_building = building
    pending_resource = resource
    target_marker.set_target((Vector2(goal) + Vector2(0.5, 0.5)) * World.TILE_SIZE)
    if not resource.is_empty():
        interaction_message = "Walking to %s  ·  press E to work" % str(resource.get("name", "resource"))
    elif building.is_empty():
        interaction_message = "Walking to marked ground"
    else:
        interaction_message = "Walking to %s" % str(building.get("name", "building"))
    interaction_timeout = 0.0
    _show_interaction_feedback()
    if movement_path.is_empty() and not pending_resource.is_empty():
        _complete_resource_interaction()
    elif movement_path.is_empty() and not pending_building.is_empty():
        _complete_building_interaction()

func _complete_building_interaction() -> void:
    var name := str(pending_building.get("name", "that place"))
    interaction_message = "Arrived at %s  ·  right-click to revisit" % name
    interaction_timeout = 4.0
    _show_interaction_feedback()
    pending_building = {}
    pending_resource = {}
    target_marker.clear_target()

func _handle_resource_action() -> void:
    var tile := Vector2i(floori(player_position.x), floori(player_position.y))
    var resource := world.resource_at(tile)
    if resource.is_empty():
        for candidate in world.resources():
            if bool(world_changes.get(str(candidate.id), false)):
                continue
            var candidate_tile := Vector2i(int(candidate.x), int(candidate.y))
            if candidate_tile.distance_to(tile) <= 2.0:
                resource = candidate
                break
    if resource.is_empty():
        interaction_message = "Nothing here needs a hand"
        interaction_timeout = 1.5
        _show_interaction_feedback()
        return
    _complete_resource_interaction_for(resource)

func _complete_resource_interaction() -> void:
    _complete_resource_interaction_for(pending_resource)

func _complete_resource_interaction_for(resource: Dictionary) -> void:
    if resource.is_empty():
        return
    var resource_id := str(resource.get("id", ""))
    if resource_id.is_empty() or bool(world_changes.get(resource_id, false)):
        return
    world_changes[resource_id] = true
    var kind := str(resource.get("kind", "resource"))
    var verb := "Gathered" if kind == "herb" else "Mined" if kind in ["stone", "ore"] else "Chopped"
    interaction_message = "%s %s  ·  %s added to the stores" % [verb, str(resource.get("name", "resource")), str(resource.get("yield", "materials"))]
    interaction_timeout = 4.0
    pending_resource = {}
    pending_building = {}
    target_marker.clear_target()
    _refresh_world_state()
    _save_game()
    _show_interaction_feedback()

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

func command_interact_with_resource(resource_id: String) -> void:
    for resource in world.resources():
        if str(resource.get("id", "")) == resource_id and not bool(world_changes.get(resource_id, false)):
            _queue_resource_interaction(resource)
            return

func _start_new_journey() -> void:
    village = DEFAULT_VILLAGE.duplicate(true)
    player_position = World.START_POSITION
    movement_path.clear()
    pending_building = {}
    pending_resource = {}
    world_changes.clear()
    interaction_message = ""
    _refresh_world_state()
    game_started = true
    _set_gameplay_hud_visible(true)
    ui.hide_overlay()
    ui.notify("A new day begins in Clovermere.")
    _refresh_player_transform()

func _continue_journey() -> void:
    if not _load_save():
        ui.notify("No saved journey found.")
        return
    game_started = true
    _set_gameplay_hud_visible(true)
    ui.hide_overlay()
    ui.notify("Journey restored.")
    _refresh_player_transform()

func _resume_journey() -> void:
    game_started = true
    _set_gameplay_hud_visible(true)
    ui.hide_overlay()

func _pause_journey() -> void:
    game_started = false
    _set_gameplay_hud_visible(false)
    ui.show_pause(_has_save())

func _return_to_welcome() -> void:
    _save_game()
    game_started = false
    _set_gameplay_hud_visible(false)
    ui.show_welcome(_has_save())

func _on_save_requested() -> void:
    if _save_game():
        ui.set_save_enabled(true)
        ui.notify("Journey saved to the village ledger.")
    else:
        ui.notify("The ledger could not be written.")

func _on_load_requested() -> void:
    if not _load_save():
        ui.notify("No saved journey found.")
        return
    game_started = true
    _set_gameplay_hud_visible(true)
    ui.hide_overlay()
    ui.notify("Journey loaded from the village ledger.")
    _refresh_player_transform()

func _on_options_requested() -> void:
    var from_page: String = "game" if game_started else ui.current_page
    game_started = false if from_page == "game" else game_started
    _set_gameplay_hud_visible(false)
    ui.show_options(from_page)

func _quit_to_desktop() -> void:
    if game_started:
        _save_game()
    get_tree().quit()

func _on_fullscreen_changed(enabled: bool) -> void:
    settings["fullscreen"] = enabled
    _apply_window_mode(enabled)
    _save_settings()
    if ui != null and ui.current_page != "loading":
        ui.notify("Fullscreen window %s." % ("enabled" if enabled else "disabled"))

func _on_pixel_filter_changed(enabled: bool) -> void:
    settings["crisp_pixels"] = enabled
    if world_sprite != null:
        world_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if enabled else CanvasItem.TEXTURE_FILTER_LINEAR
    _save_settings()

func _on_zoom_changed(value: float) -> void:
    settings["zoom"] = clampf(value, ZOOM_MIN, ZOOM_MAX)
    _set_zoom(settings["zoom"])
    _save_settings()

func _on_debug_changed(enabled: bool) -> void:
    settings["show_metrics"] = enabled
    debug_visible = enabled
    if debug_label != null:
        debug_label.visible = debug_visible
    _save_settings()

func _refresh_player_transform() -> void:
    if player == null or camera == null:
        return
    player.position = player_position * World.TILE_SIZE
    camera.position = player.position
    camera.reset_smoothing()

func _refresh_world_state() -> void:
    grid = world.build_grid(village, world_changes)
    if world_view != null:
        world_view.configure(world, grid, village, null, world_changes)
    if world_cache != null:
        world_cache.render_target_update_mode = SubViewport.UPDATE_ONCE
    _refresh_player_transform()

func _set_gameplay_hud_visible(visible: bool) -> void:
    if gameplay_hud != null:
        gameplay_hud.visible = visible

func _has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)

func _load_settings() -> void:
    var config := ConfigFile.new()
    if config.load(SETTINGS_PATH) == OK:
        settings["fullscreen"] = bool(config.get_value("display", "fullscreen", settings["fullscreen"]))
        settings["crisp_pixels"] = bool(config.get_value("display", "crisp_pixels", settings["crisp_pixels"]))
        settings["show_metrics"] = bool(config.get_value("accessibility", "show_metrics", settings["show_metrics"]))
        settings["zoom"] = clampf(float(config.get_value("display", "zoom", settings["zoom"])), ZOOM_MIN, ZOOM_MAX)
    camera_zoom = float(settings["zoom"])
    debug_visible = bool(settings["show_metrics"])

func _save_settings() -> void:
    var config := ConfigFile.new()
    config.set_value("display", "fullscreen", bool(settings.get("fullscreen", true)))
    config.set_value("display", "crisp_pixels", bool(settings.get("crisp_pixels", true)))
    config.set_value("display", "zoom", float(settings.get("zoom", 0.75)))
    config.set_value("accessibility", "show_metrics", bool(settings.get("show_metrics", false)))
    config.save(SETTINGS_PATH)

func _apply_window_mode(fullscreen: bool) -> void:
    if DisplayServer.get_name() == "headless":
        return
    get_window().mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED

func _set_zoom(value: float) -> void:
    camera_zoom = clampf(snappedf(value, ZOOM_STEP), ZOOM_MIN, ZOOM_MAX)
    camera.zoom = Vector2(camera_zoom, camera_zoom)

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 10
    gameplay_hud = layer
    add_child(layer)
    var panel := ColorRect.new()
    panel.position = Vector2(20, 20)
    panel.size = Vector2(392, 96)
    panel.color = Color(0.035, 0.08, 0.07, 0.94)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(panel)
    var logo := Sprite2D.new()
    logo.texture = load("res://assets/clovermere-mark.svg")
    logo.position = Vector2(53, 51)
    logo.scale = Vector2(0.33, 0.33)
    layer.add_child(logo)
    title_label = _label(layer, Vector2(82, 30), Vector2(300, 28), 22, Color("#f0d487"))
    subtitle_label = _label(layer, Vector2(83, 61), Vector2(300, 18), 12, Color("#b8c785"))
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
    loading_label.text = "Composing Clovermere…"

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
    title_label.text = str(village.get("name", "Clovermere"))
    subtitle_label.text = "CLOVERMERE  ·  %d%%  ·  %d FOLK" % [roundi(camera_zoom * 100.0), world.npcs().size()]
    var tile := Vector2i(floori(player_position.x), floori(player_position.y))
    var tile_name := world.tile_at(grid, tile)
    debug_label.text = "POS  %6.2f, %6.2f   TILE  %s\nFPS  %3d       F  toggle metrics" % [player_position.x, player_position.y, tile_name, Engine.get_frames_per_second()]
    hint_label.text = "Click ground  walk     Click a house  visit     Click a tree/stone/herb  work     E  work nearby     Right-click  cancel/visit     Wheel  zoom     WASD  wander"
    interaction_label.text = interaction_message
    interaction_label.visible = not interaction_message.is_empty()
    interaction_panel.visible = not interaction_message.is_empty()

func _load_save() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return false
    var parsed = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return false
    var normalized: Dictionary = world.normalize_save(parsed)
    var loaded_village = normalized.get("village", village)
    village = loaded_village if loaded_village is Dictionary else DEFAULT_VILLAGE.duplicate(true)
    var raw_player = normalized.get("player", World.START_POSITION)
    if raw_player is Vector2:
        player_position = raw_player
    elif raw_player is Dictionary:
        player_position = Vector2(float(raw_player.get("x", World.START_POSITION.x)), float(raw_player.get("y", World.START_POSITION.y)))
    var loaded_changes = normalized.get("world_changes", {})
    world_changes = loaded_changes.duplicate(true) if loaded_changes is Dictionary else {}
    _refresh_world_state()
    return true

func _save_game() -> bool:
    var payload := {
        "version": World.SAVE_VERSION,
        "village": village,
        "player": {"x": player_position.x, "y": player_position.y},
        "location": "village",
        "world_changes": world_changes.duplicate(true)
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(payload))
        return true
    return false

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        if game_started:
            _save_game()
        get_tree().quit()
