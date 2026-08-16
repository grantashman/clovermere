extends SceneTree

const SAMPLE_SECONDS := 12.0
const MIN_STEADY_FPS := 45.0

func _initialize() -> void:
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    get_root().add_child(scene)
    await create_timer(SAMPLE_SECONDS).timeout
    var fps: float = Engine.get_frames_per_second()
    var cache: SubViewport = scene.get("world_cache") as SubViewport
    var cache_mode: int = -1
    if cache != null:
        cache_mode = cache.render_target_update_mode
    print("Godot render smoke: %.1f FPS, cache_mode=%s" % [fps, cache_mode])
    quit(0 if fps >= MIN_STEADY_FPS else 1)
