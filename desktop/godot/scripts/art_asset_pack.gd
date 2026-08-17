extends RefCounted
class_name ClovermereArtAssetPack

const PALETTE := {
    "ink": Color("#1b2c26"),
    "deep": Color("#263a32"),
    "shadow": Color("#152820"),
    "grass": Color("#5c954f"),
    "grass_light": Color("#91b961"),
    "leaf_dark": Color("#21453a"),
    "leaf": Color("#356a47"),
    "leaf_light": Color("#6f9b58"),
    "wall": Color("#b87955"),
    "wall_light": Color("#d49a6a"),
    "roof": Color("#3c4f45"),
    "roof_light": Color("#61715b"),
    "timber": Color("#704936"),
    "wood": Color("#a76645"),
    "brass": Color("#e0bb6c"),
    "glass": Color("#9bcbb9"),
    "stone": Color("#73766d"),
    "stone_light": Color("#a7a78d"),
    "ore": Color("#91b59e"),
    "herb": Color("#a9c987"),
    "petal": Color("#d7b46f"),
    "grass_dark": Color("#3d7047"),
    "path": Color("#b98958"),
    "path_light": Color("#d7b576"),
    "path_edge": Color("#765947"),
    "soil": Color("#875d4d"),
    "water": Color("#4f9491"),
    "water_light": Color("#86c1ac"),
    "water_dark": Color("#326b73"),
    "moss": Color("#78975a"),
    "moss_light": Color("#a7bd6a")
}

const ASSET_PATHS := {
    "cottage": "res://assets/benchmark/cottage.png",
    "workshop": "res://assets/benchmark/workshop.png",
    "hall": "res://assets/benchmark/hall.png",
    "garden": "res://assets/benchmark/garden.png",
    "barn": "res://assets/benchmark/barn.png",
    "tree": "res://assets/benchmark/tree.png",
    "stone": "res://assets/benchmark/stone.png",
    "ore": "res://assets/benchmark/ore.png",
    "herb": "res://assets/benchmark/herb.png",
    "tree_stump": "res://assets/benchmark/tree_stump.png",
    "tree_debris": "res://assets/benchmark/tree_debris.png",
    "stone_fragments": "res://assets/benchmark/stone_fragments.png",
    "ore_fragments": "res://assets/benchmark/ore_fragments.png",
    "herb_stems": "res://assets/benchmark/herb_stems.png",
    "player": "res://assets/benchmark/player.png",
    "resident": "res://assets/benchmark/resident.png",
    "grass_a": "res://assets/benchmark/grass_a.png",
    "grass_b": "res://assets/benchmark/grass_b.png",
    "grass_c": "res://assets/benchmark/grass_c.png",
    "woodland": "res://assets/benchmark/woodland.png",
    "soil": "res://assets/benchmark/soil.png",
    "path_h": "res://assets/benchmark/path_h.png",
    "path_v": "res://assets/benchmark/path_v.png",
    "path_corner_ne": "res://assets/benchmark/path_corner_ne.png",
    "path_corner_nw": "res://assets/benchmark/path_corner_nw.png",
    "path_corner_se": "res://assets/benchmark/path_corner_se.png",
    "path_corner_sw": "res://assets/benchmark/path_corner_sw.png",
    "path_t_n": "res://assets/benchmark/path_t_n.png",
    "path_t_s": "res://assets/benchmark/path_t_s.png",
    "path_t_e": "res://assets/benchmark/path_t_e.png",
    "path_t_w": "res://assets/benchmark/path_t_w.png",
    "path_cross": "res://assets/benchmark/path_cross.png",
    "water": "res://assets/benchmark/water.png",
    "water_edge_n": "res://assets/benchmark/water_edge_n.png",
    "water_edge_s": "res://assets/benchmark/water_edge_s.png",
    "water_edge_e": "res://assets/benchmark/water_edge_e.png",
    "water_edge_w": "res://assets/benchmark/water_edge_w.png",
    "water_corner": "res://assets/benchmark/water_corner.png",
    "water_shimmer_a": "res://assets/benchmark/water_shimmer_a.png",
    "water_shimmer_b": "res://assets/benchmark/water_shimmer_b.png",
    "foliage_sway_a": "res://assets/benchmark/foliage_sway_a.png",
    "foliage_sway_b": "res://assets/benchmark/foliage_sway_b.png"
}

const TERRAIN_ASSET_IDS := [
    "grass_a", "grass_b", "grass_c", "woodland", "soil",
    "path_h", "path_v", "path_corner_ne", "path_corner_nw", "path_corner_se", "path_corner_sw",
    "path_t_n", "path_t_s", "path_t_e", "path_t_w", "path_cross",
    "water", "water_edge_n", "water_edge_s", "water_edge_e", "water_edge_w", "water_corner"
]

const RESOURCE_STATE_ASSET_IDS := [
    "tree_stump", "tree_debris", "stone_fragments", "ore_fragments", "herb_stems"
]

const AMBIENT_ASSET_IDS := [
    "water_shimmer_a", "water_shimmer_b", "foliage_sway_a", "foliage_sway_b"
]

static var _textures: Dictionary = {}

static func path_for(asset_id: String) -> String:
    return str(ASSET_PATHS.get(asset_id, ""))

static func terrain_asset_ids() -> Array:
    return TERRAIN_ASSET_IDS.duplicate()

static func resource_state_asset_ids() -> Array:
    return RESOURCE_STATE_ASSET_IDS.duplicate()

static func ambient_asset_ids() -> Array:
    return AMBIENT_ASSET_IDS.duplicate()

static func resource_asset_for(kind: String, cleared: bool, variant: String = "") -> String:
    if not cleared:
        return {"tree": "tree", "stone": "stone", "ore": "ore", "herb": "herb"}.get(kind, "")
    if kind == "tree" and variant == "debris":
        return "tree_debris"
    return {"tree": "tree_stump", "stone": "stone_fragments", "ore": "ore_fragments", "herb": "herb_stems"}.get(kind, "")

static func facade_asset_for(building_id: String) -> String:
    return {
        "greenbriar-cottage": "cottage",
        "clovermere-hall": "hall",
        "tinker-workshop": "workshop",
        "herbalists-garden": "garden",
        "old-barn": "barn"
    }.get(building_id, "")

static func texture_for(asset_id: String) -> Texture2D:
    if _textures.has(asset_id):
        return _textures[asset_id]
    var path := path_for(asset_id)
    if path.is_empty():
        return null
    var texture := load(path) as Texture2D
    if texture != null:
        _textures[asset_id] = texture
    return texture

static func sprite(asset_id: String, parent: Node, position: Vector2, z_index: int = 0) -> Sprite2D:
    var node := Sprite2D.new()
    node.name = "Art_%s" % asset_id
    node.texture = texture_for(asset_id)
    node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    node.position = position
    node.z_index = z_index
    parent.add_child(node)
    return node
