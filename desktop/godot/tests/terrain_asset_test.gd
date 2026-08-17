extends SceneTree

const ArtAssetPack = preload("res://scripts/art_asset_pack.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var expected := [
        "grass_a", "grass_b", "grass_c", "woodland", "soil",
        "path_h", "path_v", "path_corner_ne", "path_corner_nw", "path_corner_se", "path_corner_sw",
        "path_t_n", "path_t_s", "path_t_e", "path_t_w", "path_cross",
        "water", "water_edge_n", "water_edge_s", "water_edge_e", "water_edge_w", "water_corner"
    ]
    for asset_id in expected:
        require(ArtAssetPack.path_for(asset_id) != "", "terrain asset should be registered: %s" % asset_id)
        require(ArtAssetPack.texture_for(asset_id) != null, "terrain asset should load: %s" % asset_id)
    require(ArtAssetPack.terrain_asset_ids().size() == expected.size(), "terrain registry should expose the complete authored tile set")
    if failures.is_empty():
        print("Godot terrain asset contract: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
