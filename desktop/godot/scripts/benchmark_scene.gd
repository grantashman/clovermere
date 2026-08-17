extends Node2D
class_name ClovermereBenchmarkScene

const ArtAssetPack = preload("res://scripts/art_asset_pack.gd")
const TILE_SIZE := 16.0
const BRASS := Color("#e1bf70")
const SHADOW := Color("#152820")
const WOOD := Color("#80563f")
const WOOD_LIGHT := Color("#c18a59")
const HERB := Color("#cbd996")

var world
var grid: Array = []
var world_changes: Dictionary = {}
var anchor_positions: Dictionary = {}
var building_anchors: Dictionary = {}
var art_sprites: Dictionary = {}
var terrain_sprites: Dictionary = {}
var terrain_sprite: Sprite2D

func configure(_world, _grid: Array, _changes: Dictionary) -> Dictionary:
    world = _world
    grid = _grid
    world_changes = _changes.duplicate(true)
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
        if resource_id in ["oak-at-the-crossing", "greycap-boulder", "foxglove-patch"]:
            anchor_positions[resource_id] = Vector2(float(resource.get("x", 0)) + 0.5, float(resource.get("y", 0)) + 0.5)
    _mount_authored_terrain()
    _mount_authored_assets()
    queue_redraw()
    return anchor_positions

func _mount_authored_terrain() -> void:
    if is_instance_valid(terrain_sprite):
        terrain_sprite.queue_free()
    terrain_sprite = null
    terrain_sprites.clear()
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
    terrain_sprite.z_index = -1
    add_child(terrain_sprite)

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
    var cottage: Vector2 = _world_point(anchor_positions.get("greenbriar-cottage", Vector2.ZERO))
    var workshop: Vector2 = _world_point(anchor_positions.get("tinker-workshop", Vector2.ZERO))
    var tree: Vector2 = _world_point(anchor_positions.get("oak-at-the-crossing", Vector2.ZERO)) + Vector2(0, -8)
    var stone: Vector2 = _world_point(anchor_positions.get("greycap-boulder", Vector2.ZERO)) + Vector2(0, 2)
    var herb: Vector2 = _world_point(anchor_positions.get("foxglove-patch", Vector2.ZERO)) + Vector2(0, -2)
    if anchor_positions.has("greenbriar-cottage"):
        art_sprites["cottage"] = ArtAssetPack.sprite("cottage", self, cottage, 0)
    if anchor_positions.has("tinker-workshop"):
        art_sprites["workshop"] = ArtAssetPack.sprite("workshop", self, workshop, 0)
    if anchor_positions.has("oak-at-the-crossing"):
        art_sprites["tree"] = ArtAssetPack.sprite("tree", self, tree, 2)
    if anchor_positions.has("greycap-boulder"):
        art_sprites["stone"] = ArtAssetPack.sprite("stone", self, stone, 2)
    if anchor_positions.has("foxglove-patch") and not bool(world_changes.get("foxglove-patch", false)):
        art_sprites["herb"] = ArtAssetPack.sprite("herb", self, herb, 2)

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
    _draw_building_contact("greenbriar-cottage")
    _draw_building_contact("tinker-workshop")
    _draw_cottage_props()
    _draw_workshop_props()
    _draw_resource_contacts()

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
