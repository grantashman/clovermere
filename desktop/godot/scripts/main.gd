extends Node2D

const World = preload("res://scripts/world_contract.gd")
const WorldView = preload("res://scripts/world_view.gd")
const PlayerAvatar = preload("res://scripts/player_avatar.gd")

const SAVE_PATH := "user://hobbit-moon-village-v2.json"
const DEFAULT_VILLAGE := {"name": "Moonrise Hollow", "landscape": "heath"}
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1

var world = World.new()
var world_view: Node2D
var player: Node2D
var camera: Camera2D
var grid: Array = []
var village: Dictionary = DEFAULT_VILLAGE.duplicate(true)
var player_position := World.START_POSITION
var camera_zoom := 0.5
var debug_visible := true
var save_elapsed := 0.0
var title_label: Label
var subtitle_label: Label
var debug_label: Label
var hint_label: Label

func _ready() -> void:
    grid = world.build_grid(village)
    _load_save()
    camera = Camera2D.new()
    camera.position_smoothing_enabled = false
    camera.zoom = Vector2(camera_zoom, camera_zoom)
    add_child(camera)
    world_view = WorldView.new()
    add_child(world_view)
    world_view.configure(world, grid, village, camera)
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
    queue_redraw()

func _process(delta: float) -> void:
    var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var next_position: Vector2 = world.move_player(player_position, direction, delta, grid)
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
    _refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F11:
            get_window().mode = Window.MODE_FULLSCREEN if get_window().mode != Window.MODE_FULLSCREEN else Window.MODE_WINDOWED

func _set_zoom(value: float) -> void:
    camera_zoom = clampf(snappedf(value, ZOOM_STEP), ZOOM_MIN, ZOOM_MAX)
    camera.zoom = Vector2(camera_zoom, camera_zoom)

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 10
    add_child(layer)
    var panel := ColorRect.new()
    panel.position = Vector2(20, 20)
    panel.size = Vector2(390, 132)
    panel.color = Color(0.035, 0.08, 0.07, 0.88)
    layer.add_child(panel)
    title_label = _label(layer, Vector2(42, 37), Vector2(340, 30), 24, Color("#f0d487"))
    subtitle_label = _label(layer, Vector2(43, 70), Vector2(340, 22), 14, Color("#b8c785"))
    debug_label = _label(layer, Vector2(43, 96), Vector2(350, 45), 13, Color("#d9e1c1"))
    hint_label = _label(layer, Vector2(30, 670), Vector2(1220, 30), 15, Color("#f0d487"))
    hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

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
    hint_label.text = "WASD / arrows  wander     + / −  zoom     F11  fullscreen     F  metrics"

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
