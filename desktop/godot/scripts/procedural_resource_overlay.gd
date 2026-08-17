extends Node2D
class_name ClovermereProceduralResourceOverlay

const ArtAssetPack = preload("res://scripts/art_asset_pack.gd")

const TILE_SIZE := 16.0
const TREE_DARK := Color("#21453a")
const TREE := Color("#3f7650")
const TREE_LIGHT := Color("#88ae62")
const WOOD := Color("#744f3d")
const ROCK_DARK := Color("#4d5a55")
const ROCK := Color("#777a6e")
const ROCK_LIGHT := Color("#b1a88b")
const WATER_DARK := Color("#326b73")
const WATER_LIGHT := Color("#86c1ac")
const HERB := Color("#a7bd6a")
const FLOWER := Color("#d6b06e")
const WARM := Color("#e3c77d")

var world
var village: Dictionary = {}
var world_changes: Dictionary = {}
var resource_count := 0
var resource_sprites: Array[Sprite2D] = []

func configure(_world, _village: Dictionary, _changes: Dictionary) -> void:
    world = _world
    village = _village.duplicate(true)
    world_changes = _changes.duplicate(true)
    for sprite in resource_sprites:
        if is_instance_valid(sprite):
            sprite.queue_free()
    resource_sprites.clear()
    resource_count = 0
    if world != null:
        for resource in world.resources(village):
            if str(resource.get("id", "")).begins_with("proc-") and not _is_authored(resource):
                resource_count += 1
        _mount_tree_sprites()
    queue_redraw()

func _draw() -> void:
    if world == null:
        return
    for resource_variant in world.resources(village):
        var resource: Dictionary = resource_variant
        var resource_id := str(resource.get("id", ""))
        if not resource_id.begins_with("proc-") or _is_authored(resource):
            continue
        var centre := (Vector2(float(resource.get("x", 0)) + 0.5, float(resource.get("y", 0)) + 0.5) * TILE_SIZE)
        var kind := str(resource.get("kind", ""))
        var cleared := bool(world_changes.get(resource_id, false))
        _draw_shadow(centre)
        if cleared:
            _draw_cleared(centre, kind)
        else:
            _draw_resource(centre, kind, int(resource.get("variant", 0)))

func _mount_tree_sprites() -> void:
    var texture: Texture2D = ArtAssetPack.texture_for("tree")
    if texture == null:
        return
    for resource_variant in world.resources(village):
        var resource: Dictionary = resource_variant
        var resource_id := str(resource.get("id", ""))
        if not resource_id.begins_with("proc-tree") or _is_authored(resource) or bool(world_changes.get(resource_id, false)):
            continue
        var sprite := Sprite2D.new()
        sprite.name = "GeneratedTree_%s" % resource_id
        sprite.texture = texture
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        sprite.position = Vector2(float(resource.get("x", 0)) + 0.5, float(resource.get("y", 0)) + 0.5) * TILE_SIZE + Vector2(0, -8)
        sprite.z_index = 1
        add_child(sprite)
        resource_sprites.append(sprite)

func _draw_shadow(centre: Vector2) -> void:
    draw_rect(Rect2(centre + Vector2(-10, 7), Vector2(20, 4)), Color("#26372e", 0.9), true)

func _draw_cleared(centre: Vector2, kind: String) -> void:
    if kind == "tree":
        draw_rect(Rect2(centre + Vector2(-5, -3), Vector2(10, 9)), WOOD, true)
        draw_rect(Rect2(centre + Vector2(-4, -5), Vector2(8, 3)), TREE_LIGHT, true)
    elif kind in ["stone", "ore"]:
        draw_rect(Rect2(centre + Vector2(-7, -3), Vector2(14, 8)), ROCK_DARK, true)
        draw_rect(Rect2(centre + Vector2(-5, -5), Vector2(10, 4)), ROCK, true)
    elif kind == "fish":
        draw_arc(centre + Vector2(0, 2), 10.0, 0.15, 2.95, 10, Color(WATER_LIGHT, 0.5), 1.0, false)
    else:
        draw_line(centre + Vector2(-5, 5), centre + Vector2(-5, -4), HERB, 1.0, false)

func _draw_resource(centre: Vector2, kind: String, variant: int) -> void:
    if kind == "tree":
        var canopy: Color = [TREE, TREE_LIGHT, Color("#6f9b58")][posmod(variant, 3)]
        draw_rect(Rect2(centre + Vector2(-3, -5), Vector2(6, 15)), WOOD, true)
        draw_circle(centre + Vector2(-6, -6), 10.0, TREE_DARK, true, -1.0, false)
        draw_circle(centre + Vector2(5, -9), 11.0, canopy, true, -1.0, false)
        draw_circle(centre + Vector2(0, -17), 8.0, TREE_LIGHT, true, -1.0, false)
        draw_rect(Rect2(centre + Vector2(-8, -11), Vector2(4, 2)), TREE_LIGHT, true)
        draw_rect(Rect2(centre + Vector2(5, -15), Vector2(3, 2)), WARM, true)
        draw_rect(Rect2(centre + Vector2(-4, -28), Vector2(8, 3)), Color("#d6b06e", 0.9), true)
    elif kind == "stone":
        draw_colored_polygon(PackedVector2Array([
            centre + Vector2(-10, 6), centre + Vector2(-7, -6), centre + Vector2(1, -10), centre + Vector2(10, -4), centre + Vector2(8, 7)
        ]), ROCK_DARK)
        draw_colored_polygon(PackedVector2Array([
            centre + Vector2(-5, 1), centre + Vector2(-3, -5), centre + Vector2(3, -7), centre + Vector2(6, -2), centre + Vector2(3, 3)
        ]), ROCK)
        draw_rect(Rect2(centre + Vector2(-3, -6), Vector2(4, 2)), ROCK_LIGHT, true)
    elif kind == "ore":
        draw_colored_polygon(PackedVector2Array([
            centre + Vector2(-10, 6), centre + Vector2(-6, -5), centre + Vector2(0, -10), centre + Vector2(9, -3), centre + Vector2(7, 7)
        ]), ROCK_DARK)
        draw_rect(Rect2(centre + Vector2(-4, -5), Vector2(4, 4)), Color("#9bb6a0"), true)
        draw_rect(Rect2(centre + Vector2(2, 0), Vector2(4, 4)), Color("#6f9c8b"), true)
        draw_rect(Rect2(centre + Vector2(-1, 5), Vector2(3, 2)), Color("#bdd5ad"), true)
    elif kind == "fish":
        var fish_color := WATER_LIGHT if posmod(variant, 2) == 0 else HERB
        draw_arc(centre + Vector2(0, 2), 14.0, 0.15, 2.95, 12, Color(fish_color, 0.55), 1.0, false)
        draw_arc(centre + Vector2(0, 2), 8.0, 0.25, 2.9, 10, Color(fish_color, 0.8), 1.0, false)
        draw_rect(Rect2(centre + Vector2(-9, -3), Vector2(18, 6)), WATER_DARK, true)
        draw_colored_polygon(PackedVector2Array([centre + Vector2(9, 0), centre + Vector2(15, -7), centre + Vector2(15, 7)]), fish_color)
        draw_rect(Rect2(centre + Vector2(-5, -2), Vector2(3, 3)), WARM, true)
    else:
        for offset in [-6.0, 0.0, 6.0]:
            draw_line(centre + Vector2(offset, 6), centre + Vector2(offset - 1, -7), HERB, 1.0, false)
            draw_rect(Rect2(centre + Vector2(offset - 3, -9), Vector2(5, 3)), FLOWER, true)

func _is_authored(resource: Dictionary) -> bool:
    var x := int(resource.get("x", 0))
    var y := int(resource.get("y", 0))
    return x >= world.SETTLEMENT_ORIGIN.x - 10 and x < world.SETTLEMENT_ORIGIN.x + 72 and y >= world.SETTLEMENT_ORIGIN.y + 2 and y < world.SETTLEMENT_ORIGIN.y + 50
