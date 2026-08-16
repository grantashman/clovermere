extends SceneTree

const ArtAssetPack = preload("res://scripts/art_asset_pack.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    require(ArtAssetPack.PALETTE.size() >= 12, "the authored pack should expose a restrained palette")
    for asset_id in ["cottage", "workshop", "tree", "stone", "herb", "player", "resident"]:
        var path := ArtAssetPack.path_for(asset_id)
        require(not path.is_empty(), "%s should have a registered asset path" % asset_id)
        require(FileAccess.file_exists(path), "%s should exist at %s" % [asset_id, path])
    require(ArtAssetPack.texture_for("cottage") != null, "cottage texture should import in Godot")
    require(ArtAssetPack.texture_for("workshop") != null, "workshop texture should import in Godot")

    if failures.is_empty():
        print("Godot art asset-pack contract: PASS")
    else:
        for failure in failures:
            push_error(failure)
        print("Godot art asset-pack contract: FAIL (%d)" % failures.size())
        quit(1)
    quit(0)
