class_name WorldView
extends Node2D

signal tile_clicked(cell: Vector2i, button_index: int)
signal tile_hovered(cell: Vector2i)
signal zoom_requested(direction: int, focus_cell: Vector2i)
signal drag_pan_requested(delta_cells: Vector2i)

var state = null
var rules = null
var grid = null

var map_size: Vector2i = Vector2i.ZERO
var view_tiles: Vector2i = Vector2i(30, 20)
var camera_cell: Vector2i = Vector2i.ZERO
var hover_cell: Vector2i = Vector2i(-1, -1)

var selected_unit = null
var selected_city = null
var reachable_cells: Array = []
var preview_path_cells: Array = []
var is_drag_panning = false
var last_drag_cell: Vector2i = Vector2i(-1, -1)

func configure(p_grid, p_rules, p_map_size: Vector2i, p_view_tiles: Vector2i) -> void:
	grid = p_grid
	rules = p_rules
	map_size = p_map_size
	view_tiles = p_view_tiles

func set_state(p_state) -> void:
	state = p_state
	queue_redraw()

func set_camera(p_camera_cell: Vector2i) -> void:
	camera_cell = p_camera_cell
	queue_redraw()

func set_view_tiles(p_view_tiles: Vector2i) -> void:
	view_tiles = p_view_tiles
	queue_redraw()

func set_selection(p_selected_unit, p_selected_city, p_reachable_cells: Array, p_preview_path_cells: Array = []) -> void:
	selected_unit = p_selected_unit
	selected_city = p_selected_city
	reachable_cells = p_reachable_cells
	preview_path_cells = p_preview_path_cells
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _input(event: InputEvent) -> void:
	if grid == null:
		return

	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		var local_pos = to_local(motion_event.position)
		if is_drag_panning and _inside_map(local_pos):
			var current_drag_cell: Vector2i = grid.local_to_cell(local_pos, camera_cell)
			if last_drag_cell.x >= 0 and last_drag_cell.y >= 0:
				var delta_cells = last_drag_cell - current_drag_cell
				if delta_cells != Vector2i.ZERO:
					drag_pan_requested.emit(delta_cells)
			last_drag_cell = current_drag_cell
		if _inside_map(local_pos):
			var cell = grid.local_to_cell(local_pos, camera_cell)
			hover_cell = cell
			tile_hovered.emit(cell)
		else:
			hover_cell = Vector2i(-1, -1)

	if event is InputEventMouseButton:
		var mouse_button_event: InputEventMouseButton = event
		var local_pos = to_local(mouse_button_event.position)
		if mouse_button_event.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse_button_event.pressed and _inside_map(local_pos):
				is_drag_panning = true
				last_drag_cell = grid.local_to_cell(local_pos, camera_cell)
			else:
				is_drag_panning = false
				last_drag_cell = Vector2i(-1, -1)
			return
		if not mouse_button_event.pressed:
			return
		if not _inside_map(local_pos):
			return
		var cell = grid.local_to_cell(local_pos, camera_cell)
		if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_requested.emit(1, cell)
			return
		if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_requested.emit(-1, cell)
			return
		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT or mouse_button_event.button_index == MOUSE_BUTTON_RIGHT:
			tile_clicked.emit(cell, mouse_button_event.button_index)

func _draw() -> void:
	if state == null or rules == null or grid == null:
		return

	var human = state.get_player_by_id(0)
	for y in range(view_tiles.y):
		for x in range(view_tiles.x):
			var cell = camera_cell + Vector2i(x, y)
			var local_pos = grid.cell_to_local(cell, camera_cell)
			var tile_rect = Rect2(local_pos, Vector2(grid.cell_size, grid.cell_size))

			if not state.in_bounds(cell):
				draw_rect(tile_rect, Color("#05080c"), true)
				continue

			var explored = human.explored_cells.has(_key(cell))
			if not explored:
				draw_rect(tile_rect, Color("#05080c"), true)
				continue

			var terrain_id: String = state.tiles[cell.y][cell.x]
			var terrain_info: Dictionary = rules.terrain_info(terrain_id)
			draw_rect(tile_rect, terrain_info["color"], true)
			_draw_terrain_pattern(tile_rect, terrain_id, terrain_info["accent"])

			if not human.visible_cells.has(_key(cell)):
				draw_rect(tile_rect, Color(0.02, 0.04, 0.06, 0.55), true)

	_draw_reachable_cells()
	_draw_preview_path()
	_draw_cities(human)
	_draw_units(human)
	_draw_selection()
	_draw_hover()
	_draw_grid()

func _draw_terrain_pattern(tile_rect: Rect2, terrain_id: String, accent: Color) -> void:
	var x = tile_rect.position.x
	var y = tile_rect.position.y
	if terrain_id == "water":
		for i in range(3):
			draw_rect(Rect2(Vector2(x + 4 + i * 8, y + 5 + (i % 2) * 4), Vector2(4, 2)), accent, true)
	elif terrain_id == "grass":
		for i in range(5):
			draw_rect(Rect2(Vector2(x + 3 + (i * 5) % 24, y + 6 + (i * 3) % 18), Vector2(2, 3)), accent, true)
	elif terrain_id == "plains":
		for i in range(4):
			draw_rect(Rect2(Vector2(x + 4 + i * 6, y + 10 + (i % 2) * 5), Vector2(4, 1)), accent, true)
	elif terrain_id == "forest":
		for i in range(4):
			draw_rect(Rect2(Vector2(x + 4 + (i * 6) % 18, y + 6 + (i * 4) % 14), Vector2(5, 6)), accent, true)
	elif terrain_id == "hill":
		draw_rect(Rect2(Vector2(x + 4, y + 18), Vector2(24, 4)), accent, true)
		draw_rect(Rect2(Vector2(x + 8, y + 14), Vector2(16, 4)), accent, true)
		draw_rect(Rect2(Vector2(x + 12, y + 10), Vector2(8, 4)), accent, true)

func _draw_reachable_cells() -> void:
	for cell in reachable_cells:
		if not _in_view(cell):
			continue
		var local_pos = grid.cell_to_local(cell, camera_cell)
		var rect = Rect2(local_pos + Vector2(2, 2), Vector2(grid.cell_size - 4, grid.cell_size - 4))
		draw_rect(rect, Color(1.0, 0.75, 0.34, 0.22), true)

func _draw_cities(human) -> void:
	for player in state.players:
		for city in player.cities:
			if not _in_view(city.cell):
				continue
			if not human.visible_cells.has(_key(city.cell)):
				continue
			var local_pos = grid.cell_to_local(city.cell, camera_cell)
			_draw_city(local_pos, player.color, player.dark_color)

func _draw_city(local_pos: Vector2, color_main: Color, color_dark: Color) -> void:
	var city_size = clampi(int(round(float(grid.cell_size) * 0.74)), 12, max(12, grid.cell_size - 2))
	var inset = float(grid.cell_size - city_size) * 0.5
	var base = local_pos + Vector2(inset, inset)
	var scale = float(city_size)
	draw_rect(_scaled_rect(base, scale, 0.0, 0.0, 1.0, 1.0), Color("#e7dcb6"), true)
	draw_rect(_scaled_rect(base, scale, 0.14, 0.14, 0.72, 0.64), color_main, true)
	draw_rect(_scaled_rect(base, scale, 0.32, 0.02, 0.36, 0.26), color_dark, true)
	draw_rect(_scaled_rect(base, scale, 0.08, 0.78, 0.84, 0.16), color_dark, true)

func _draw_units(human) -> void:
	var unit_size = clampi(int(round(float(grid.cell_size) * 0.88)), 10, max(10, grid.cell_size - 2))
	var inset = float(grid.cell_size - unit_size) * 0.5
	var current_player = state.get_current_player()
	var show_ready = current_player != null and current_player.is_human
	for player in state.players:
		for unit in player.units:
			if not _in_view(unit.cell):
				continue
			if not human.visible_cells.has(_key(unit.cell)):
				continue
			var local_pos = grid.cell_to_local(unit.cell, camera_cell) + Vector2(inset, inset)
			_draw_unit(local_pos, unit_size, unit.type_id, player.color, player.dark_color, float(unit.hp) / float(unit.max_hp))
			if show_ready and player.id == current_player.id and unit.moves_left > 0:
				_draw_ready_marker(local_pos, unit_size)

func _draw_unit(local_pos: Vector2, unit_size: int, unit_type: String, color_main: Color, color_dark: Color, hp_ratio: float) -> void:
	var skin = Color("#f7f0d0")
	var scale = float(unit_size)
	match unit_type:
		"settler":
			draw_rect(_scaled_rect(local_pos, scale, 0.37, 0.05, 0.26, 0.18), skin, true)
			draw_rect(_scaled_rect(local_pos, scale, 0.30, 0.24, 0.40, 0.42), color_main, true)
			draw_rect(_scaled_rect(local_pos, scale, 0.27, 0.64, 0.20, 0.30), color_dark, true)
			draw_rect(_scaled_rect(local_pos, scale, 0.53, 0.64, 0.20, 0.30), color_dark, true)
			draw_rect(_scaled_rect(local_pos, scale, 0.12, 0.30, 0.14, 0.46), Color("#7b5f3f"), true)
			draw_rect(_scaled_rect(local_pos, scale, 0.78, 0.24, 0.10, 0.64), Color("#c6a36c"), true)
		"warrior":
			draw_rect(_scaled_rect(local_pos, scale, 0.37, 0.05, 0.26, 0.18), skin, true)
			draw_rect(_scaled_rect(local_pos, scale, 0.30, 0.24, 0.40, 0.42), color_main, true)
			draw_rect(_scaled_rect(local_pos, scale, 0.04, 0.32, 0.24, 0.50), Color("#6d88a8"), true)
			draw_rect(_scaled_rect(local_pos, scale, 0.80, 0.10, 0.08, 0.80), Color("#d8d8d8"), true)
			draw_rect(_scaled_rect(local_pos, scale, 0.73, 0.02, 0.20, 0.12), Color("#a7d7ff"), true)
			draw_rect(_scaled_rect(local_pos, scale, 0.27, 0.64, 0.20, 0.30), color_dark, true)
			draw_rect(_scaled_rect(local_pos, scale, 0.53, 0.64, 0.20, 0.30), color_dark, true)
		"scout":
			draw_rect(_scaled_rect(local_pos, scale, 0.33, 0.04, 0.34, 0.18), skin, true)
			draw_rect(_scaled_rect(local_pos, scale, 0.24, 0.22, 0.52, 0.40), color_main, true)
			draw_rect(_scaled_rect(local_pos, scale, 0.10, 0.36, 0.12, 0.34), color_dark, true)
			draw_rect(_scaled_rect(local_pos, scale, 0.78, 0.36, 0.12, 0.34), color_dark, true)
			draw_rect(_scaled_rect(local_pos, scale, 0.37, 0.00, 0.26, 0.10), Color("#a7d7ff"), true)
			draw_rect(_scaled_rect(local_pos, scale, 0.18, 0.64, 0.64, 0.24), Color("#4a5f70"), true)
		_:
			draw_rect(_scaled_rect(local_pos, scale, 0.12, 0.12, 0.76, 0.76), color_main, true)
			draw_rect(_scaled_rect(local_pos, scale, 0.24, 0.24, 0.52, 0.52), color_dark, true)

	var hp_bar_width = unit_size
	var hp_bar_height = max(2, int(round(float(unit_size) * 0.16)))
	var hp_offset = max(2, int(round(float(unit_size) * 0.12)))
	var hp_top = local_pos.y - float(hp_bar_height + hp_offset)
	var clamped_hp = clampf(hp_ratio, 0.0, 1.0)
	var hp_fill_width = max(1, int(round(float(hp_bar_width) * clamped_hp)))
	draw_rect(Rect2(Vector2(local_pos.x, hp_top), Vector2(hp_bar_width, hp_bar_height)), Color("#111820"), true)
	draw_rect(Rect2(Vector2(local_pos.x, hp_top), Vector2(hp_fill_width, hp_bar_height)), Color("#6adf7a"), true)

func _draw_ready_marker(local_pos: Vector2, unit_size: int) -> void:
	var marker_size = max(3, int(round(float(unit_size) * 0.22)))
	var marker_pos = local_pos + Vector2(float(unit_size - marker_size), 0)
	draw_rect(Rect2(marker_pos, Vector2(marker_size, marker_size)), Color("#ffd15f"), true)
	draw_rect(Rect2(marker_pos + Vector2(1, 1), Vector2(max(1, marker_size - 2), max(1, marker_size - 2))), Color("#f6a72b"), true)

func _draw_preview_path() -> void:
	if preview_path_cells.is_empty():
		return

	var centers: Array = []
	for cell in preview_path_cells:
		if not _in_view(cell):
			continue
		var local_pos = grid.cell_to_local(cell, camera_cell)
		var center = local_pos + Vector2(float(grid.cell_size) * 0.5, float(grid.cell_size) * 0.5)
		centers.append(center)

	if centers.size() <= 0:
		return

	var line_width = max(2.0, float(grid.cell_size) * 0.11)
	var dot_radius = max(2.0, float(grid.cell_size) * 0.12)
	for i in range(centers.size()):
		if i > 0:
			draw_line(centers[i - 1], centers[i], Color(1.0, 0.94, 0.58, 0.84), line_width)
		draw_circle(centers[i], dot_radius, Color(1.0, 0.78, 0.33, 0.92))

	var last_cell = preview_path_cells[preview_path_cells.size() - 1]
	if _in_view(last_cell):
		var end_local = grid.cell_to_local(last_cell, camera_cell)
		var pad = max(1.0, floor(float(grid.cell_size) * 0.1))
		draw_rect(
			Rect2(end_local + Vector2(pad, pad), Vector2(float(grid.cell_size) - pad * 2.0, float(grid.cell_size) - pad * 2.0)),
			Color(1.0, 0.85, 0.35, 0.95),
			false,
			2.0
		)

func _draw_selection() -> void:
	if selected_unit != null and _in_view(selected_unit.cell):
		var local_pos = grid.cell_to_local(selected_unit.cell, camera_cell)
		draw_rect(Rect2(local_pos + Vector2(2, 2), Vector2(grid.cell_size - 4, grid.cell_size - 4)), Color("#ffd15f"), false, 3.0)

	if selected_city != null and _in_view(selected_city.cell):
		var local_pos = grid.cell_to_local(selected_city.cell, camera_cell)
		draw_rect(Rect2(local_pos + Vector2(2, 2), Vector2(grid.cell_size - 4, grid.cell_size - 4)), Color("#81e2ff"), false, 3.0)

func _draw_hover() -> void:
	if hover_cell.x < 0 or hover_cell.y < 0:
		return
	if not _in_view(hover_cell):
		return
	var local_pos = grid.cell_to_local(hover_cell, camera_cell)
	draw_rect(Rect2(local_pos + Vector2(1, 1), Vector2(grid.cell_size - 2, grid.cell_size - 2)), Color(1, 1, 1, 0.55), false, 1.0)

func _draw_grid() -> void:
	var draw_w = view_tiles.x * grid.cell_size
	var draw_h = view_tiles.y * grid.cell_size
	for x in range(view_tiles.x + 1):
		var px = x * grid.cell_size
		draw_line(Vector2(px, 0), Vector2(px, draw_h), Color(0, 0, 0, 0.16), 1.0)
	for y in range(view_tiles.y + 1):
		var py = y * grid.cell_size
		draw_line(Vector2(0, py), Vector2(draw_w, py), Color(0, 0, 0, 0.16), 1.0)

func _scaled_rect(origin: Vector2, scale: float, x_factor: float, y_factor: float, w_factor: float, h_factor: float) -> Rect2:
	return Rect2(
		origin + Vector2(floor(x_factor * scale), floor(y_factor * scale)),
		Vector2(max(1.0, floor(w_factor * scale)), max(1.0, floor(h_factor * scale)))
	)

func _inside_map(local_pos: Vector2) -> bool:
	return local_pos.x >= 0 and local_pos.y >= 0 and local_pos.x < view_tiles.x * grid.cell_size and local_pos.y < view_tiles.y * grid.cell_size

func is_point_inside_map(local_pos: Vector2) -> bool:
	return _inside_map(local_pos)

func _in_view(cell: Vector2i) -> bool:
	return cell.x >= camera_cell.x and cell.y >= camera_cell.y and cell.x < camera_cell.x + view_tiles.x and cell.y < camera_cell.y + view_tiles.y

func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
