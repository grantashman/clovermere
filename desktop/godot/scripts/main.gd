extends Node2D

const World = preload("res://scripts/world_contract.gd")
const WorldView = preload("res://scripts/world_view.gd")
const PlayerAvatar = preload("res://scripts/player_avatar.gd")
const TargetMarker = preload("res://scripts/target_marker.gd")
const UiShell = preload("res://scripts/ui_shell.gd")
const LightingOverlay = preload("res://scripts/lighting_overlay.gd")
const DayState = preload("res://scripts/day_state.gd")
const NpcSchedule = preload("res://scripts/npc_schedule.gd")
const NpcActor = preload("res://scripts/npc_actor.gd")
const WorkAction = preload("res://scripts/work_action.gd")
const InteractionFeedback = preload("res://scripts/interaction_feedback.gd")
const BenchmarkScene = preload("res://scripts/benchmark_scene.gd")
const GameplayHud = preload("res://scripts/gameplay_hud.gd")
const InteriorContract = preload("res://scripts/interior_contract.gd")
const InteriorScene = preload("res://scripts/interior_scene.gd")
const VillageMemory = preload("res://scripts/village_memory.gd")
const ProceduralResourceOverlay = preload("res://scripts/procedural_resource_overlay.gd")


const SAVE_PATH := "user://hobbit-moon-village-v2.json"
const SETTINGS_PATH := "user://hobbit-moon-settings.cfg"
const DEFAULT_VILLAGE := {"name": "Clovermere", "landscape": "heath"}
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1
const INTERIOR_ZOOM_MULTIPLIER := 1.65
const WORK_MINUTES_PER_SECOND := 5.0

var world = World.new()
var world_cache: SubViewport
var world_sprite: Sprite2D
var procedural_resource_overlay: Node2D
var world_view: Node2D
var benchmark_scene: Node2D
var lighting_overlay: Node2D
var player: Node2D
var interaction_feedback: Node2D
var npc_layer: Node2D
var npc_actors: Dictionary = {}
var npc_schedule_phases: Dictionary = {}
var target_marker: Node2D
var camera: Camera2D
var grid: Array = []
var village: Dictionary = DEFAULT_VILLAGE.duplicate(true)
var day_state = DayState.new()
var village_memory = VillageMemory.new()
var resident_memory: Dictionary = village_memory.default_state()
var player_position := World.START_POSITION
var camera_zoom := 0.75
var debug_visible := false
var save_elapsed := 0.0
var title_label: Label
var subtitle_label: Label
var day_label: Label
var stores_label: Label
var debug_label: Label
var hint_label: Label
var loading_overlay: ColorRect
var interaction_panel: Control
var interaction_label: Label
var gameplay_hud
var interior_contract = InteriorContract.new()
var interior_scene: Node2D
var interior_grid: Array = []
var interior_location := ""
var exterior_position := World.START_POSITION
var interior_transitioning := false
var interior_transition_remaining := 0.0
var transition_layer: CanvasLayer
var transition_rect: ColorRect
var dialogue_flags: Dictionary = {}
var movement_path: Array = []
var pending_building: Dictionary = {}
var pending_interior_interaction: Dictionary = {}
var pending_resource: Dictionary = {}
var world_changes: Dictionary = {}
var resource_states: Dictionary = {}
var active_work_action = null
var last_work_result: Dictionary = {}
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
    benchmark_scene = BenchmarkScene.new()
    benchmark_scene.name = "CentralCrossingBenchmark"
    benchmark_scene.z_index = 4
    add_child(benchmark_scene)
    benchmark_scene.configure(world, grid, world_changes, resource_states, village_memory.consequence_flags(resident_memory), village)
    camera = Camera2D.new()
    camera.position_smoothing_enabled = false
    camera.zoom = Vector2(camera_zoom, camera_zoom)
    add_child(camera)
    player = PlayerAvatar.new()
    # Keep the player on the same authored pixel scale as residents; the prior
    # 1.55 multiplier made the hero dominate the village silhouettes.
    player.scale = Vector2.ONE
    player.z_index = 100 + floori(player_position.y)
    add_child(player)
    player.position = player_position * World.TILE_SIZE
    interaction_feedback = InteractionFeedback.new()
    interaction_feedback.name = "WorkFeedback"
    interaction_feedback.z_index = 320
    interaction_feedback.visible = false
    add_child(interaction_feedback)
    camera.position = player.position
    camera.make_current()
    camera.reset_smoothing()
    _build_npc_actors()
    _build_hud()
    _build_ui()
    _build_transition_overlay()
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

    procedural_resource_overlay = ProceduralResourceOverlay.new()
    procedural_resource_overlay.name = "ProceduralResourceField"
    procedural_resource_overlay.z_index = 6
    procedural_resource_overlay.configure(world, village, world_changes)
    add_child(procedural_resource_overlay)

    lighting_overlay = LightingOverlay.new()
    lighting_overlay.name = "WorldLighting"
    lighting_overlay.z_index = 5
    add_child(lighting_overlay)
    lighting_overlay.configure(world)

    target_marker = TargetMarker.new()
    target_marker.z_index = 300
    target_marker.visible = false
    add_child(target_marker)

func _build_npc_actors() -> void:
    npc_layer = Node2D.new()
    npc_layer.name = "LiveResidents"
    npc_layer.z_index = 0
    add_child(npc_layer)
    npc_actors.clear()
    npc_schedule_phases.clear()
    for npc_variant in world.npcs():
        if not npc_variant is Dictionary:
            continue
        var npc: Dictionary = npc_variant
        var actor = NpcActor.new()
        actor.name = "Resident_%s" % str(npc.get("id", "unknown"))
        actor.set_npc(npc)
        actor.position = (Vector2(float(npc.get("x", World.START_TILE.x)) + 0.5, float(npc.get("y", World.START_TILE.y)) + 0.9) * World.TILE_SIZE)
        actor.update_depth()
        npc_layer.add_child(actor)
        npc_actors[str(npc.get("id", ""))] = actor
    _refresh_npc_schedules(true)

func _refresh_npc_schedules(force: bool = false) -> void:
    if npc_actors.is_empty():
        return
    for npc_variant in world.npcs():
        if not npc_variant is Dictionary:
            continue
        var npc: Dictionary = npc_variant
        var npc_id := str(npc.get("id", ""))
        var actor = npc_actors.get(npc_id)
        if actor == null:
            continue
        var decision: Dictionary = NpcSchedule.resolve(npc, day_state.minute_of_day)
        var phase := str(decision.get("phase", ""))
        actor.set_activity(str(decision.get("activity", "resting")))
        if force or str(npc_schedule_phases.get(npc_id, "")) != phase:
            var requested_target: Vector2i = decision.get("target", World.START_TILE)
            var target := world.nearest_walkable(grid, requested_target, 10)
            var start := Vector2i(floori(actor.position.x / World.TILE_SIZE), floori(actor.position.y / World.TILE_SIZE))
            actor.set_route(world.find_path(grid, start, target))
            npc_schedule_phases[npc_id] = phase

func _update_npc_actors(delta: float) -> void:
    for actor_variant in npc_actors.values():
        var actor = actor_variant
        actor.advance_navigation(delta, World.TILE_SIZE, 1.8)
        actor.update_depth()

func _process(delta: float) -> void:
    if lighting_overlay != null:
        lighting_overlay.set_time(day_state.minute_of_day)
        lighting_overlay.set_player_position(player.position if player != null else Vector2.ZERO, game_started and not _in_interior())
        lighting_overlay.visible = not _in_interior()
    if benchmark_scene != null:
        benchmark_scene.set_time(day_state.minute_of_day)
        benchmark_scene.visible = not _in_interior()
    if interior_scene != null and _in_interior():
        interior_scene.set_time(day_state.minute_of_day)
        interior_scene.set_player_position(player_position * World.TILE_SIZE)
    if interior_transitioning:
        interior_transition_remaining = maxf(0.0, interior_transition_remaining - delta)
        if interior_transition_remaining <= 0.0:
            interior_transitioning = false
            if transition_rect != null:
                transition_rect.visible = false
    if not game_started or interior_transitioning:
        _refresh_hud()
        return
    _advance_work_action(delta)
    if not _in_interior():
        _update_npc_actors(delta)
    var active_grid := _active_grid()
    var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var next_position := player_position
    if direction.length_squared() > 0.0001:
        _cancel_work_action("Work cancelled  ·  movement resumed")
        movement_path.clear()
        pending_building = {}
        pending_interior_interaction = {}
        target_marker.clear_target()
        next_position = world.move_player(player_position, direction, delta, active_grid)
    elif not movement_path.is_empty():
        var next_tile: Vector2i = movement_path[0]
        var destination := Vector2(next_tile) + Vector2(0.5, 0.5)
        if player_position.distance_to(destination) < 0.11:
            player_position = destination
            next_position = player_position
            movement_path.pop_front()
            if movement_path.is_empty() and not pending_interior_interaction.is_empty():
                _arrive_at_interior_interaction()
            elif movement_path.is_empty() and not pending_resource.is_empty():
                _arrive_at_resource()
            elif movement_path.is_empty() and not pending_building.is_empty():
                _complete_building_interaction()
        else:
            next_position = world.move_player(player_position, player_position.direction_to(destination), delta, active_grid, 5.0)
    if next_position != player_position:
        player_position = next_position
        player.position = player_position * World.TILE_SIZE
        player.z_index = 100 + floori(player_position.y)
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
    if interior_transitioning:
        get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F11:
            _on_fullscreen_changed(get_window().mode != Window.MODE_FULLSCREEN)
        elif event.keycode == KEY_ESCAPE:
            if game_started and gameplay_hud != null and gameplay_hud.dialogue_panel.visible:
                gameplay_hud.hide_dialogue()
            elif game_started:
                if gameplay_hud != null and gameplay_hud.management_panel.visible:
                    gameplay_hud.close_management()
                else:
                    _pause_journey()
            elif ui != null and ui.current_page == "options":
                ui._back_from_options()
            elif ui != null and ui.current_page == "pause":
                _resume_journey()
        elif event.keycode == KEY_ENTER and game_started and gameplay_hud != null and gameplay_hud.dialogue_panel.visible:
            gameplay_hud.hide_dialogue()
        elif event.keycode == KEY_ENTER and not game_started and ui != null and ui.current_page == "welcome":
            if _has_save():
                _continue_journey()
        elif event.keycode == KEY_E and game_started:
            if gameplay_hud != null and gameplay_hud.dialogue_panel.visible:
                gameplay_hud.hide_dialogue()
            elif _in_interior():
                _handle_interior_action()
            else:
                _handle_resource_action()
        elif event.keycode == KEY_B and game_started:
            gameplay_hud.open_pack()
        elif event.keycode == KEY_C and game_started:
            gameplay_hud.open_crafting()
        elif event.keycode == KEY_T and game_started and not _in_interior():
            _talk_to_nearest_npc()
    elif event is InputEventMouseButton and event.pressed:
        if not game_started:
            return
        if event.button_index == MOUSE_BUTTON_LEFT:
            if _in_interior():
                _handle_interior_click(get_global_mouse_position())
            else:
                _handle_world_click(get_global_mouse_position())
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            if _in_interior():
                _handle_interior_click(get_global_mouse_position())
            else:
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
    var resource := world.resource_at(tile, village)
    if not resource.is_empty() and not bool(world_changes.get(str(resource.id), false)):
        _queue_resource_interaction(resource)
        return
    var goal := world.nearest_walkable(grid, tile, 10)
    _queue_path_to(goal, {})

func _handle_context_click(world_position: Vector2) -> void:
    _cancel_work_action("Work cancelled  ·  target changed")
    var tile := Vector2i(floori(world_position.x / World.TILE_SIZE), floori(world_position.y / World.TILE_SIZE))
    var building := world.building_at(tile)
    var resource := world.resource_at(tile, village)
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

func _in_interior() -> bool:
    return interior_contract.is_interior(interior_location)

func _active_grid() -> Array:
    return interior_grid if _in_interior() else grid

func _handle_interior_click(world_position: Vector2) -> void:
    var tile := Vector2i(floori(world_position.x / World.TILE_SIZE), floori(world_position.y / World.TILE_SIZE))
    if tile == interior_contract.exit_tile(interior_location):
        _queue_path_to(tile, {})
        pending_interior_interaction = {"id": "interior-exit", "name": "Doorway", "action": "exit"}
        return
    var interaction := interior_contract.interaction_at(interior_location, tile)
    if not interaction.is_empty():
        _queue_interior_interaction(interaction)
        return
    if interior_contract.is_walkable(_active_grid(), tile):
        pending_interior_interaction = {}
        _queue_path_to(tile, {})
        interaction_message = "Walking through %s" % str(interior_contract.definition_for(interior_location).get("short_name", "the room"))
        interaction_timeout = 1.5
        _show_interaction_feedback()

func _queue_interior_interaction(interaction: Dictionary) -> void:
    var target := Vector2i(int(interaction.get("x", 0)), int(interaction.get("y", 0)))
    var candidates := [target + Vector2i(0, 1), target + Vector2i(0, -1), target + Vector2i(-1, 0), target + Vector2i(1, 0)]
    candidates = candidates.filter(func(candidate: Vector2i): return interior_contract.is_walkable(_active_grid(), candidate))
    if candidates.is_empty():
        interaction_message = "There is no clear space by %s" % str(interaction.get("name", "that object"))
        interaction_timeout = 2.0
        _show_interaction_feedback()
        return
    candidates.sort_custom(func(a: Vector2i, b: Vector2i): return player_position.distance_squared_to(Vector2(a) + Vector2(0.5, 0.5)) < player_position.distance_squared_to(Vector2(b) + Vector2(0.5, 0.5)))
    pending_interior_interaction = interaction.duplicate(true)
    _queue_path_to(candidates[0], {})
    interaction_message = "Walking to %s" % str(interaction.get("name", "that object"))
    interaction_timeout = 0.0
    _show_interaction_feedback()

func _arrive_at_interior_interaction() -> void:
    if pending_interior_interaction.is_empty():
        return
    interaction_message = "Arrived at %s  ·  press E to interact" % str(pending_interior_interaction.get("name", "that object"))
    interaction_timeout = 4.0
    target_marker.clear_target()
    _show_interaction_feedback()

func _handle_interior_action() -> void:
    if _is_near_interior_exit():
        _exit_interior()
        return
    var interaction := pending_interior_interaction
    if interaction.is_empty():
        interaction = interior_contract.nearest_interaction(interior_location, player_position)
    if interaction.is_empty():
        interaction_message = "The room is quiet. The doorway is behind you."
        interaction_timeout = 2.0
        _show_interaction_feedback()
        return
    var action := str(interaction.get("action", "inspect"))
    if action == "sleep":
        _sleep_at_home()
    elif action == "storage":
        _withdraw_home_stores()
    elif action == "cook":
        interaction_message = "The Hearth Pantry is ready  ·  press MAKE"
        interaction_timeout = 3.0
        _show_interaction_feedback()
        if gameplay_hud != null:
            gameplay_hud.open_cooking()
    elif action == "craft":
        interaction_message = "The workbench is ready  ·  press C to view recipes"
        interaction_timeout = 3.0
        _show_interaction_feedback()
        if gameplay_hud != null:
            gameplay_hud.open_crafting()
    elif action == "rest":
        interaction_message = "The hearth is warm. It will be here when the day asks enough of you."
        interaction_timeout = 3.0
        _show_interaction_feedback()
    elif action == "forge":
        interaction_message = "The forge holds a patient ember. Bring materials to the workbench."
        interaction_timeout = 3.0
        _show_interaction_feedback()
    else:
        interaction_message = "%s is neatly kept." % str(interaction.get("name", "That object"))
        interaction_timeout = 2.5
        _show_interaction_feedback()
    pending_interior_interaction = {}

func _is_near_interior_exit() -> bool:
    if not _in_interior():
        return false
    return player_position.distance_to(Vector2(interior_contract.exit_tile(interior_location)) + Vector2(0.5, 0.5)) <= 0.85

func _queue_path_to(goal: Vector2i, building: Dictionary, resource: Dictionary = {}) -> void:
    _cancel_work_action("Work cancelled  ·  walking to a new target")
    var start := Vector2i(floori(player_position.x), floori(player_position.y))
    var route: Array = world.find_path(_active_grid(), start, goal)
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
    if movement_path.is_empty() and not pending_interior_interaction.is_empty():
        _arrive_at_interior_interaction()
    elif movement_path.is_empty() and not pending_resource.is_empty():
        _arrive_at_resource()
    elif movement_path.is_empty() and not pending_building.is_empty():
        _complete_building_interaction()

func _complete_building_interaction() -> void:
    var name := str(pending_building.get("name", "that place"))
    var building_id := str(pending_building.get("id", ""))
    if interior_contract.is_interior(building_id):
        interaction_message = "Arrived at %s  ·  press E to enter" % name
    else:
        interaction_message = "Arrived at %s  ·  press E to interact" % name
    interaction_timeout = 4.0
    _show_interaction_feedback()
    pending_resource = {}
    pending_interior_interaction = {}
    target_marker.clear_target()

func _handle_resource_action() -> void:
    if active_work_action != null and active_work_action.is_active():
        return
    if not pending_building.is_empty():
        _handle_building_action()
        return
    var tile := Vector2i(floori(player_position.x), floori(player_position.y))
    var resource := world.resource_at(tile, village)
    if resource.is_empty():
        for candidate in world.resources(village):
            if bool(world_changes.get(str(candidate.id), false)):
                continue
            var candidate_tile := Vector2i(int(candidate.x), int(candidate.y))
            if candidate_tile.distance_to(tile) <= 2.0:
                resource = candidate
                break
    if resource.is_empty():
        var nearby_npc := _nearest_npc_id()
        if not nearby_npc.is_empty():
            _talk_to_nearest_npc()
            return
        if _is_near_home():
            _sleep_at_home()
            return
        interaction_message = "Nothing here needs a hand"
        interaction_timeout = 1.5
        _show_interaction_feedback()
        return
    _start_resource_work(resource)

func _handle_building_action() -> void:
    var building_id := str(pending_building.get("id", ""))
    if building_id == "tinker-workshop" and not day_state.has_upgrade("tinkers-kit"):
        _purchase_workshop_upgrade()
    elif interior_contract.is_interior(building_id):
        _enter_interior(building_id)
    elif building_id == "greenbriar-cottage":
        _sleep_at_home()
    else:
        interaction_message = "%s is quiet for now" % str(pending_building.get("name", "That place"))
        interaction_timeout = 2.0
        _show_interaction_feedback()

func _is_near_workshop() -> bool:
    if _in_interior():
        return interior_location == "tinker-workshop"
    for building in world.buildings():
        if str(building.get("id", "")) != "tinker-workshop":
            continue
        var candidates := [
            Vector2(int(building.x) + int(building.w) / 2, int(building.y) + int(building.h) + 1),
            Vector2(int(building.x) + int(building.w) / 2, int(building.y) - 1),
            Vector2(int(building.x) - 1, int(building.y) + int(building.h) / 2),
            Vector2(int(building.x) + int(building.w), int(building.y) + int(building.h) / 2)
        ]
        for candidate in candidates:
            if player_position.distance_to(candidate + Vector2(0.5, 0.5)) <= 2.0:
                return true
    return false

func _cook_recipe(recipe_id: String) -> void:
    if not _in_interior() or interior_location != "greenbriar-cottage":
        interaction_message = "Stand at the Cottage Hearth Pantry to cook"
        interaction_timeout = 2.5
        _show_interaction_feedback()
        return
    var result: Dictionary = day_state.cook_recipe(recipe_id)
    if bool(result.get("ok", false)):
        var meal_id := str(result.get("meal_id", ""))
        if meal_id.is_empty():
            interaction_message = "%s made  ·  +%d energy  ·  %d minutes" % [str(result.get("name", recipe_id)), int(result.get("energy", 0)), int(result.get("minutes", 0))]
        else:
            interaction_message = "%s prepared  ·  READY in the Hearth Pantry" % str(result.get("name", recipe_id))
        interaction_timeout = 4.0
        _save_game()
        _refresh_hud()
        _show_interaction_feedback()
        if gameplay_hud != null:
            gameplay_hud.open_cooking()
        return
    var reason := str(result.get("reason", ""))
    interaction_message = "Not enough pantry ingredients" if reason == "missing-materials" else "The Hearth Pantry cannot make that yet"
    interaction_timeout = 2.5
    _show_interaction_feedback()

func _eat_meal(meal_id: String) -> void:
    var result: Dictionary = day_state.eat_meal(meal_id)
    if bool(result.get("ok", false)):
        interaction_message = "%s eaten  ·  +%d energy  ·  next work is improved" % [str(result.get("name", meal_id)), int(result.get("energy", 0))]
        interaction_timeout = 4.0
        _save_game()
        _refresh_hud()
        _show_interaction_feedback()
        if gameplay_hud != null:
            gameplay_hud.open_cooking()
        return
    interaction_message = "No prepared meal of that kind is ready"
    interaction_timeout = 2.5
    _show_interaction_feedback()

func _craft_recipe(recipe_id: String) -> void:
    if not _is_near_workshop():
        interaction_message = "Stand at Tinker Workshop to craft that recipe"
        interaction_timeout = 2.5
        _show_interaction_feedback()
        return
    var result: Dictionary = day_state.craft_recipe(recipe_id)
    if bool(result.get("ok", false)):
        interaction_message = "%s fitted  ·  the village road grows kinder" % str(result.get("name", recipe_id))
        interaction_timeout = 4.0
        _save_game()
        _refresh_hud()
        _show_interaction_feedback()
        if gameplay_hud != null:
            gameplay_hud.open_crafting()
        return
    var reason := str(result.get("reason", ""))
    interaction_message = "Already fitted" if reason == "already-owned" else "Not enough materials for that recipe"
    interaction_timeout = 2.5
    _show_interaction_feedback()

func _withdraw_home_stores() -> void:
    if not _is_near_home():
        interaction_message = "Stand at Greenbriar Cottage to take your home stores"
        interaction_timeout = 2.5
        _show_interaction_feedback()
        return
    var moved := day_state.withdraw_storage(day_state.storage.duplicate(true))
    if moved.is_empty():
        interaction_message = "Greenbriar Cottage stores are empty"
    else:
        interaction_message = "Home stores returned to the field pack"
        _save_game()
        _refresh_hud()
    interaction_timeout = 2.5
    _show_interaction_feedback()
    if gameplay_hud != null:
        gameplay_hud.open_pack()

func _purchase_workshop_upgrade() -> void:
    var purchase: Dictionary = day_state.purchase_upgrade("tinkers-kit")
    if bool(purchase.get("ok", false)):
        interaction_message = "Tinker’s Kit made  ·  work now costs less energy"
        interaction_timeout = 4.0
        _save_game()
        _refresh_hud()
        _show_interaction_feedback()
        if ui != null:
            ui.notify("Tinker’s Kit added to your field kit.")
        return
    var reason := str(purchase.get("reason", ""))
    if reason == "already-owned":
        interaction_message = "Tinker’s Kit already fitted"
    elif reason == "missing-materials":
        interaction_message = "Workshop needs 3 timber · 2 stone · 1 ore"
    else:
        interaction_message = "The workshop cannot make that yet"
    interaction_timeout = 2.5
    _show_interaction_feedback()

func _is_near_home() -> bool:
    if _in_interior():
        return interior_location == "greenbriar-cottage"
    for building in world.buildings():
        if str(building.get("id", "")) != "greenbriar-cottage":
            continue
        var candidates := [
            Vector2(int(building.x) + int(building.w) / 2, int(building.y) + int(building.h) + 1),
            Vector2(int(building.x) + int(building.w) / 2, int(building.y) - 1),
            Vector2(int(building.x) - 1, int(building.y) + int(building.h) / 2),
            Vector2(int(building.x) + int(building.w), int(building.y) + int(building.h) / 2)
        ]
        for candidate in candidates:
            if player_position.distance_to(candidate + Vector2(0.5, 0.5)) <= 2.0:
                return true
    return false

func _sleep_at_home() -> bool:
    if active_work_action != null and active_work_action.is_active():
        interaction_message = "Finish the work first"
        interaction_timeout = 1.5
        _show_interaction_feedback()
        return false
    if not _is_near_home() and game_started:
        interaction_message = "Stand by Greenbriar Cottage to sleep"
        interaction_timeout = 2.0
        _show_interaction_feedback()
        return false
    var deposited := day_state.deposit_inventory()
    var restored_ids: Array[String] = day_state.sleep_next_day(world_changes, world.resources(village), resource_states)
    movement_path.clear()
    pending_building = {}
    pending_resource = {}
    target_marker.clear_target()
    interaction_message = "A new day begins  ·  %s  ·  energy restored%s" % [day_state.format_clock(), "  ·  materials stored" if not deposited.is_empty() else ""]
    interaction_timeout = 4.0
    _refresh_world_state()
    for resource_id in restored_ids:
        if benchmark_scene != null:
            benchmark_scene.begin_regrowth(resource_id)
    _save_game()
    _refresh_hud()
    _show_interaction_feedback()
    if ui != null:
        ui.notify("Day %d begins in Clovermere." % day_state.day)
    return true

func _complete_resource_interaction_for(resource: Dictionary) -> void:
    _start_resource_work(resource)

func _start_resource_work(resource: Dictionary) -> void:
    if resource.is_empty():
        return
    var resource_id := str(resource.get("id", ""))
    if resource_id.is_empty() or bool(world_changes.get(resource_id, false)):
        return
    if active_work_action != null and active_work_action.is_active():
        return
    var action = WorkAction.new()
    var start_result: Dictionary = action.start(resource, day_state)
    if not bool(start_result.get("ok", false)):
        if str(start_result.get("reason", "")) == "too-tired":
            interaction_message = "Too tired to work that  ·  sleep at Greenbriar Cottage"
        else:
            interaction_message = "That resource cannot be worked"
        interaction_timeout = 2.5
        _show_interaction_feedback()
        return
    active_work_action = action
    pending_resource = resource.duplicate(true)
    player.begin_work(str(resource.get("kind", "resource")))
    if benchmark_scene != null:
        benchmark_scene.set_active_work(resource_id, 0.0)
    interaction_feedback.begin_action(action, player.position)
    target_marker.clear_target()
    interaction_timeout = 0.0
    interaction_message = "%s  ·  0%%" % _work_label(resource)
    _show_interaction_feedback()

func _advance_work_action(delta: float) -> void:
    if active_work_action == null or not active_work_action.is_active():
        return
    active_work_action.advance(delta * WORK_MINUTES_PER_SECOND)
    if active_work_action.status == "completed":
        var resource: Dictionary = active_work_action.resource.duplicate(true)
        var work_result: Dictionary = active_work_action.result.duplicate(true)
        last_work_result = work_result
        player.clear_work()
        interaction_feedback.complete_action(resource, player.position)
        if benchmark_scene != null:
            benchmark_scene.clear_active_work()
        active_work_action = null
        _apply_completed_resource_work(resource, work_result)
    elif active_work_action.status == "working":
        player.update_work(active_work_action.progress)
        if benchmark_scene != null:
            benchmark_scene.set_active_work(str(active_work_action.resource.get("id", "")), active_work_action.progress)
        interaction_feedback.update_action(active_work_action, player.position)
        interaction_message = "%s  ·  %d%%" % [_work_label(active_work_action.resource), roundi(active_work_action.progress * 100.0)]
        interaction_timeout = 0.0
        _show_interaction_feedback()

func _cancel_work_action(message: String = "") -> void:
    if active_work_action == null or not active_work_action.is_active():
        return
    active_work_action.cancel()
    active_work_action = null
    player.clear_work()
    if benchmark_scene != null:
        benchmark_scene.clear_active_work()
    interaction_feedback.clear_action()
    if not message.is_empty():
        interaction_message = message
        interaction_timeout = 1.8
        _show_interaction_feedback()

func _arrive_at_resource() -> void:
    if pending_resource.is_empty():
        return
    interaction_message = "Arrived at %s  ·  press E to work" % str(pending_resource.get("name", "resource"))
    interaction_timeout = 4.0
    target_marker.clear_target()
    _show_interaction_feedback()

func _work_label(resource: Dictionary) -> String:
    var kind := str(resource.get("kind", "resource"))
    if kind == "tree":
        return "CHOPPING TIMBER"
    if kind == "stone":
        return "MINING STONE"
    if kind == "ore":
        return "MINING ORE"
    if kind == "herb":
        return "GATHERING HERBS"
    if kind == "fish":
        return "FISHING"
    return "WORKING"

func _apply_completed_resource_work(resource: Dictionary, work_result: Dictionary) -> void:
    if resource.is_empty() or not bool(work_result.get("ok", false)):
        return
    var resource_id := str(resource.get("id", ""))
    if resource_id.is_empty() or bool(world_changes.get(resource_id, false)):
        return
    var kind := str(resource.get("kind", "resource"))
    day_state.mark_resource_cleared(resource, world_changes, resource_states, day_state.day)
    var verb := "Gathered" if kind == "herb" else "Mined" if kind in ["stone", "ore"] else "Chopped"
    interaction_message = "%s %s  ·  %s ×%d  ·  %s" % [verb, str(resource.get("name", "resource")), str(resource.get("yield", "materials")), int(work_result.get("amount", 0)), day_state.format_clock()]
    interaction_timeout = 4.0
    pending_resource = {}
    pending_building = {}
    target_marker.clear_target()
    _refresh_world_state()
    _save_game()
    _refresh_hud()
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
    for resource in world.resources(village):
        if str(resource.get("id", "")) == resource_id and not bool(world_changes.get(resource_id, false)):
            _queue_resource_interaction(resource)
            return

func _build_transition_overlay() -> void:
    transition_layer = CanvasLayer.new()
    transition_layer.name = "InteriorTransition"
    transition_layer.layer = 30
    add_child(transition_layer)
    transition_rect = ColorRect.new()
    transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    transition_rect.color = Color("#091610", 0.0)
    transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
    transition_rect.visible = false
    transition_layer.add_child(transition_rect)

func _begin_interior_transition() -> void:
    interior_transitioning = true
    interior_transition_remaining = interior_contract.transition_seconds()
    if transition_rect == null:
        return
    transition_rect.visible = true
    transition_rect.color = Color("#091610", 0.0)
    var tween := create_tween()
    tween.set_parallel(false)
    tween.tween_property(transition_rect, "color:a", 0.96, interior_contract.transition_seconds() * 0.5)
    tween.tween_property(transition_rect, "color:a", 0.0, interior_contract.transition_seconds() * 0.5)

func _set_world_visibility(visible: bool) -> void:
    if world_sprite != null:
        world_sprite.visible = visible
    if procedural_resource_overlay != null:
        procedural_resource_overlay.visible = visible
    if benchmark_scene != null:
        benchmark_scene.visible = visible
    if npc_layer != null:
        npc_layer.visible = visible
    if lighting_overlay != null:
        lighting_overlay.visible = visible
    if interior_scene != null:
        interior_scene.visible = not visible

func _ensure_interior_scene() -> void:
    if interior_scene != null:
        return
    interior_scene = InteriorScene.new()
    interior_scene.name = "AuthoredInterior"
    interior_scene.z_index = 6
    add_child(interior_scene)
    interior_scene.visible = false

func _enter_interior(building_id: String, with_transition: bool = true, restored_position: Vector2 = Vector2(-1, -1)) -> void:
    if not interior_contract.is_interior(building_id):
        return
    if _in_interior():
        return
    exterior_position = player_position
    interior_location = building_id
    interior_grid = interior_contract.build_grid(building_id)
    _ensure_interior_scene()
    interior_scene.configure(interior_contract.definition_for(building_id))
    interior_scene.set_time(day_state.minute_of_day)
    var requested_position := restored_position if restored_position.x >= 0.0 and restored_position.y >= 0.0 else interior_contract.spawn_position(building_id)
    player_position = requested_position
    movement_path.clear()
    pending_building = {}
    pending_resource = {}
    pending_interior_interaction = {}
    target_marker.clear_target()
    _set_world_visibility(false)
    if gameplay_hud != null:
        gameplay_hud.close_management()
        gameplay_hud.set_interior_mode(true, str(interior_contract.definition_for(building_id).get("short_name", building_id)))
    if ui != null:
        ui.dismiss_toast()
    interaction_message = "Entering %s" % str(interior_contract.definition_for(building_id).get("short_name", building_id))
    interaction_timeout = 2.0
    _refresh_player_transform()
    _refresh_hud()
    if with_transition:
        _begin_interior_transition()

func _exit_interior(with_transition: bool = true) -> void:
    if not _in_interior():
        return
    interior_location = ""
    interior_grid = []
    player_position = exterior_position
    movement_path.clear()
    pending_building = {}
    pending_resource = {}
    pending_interior_interaction = {}
    target_marker.clear_target()
    _set_world_visibility(true)
    if gameplay_hud != null:
        gameplay_hud.close_management()
        gameplay_hud.set_interior_mode(false)
    interaction_message = "Back in Clovermere"
    interaction_timeout = 2.0
    _refresh_player_transform()
    _refresh_hud()
    if with_transition:
        _begin_interior_transition()

func _nearest_npc_id(max_distance: float = 2.4) -> String:
    if _in_interior():
        return ""
    var closest_id := ""
    var closest_distance := max_distance
    for npc_id in npc_actors.keys():
        var actor = npc_actors.get(npc_id)
        if actor == null:
            continue
        var distance := player_position.distance_to(actor.position / World.TILE_SIZE)
        if distance <= closest_distance:
            closest_distance = distance
            closest_id = str(npc_id)
    return closest_id

func _talk_to_nearest_npc() -> void:
    var npc_id := _nearest_npc_id()
    if npc_id.is_empty():
        interaction_message = "No one nearby has time for a word"
        interaction_timeout = 1.8
        _show_interaction_feedback()
        return
    var context := {
        "location": interior_location if _in_interior() else "village",
        "minute": day_state.minute_of_day,
        "day": day_state.day,
        "inventory": day_state.inventory,
        "work_active": active_work_action != null and active_work_action.is_active()
    }
    var dialogue: Dictionary = village_memory.dialogue_for(npc_id, resident_memory, context)
    if dialogue.is_empty():
        return
    var resident_state := village_memory.state_for(resident_memory, npc_id)
    var stage := int(resident_state.get("stage", 0))
    dialogue_flags[npc_id] = true
    if stage == 0:
        village_memory.mark_introduced(resident_memory, npc_id, day_state.day)
        interaction_message = "You met %s" % str(dialogue.get("speaker", npc_id))
        interaction_timeout = 2.5
    elif stage == 1 and bool(dialogue.get("favor_ready", false)):
        var cost: Dictionary = dialogue.get("cost", {})
        if day_state.spend_materials(cost):
            var completion: Dictionary = village_memory.complete_favor(resident_memory, npc_id, day_state.day)
            if bool(completion.get("ok", false)):
                day_state.apply_reward(completion.get("reward", {}))
                if benchmark_scene != null:
                    benchmark_scene.set_consequence_flags(village_memory.consequence_flags(resident_memory))
                dialogue = village_memory.dialogue_for(npc_id, resident_memory, context)
                interaction_message = "%s complete  ·  trust grows in Clovermere" % str(completion.get("name", "Favor"))
                interaction_timeout = 4.0
            else:
                interaction_message = "The favor could not be recorded"
                interaction_timeout = 2.0
        else:
            interaction_message = "Keep the requested materials in your field pack"
            interaction_timeout = 2.5
    elif stage == 2 and bool(dialogue.get("gift_ready", false)):
        var gift: Dictionary = village_memory.claim_gift(resident_memory, npc_id, day_state.day)
        if bool(gift.get("ok", false)):
            day_state.apply_reward(gift.get("reward", {}))
            dialogue = village_memory.dialogue_for(npc_id, resident_memory, context)
            interaction_message = "%s brought a small gift" % str(dialogue.get("speaker", npc_id))
            interaction_timeout = 3.5
        else:
            interaction_message = "That gift will be ready another day"
            interaction_timeout = 2.0
    if ui != null:
        ui.dismiss_toast()
    if gameplay_hud != null:
        gameplay_hud.show_dialogue(str(dialogue.get("speaker", npc_id)), str(dialogue.get("text", "")))
    _save_game()
    _refresh_hud()

func _start_new_journey() -> void:
    village = DEFAULT_VILLAGE.duplicate(true)
    player_position = World.START_POSITION
    exterior_position = World.START_POSITION
    interior_location = ""
    interior_grid = []
    movement_path.clear()
    pending_building = {}
    pending_resource = {}
    pending_interior_interaction = {}
    dialogue_flags.clear()
    resident_memory = village_memory.default_state()
    world_changes.clear()
    resource_states.clear()
    day_state = DayState.new()
    active_work_action = null
    if player != null:
        player.clear_work()
    if interaction_feedback != null:
        interaction_feedback.clear_action()
    if benchmark_scene != null:
        benchmark_scene.clear_active_work()
    interaction_message = ""
    _refresh_world_state()
    _set_world_visibility(true)
    if gameplay_hud != null:
        gameplay_hud.set_interior_mode(false)
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
    player.z_index = 100 + floori(player_position.y)
    camera.position = player.position
    var effective_zoom := camera_zoom * INTERIOR_ZOOM_MULTIPLIER if _in_interior() else camera_zoom
    camera.zoom = Vector2(effective_zoom, effective_zoom)
    camera.reset_smoothing()

func _refresh_world_state() -> void:
    grid = world.build_grid(village, world_changes)
    if world_view != null:
        world_view.configure(world, grid, village, null, world_changes)
    if benchmark_scene != null:
        benchmark_scene.configure(world, grid, world_changes, resource_states, village_memory.consequence_flags(resident_memory), village)
    if procedural_resource_overlay != null:
        procedural_resource_overlay.configure(world, village, world_changes)
    if world_cache != null:
        world_cache.render_target_update_mode = SubViewport.UPDATE_ONCE
    if gameplay_hud != null:
        gameplay_hud.configure_map(world, grid, player_position, _building_map())
    _refresh_player_transform()
    _refresh_npc_schedules(true)

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
    var effective_zoom := camera_zoom * INTERIOR_ZOOM_MULTIPLIER if _in_interior() else camera_zoom
    camera.zoom = Vector2(effective_zoom, effective_zoom)

func _build_hud() -> void:
    gameplay_hud = GameplayHud.new()
    add_child(gameplay_hud)
    gameplay_hud.recipe_requested.connect(_craft_recipe)
    gameplay_hud.cooking_requested.connect(_cook_recipe)
    gameplay_hud.meal_requested.connect(_eat_meal)
    gameplay_hud.storage_requested.connect(_withdraw_home_stores)
    gameplay_hud.pause_requested.connect(_pause_journey)
    title_label = gameplay_hud.title_label
    subtitle_label = gameplay_hud.subtitle_label
    day_label = gameplay_hud.day_label
    stores_label = gameplay_hud.stores_label
    debug_label = gameplay_hud.debug_label
    hint_label = gameplay_hud.hint_label
    interaction_panel = gameplay_hud.interaction_panel
    interaction_label = gameplay_hud.interaction_label
    gameplay_hud.configure_map(world, grid, player_position, _building_map())

func _building_map() -> Dictionary:
    var result: Dictionary = {}
    for building_variant in world.buildings():
        if building_variant is Dictionary:
            var building: Dictionary = building_variant
            result[str(building.get("id", ""))] = building.duplicate(true)
    return result

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
    if gameplay_hud == null:
        return
    var tile := Vector2i(floori(player_position.x), floori(player_position.y))
    var tile_name := "interior floor" if _in_interior() else world.tile_at(grid, tile)
    var recipes: Dictionary = {}
    for recipe_id in day_state.recipe_ids():
        recipes[recipe_id] = day_state.recipe_preview(recipe_id)
    gameplay_hud.refresh({
        "village_name": str(village.get("name", "CLOVERMERE")),
        "folk": world.npcs().size(),
        "zoom": camera_zoom,
        "day": day_state.day,
        "clock": day_state.format_clock(),
        "energy": day_state.energy,
        "max_energy": day_state.max_energy(),
        "inventory": day_state.inventory,
        "storage": day_state.storage,
        "kit_ready": day_state.has_upgrade("tinkers-kit"),
        "recipes": recipes,
        "near_workshop": _is_near_workshop(),
        "near_home": _is_near_home(),
        "interior_mode": _in_interior(),
        "cooking": _cooking_snapshot(),
        "meals": day_state.meals.duplicate(true),
        "next_work_effects": day_state.next_work_effects.duplicate(true),
        "location_name": interior_contract.definition_for(interior_location).get("short_name", "Interior") if _in_interior() else "Clovermere",
        "interaction": interaction_message,
        "hint": "Click to walk  ·  E interact  ·  B pack  ·  C craft  ·  T talk  ·  Esc pause" if _in_interior() else "Click ground  walk     Click a house  visit     Click a resource  work     B  pack     C  craft     E  interact     T  talk     Wheel  zoom     WASD  wander",
        "debug_visible": debug_visible,
        "debug": "POS  %6.2f, %6.2f   TILE  %s   FPS  %3d       F  toggle metrics" % [player_position.x, player_position.y, tile_name, Engine.get_frames_per_second()]
    })
    gameplay_hud.set_player_position(player_position)

func _cooking_snapshot() -> Dictionary:
    var result: Dictionary = {}
    for recipe_id in day_state.cooking_ids():
        result[recipe_id] = day_state.cooking_preview(recipe_id)
    return result

func _load_save() -> bool:
    if active_work_action != null and active_work_action.is_active():
        _cancel_work_action()
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
    exterior_position = player_position
    interior_location = ""
    var loaded_changes = normalized.get("world_changes", {})
    world_changes = loaded_changes.duplicate(true) if loaded_changes is Dictionary else {}
    var loaded_day_state = normalized.get("day_state", {})
    day_state = DayState.new()
    if loaded_day_state is Dictionary:
        day_state.from_dict(loaded_day_state)
    var loaded_resource_states = normalized.get("resource_states", {})
    resource_states = loaded_resource_states.duplicate(true) if loaded_resource_states is Dictionary else {}
    var loaded_dialogue_flags = normalized.get("dialogue_flags", {})
    dialogue_flags = loaded_dialogue_flags.duplicate(true) if loaded_dialogue_flags is Dictionary else {}
    var loaded_resident_memory = normalized.get("resident_memory", {})
    resident_memory = village_memory.from_dict(loaded_resident_memory if loaded_resident_memory is Dictionary else {})
    for resident_id in village_memory.resident_ids():
        if bool(dialogue_flags.get(resident_id, false)) and int(resident_memory.get(resident_id, {}).get("stage", 0)) == 0:
            village_memory.mark_introduced(resident_memory, resident_id, day_state.day)
    day_state.normalize_resource_states(world_changes, resource_states, world.resources(village), day_state.day)
    _refresh_world_state()
    var loaded_location := str(normalized.get("location", "village"))
    var loaded_interior = normalized.get("interior", {})
    var local_position := Vector2(-1, -1)
    if loaded_interior is Dictionary:
        var raw_local = loaded_interior.get("player", {})
        if raw_local is Dictionary:
            local_position = Vector2(float(raw_local.get("x", -1.0)), float(raw_local.get("y", -1.0)))
    if interior_contract.is_interior(loaded_location):
        _enter_interior(loaded_location, false, local_position)
    else:
        _set_world_visibility(true)
    return true

func _save_game() -> bool:
    var payload := {
        "version": World.SAVE_VERSION,
        "village": village,
        "player": {"x": exterior_position.x, "y": exterior_position.y},
        "location": interior_location if _in_interior() else "village",
        "interior": {"building_id": interior_location, "player": {"x": player_position.x, "y": player_position.y}} if _in_interior() else {},
        "dialogue_flags": dialogue_flags.duplicate(true),
        "resident_memory": village_memory.to_dict(resident_memory),
        "world_changes": world_changes.duplicate(true),
        "resource_states": resource_states.duplicate(true),
        "day_state": day_state.to_dict()
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
