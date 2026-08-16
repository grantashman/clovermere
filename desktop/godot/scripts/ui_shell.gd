extends CanvasLayer
class_name HobbitMoonUi

signal new_journey_requested
signal continue_requested
signal save_requested
signal load_requested
signal resume_requested
signal options_requested
signal main_menu_requested
signal quit_requested
signal fullscreen_changed(enabled: bool)
signal pixel_filter_changed(enabled: bool)
signal zoom_changed(value: float)
signal debug_changed(enabled: bool)

const FOREST := Color("#12271f")
const FOREST_DEEP := Color("#091610")
const FOREST_MID := Color("#1d3b2d")
const PARCHMENT := Color("#e7d6a7")
const PARCHMENT_DARK := Color("#bda875")
const BRASS := Color("#f0d487")
const MUTED := Color("#b8c785")
const INK := Color("#1d2b24")

var root: Control
var loading_screen: Control
var welcome_screen: Control
var pause_screen: Control
var options_screen: Control
var toast_panel: PanelContainer
var toast_label: Label
var welcome_continue: Button
var welcome_save_note: Label
var pause_save: Button
var pause_load: Button
var fullscreen_check: CheckButton
var pixel_check: CheckButton
var debug_check: CheckButton
var zoom_slider: HSlider
var zoom_value_label: Label
var current_page := "loading"
var previous_page := "welcome"
var toast_time := 0.0
var has_save := false
var settings: Dictionary = {}

func _ready() -> void:
    layer = 30
    _build_root()

func _process(delta: float) -> void:
    if toast_time > 0.0:
        toast_time = maxf(0.0, toast_time - delta)
        if toast_time <= 0.0 and toast_panel != null:
            toast_panel.visible = false

func configure(initial_settings: Dictionary, save_exists: bool, zoom: float) -> void:
    settings = initial_settings.duplicate(true)
    has_save = save_exists
    if zoom_slider != null:
        zoom_slider.value = zoom
        _refresh_zoom_label(zoom)
    if fullscreen_check != null:
        fullscreen_check.button_pressed = bool(settings.get("fullscreen", true))
    if pixel_check != null:
        pixel_check.button_pressed = bool(settings.get("crisp_pixels", true))
    if debug_check != null:
        debug_check.button_pressed = bool(settings.get("show_metrics", false))
    _refresh_save_state()

func _build_root() -> void:
    root = Control.new()
    root.name = "NativeUiRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    loading_screen = _build_loading_screen()
    welcome_screen = _build_welcome_screen()
    pause_screen = _build_pause_screen()
    options_screen = _build_options_screen()
    toast_panel = _build_toast()

    _show_only(loading_screen)

func _build_loading_screen() -> Control:
    var screen := _screen("LoadingScreen", Color(FOREST_DEEP, 0.98))
    var centre := CenterContainer.new()
    centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen.add_child(centre)
    var column := VBoxContainer.new()
    column.custom_minimum_size = Vector2(520, 260)
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 12)
    centre.add_child(column)
    var mark := Label.new()
    mark.text = "✦"
    mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mark.add_theme_font_size_override("font_size", 30)
    mark.add_theme_color_override("font_color", BRASS)
    column.add_child(mark)
    var title := _title_label("MOONRISE HOLLOW", 30)
    column.add_child(title)
    var subtitle := _body_label("A quiet life, shared.", 16, MUTED)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(subtitle)
    var line := _body_label("Preparing the village ledger and field map…", 13, PARCHMENT_DARK)
    line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(line)
    var bar := ProgressBar.new()
    bar.custom_minimum_size = Vector2(360, 8)
    bar.show_percentage = false
    bar.value = 72.0
    bar.add_theme_stylebox_override("background", _style(Color("#223b30"), Color("#355746"), 4, 1))
    bar.add_theme_stylebox_override("fill", _style(BRASS, BRASS, 4, 0))
    column.add_child(bar)
    var hint := _body_label("The first composition is cached for a smoother journey.", 11, Color("#8fa67b"))
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(hint)
    return screen

func _build_welcome_screen() -> Control:
    var screen := _screen("WelcomeScreen", Color(FOREST_DEEP, 0.78))
    var centre := CenterContainer.new()
    centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen.add_child(centre)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(560, 590)
    panel.add_theme_stylebox_override("panel", _style(Color("#10251d"), Color("#9f8952"), 2, 14))
    centre.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    column.add_theme_constant_override("margin_left", 42)
    column.add_theme_constant_override("margin_right", 42)
    column.add_theme_constant_override("margin_top", 34)
    column.add_theme_constant_override("margin_bottom", 34)
    panel.add_child(column)

    var eyebrow := _body_label("FIELD NOTES  /  A NATIVE SLICE", 11, MUTED)
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(eyebrow)
    column.add_child(_title_label("MOONRISE\nHOLLOW", 36))
    var strap := _body_label("A village of small paths, warm windows,\nand ordinary days worth remembering.", 16, PARCHMENT)
    strap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(strap)
    column.add_child(_rule())
    welcome_save_note = _body_label("", 13, MUTED)
    welcome_save_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    welcome_save_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(welcome_save_note)

    welcome_continue = _button("Continue Journey", func(): continue_requested.emit())
    column.add_child(welcome_continue)
    column.add_child(_button("Begin New Journey", func(): new_journey_requested.emit()))
    column.add_child(_button("Options", func(): options_requested.emit()))
    column.add_spacer(false)
    column.add_child(_button("Quit to Desktop", func(): quit_requested.emit(), false))
    var footer := _body_label("Fullscreen by default  ·  F11 toggles window mode", 11, Color("#7e9a7b"))
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(footer)
    return screen

func _build_pause_screen() -> Control:
    var screen := _screen("PauseScreen", Color(FOREST_DEEP, 0.68))
    var centre := CenterContainer.new()
    centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen.add_child(centre)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(460, 490)
    panel.add_theme_stylebox_override("panel", _style(Color("#10251d"), Color("#9f8952"), 2, 12))
    centre.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    column.add_theme_constant_override("margin_left", 40)
    column.add_theme_constant_override("margin_right", 40)
    column.add_theme_constant_override("margin_top", 32)
    column.add_theme_constant_override("margin_bottom", 32)
    panel.add_child(column)
    var label := _title_label("FIELD PAUSED", 28)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(label)
    var sub := _body_label("The kettle is warm. The path will wait.", 14, MUTED)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(sub)
    column.add_child(_rule())
    column.add_child(_button("Resume Journey", func(): resume_requested.emit()))
    pause_save = _button("Save Journey", func(): save_requested.emit())
    column.add_child(pause_save)
    pause_load = _button("Load Journey", func(): load_requested.emit())
    column.add_child(pause_load)
    column.add_child(_button("Options", func(): options_requested.emit()))
    column.add_spacer(false)
    column.add_child(_button("Return to Welcome", func(): main_menu_requested.emit(), false))
    var hint := _body_label("Esc  resume / pause", 11, Color("#7e9a7b"))
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(hint)
    return screen

func _build_options_screen() -> Control:
    var screen := _screen("OptionsScreen", Color(FOREST_DEEP, 0.92))
    var frame := ColorRect.new()
    frame.set_anchors_preset(Control.PRESET_CENTER)
    frame.offset_left = -310.0
    frame.offset_top = -280.0
    frame.offset_right = 310.0
    frame.offset_bottom = 280.0
    frame.color = Color("#9f8952")
    screen.add_child(frame)
    var panel := ColorRect.new()
    panel.position = Vector2(2, 2)
    panel.size = Vector2(616, 556)
    panel.color = Color("#10251d")
    frame.add_child(panel)
    var column := VBoxContainer.new()
    column.position = Vector2(44, 32)
    column.size = Vector2(532, 496)
    column.add_theme_constant_override("separation", 12)
    panel.add_child(column)
    var heading := _title_label("OPTIONS", 28)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(heading)
    var sub := _body_label("Shape the window and the way the field reads.", 14, MUTED)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(sub)
    column.add_child(_rule())

    fullscreen_check = CheckButton.new()
    fullscreen_check.text = "Fullscreen window"
    fullscreen_check.tooltip_text = "Start and play in a borderless fullscreen window."
    fullscreen_check.add_theme_font_size_override("font_size", 16)
    fullscreen_check.add_theme_color_override("font_color", PARCHMENT)
    fullscreen_check.toggled.connect(func(value: bool): fullscreen_changed.emit(value))
    column.add_child(fullscreen_check)

    pixel_check = CheckButton.new()
    pixel_check.text = "Crisp pixel filtering"
    pixel_check.tooltip_text = "Use nearest-neighbour filtering for sharper pixel forms."
    pixel_check.add_theme_font_size_override("font_size", 16)
    pixel_check.add_theme_color_override("font_color", PARCHMENT)
    pixel_check.toggled.connect(func(value: bool): pixel_filter_changed.emit(value))
    column.add_child(pixel_check)

    debug_check = CheckButton.new()
    debug_check.text = "Show performance metrics on launch"
    debug_check.add_theme_font_size_override("font_size", 16)
    debug_check.add_theme_color_override("font_color", PARCHMENT)
    debug_check.toggled.connect(func(value: bool): debug_changed.emit(value))
    column.add_child(debug_check)

    var zoom_heading := _body_label("Starting field zoom", 13, MUTED)
    column.add_child(zoom_heading)
    var zoom_row := HBoxContainer.new()
    zoom_row.add_theme_constant_override("separation", 12)
    zoom_slider = HSlider.new()
    zoom_slider.min_value = 0.5
    zoom_slider.max_value = 2.0
    zoom_slider.step = 0.1
    zoom_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    zoom_slider.tooltip_text = "Choose the zoom used when entering the village."
    zoom_slider.value_changed.connect(func(value: float):
        _refresh_zoom_label(value)
        zoom_changed.emit(value)
    )
    zoom_row.add_child(zoom_slider)
    zoom_value_label = _body_label("75%", 14, BRASS)
    zoom_value_label.custom_minimum_size = Vector2(54, 28)
    zoom_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    zoom_row.add_child(zoom_value_label)
    column.add_child(zoom_row)
    column.add_spacer(false)
    column.add_child(_button("Restore Recommended Settings", func(): _restore_defaults(), false))
    column.add_child(_button("Back", func(): _back_from_options()))
    return screen

func _build_toast() -> PanelContainer:
    var panel := PanelContainer.new()
    panel.name = "UiToast"
    panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    panel.position = Vector2(-230, -94)
    panel.size = Vector2(460, 48)
    panel.add_theme_stylebox_override("panel", _style(Color("#1d3b2d"), Color("#c0a35d"), 1, 7))
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    toast_label = _body_label("", 14, PARCHMENT)
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(toast_label)
    root.add_child(panel)
    panel.visible = false
    return panel

func _screen(screen_name: String, color: Color) -> Control:
    var screen := Control.new()
    screen.name = screen_name
    screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen.mouse_filter = Control.MOUSE_FILTER_STOP
    var backdrop := ColorRect.new()
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.color = color
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    screen.add_child(backdrop)
    root.add_child(screen)
    return screen

func _show_only(screen: Control) -> void:
    for candidate in [loading_screen, welcome_screen, pause_screen, options_screen]:
        if candidate != null:
            candidate.visible = candidate == screen
    current_page = "loading" if screen == loading_screen else "welcome" if screen == welcome_screen else "pause" if screen == pause_screen else "options"
    root.mouse_filter = Control.MOUSE_FILTER_STOP if screen != null else Control.MOUSE_FILTER_IGNORE

func show_loading() -> void:
    _show_only(loading_screen)

func show_welcome(save_exists: bool) -> void:
    has_save = save_exists
    _refresh_save_state()
    _show_only(welcome_screen)

func show_pause(save_exists: bool) -> void:
    has_save = save_exists
    _refresh_save_state()
    _show_only(pause_screen)

func show_options(from_page: String = "welcome") -> void:
    previous_page = from_page
    _show_only(options_screen)

func hide_overlay() -> void:
    for candidate in [loading_screen, welcome_screen, pause_screen, options_screen]:
        if candidate != null:
            candidate.visible = false
    current_page = "game"
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE

func is_menu_open() -> bool:
    return current_page != "game"

func notify(message: String, seconds: float = 2.5) -> void:
    if toast_label == null or toast_panel == null:
        return
    toast_label.text = message
    toast_panel.visible = true
    toast_time = seconds

func set_save_enabled(enabled: bool) -> void:
    has_save = enabled
    _refresh_save_state()

func _refresh_save_state() -> void:
    if welcome_continue == null:
        return
    welcome_continue.disabled = not has_save
    pause_load.disabled = not has_save
    welcome_save_note.text = "A local journey is ready to continue." if has_save else "No local journey yet. Begin a new day, then save from the pause menu."
    welcome_save_note.add_theme_color_override("font_color", MUTED if has_save else PARCHMENT_DARK)

func _refresh_zoom_label(value: float) -> void:
    if zoom_value_label != null:
        zoom_value_label.text = "%d%%" % roundi(value * 100.0)

func _restore_defaults() -> void:
    if fullscreen_check != null:
        fullscreen_check.button_pressed = true
        fullscreen_changed.emit(true)
    if pixel_check != null:
        pixel_check.button_pressed = true
        pixel_filter_changed.emit(true)
    if debug_check != null:
        debug_check.button_pressed = false
        debug_changed.emit(false)
    if zoom_slider != null:
        zoom_slider.value = 0.75
        zoom_changed.emit(0.75)
    notify("Recommended field settings restored.")

func _back_from_options() -> void:
    if previous_page == "pause":
        show_pause(has_save)
    elif previous_page == "game":
        hide_overlay()
        resume_requested.emit()
    else:
        show_welcome(has_save)

func _title_label(text: String, size: int) -> Label:
    var label := Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", BRASS)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _body_label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

func _rule() -> HSeparator:
    var rule := HSeparator.new()
    rule.custom_minimum_size = Vector2(0, 12)
    rule.add_theme_stylebox_override("separator", _style(Color("#806d45"), Color("#806d45"), 0, 1))
    return rule

func _button(text: String, callback: Callable, primary: bool = true) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(0, 42)
    button.focus_mode = Control.FOCUS_ALL
    button.add_theme_font_size_override("font_size", 15 if primary else 13)
    button.add_theme_color_override("font_color", INK if primary else PARCHMENT)
    button.add_theme_color_override("font_hover_color", INK if primary else BRASS)
    button.add_theme_stylebox_override("normal", _style(BRASS.darkened(0.12) if primary else Color("#1d3b2d"), Color("#c0a35d"), 1, 6))
    button.add_theme_stylebox_override("hover", _style(BRASS if primary else Color("#2b523e"), Color("#f5d88a"), 2, 6))
    button.add_theme_stylebox_override("pressed", _style(BRASS.darkened(0.24) if primary else Color("#12271f"), Color("#f5d88a"), 1, 6))
    button.add_theme_stylebox_override("disabled", _style(Color("#263c32"), Color("#4e6855"), 1, 6))
    button.pressed.connect(callback)
    return button

func _style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    return style
