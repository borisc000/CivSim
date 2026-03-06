class_name HUD
extends CanvasLayer

signal end_turn_requested
signal found_city_requested
signal queue_requested(unit_type: String)
signal new_game_requested

var stats_label: Label
var selection_mode_label: Label
var selection_info_label: Label
var tile_info_label: Label
var logs_label: Label
var winner_label: Label

var end_turn_button: Button
var found_city_button: Button
var queue_warrior_button: Button
var queue_scout_button: Button
var queue_settler_button: Button

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	var sidebar = PanelContainer.new()
	sidebar.anchor_left = 1.0
	sidebar.anchor_right = 1.0
	sidebar.anchor_top = 0.0
	sidebar.anchor_bottom = 1.0
	sidebar.offset_left = -332.0
	sidebar.offset_right = -16.0
	sidebar.offset_top = 16.0
	sidebar.offset_bottom = -16.0
	root.add_child(sidebar)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	sidebar.add_child(margin)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var title = Label.new()
	title.text = "CivSim Godot MVP"
	title.add_theme_font_size_override("font_size", 18)
	layout.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Turnos, ciudades, IA, pixel art sobrio"
	subtitle.modulate = Color("#afbea8")
	layout.add_child(subtitle)

	var top_buttons = HBoxContainer.new()
	layout.add_child(top_buttons)

	var new_game_button = Button.new()
	new_game_button.text = "Nuevo Mundo"
	new_game_button.pressed.connect(func() -> void: new_game_requested.emit())
	top_buttons.add_child(new_game_button)

	end_turn_button = Button.new()
	end_turn_button.text = "Terminar Turno"
	end_turn_button.pressed.connect(func() -> void: end_turn_requested.emit())
	top_buttons.add_child(end_turn_button)

	layout.add_child(_separator())
	layout.add_child(_section_label("Estado"))

	stats_label = Label.new()
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.text = "-"
	layout.add_child(stats_label)

	layout.add_child(_separator())
	layout.add_child(_section_label("Seleccion"))

	selection_mode_label = Label.new()
	selection_mode_label.text = "Nada"
	selection_mode_label.modulate = Color("#ffbf56")
	layout.add_child(selection_mode_label)

	selection_info_label = Label.new()
	selection_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_info_label.text = "Selecciona una unidad o ciudad."
	layout.add_child(selection_info_label)

	found_city_button = Button.new()
	found_city_button.text = "Fundar Ciudad"
	found_city_button.pressed.connect(func() -> void: found_city_requested.emit())
	layout.add_child(found_city_button)

	var queue_row = HBoxContainer.new()
	layout.add_child(queue_row)

	queue_warrior_button = Button.new()
	queue_warrior_button.text = "Guerrero"
	queue_warrior_button.pressed.connect(func() -> void: queue_requested.emit("warrior"))
	queue_row.add_child(queue_warrior_button)

	queue_scout_button = Button.new()
	queue_scout_button.text = "Explorador"
	queue_scout_button.pressed.connect(func() -> void: queue_requested.emit("scout"))
	queue_row.add_child(queue_scout_button)

	queue_settler_button = Button.new()
	queue_settler_button.text = "Colono"
	queue_settler_button.pressed.connect(func() -> void: queue_requested.emit("settler"))
	queue_row.add_child(queue_settler_button)

	layout.add_child(_separator())
	layout.add_child(_section_label("Terreno"))

	tile_info_label = Label.new()
	tile_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile_info_label.text = "Mueve el cursor sobre el mapa."
	layout.add_child(tile_info_label)

	layout.add_child(_separator())
	layout.add_child(_section_label("Eventos"))

	logs_label = Label.new()
	logs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	logs_label.text = "-"
	logs_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(logs_label)

	winner_label = Label.new()
	winner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	winner_label.modulate = Color("#ffd784")
	winner_label.visible = false
	layout.add_child(winner_label)

func _separator() -> HSeparator:
	var sep = HSeparator.new()
	return sep

func _section_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.modulate = Color("#ffbf56")
	label.add_theme_font_size_override("font_size", 14)
	return label

func update_stats(turn_number: int, player_name: String, gold: int, science: int, city_count: int, unit_count: int) -> void:
	stats_label.text = "Turno: %d\nCivilizacion activa: %s\nOro: %d\nCiencia: %d\nCiudades: %d\nUnidades: %d" % [
		turn_number,
		player_name,
		gold,
		science,
		city_count,
		unit_count,
	]

func update_selection(mode: String, description: String) -> void:
	selection_mode_label.text = mode
	selection_info_label.text = description

func update_tile_info(coords: String, description: String) -> void:
	tile_info_label.text = "Casilla: %s\n%s" % [coords, description]

func update_logs(messages: Array) -> void:
	var lines: Array = []
	for i in range(max(0, messages.size() - 10), messages.size()):
		lines.append(str(messages[i]))
	logs_label.text = "\n".join(lines)

func set_action_state(can_end_turn: bool, can_found_city: bool, can_queue_city: bool, can_queue_settler: bool) -> void:
	end_turn_button.disabled = not can_end_turn
	found_city_button.disabled = not can_found_city
	queue_warrior_button.disabled = not can_queue_city
	queue_scout_button.disabled = not can_queue_city
	queue_settler_button.disabled = not can_queue_settler

func set_winner_text(text: String) -> void:
	winner_label.visible = text != ""
	winner_label.text = text
