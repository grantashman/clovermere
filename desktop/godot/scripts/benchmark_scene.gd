extends Node2D
class_name ClovermereBenchmarkScene

const ArtAssetPack = preload("res://scripts/art_asset_pack.gd")
const LightingAccents = preload("res://scripts/lighting_accents.gd")
const TILE_SIZE := 16.0
const DEPTH_LAYERS := {
    "terrain": -4,
    "contact": -2,
    "building": 0,
    "props": 2,
    "resource": 6,
    "foreground": 8
}
const BRASS := Color("#e1bf70")
const SHADOW := Color("#152820")
const WOOD := Color("#80563f")
const WOOD_LIGHT := Color("#c18a59")
const HERB := Color("#cbd996")

var world
var grid: Array = []
var world_changes: Dictionary = {}
var resource_states: Dictionary = {}
var anchor_positions: Dictionary = {}
var building_anchors: Dictionary = {}
var art_sprites: Dictionary = {}
var terrain_sprites: Dictionary = {}
var resource_art_assets: Dictionary = {}
var terrain_cluster_sprites: Dictionary = {}
var terrain_sprite: Sprite2D
var lighting_accents: Node2D
var animation_phase := 0.0
var redraw_accumulator := 0.0
var minute_of_day := 480
var fireflies_visible := false
var active_resource_id := ""
var active_work_progress := 0.0
var regrowth_resource_ids: Dictionary = {}

func configure(_world, _grid: Array, _changes: Dictionary, _resource_states: Dictionary = {}) -> Dictionary:
    world = _world
    grid = _grid
    world_changes = _changes.duplicate(true)
    resource_states = _resource_states.duplicate(true)
    anchor_positions.clear()
    building_anchors.clear()
    if world == null:
        return anchor_positions
    for building_variant in world.buildings():
        if not building_variant is Dictionary:
            continue
        var building: Dictionary = building_variant
        var id := str(building.get("id", ""))
        building_anchors[id] = building.duplicate(true)
        anchor_positions[id] = Vector2(float(building.get("x", 0)) + float(building.get("w", 1)) * 0.5, float(building.get("y", 0)) + float(building.get("h", 1)) * 0.5)
    anchor_positions["central-crossing"] = Vector2(float(world.SETTLEMENT_ORIGIN.x + 30) + 0.5, float(world.SETTLEMENT_ORIGIN.y + 11) + 0.5)
    for npc_variant in world.npcs():
        if not npc_variant is Dictionary:
            continue
        var npc: Dictionary = npc_variant
        var npc_id := str(npc.get("id", ""))
        if npc_id in ["alda-fen", "orin-reed"]:
            anchor_positions[npc_id] = Vector2(float(npc.get("x", 0)) + 0.5, float(npc.get("y", 0)) + 0.9)
    for resource_variant in world.resources():
        if not resource_variant is Dictionary:
            continue
        var resource: Dictionary = resource_variant
        var resource_id := str(resource.get("id", ""))
        if is_authored_area(Vector2i(int(resource.get("x", 0)), int(resource.get("y", 0)))):
            anchor_positions[resource_id] = Vector2(float(resource.get("x", 0)) + 0.5, float(resource.get("y", 0)) + 0.5)
    _mount_authored_terrain()
    _mount_authored_assets()
    _configure_lighting_accents()
    queue_redraw()
    return anchor_positions

func depth_layers() -> Dictionary:
    return DEPTH_LAYERS.duplicate(true)

func terrain_cluster_asset_ids() -> Array:
    return ArtAssetPack.terrain_cluster_asset_ids()

func _configure_lighting_accents() -> void:
    if lighting_accents == null:
        lighting_accents = LightingAccents.new()
        lighting_accents.name = "WindowLightAccents"
        lighting_accents.z_index = DEPTH_LAYERS["foreground"] + 1
        add_child(lighting_accents)
    var points: Array[Vector2] = []
    for building_id in ["greenbriar-cottage", "clovermere-hall", "tinker-workshop", "herbalists-garden", "old-barn"]:
        if not anchor_positions.has(building_id):
            continue
        var centre: Vector2 = _world_point(anchor_positions[building_id])
        points.append(centre + Vector2(-20, 13))
        points.append(centre + Vector2(2, 13))
        points.append(centre + Vector2(22, 13))
    lighting_accents.configure(points)
    lighting_accents.set_time(minute_of_day)

func _process(delta: float) -> void:
    var step := maxf(delta, 0.0)
    animation_phase = fmod(animation_phase + step, TAU)
    redraw_accumulator += step
    for resource_id_variant in regrowth_resource_ids.keys():
        var resource_id: String = str(resource_id_variant)
        regrowth_resource_ids[resource_id] = float(regrowth_resource_ids[resource_id]) - step
        if float(regrowth_resource_ids[resource_id]) <= 0.0:
            regrowth_resource_ids.erase(resource_id)
    # The authored benchmark contains a comparatively expensive full-scene draw.
    # Updating its animated accents at 20 Hz preserves readable motion while keeping
    # the native desktop render budget above the release gate.
    if redraw_accumulator >= (1.0 / 20.0):
        redraw_accumulator = fmod(redraw_accumulator, 1.0 / 20.0)
        queue_redraw()

func set_time(minutes: int) -> void:
    var next_minute := posmod(minutes, 1440)
    var next_fireflies := next_minute >= 1110 or next_minute < 330
    if next_minute == minute_of_day and next_fireflies == fireflies_visible:
        return
    minute_of_day = next_minute
    fireflies_visible = next_fireflies
    if lighting_accents != null:
        lighting_accents.set_time(minute_of_day)
    queue_redraw()

func set_active_work(resource_id: String, progress: float) -> void:
    active_resource_id = resource_id
    active_work_progress = clampf(progress, 0.0, 1.0)

func clear_active_work() -> void:
    active_resource_id = ""
    active_work_progress = 0.0
    queue_redraw()

func begin_regrowth(resource_id: String) -> void:
    if anchor_positions.has(resource_id):
        regrowth_resource_ids[resource_id] = 4.0
        queue_redraw()

func _mount_authored_terrain() -> void:
    if is_instance_valid(terrain_sprite):
        terrain_sprite.queue_free()
    terrain_sprite = null
    terrain_sprites.clear()
    for node in terrain_cluster_sprites.values():
        if is_instance_valid(node):
            node.queue_free()
    terrain_cluster_sprites.clear()
    var bounds := benchmark_bounds()
    var terrain_image := Image.create(bounds.size.x * int(TILE_SIZE), bounds.size.y * int(TILE_SIZE), false, Image.FORMAT_RGBA8)
    terrain_image.fill(Color(0, 0, 0, 0))
    for y in range(bounds.position.y, bounds.end.y):
        for x in range(bounds.position.x, bounds.end.x):
            var tile := Vector2i(x, y)
            var asset_id := _terrain_asset_for(tile)
            if asset_id.is_empty():
                continue
            terrain_sprites[tile] = asset_id
            var source_texture := ArtAssetPack.texture_for(asset_id)
            if source_texture == null:
                continue
            terrain_image.blit_rect(source_texture.get_image(), Rect2i(Vector2i.ZERO, Vector2i(source_texture.get_size())), Vector2i((x - bounds.position.x) * int(TILE_SIZE), (y - bounds.position.y) * int(TILE_SIZE)))
    terrain_sprite = Sprite2D.new()
    terrain_sprite.name = "AuthoredTerrainField"
    terrain_sprite.texture = ImageTexture.create_from_image(terrain_image)
    terrain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    terrain_sprite.position = (Vector2(bounds.position) + Vector2(bounds.size) * 0.5) * TILE_SIZE
    terrain_sprite.z_index = DEPTH_LAYERS["terrain"]
    add_child(terrain_sprite)
    _mount_terrain_clusters()

func _mount_terrain_clusters() -> void:
    var placements := {
        "meadow": Vector2(float(world.SETTLEMENT_ORIGIN.x + 31), float(world.SETTLEMENT_ORIGIN.y + 13)),
        "forest_floor": Vector2(float(world.SETTLEMENT_ORIGIN.x + 1), float(world.SETTLEMENT_ORIGIN.y + 14)),
        "village_verge": Vector2(float(world.SETTLEMENT_ORIGIN.x + 28), float(world.SETTLEMENT_ORIGIN.y + 21))
    }
    var assets := {
        "meadow": "meadow_cluster",
        "forest_floor": "forest_floor_cluster",
        "village_verge": "village_verge_cluster"
    }
    for cluster_id in placements.keys():
        var asset_id: String = assets[cluster_id]
        var node := ArtAssetPack.sprite(asset_id, self, _world_point(placements[cluster_id]), DEPTH_LAYERS["terrain"] + 1)
        terrain_cluster_sprites[cluster_id] = node

func _terrain_asset_for(tile: Vector2i) -> String:
    if tile.y < 0 or tile.y >= grid.size() or tile.x < 0 or tile.x >= grid[tile.y].size():
        return ""
    var tile_kind := str(grid[tile.y][tile.x])
    if tile_kind in ["b", "f", "s", "h"]:
        return ""
    if tile_kind in ["p", "d"]:
        return _path_asset(tile)
    if tile_kind == "w":
        return "water"
    var oak_tile := Vector2i(roundi(float(anchor_positions.get("oak-at-the-crossing", Vector2(-999, -999)).x)), roundi(float(anchor_positions.get("oak-at-the-crossing", Vector2(-999, -999)).y)))
    if anchor_positions.has("oak-at-the-crossing") and tile.distance_squared_to(oak_tile) <= 10:
        return "woodland"
    var herb_tile := Vector2i(roundi(float(anchor_positions.get("foxglove-patch", Vector2(-999, -999)).x)), roundi(float(anchor_positions.get("foxglove-patch", Vector2(-999, -999)).y)))
    if anchor_positions.has("foxglove-patch") and tile.distance_squared_to(herb_tile) <= 5:
        return "soil"
    if tile_kind in ["t", "m"]:
        return "woodland"
    if tile_kind == "r":
        return "grass_b"
    var variant: int = abs(tile.x * 17 + tile.y * 31) % 3
    return ["grass_a", "grass_b", "grass_c"][variant]

func _path_asset(tile: Vector2i) -> String:
    var mask := 0
    if _is_path_tile(tile + Vector2i(0, -1)):
        mask |= 1
    if _is_path_tile(tile + Vector2i(1, 0)):
        mask |= 2
    if _is_path_tile(tile + Vector2i(0, 1)):
        mask |= 4
    if _is_path_tile(tile + Vector2i(-1, 0)):
        mask |= 8
    match mask:
        15:
            return "path_cross"
        11:
            return "path_t_n"
        14:
            return "path_t_s"
        13:
            return "path_t_w"
        7:
            return "path_t_e"
        3:
            return "path_corner_ne"
        9:
            return "path_corner_nw"
        6:
            return "path_corner_se"
        12:
            return "path_corner_sw"
        1, 4:
            return "path_v"
        2, 8:
            return "path_h"
        _:
            return "path_cross"

func _is_path_tile(tile: Vector2i) -> bool:
    if tile.y < 0 or tile.y >= grid.size() or tile.x < 0 or tile.x >= grid[tile.y].size():
        return false
    return str(grid[tile.y][tile.x]) in ["p", "d"]

func _mount_authored_assets() -> void:
    for node in art_sprites.values():
        if is_instance_valid(node):
            node.queue_free()
    art_sprites.clear()
    resource_art_assets.clear()
    var cottage: Vector2 = _world_point(anchor_positions.get("greenbriar-cottage", Vector2.ZERO))
    var workshop: Vector2 = _world_point(anchor_positions.get("tinker-workshop", Vector2.ZERO))
    if anchor_positions.has("greenbriar-cottage"):
        art_sprites["cottage"] = ArtAssetPack.sprite("cottage", self, cottage, DEPTH_LAYERS["building"])
    if anchor_positions.has("tinker-workshop"):
        art_sprites["workshop"] = ArtAssetPack.sprite("workshop", self, workshop, DEPTH_LAYERS["building"])
    for building_id in ["clovermere-hall", "herbalists-garden", "old-barn"]:
        var asset_id := ArtAssetPack.facade_asset_for(building_id)
        if asset_id.is_empty() or not anchor_positions.has(building_id):
            continue
        art_sprites[asset_id] = ArtAssetPack.sprite(asset_id, self, _world_point(anchor_positions[building_id]), DEPTH_LAYERS["building"])
    for resource_variant in world.resources():
        if not resource_variant is Dictionary:
            continue
        var resource: Dictionary = resource_variant
        var resource_id := str(resource.get("id", ""))
        var tile := Vector2i(int(resource.get("x", 0)), int(resource.get("y", 0)))
        if not anchor_positions.has(resource_id) or not is_authored_area(tile):
            continue
        var kind := str(resource.get("kind", ""))
        var cleared := bool(world_changes.get(resource_id, false))
        var state_variant := _resource_state_variant(resource_id, kind, cleared)
        var asset_id := ArtAssetPack.resource_asset_for(kind, cleared, state_variant)
        if asset_id.is_empty():
            continue
        resource_art_assets[resource_id] = asset_id
        var offset := Vector2(0, -8) if kind == "tree" else Vector2(0, -2) if kind == "herb" else Vector2(0, 2)
        var sprite := ArtAssetPack.sprite(asset_id, self, _world_point(anchor_positions[resource_id]) + offset, DEPTH_LAYERS["resource"])
        art_sprites[resource_id] = sprite
        if resource_id == "oak-at-the-crossing":
            art_sprites["tree"] = sprite
        elif resource_id == "greycap-boulder":
            art_sprites["stone"] = sprite
        elif resource_id == "foxglove-patch":
            art_sprites["herb"] = sprite
        elif resource_id == "ironroot-vein":
            art_sprites["ore"] = sprite

func _resource_state_variant(resource_id: String, kind: String, cleared: bool) -> String:
    if not cleared:
        return ""
    var state: Dictionary = resource_states.get(resource_id, {}) if resource_states.get(resource_id, {}) is Dictionary else {}
    var stage := str(state.get("stage", ""))
    if kind == "tree" and stage == "felled" and resource_id != "oak-at-the-crossing":
        return "debris"
    if not stage.is_empty():
        return stage
    if kind == "tree" and resource_id != "oak-at-the-crossing":
        return "debris"
    return ""

func benchmark_bounds() -> Rect2i:
    if world == null:
        return Rect2i()
    return Rect2i(world.SETTLEMENT_ORIGIN.x - 10, world.SETTLEMENT_ORIGIN.y + 2, 82, 48)

func is_authored_area(tile: Vector2i) -> bool:
    return benchmark_bounds().has_point(tile)

func _draw() -> void:
    if world == null:
        return
    _draw_crossing()
    for building_id in ["greenbriar-cottage", "clovermere-hall", "tinker-workshop", "herbalists-garden", "old-barn"]:
        _draw_building_contact(building_id)
    _draw_cottage_props()
    _draw_hall_props()
    _draw_workshop_props()
    _draw_garden_props()
    _draw_barn_props()
    _draw_resource_contacts()
    _draw_living_terrain()

func _draw_living_terrain() -> void:
    _draw_resource_state_terrain()
    _draw_water_shimmer()
    _draw_foliage_sway()
    _draw_active_work_feedback()
    _draw_regrowth_feedback()
    if fireflies_visible:
        _draw_fireflies()

func _draw_resource_state_terrain() -> void:
    for resource_variant in world.resources():
        if not resource_variant is Dictionary:
            continue
        var resource: Dictionary = resource_variant
        var resource_id := str(resource.get("id", ""))
        if not anchor_positions.has(resource_id) or not bool(world_changes.get(resource_id, false)):
            continue
        var kind := str(resource.get("kind", ""))
        var state: Dictionary = resource_states.get(resource_id, {}) if resource_states.get(resource_id, {}) is Dictionary else {}
        var stage := str(state.get("stage", _resource_state_variant(resource_id, kind, true)))
        var point: Vector2 = _world_point(anchor_positions[resource_id])
        if kind == "tree":
            draw_rect(Rect2(point + Vector2(-12, 5), Vector2(24, 4)), Color("#765947", 0.36), true)
            if stage == "sprout":
                draw_line(point + Vector2(-7, 5), point + Vector2(-8, -3), Color("#91b961", 0.74), 1.0, false)
                draw_line(point + Vector2(7, 5), point + Vector2(8, -2), Color("#6f9b58", 0.74), 1.0, false)
            elif stage == "young":
                draw_line(point + Vector2(0, 5), point + Vector2(1, -7), Color("#704936", 0.76), 2.0, false)
                draw_circle(point + Vector2(1, -9), 4.0, Color("#6f9b58", 0.68))
        elif kind == "stone":
            draw_rect(Rect2(point + Vector2(-10, 4), Vector2(20, 4)), Color("#5d665d", 0.3), true)
            if stage == "fractures":
                draw_line(point + Vector2(-6, 2), point + Vector2(-1, -4), Color("#a7a78d", 0.8), 1.0, false)
                draw_line(point + Vector2(-1, -4), point + Vector2(6, 1), Color("#a7a78d", 0.72), 1.0, false)
        elif kind == "ore" and stage == "crystals":
            draw_colored_polygon(PackedVector2Array([point + Vector2(-5, 4), point + Vector2(-2, -7), point + Vector2(1, 4)]), Color("#91b59e", 0.82))
            draw_colored_polygon(PackedVector2Array([point + Vector2(1, 4), point + Vector2(5, -5), point + Vector2(7, 4)]), Color("#6f9b8c", 0.82))

func _draw_water_shimmer() -> void:
    var frame_id := "water_shimmer_a" if int(floor(animation_phase * 3.0)) % 2 == 0 else "water_shimmer_b"
    var frame := ArtAssetPack.texture_for(frame_id)
    if frame == null:
        return
    for tile_variant in terrain_sprites.keys():
        var tile: Vector2i = tile_variant
        var asset_id := str(terrain_sprites[tile_variant])
        if asset_id not in ["water", "water_edge_n", "water_edge_s", "water_edge_e", "water_edge_w", "water_corner"]:
            continue
        draw_texture_rect(frame, Rect2(Vector2(tile) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE)), false, Color(1, 1, 1, 0.28))

func _draw_foliage_sway() -> void:
    var sway := sin(animation_phase * 1.7) * 1.2
    for resource_variant in world.resources():
        if not resource_variant is Dictionary:
            continue
        var resource: Dictionary = resource_variant
        if str(resource.get("kind", "")) != "tree":
            continue
        var resource_id := str(resource.get("id", ""))
        if not anchor_positions.has(resource_id) or bool(world_changes.get(resource_id, false)):
            continue
        var point: Vector2 = _world_point(anchor_positions[resource_id]) + Vector2(0, -26)
        draw_line(point + Vector2(-7, 8), point + Vector2(-8 + sway, 3), Color("#6f9b58", 0.72), 1.0, false)
        draw_line(point + Vector2(5, 6), point + Vector2(6 + sway, 1), Color("#a7bd6a", 0.68), 1.0, false)

func _draw_active_work_feedback() -> void:
    if active_resource_id.is_empty() or not anchor_positions.has(active_resource_id):
        return
    var point: Vector2 = _world_point(anchor_positions[active_resource_id])
    var pulse := 0.5 + 0.5 * sin(animation_phase * 8.0)
    var radius := 7.0 + active_work_progress * 5.0
    draw_arc(point + Vector2(0, -4), radius, -2.5, -0.65, 6, Color(BRASS, 0.45 + pulse * 0.3), 1.0, false)
    draw_rect(Rect2(point + Vector2(-1, -18 - pulse * 2.0), Vector2(2, 2)), Color(BRASS, 0.65 + pulse * 0.3), true)
    draw_rect(Rect2(point + Vector2(7 + pulse * 2.0, -11), Vector2(2, 2)), Color("#d49a6a", 0.6), true)

func _draw_regrowth_feedback() -> void:
    for resource_id_variant in regrowth_resource_ids.keys():
        var resource_id: String = str(resource_id_variant)
        if not anchor_positions.has(resource_id):
            continue
        var point: Vector2 = _world_point(anchor_positions[resource_id])
        var remaining: float = clampf(float(regrowth_resource_ids[resource_id]) / 4.0, 0.0, 1.0)
        var lift := (1.0 - remaining) * 3.0
        draw_line(point + Vector2(-5, 5), point + Vector2(-6, -2 - lift), Color("#a9c987", 0.9), 1.0, false)
        draw_line(point + Vector2(0, 5), point + Vector2(1, -5 - lift), Color("#91b961", 0.95), 1.0, false)
        draw_line(point + Vector2(5, 5), point + Vector2(6, -1 - lift), Color("#6f9b58", 0.9), 1.0, false)

func _draw_fireflies() -> void:
    var anchors := ["oak-at-the-crossing", "foxglove-patch", "moonmint-patch"]
    for index in anchors.size():
        var resource_id: String = anchors[index]
        if not anchor_positions.has(resource_id):
            continue
        var base: Vector2 = _world_point(anchor_positions[resource_id])
        var angle := animation_phase * (1.0 + float(index) * 0.17) + float(index) * 2.1
        var point := base + Vector2(cos(angle) * (10.0 + index * 2.0), -12.0 + sin(angle * 1.7) * 7.0)
        var glow := 0.45 + 0.35 * sin(animation_phase * 5.0 + index)
        draw_circle(point + Vector2(1.5, 1.5), 5.0, Color(BRASS, glow * 0.12))
        draw_rect(Rect2(point, Vector2(4, 4)), Color(BRASS, glow), true)

func _draw_crossing() -> void:
    var centre: Vector2 = _world_point(anchor_positions.get("central-crossing", Vector2.ZERO))
    draw_rect(Rect2(centre + Vector2(-14, -14), Vector2(28, 28)), Color(0.12, 0.18, 0.13, 0.16), true)
    draw_rect(Rect2(centre + Vector2(-12, -2), Vector2(5, 4)), Color(BRASS, 0.42), true)
    draw_rect(Rect2(centre + Vector2(7, -2), Vector2(5, 4)), Color(BRASS, 0.42), true)
    draw_rect(Rect2(centre + Vector2(-2, -12), Vector2(4, 5)), Color(BRASS, 0.36), true)
    draw_rect(Rect2(centre + Vector2(-2, 7), Vector2(4, 5)), Color(BRASS, 0.36), true)

func _draw_building_contact(building_id: String) -> void:
    var building: Dictionary = building_anchors.get(building_id, {})
    if building.is_empty():
        return
    var rect := Rect2(Vector2(float(building.x), float(building.y)) * TILE_SIZE, Vector2(float(building.w), float(building.h)) * TILE_SIZE)
    var points := PackedVector2Array([
        rect.position + Vector2(8, rect.size.y - 1), rect.position + Vector2(rect.size.x - 8, rect.size.y - 1),
        rect.position + Vector2(rect.size.x + 7, rect.size.y + 6), rect.position + Vector2(3, rect.size.y + 6)
    ])
    draw_colored_polygon(points, Color(SHADOW, 0.28))
    draw_line(rect.position + Vector2(6, rect.size.y), rect.position + Vector2(rect.size.x - 6, rect.size.y), Color(BRASS, 0.34), 2.0, false)

func _draw_cottage_props() -> void:
    var building: Dictionary = building_anchors.get("greenbriar-cottage", {})
    if building.is_empty():
        return
    var step := Vector2(float(building.x) + float(building.w) * 0.5, float(building.y + building.h)) * TILE_SIZE
    draw_rect(Rect2(step + Vector2(-15, 1), Vector2(30, 5)), WOOD, true)
    draw_rect(Rect2(step + Vector2(-10, 6), Vector2(20, 4)), WOOD_LIGHT, true)
    draw_rect(Rect2(step + Vector2(-26, -1), Vector2(6, 5)), Color("#5f7d58"), true)
    draw_rect(Rect2(step + Vector2(20, -1), Vector2(6, 5)), Color("#5f7d58"), true)

func _draw_workshop_props() -> void:
    var building: Dictionary = building_anchors.get("tinker-workshop", {})
    if building.is_empty():
        return
    var base := Vector2(float(building.x), float(building.y + building.h + 1)) * TILE_SIZE
    draw_rect(Rect2(base + Vector2(4, 0), Vector2(38, 5)), WOOD, true)
    draw_rect(Rect2(base + Vector2(7, -5), Vector2(6, 5)), WOOD_LIGHT, true)
    draw_rect(Rect2(base + Vector2(27, -5), Vector2(6, 5)), WOOD_LIGHT, true)
    draw_rect(Rect2(base + Vector2(46, 3), Vector2(9, 9)), Color("#6b4938"), true)
    draw_rect(Rect2(base + Vector2(48, 5), Vector2(5, 3)), Color("#b88954"), true)
    draw_line(base + Vector2(17, -1), base + Vector2(17, -12), Color("#d3b16f"), 2.0, false)
    draw_rect(Rect2(base + Vector2(13, -14), Vector2(8, 4)), Color("#263f32"), true)

func _draw_hall_props() -> void:
    var building: Dictionary = building_anchors.get("clovermere-hall", {})
    if building.is_empty():
        return
    var base := Vector2(float(building.x), float(building.y + building.h + 1)) * TILE_SIZE
    draw_rect(Rect2(base + Vector2(16, 0), Vector2(48, 5)), Color("#6f6250"), true)
    draw_rect(Rect2(base + Vector2(27, -5), Vector2(24, 5)), Color("#b5a57b"), true)
    draw_rect(Rect2(base + Vector2(58, -1), Vector2(3, 10)), Color("#704936"), true)
    draw_circle(base + Vector2(59, -4), 4.0, Color(BRASS, 0.75))

func _draw_garden_props() -> void:
    var building: Dictionary = building_anchors.get("herbalists-garden", {})
    if building.is_empty():
        return
    var base := Vector2(float(building.x), float(building.y + building.h + 1)) * TILE_SIZE
    for offset in [4.0, 28.0, 52.0, 76.0, 100.0]:
        draw_rect(Rect2(base + Vector2(offset, 2), Vector2(17, 5)), Color("#875d4d"), true)
        draw_rect(Rect2(base + Vector2(offset + 4, -2), Vector2(2, 5)), HERB, true)
        draw_rect(Rect2(base + Vector2(offset + 11, -3), Vector2(2, 6)), Color("#d7b46f"), true)
    draw_rect(Rect2(base + Vector2(130, -1), Vector2(12, 7)), Color("#704936"), true)
    draw_rect(Rect2(base + Vector2(132, 1), Vector2(8, 3)), Color("#a9c987"), true)

func _draw_barn_props() -> void:
    var building: Dictionary = building_anchors.get("old-barn", {})
    if building.is_empty():
        return
    var base := Vector2(float(building.x), float(building.y + building.h + 1)) * TILE_SIZE
    draw_rect(Rect2(base + Vector2(8, 1), Vector2(28, 8)), Color("#704936"), true)
    draw_rect(Rect2(base + Vector2(11, -2), Vector2(22, 4)), Color("#c48959"), true)
    draw_rect(Rect2(base + Vector2(89, 0), Vector2(16, 9)), Color("#704936"), true)
    draw_rect(Rect2(base + Vector2(92, 2), Vector2(10, 5)), Color("#a7a78d"), true)

func _draw_resource_contacts() -> void:
    for resource_id in ["oak-at-the-crossing", "greycap-boulder", "foxglove-patch"]:
        if not anchor_positions.has(resource_id):
            continue
        var point: Vector2 = _world_point(anchor_positions[resource_id])
        _draw_ellipse_custom(point + Vector2(3, 6), Vector2(13, 5), Color(SHADOW, 0.22))
    if anchor_positions.has("foxglove-patch") and not bool(world_changes.get("foxglove-patch", false)):
        var herb_point: Vector2 = _world_point(anchor_positions["foxglove-patch"])
        for offset in [-6.0, 0.0, 6.0]:
            draw_rect(Rect2(herb_point + Vector2(offset - 2, -9), Vector2(4, 3)), HERB, true)

func _draw_ellipse_custom(centre: Vector2, radius: Vector2, color: Color) -> void:
    var points := PackedVector2Array()
    for index in range(16):
        var angle := float(index) * TAU / 16.0
        points.append(centre + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
    draw_colored_polygon(points, color)

func _world_point(tile_position: Vector2) -> Vector2:
    return tile_position * TILE_SIZE
