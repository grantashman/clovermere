extends SceneTree

const UiShell = preload("res://scripts/ui_shell.gd")

var failures: Array[String] = []

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var ui := UiShell.new()
    get_root().add_child(ui)
    await process_frame
    require(ui.has_method("presentation_markers"), "UI shell should expose its authored screen markers")
    if ui.has_method("presentation_markers"):
        var markers: Array = ui.presentation_markers()
        require(markers.has("welcome-illustration"), "welcome screen should register an authored illustration")
        require(markers.has("loading-illustration"), "loading screen should register an authored illustration")
        require(markers.has("journey-actions"), "welcome screen should register its journey action group")
    require(ui.welcome_screen.find_child("WelcomeIllustration", true, false) != null, "welcome screen should mount a named illustration node")
    require(ui.loading_screen.find_child("LoadingIllustration", true, false) != null, "loading screen should mount a named illustration node")
    require(ui.welcome_continue.custom_minimum_size.x >= 420.0, "primary journey action should remain readable at the baseline viewport")
    ui.free()
    if failures.is_empty():
        print("Godot screen presentation contract: PASS")
        quit(0)
        return
    print("Godot screen presentation contract: FAIL (%d)" % failures.size())
    for failure in failures:
        print(" - ", failure)
    quit(1)
