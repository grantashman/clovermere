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
    "petal": Color("#d7b46f")
}

const ASSET_PATHS := {
    "cottage": "res://assets/benchmark/cottage.png",
    "workshop": "res://assets/benchmark/workshop.png",
    "tree": "res://assets/benchmark/tree.png",
    "stone": "res://assets/benchmark/stone.png",
    "herb": "res://assets/benchmark/herb.png",
    "player": "res://assets/benchmark/player.png",
    "resident": "res://assets/benchmark/resident.png"
}

static var _textures: Dictionary = {}

static func path_for(asset_id: String) -> String:
    return str(ASSET_PATHS.get(asset_id, ""))

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
