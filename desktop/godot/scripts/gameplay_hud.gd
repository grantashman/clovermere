extends CanvasLayer
class_name ClovermereGameplayHud

const Minimap = preload("res://scripts/minimap.gd")
const HudArt = preload("res://scripts/hud_art.gd")
const ResourceSlot = preload("res://scripts/hud_resource_slot.gd")
const HudButton = preload("res://scripts/hud_button.gd")

signal pack_requested
signal craft_requested
signal pause_requested
signal recipe_requested(recipe_id: String)
signal cooking_requested(recipe_id: String)
signal meal_requested(meal_id: String)
signal storage_requested
signal surface_requested

const FOREST_DEEP := Color("#091610")
const FOREST := Color("#12271f")
const FOREST_MID := Color("#1d3b2d")
const WOOD := Color("#6d4b36")
const WOOD_LIGHT := Color("#a5794d")
const PARCHMENT := Color("#e7d6a7")
const PARCHMENT_DIM := Color("#bda875")
const BRASS := Color("#f0d487")
const MOSS := Color("#a7bd6a")
const INK := Color("#18271f")

var root: Control
var hud_art: Control
var status_panel: PanelContainer
var minimap: Control
var map_caption: Label
var management_panel: PanelContainer
var location_panel: PanelContainer
var location_label: Label
var dialogue_panel: PanelContainer
var action_bar: PanelContainer
var dialogue_speaker: Label
var dialogue_text: Label
var interior_mode := false
var management_content: VBoxContainer
var management_title: Label
var management_mode := "pack"
var pack_button: Button
var craft_button: Button
var pause_button: Button
var title_label: Label
var subtitle_label: Label
var day_label: Label
var stores_label: Label
var home_store_label: Label
var resource_strip: HBoxContainer
var resource_slots: Array = []
var tab_buttons: Dictionary = {}
var debug_label: Label
var hint_label: Label
var interaction_panel: PanelContainer
var interaction_label: Label
var energy_bar: ProgressBar
var energy_label: Label
var mode_hint: Label
var _snapshot: Dictionary = {}
var _world = null
var _grid: Array = []

func _ready() -> void:
    layer = 40
    _build_root()

func resource_slot_kinds() -> Array[String]:
    return ["timber", "stone", "ore", "herbs", "fish"]

func _build_root() -> void:
    root = Control.new()
    root.name = "TraditionalPcHud"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    hud_art = HudArt.new()
    hud_art.name = "AuthoredHudFrames"
    hud_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud_art.z_index = -5
    root.add_child(hud_art)

    status_panel = _panel(Vector2(24, 20), Vector2(330, 108), "StatusPanel")
    root.add_child(status_panel)
    _build_status_panel()

    location_panel = _panel(Vector2(432, 20), Vector2(416, 42), "LocationRibbon")
    root.add_child(location_panel)
    _build_location_panel()

    minimap = Minimap.new()
    minimap.name = "ClovermereMinimap"
    minimap.position = Vector2(1040, 20)
    minimap.size = Vector2(216, 136)
    root.add_child(minimap)
    map_caption = _label(root, Vector2(1048, 160), Vector2(208, 18), 9, PARCHMENT_DIM)
    map_caption.text = "FIELD MAP  ·  CLOVERMERE"
    map_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

    management_panel = _panel(Vector2(888, 180), Vector2(368, 440), "ManagementPanel")
    root.add_child(management_panel)
    _build_management_panel()
    management_panel.visible = false

    interaction_panel = _panel(Vector2(350, 578), Vector2(580, 38), "InteractionPanel")
    root.add_child(interaction_panel)
    var interaction_margin := _margin(interaction_panel, 12, 8, 12, 8)
    interaction_label = _body_label("", 14, BRASS)
    interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    interaction_margin.add_child(interaction_label)
    interaction_panel.visible = false

    dialogue_panel = PanelContainer.new()
    dialogue_panel.name = "DialoguePanel"
    dialogue_panel.position = Vector2(260, 486)
    dialogue_panel.size = Vector2(760, 112)
    dialogue_panel.add_theme_stylebox_override("panel", _style(Color("#ead6a7", 0.97), WOOD_LIGHT, 2, 4))
    root.add_child(dialogue_panel)
    var dialogue_margin := _margin(dialogue_panel, 16, 10, 16, 10)
    var dialogue_column := VBoxContainer.new()
    dialogue_column.add_theme_constant_override("separation", 4)
    dialogue_margin.add_child(dialogue_column)
    dialogue_speaker = _body_label("", 12, INK)
    dialogue_speaker.add_theme_color_override("font_shadow_color", Color("#f5e8bf"))
    dialogue_speaker.add_theme_constant_override("shadow_offset_x", 1)
    dialogue_speaker.add_theme_constant_override("shadow_offset_y", 1)
    dialogue_column.add_child(dialogue_speaker)
    dialogue_text = _body_label("", 14, INK)
    dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
    dialogue_column.add_child(dialogue_text)
    dialogue_panel.visible = false

    _build_action_bar()
    debug_label = _label(root, Vector2(30, 188), Vector2(420, 42), 11, PARCHMENT_DIM)
    debug_label.visible = false
    hint_label = _label(root, Vector2(30, 686), Vector2(1220, 18), 10, PARCHMENT_DIM)
    hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint_label.add_theme_color_override("font_color", PARCHMENT)
    hint_label.add_theme_color_override("font_outline_color", Color(FOREST_DEEP, 0.95))
    hint_label.add_theme_constant_override("outline_size", 3)

func _build_status_panel() -> void:
    var margin := _margin(status_panel, 14, 3, 14, 3)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 2)
    margin.add_child(column)
    title_label = _title_label("CLOVERMERE", 15)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    column.add_child(title_label)
    subtitle_label = _body_label("THE GREEN COUNTRY  ·  6 FOLK", 8, MOSS)
    column.add_child(subtitle_label)
    day_label = _body_label("DAY 01  ·  08:00 AM", 10, PARCHMENT)
    column.add_child(day_label)
    var energy_row := HBoxContainer.new()
    energy_row.add_theme_constant_override("separation", 8)
    energy_label = _body_label("ENERGY", 8, PARCHMENT_DIM)
    energy_label.custom_minimum_size = Vector2(54, 12)
    energy_row.add_child(energy_label)
    energy_bar = ProgressBar.new()
    energy_bar.custom_minimum_size = Vector2(166, 8)
    energy_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    energy_bar.show_percentage = false
    energy_bar.add_theme_stylebox_override("background", _style(Color("#1b3529"), WOOD, 1, 2))
    energy_bar.add_theme_stylebox_override("fill", _style(Color("#b6a165"), BRASS, 1, 2))
    energy_row.add_child(energy_bar)
    column.add_child(energy_row)
    stores_label = _body_label("HOME STORES  ·  00 MATERIALS", 8, MOSS)
    home_store_label = stores_label
    stores_label.visible = false
    resource_strip = HBoxContainer.new()
    resource_strip.add_theme_constant_override("separation", 4)
    resource_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_child(resource_strip)
    for kind in resource_slot_kinds():
        var slot = ResourceSlot.new()
        slot.custom_minimum_size = Vector2(54, 24)
        resource_strip.add_child(slot)
        resource_slots.append(slot)

func _build_location_panel() -> void:
    var margin := _margin(location_panel, 14, 7, 14, 7)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    margin.add_child(row)
    var compass := _body_label("✦", 13, BRASS)
    compass.custom_minimum_size = Vector2(20, 20)
    compass.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(compass)
    location_label = _body_label("THE CROSSING  ·  CLOVERMERE", 12, PARCHMENT)
    location_label.name = "LocationLabel"
    location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    location_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(location_label)
    var marker := _body_label("✦", 13, BRASS)
    marker.custom_minimum_size = Vector2(20, 20)
    marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(marker)

func _build_action_bar() -> void:
    action_bar = PanelContainer.new()
    action_bar.name = "ActionBar"
    action_bar.position = Vector2(430, 622)
    action_bar.size = Vector2(420, 52)
    action_bar.add_theme_stylebox_override("panel", _style(Color(FOREST_DEEP, 0.9), WOOD_LIGHT, 1, 4))
    root.add_child(action_bar)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 7)
    var margin := _margin(action_bar, 7, 7, 7, 7)
    margin.add_child(row)
    pack_button = _shortcut_button("PACK", "B", "pack", func(): open_pack())
    craft_button = _shortcut_button("CRAFT", "C", "craft", func(): open_crafting())
    pause_button = _shortcut_button("MENU", "ESC", "menu", func(): pause_requested.emit())
    row.add_child(pack_button)
    row.add_child(craft_button)
    row.add_child(pause_button)

func _build_management_panel() -> void:
    var margin := _margin(management_panel, 18, 14, 18, 14)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    margin.add_child(column)
    var heading_row := HBoxContainer.new()
    management_title = _title_label("FIELD PACK", 20)
    management_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    management_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading_row.add_child(management_title)
    var close := _small_button("×", func(): close_management())
    close.custom_minimum_size = Vector2(28, 28)
    heading_row.add_child(close)
    column.add_child(heading_row)
    mode_hint = _body_label("Materials carried on the road.", 11, PARCHMENT_DIM)
    column.add_child(mode_hint)
    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 6)
    var pack_tab := _tab_button("PACK", "pack", func(): open_pack())
    var craft_tab := _tab_button("CRAFT", "craft", func(): open_crafting())
    var cook_tab := _tab_button("HEARTH", "hearth", func(): open_cooking())
    tab_buttons = {"pack": pack_tab, "craft": craft_tab, "cook": cook_tab}
    tabs.add_child(pack_tab)
    tabs.add_child(craft_tab)
    tabs.add_child(cook_tab)
    column.add_child(tabs)
    var rule := HSeparator.new()
    rule.add_theme_stylebox_override("separator", _style(WOOD_LIGHT, WOOD_LIGHT, 0, 1))
    column.add_child(rule)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(0, 320)
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    management_content = VBoxContainer.new()
    management_content.custom_minimum_size = Vector2(324, 0)
    management_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    management_content.add_theme_constant_override("separation", 8)
    scroll.add_child(management_content)
    column.add_child(scroll)

func _refresh_management() -> void:
    if management_content == null:
        return
    _refresh_tab_state()
    for child in management_content.get_children():
        child.queue_free()
    if management_mode == "pack":
        management_title.text = "FIELD PACK"
        mode_hint.text = "Carry what you need. Home stores wait at Greenbriar Cottage."
        _build_pack_content()
    elif management_mode == "craft":
        management_title.text = "WORKSHOP RECIPES"
        mode_hint.text = "Crafting is available at Tinker Workshop."
        _build_craft_content()
    else:
        management_title.text = "HEARTH PANTRY"
        mode_hint.text = "Make one warm thing before the road asks more of you."
        _build_cook_content()

func _refresh_tab_state() -> void:
    for key in tab_buttons.keys():
        var button = tab_buttons[key]
        if button == null:
            continue
        var selected: bool = (str(key) == management_mode)
        button.set_active(selected)
        button.add_theme_color_override("font_color", BRASS if selected else PARCHMENT_DIM)
        button.add_theme_stylebox_override("normal", _style(Color("#2b4b38") if selected else Color("#14271e"), BRASS if selected else WOOD, 1, 3))

func _build_pack_content() -> void:
    var carried: Dictionary = _snapshot.get("inventory", {})
    var stored: Dictionary = _snapshot.get("storage", {})
    management_content.add_child(_section_label("CARRIED MATERIALS"))
    for material in ["timber", "stone", "ore", "herbs", "fish"]:
        management_content.add_child(_material_row(material, int(carried.get(material, 0)), MOSS))
    management_content.add_child(_section_label("HOME STORES"))
    for material in ["timber", "stone", "ore", "herbs", "fish"]:
        management_content.add_child(_material_row(material, int(stored.get(material, 0)), PARCHMENT_DIM))
    var note := _body_label("Sleeping at home automatically stores your carried materials.", 11, PARCHMENT_DIM)
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    management_content.add_child(note)
    if bool(_snapshot.get("near_home", false)):
        var take_stores := _small_button("TAKE STORES", func(): storage_requested.emit())
        take_stores.custom_minimum_size = Vector2(132, 30)
        management_content.add_child(take_stores)

func _build_craft_content() -> void:
    var recipes: Dictionary = _snapshot.get("recipes", {})
    var near_workshop := bool(_snapshot.get("near_workshop", false))
    for recipe_id in ["tinkers-kit", "wayfarers-satchel", "hearthward-charm"]:
        var recipe: Dictionary = recipes.get(recipe_id, {})
        if recipe.is_empty():
            continue
        var card := PanelContainer.new()
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        card.custom_minimum_size = Vector2(320, 104)
        card.add_theme_stylebox_override("panel", _style(Color("#193226"), WOOD, 1, 3))
        var card_margin := _margin(card, 10, 8, 10, 8)
        var card_column := VBoxContainer.new()
        card_column.add_theme_constant_override("separation", 3)
        card_margin.add_child(card_column)
        var row := HBoxContainer.new()
        var name := _body_label(str(recipe.get("name", recipe_id)), 14, PARCHMENT)
        name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(name)
        var craft := _small_button("CRAFT", func(id: String = recipe_id): recipe_requested.emit(id))
        var craftable_at_workshop := near_workshop and bool(recipe.get("craftable", false))
        craft.disabled = not craftable_at_workshop
        row.add_child(craft)
        card_column.add_child(row)
        var summary := _body_label(str(recipe.get("summary", "")), 10, PARCHMENT_DIM)
        summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        card_column.add_child(summary)
        card_column.add_child(_body_label(_cost_text(recipe.get("cost", {}), recipe), 10, BRASS if bool(recipe.get("craftable", false)) else PARCHMENT_DIM))
        management_content.add_child(card)
    if not near_workshop:
        var note := _body_label("Stand at Tinker Workshop to make a recipe.", 11, PARCHMENT_DIM)
        note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        management_content.add_child(note)

func _build_cook_content() -> void:
    var cooking: Dictionary = _snapshot.get("cooking", {})
    var near_home := bool(_snapshot.get("near_home", false)) and bool(_snapshot.get("interior_mode", false))
    for recipe_id in ["hearth-tea", "riverside-stew", "garden-chowder"]:
        var recipe: Dictionary = cooking.get(recipe_id, {})
        if recipe.is_empty():
            continue
        var card := PanelContainer.new()
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        card.custom_minimum_size = Vector2(320, 92)
        card.add_theme_stylebox_override("panel", _style(Color("#3c3027"), WOOD_LIGHT, 1, 3))
        var card_margin := _margin(card, 10, 6, 10, 6)
        var card_column := VBoxContainer.new()
        card_column.add_theme_constant_override("separation", 2)
        card_margin.add_child(card_column)
        var row := HBoxContainer.new()
        var name := _body_label(str(recipe.get("name", recipe_id)), 14, PARCHMENT)
        name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(name)
        var meal_id := str(recipe.get("meal_id", ""))
        if not meal_id.is_empty() and int(recipe.get("meal_count", 0)) > 0:
            var meal_count := _body_label("READY %02d" % int(recipe.get("meal_count", 0)), 10, MOSS)
            meal_count.custom_minimum_size = Vector2(62, 30)
            meal_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            row.add_child(meal_count)
        var cook_text := "COOK" if not meal_id.is_empty() else "MAKE"
        var cook := _small_button(cook_text, func(id: String = recipe_id): cooking_requested.emit(id))
        cook.disabled = not near_home or not bool(recipe.get("craftable", false))
        row.add_child(cook)
        if not meal_id.is_empty():
            var eat := _small_button("EAT", func(id: String = meal_id): meal_requested.emit(id))
            eat.disabled = int(recipe.get("meal_count", 0)) <= 0
            row.add_child(eat)
        card_column.add_child(row)
        var summary := _body_label(str(recipe.get("summary", "")), 9, PARCHMENT_DIM)
        summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        card_column.add_child(summary)
        var timing := "%d ENERGY  ·  %d MINUTES" % [int(recipe.get("energy", 0)), int(recipe.get("minutes", 0))]
        card_column.add_child(_body_label(timing, 9, BRASS))
        card_column.add_child(_body_label(_cost_text(recipe.get("cost", {}), recipe), 9, PARCHMENT_DIM))
        management_content.add_child(card)
    var meals: Dictionary = _snapshot.get("meals", {})
    if not meals.is_empty():
        management_content.add_child(_section_label("PREPARED MEALS"))
        for meal_id in ["riverside-stew", "garden-chowder"]:
            var count := int(meals.get(meal_id, 0))
            management_content.add_child(_body_label("%s  ·  %02d ready" % [meal_id.replace("-", " ").to_upper(), count], 11, MOSS if count > 0 else PARCHMENT_DIM))
    if not near_home:
        var note := _body_label("Stand at the Cottage Hearth Pantry to cook.", 11, PARCHMENT_DIM)
        note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        management_content.add_child(note)

func _cost_text(cost: Dictionary, recipe: Dictionary) -> String:
    if bool(recipe.get("owned", false)):
        return "ALREADY FITTED"
    var parts: Array[String] = []
    for material in ["timber", "stone", "ore", "herbs", "fish"]:
        if cost.has(material):
            parts.append("%d %s" % [int(cost[material]), material.to_upper()])
    return "  ·  ".join(parts)

func _material_row(material: String, amount: int, color: Color) -> Control:
    var surface := PanelContainer.new()
    surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    surface.custom_minimum_size = Vector2(0, 28)
    surface.add_theme_stylebox_override("panel", _style(Color("#10251b"), Color("#3b5a40"), 1, 2))
    var margin := _margin(surface, 7, 3, 7, 3)
    var row := HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.add_child(row)
    var marker := _body_label("◆", 10, BRASS)
    marker.custom_minimum_size = Vector2(18, 18)
    marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(marker)
    var name := _body_label(material.to_upper(), 11, color)
    name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(name)
    var count := _body_label("%02d" % amount, 12, PARCHMENT)
    count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(count)
    return surface

func set_active_surface(surface: String) -> void:
    management_mode = surface if surface in ["pack", "craft", "cook"] else management_mode
    _refresh_tab_state()

func set_hud_frame_state(management: bool, dialogue: bool, interaction: bool, interior: bool) -> void:
    if hud_art != null:
        hud_art.set_state(management, dialogue, interaction, interior, management_mode)

func clear_interaction_banner() -> void:
    if interaction_label != null:
        interaction_label.text = ""
    if interaction_panel != null:
        interaction_panel.visible = false
    set_hud_frame_state(management_panel.visible, dialogue_panel.visible, false, interior_mode)

func open_pack() -> void:
    surface_requested.emit()
    clear_interaction_banner()
    set_active_surface("pack")
    management_mode = "pack"
    management_panel.visible = true
    set_hud_frame_state(true, dialogue_panel.visible, interaction_panel.visible, interior_mode)
    _refresh_management()

func open_crafting() -> void:
    surface_requested.emit()
    clear_interaction_banner()
    set_active_surface("craft")
    management_mode = "craft"
    management_panel.visible = true
    set_hud_frame_state(true, dialogue_panel.visible, interaction_panel.visible, interior_mode)
    _refresh_management()

func open_cooking() -> void:
    surface_requested.emit()
    clear_interaction_banner()
    set_active_surface("cook")
    management_mode = "cook"
    management_panel.visible = true
    set_hud_frame_state(true, dialogue_panel.visible, interaction_panel.visible, interior_mode)
    _refresh_management()

func close_management() -> void:
    management_panel.visible = false
    set_hud_frame_state(false, dialogue_panel.visible, interaction_panel.visible, interior_mode)

func show_dialogue(speaker: String, text: String) -> void:
    clear_interaction_banner()
    dialogue_speaker.text = speaker.to_upper()
    dialogue_text.text = text
    dialogue_panel.visible = true
    set_hud_frame_state(management_panel.visible, true, interaction_panel.visible, interior_mode)

func hide_dialogue() -> void:
    if dialogue_panel != null:
        dialogue_panel.visible = false
        set_hud_frame_state(management_panel.visible, false, interaction_panel.visible, interior_mode)

func set_interior_mode(enabled: bool, location_name: String = "") -> void:
    interior_mode = enabled
    if minimap != null:
        minimap.visible = not enabled
    if map_caption != null:
        map_caption.visible = not enabled
    if enabled and not location_name.is_empty():
        subtitle_label.text = "HEARTH & HOME  ·  %s" % location_name.to_upper()
        location_label.text = location_name.to_upper()
    elif not enabled:
        location_label.text = "THE CROSSING  ·  CLOVERMERE"
    set_hud_frame_state(management_panel.visible, dialogue_panel.visible, interaction_panel.visible, interior_mode)
    hide_dialogue()

func refresh(snapshot: Dictionary) -> void:
    _snapshot = snapshot.duplicate(true)
    title_label.text = str(snapshot.get("village_name", "CLOVERMERE"))
    subtitle_label.text = "HEARTH & HOME  ·  %s" % str(snapshot.get("location_name", "INTERIOR")).to_upper() if interior_mode else "THE GREEN COUNTRY  ·  %d FOLK  ·  %d%%" % [int(snapshot.get("folk", 6)), roundi(float(snapshot.get("zoom", 0.75)) * 100.0)]
    location_label.text = str(snapshot.get("location_name", "THE CROSSING  ·  CLOVERMERE")).to_upper() if interior_mode else "THE CROSSING  ·  CLOVERMERE"
    day_label.text = "DAY %02d  ·  %s" % [int(snapshot.get("day", 1)), str(snapshot.get("clock", "08:00 AM"))]
    var energy := int(snapshot.get("energy", 0))
    var max_energy := maxi(1, int(snapshot.get("max_energy", 100)))
    energy_bar.max_value = max_energy
    energy_bar.value = energy
    energy_label.text = "ENERGY %d/%d" % [energy, max_energy]
    var inventory: Dictionary = snapshot.get("inventory", {})
    var storage: Dictionary = snapshot.get("storage", {})
    var carried_total := 0
    var stored_total := 0
    for material in resource_slot_kinds():
        carried_total += int(inventory.get(material, 0))
        stored_total += int(storage.get(material, 0))
    home_store_label.text = "ON HAND %02d  ·  HOME STORES %02d" % [carried_total, stored_total]
    for index in range(mini(resource_slots.size(), resource_slot_kinds().size())):
        var kind := resource_slot_kinds()[index]
        resource_slots[index].set_resource(kind, int(inventory.get(kind, 0)), int(storage.get(kind, 0)))
    hint_label.text = str(snapshot.get("hint", "Click to walk  ·  B pack  ·  C craft  ·  E interact  ·  Wheel zoom"))
    debug_label.text = str(snapshot.get("debug", ""))
    debug_label.visible = bool(snapshot.get("debug_visible", false))
    interaction_label.text = str(snapshot.get("interaction", ""))
    interaction_panel.visible = not interaction_label.text.is_empty()
    set_hud_frame_state(management_panel.visible, dialogue_panel.visible, interaction_panel.visible, interior_mode)
    if management_panel.visible:
        _refresh_management()

func configure_map(world, grid: Array, player_position: Vector2, buildings: Dictionary) -> void:
    _world = world
    _grid = grid
    minimap.configure(world, grid, player_position, buildings)

func set_player_position(player_position: Vector2) -> void:
    if minimap != null:
        minimap.set_player_position(player_position)

func _panel(position: Vector2, panel_size: Vector2, panel_name: String) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.name = panel_name
    panel.position = position
    panel.size = panel_size
    panel.add_theme_stylebox_override("panel", _style(Color(FOREST_DEEP, 0.94), WOOD_LIGHT, 1, 3))
    panel.mouse_filter = Control.MOUSE_FILTER_PASS
    return panel

func _margin(parent: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", left)
    margin.add_theme_constant_override("margin_top", top)
    margin.add_theme_constant_override("margin_right", right)
    margin.add_theme_constant_override("margin_bottom", bottom)
    margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
    parent.add_child(margin)
    return margin

func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(width)
    style.set_corner_radius_all(radius)
    style.shadow_color = Color(0, 0, 0, 0.28)
    style.shadow_size = 4
    style.shadow_offset = Vector2(0, 2)
    style.content_margin_left = 8.0
    style.content_margin_right = 8.0
    style.content_margin_top = 6.0
    style.content_margin_bottom = 6.0
    return style

func _title_label(text: String, size: int) -> Label:
    return _body_label(text, size, BRASS)

func _section_label(text: String) -> Label:
    return _body_label(text, 10, PARCHMENT_DIM)

func _body_label(text: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.autowrap_mode = TextServer.AUTOWRAP_OFF
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

func _label(parent: Control, position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
    var label := _body_label("", font_size, color)
    label.position = position
    label.size = label_size
    parent.add_child(label)
    return label

func _button(text: String, callback: Callable) -> Button:
    var button = HudButton.new()
    button.text = text
    button.pressed.connect(callback)
    button.add_theme_font_size_override("font_size", 11)
    button.add_theme_color_override("font_color", PARCHMENT)
    button.add_theme_color_override("font_hover_color", BRASS)
    button.add_theme_color_override("font_pressed_color", BRASS)
    button.add_theme_color_override("font_focus_color", BRASS)
    button.add_theme_color_override("font_disabled_color", Color(PARCHMENT_DIM, 0.45))
    button.add_theme_stylebox_override("normal", _style(Color("#1b3529"), WOOD, 1, 2))
    button.add_theme_stylebox_override("hover", _style(Color("#294936"), BRASS, 1, 2))
    button.add_theme_stylebox_override("pressed", _style(Color("#0f2119"), BRASS, 1, 2))
    button.add_theme_stylebox_override("focus", _style(Color("#294936"), Color("#f0d487"), 2, 2))
    button.add_theme_stylebox_override("disabled", _style(Color("#14261e"), Color("#3d4d3c"), 1, 2))
    return button

func _shortcut_button(text: String, shortcut: String, glyph: String, callback: Callable) -> Button:
    var button = _button("  " + text, callback)
    button.set_glyph(glyph)
    button.tooltip_text = "%s  ·  %s" % [text, shortcut]
    button.custom_minimum_size = Vector2(112, 34)
    button.add_theme_font_size_override("font_size", 10)
    return button

func _small_button(text: String, callback: Callable) -> Button:
    var button := _button(text, callback)
    button.custom_minimum_size = Vector2(70, 30)
    button.add_theme_font_size_override("font_size", 10)
    return button

func _tab_button(text: String, glyph: String, callback: Callable) -> Button:
    var button := _button("  " + text, callback)
    button.set_glyph(glyph)
    button.custom_minimum_size = Vector2(96, 28)
    button.add_theme_font_size_override("font_size", 9)
    return button
