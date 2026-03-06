class_name WorldView
extends Node2D

signal tile_clicked(cell: Vector2i, button_index: int)
signal tile_hovered(cell: Vector2i)

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

func set_selection(p_selected_unit, p_selected_city, p_reachable_cells: Array) -> void:
	selected_unit = p_selected_unit
	selected_city = p_selected_city
	reachable_cells = p_reachable_cells
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if grid == null:
		return

	if event is InputEventMouseMotion:
		var local_pos := to_local(event.position)
		if _inside_map(local_pos):
			var cell := grid.local_to_cell(local_pos, camera_cell)
			hover_cell = cell
			tile_hovered.emit(cell)
		else:
			hover_cell = Vector2i(-1, -1)

	if event is InputEventMouseButton and event.pressed:
		if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
			return
		var local_pos := to_local(event.position)
		if not _inside_map(local_pos):
			return
		var cell := grid.local_to_cell(local_pos, camera_cell)
		tile_clicked.emit(cell, event.button_index)

func _draw() -> void:
	if state == null or rules == null or grid == null:
		return

	var human = state.get_player_by_id(0)
	for y in range(view_tiles.y):
		for x in range(view_tiles.x):
			var cell := camera_cell + Vector2i(x, y)
			var local_pos := grid.cell_to_local(cell, camera_cell)
			var tile_rect := Rect2(local_pos, Vector2(grid.cell_size, grid.cell_size))

			if not state.in_bounds(cell):
				draw_rect(tile_rect, Color("#05080c"), true)
				continue

			var explored := human.explored_cells.has(_key(cell))
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
	_draw_cities(human)
	_draw_units(human)
	_draw_selection()
	_draw_hover()
	_draw_grid()

func _draw_terrain_pattern(tile_rect: Rect2, terrain_id: String, accent: Color) -> void:
	var x := tile_rect.position.x
	var y := tile_rect.position.y
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
		var local_pos := grid.cell_to_local(cell, camera_cell)
		var rect := Rect2(local_pos + Vector2(2, 2), Vector2(grid.cell_size - 4, grid.cell_size - 4))
		draw_rect(rect, Color(1.0, 0.75, 0.34, 0.22), true)

func _draw_cities(human) -> void:
	for player in state.players:
		for city in player.cities:
			if not _in_view(city.cell):
				continue
			if not human.visible_cells.has(_key(city.cell)):
				continue
			var local_pos := grid.cell_to_local(city.cell, camera_cell)
			_draw_city(local_pos, player.color, player.dark_color)

func _draw_city(local_pos: Vector2, color_main: Color, color_dark: Color) -> void:
	var base := local_pos + Vector2(5, 5)
	draw_rect(Rect2(base, Vector2(22, 22)), Color("#e7dcb6"), true)
	draw_rect(Rect2(base + Vector2(3, 3), Vector2(16, 16)), color_main, true)
	draw_rect(Rect2(base + Vector2(7, 1), Vector2(8, 6)), color_dark, true)
	draw_rect(Rect2(base + Vector2(2, 18), Vector2(18, 3)), color_dark, true)

func _draw_units(human) -> void:
	for player in state.players:
		for unit in player.units:
			if not _in_view(unit.cell):
				continue
			if not human.visible_cells.has(_key(unit.cell)):
				continue
			var local_pos := grid.cell_to_local(unit.cell, camera_cell) + Vector2(8, 8)
			_draw_unit(local_pos, unit.type_id, player.color, player.dark_color, float(unit.hp) / float(unit.max_hp))

func _draw_unit(local_pos: Vector2, unit_type: String, color_main: Color, color_dark: Color, hp_ratio: float) -> void:
	draw_rect(Rect2(local_pos, Vector2(16, 16)), color_dark, true)
	draw_rect(Rect2(local_pos + Vector2(2, 2), Vector2(12, 12)), color_main, true)

	if unit_type == "settler":
		draw_rect(Rect2(local_pos + Vector2(6, 1), Vector2(4, 3)), Color("#f7f0d0"), true)
		draw_rect(Rect2(local_pos + Vector2(3, 6), Vector2(10, 3)), Color("#f7f0d0"), true)
	elif unit_type == "warrior":
		draw_rect(Rect2(local_pos + Vector2(6, 1), Vector2(4, 3)), Color("#f7f0d0"), true)
		draw_rect(Rect2(local_pos + Vector2(11, 3), Vector2(2, 9)), Color("#a7d7ff"), true)
	elif unit_type == "scout":
		draw_rect(Rect2(local_pos + Vector2(5, 1), Vector2(6, 3)), Color("#f7f0d0"), true)
		draw_rect(Rect2(local_pos + Vector2(3, 10), Vector2(10, 2)), Color("#a7d7ff"), true)

	draw_rect(Rect2(local_pos + Vector2(0, -3), Vector2(16, 2)), Color("#111820"), true)
	draw_rect(Rect2(local_pos + Vector2(0, -3), Vector2(max(1, int(16.0 * hp_ratio)), 2)), Color("#6adf7a"), true)

func _draw_selection() -> void:
	if selected_unit != null and _in_view(selected_unit.cell):
		var local_pos := grid.cell_to_local(selected_unit.cell, camera_cell)
		draw_rect(Rect2(local_pos + Vector2(2, 2), Vector2(grid.cell_size - 4, grid.cell_size - 4)), Color("#ffd15f"), false, 3.0)

	if selected_city != null and _in_view(selected_city.cell):
		var local_pos := grid.cell_to_local(selected_city.cell, camera_cell)
		draw_rect(Rect2(local_pos + Vector2(2, 2), Vector2(grid.cell_size - 4, grid.cell_size - 4)), Color("#81e2ff"), false, 3.0)

func _draw_hover() -> void:
	if hover_cell.x < 0 or hover_cell.y < 0:
		return
	if not _in_view(hover_cell):
		return
	var local_pos := grid.cell_to_local(hover_cell, camera_cell)
	draw_rect(Rect2(local_pos + Vector2(1, 1), Vector2(grid.cell_size - 2, grid.cell_size - 2)), Color(1, 1, 1, 0.55), false, 1.0)

func _draw_grid() -> void:
	var draw_w := view_tiles.x * grid.cell_size
	var draw_h := view_tiles.y * grid.cell_size
	for x in range(view_tiles.x + 1):
		var px := x * grid.cell_size
		draw_line(Vector2(px, 0), Vector2(px, draw_h), Color(0, 0, 0, 0.16), 1.0)
	for y in range(view_tiles.y + 1):
		var py := y * grid.cell_size
		draw_line(Vector2(0, py), Vector2(draw_w, py), Color(0, 0, 0, 0.16), 1.0)

func _inside_map(local_pos: Vector2) -> bool:
	return local_pos.x >= 0 and local_pos.y >= 0 and local_pos.x < view_tiles.x * grid.cell_size and local_pos.y < view_tiles.y * grid.cell_size

func _in_view(cell: Vector2i) -> bool:
	return cell.x >= camera_cell.x and cell.y >= camera_cell.y and cell.x < camera_cell.x + view_tiles.x and cell.y < camera_cell.y + view_tiles.y

func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
