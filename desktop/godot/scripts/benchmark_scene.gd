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
    _mount_authored_assets()
    queue_redraw()
    return anchor_positions

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
