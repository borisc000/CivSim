extends Node2D

const GameState = preload("res://scripts/core/game_state.gd")
const PlayerData = preload("res://scripts/core/data/player_data.gd")
const SquareGridAdapter = preload("res://scripts/core/grid/square_grid_adapter.gd")
const MapGenerator = preload("res://scripts/core/map_generator.gd")
const Ruleset = preload("res://scripts/core/ruleset.gd")
const CombatService = preload("res://scripts/core/combat_service.gd")
const AIService = preload("res://scripts/core/ai_service.gd")

@onready var world_view: WorldView = $WorldView
@onready var hud: HUD = $HUD

var state = GameState.new()
var rules = Ruleset.new()
var map_generator = MapGenerator.new()
var combat_service = CombatService.new()
var ai_service = AIService.new()
var grid = SquareGridAdapter.new(32)

var rng = RandomNumberGenerator.new()
var map_size = Vector2i(44, 28)
var view_tiles = Vector2i(30, 20)
var camera_cell = Vector2i.ZERO
var hover_cell = Vector2i(-1, -1)
var pending_end_turn_confirmation = false
var hover_path_steps = -1
var hover_path_cost = -1
var hover_combat_preview = ""
var edge_pan_accumulator = 0.0

const MAP_MARGIN_PIXELS = Vector2i(16, 16)
const HUD_RESERVED_WIDTH = 376
const MIN_MAP_VIEW_SIZE_PIXELS = Vector2i(640, 420)
const MIN_CELL_SIZE = 20
const MAX_CELL_SIZE = 96
const ZOOM_STEP_PIXELS = 4
const EDGE_PAN_MARGIN_PIXELS = 20.0
const EDGE_PAN_INTERVAL = 0.05

var map_view_size_pixels = Vector2i(960, 640)

func _ready() -> void:
	rng.randomize()
	world_view.position = Vector2(MAP_MARGIN_PIXELS.x, MAP_MARGIN_PIXELS.y)
	_update_map_view_size_from_viewport()
	_recalculate_view_tiles()

	world_view.configure(grid, rules, map_size, view_tiles)
	world_view.tile_clicked.connect(_on_tile_clicked)
	world_view.tile_hovered.connect(_on_tile_hovered)
	world_view.zoom_requested.connect(_on_zoom_requested)
	world_view.drag_pan_requested.connect(_on_drag_pan_requested)

	hud.end_turn_requested.connect(_on_end_turn_requested)
	hud.found_city_requested.connect(_on_found_city_requested)
	hud.queue_requested.connect(_on_queue_requested)
	hud.new_game_requested.connect(_on_new_game_requested)
	hud.next_unit_requested.connect(_on_next_unit_requested)

	_new_game()
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _process(delta: float) -> void:
	_process_edge_pan(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				_end_turn_from_human()
			KEY_TAB:
				_on_next_unit_requested()
			KEY_SPACE:
				if not _select_next_idle_unit(true):
					_end_turn_from_human()
				_sync_presentation()
			KEY_ESCAPE:
				state.clear_selection()
				pending_end_turn_confirmation = false
				_sync_presentation()
			KEY_C:
				_center_camera_on_selection()
				_sync_presentation()
			KEY_F:
				_try_found_city_from_selected()
			KEY_N:
				_new_game()
			KEY_A, KEY_LEFT:
				_move_camera(Vector2i(-1, 0))
			KEY_D, KEY_RIGHT:
				_move_camera(Vector2i(1, 0))
			KEY_W, KEY_UP:
				_move_camera(Vector2i(0, -1))
			KEY_S, KEY_DOWN:
				_move_camera(Vector2i(0, 1))
			KEY_EQUAL, KEY_KP_ADD:
				_zoom_around_camera(1)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom_around_camera(-1)

func _new_game() -> void:
	state = GameState.new()
	state.map_width = map_size.x
	state.map_height = map_size.y
	state.tiles = map_generator.generate(map_size.x, map_size.y, rng)

	var human = PlayerData.new(0, "Liga Solar", Color("#f8d36a"), Color("#7f5e21"), true)
	var ai = PlayerData.new(1, "Pacto Carmesi", Color("#f27768"), Color("#6d2a26"), false)
	state.players = [human, ai]

	var starts = _find_start_positions(2)
	for i in range(state.players.size()):
		var player = state.players[i]
		var start_cell: Vector2i = starts[i]
		_spawn_unit(player.id, "settler", start_cell)
		var guard_cell = _find_spawn_cell_around(start_cell)
		_spawn_unit(player.id, "warrior", guard_cell)
		var scout_cell = _find_spawn_cell_around(start_cell)
		if state.get_unit_at(scout_cell) == null:
			_spawn_unit(player.id, "scout", scout_cell)

	for player in state.players:
		_refresh_visibility(player)

	camera_cell = Vector2i.ZERO
	_center_camera_on(starts[0])
	pending_end_turn_confirmation = false
	hover_path_steps = -1
	hover_path_cost = -1
	hover_combat_preview = ""

	state.log("Nuevo mundo listo. Funda una ciudad con tu colono.")
	state.log("Combate: chocar y resolver. Arquitectura lista para escalar.")
	_start_current_player_turn()
	_sync_presentation()

func _find_start_positions(count: int) -> Array:
	var starts: Array = []
	var attempts = 0
	while starts.size() < count and attempts < 9000:
		attempts += 1
		var cell = Vector2i(rng.randi_range(3, map_size.x - 4), rng.randi_range(3, map_size.y - 4))
		if not _can_start_at(cell):
			continue
		var too_close = false
		for existing in starts:
			if grid.distance(existing, cell) < 18:
				too_close = true
				break
		if too_close:
			continue
		starts.append(cell)

	while starts.size() < count:
		for y in range(1, map_size.y - 1):
			var found = false
			for x in range(1, map_size.x - 1):
				var cell = Vector2i(x, y)
				if _can_start_at(cell):
					starts.append(cell)
					found = true
					break
			if found:
				break
		if starts.size() < count:
			starts.append(Vector2i(1, 1))

	return starts

func _can_start_at(cell: Vector2i) -> bool:
	if not state.in_bounds(cell):
		return false
	var terrain: String = state.tiles[cell.y][cell.x]
	return terrain != "water" and terrain != "hill"

func _spawn_unit(owner_id: int, unit_type: String, cell: Vector2i) -> void:
	var unit = rules.create_unit(unit_type, owner_id, cell, state.next_unit_id)
	state.next_unit_id += 1
	state.add_unit(owner_id, unit)

func _create_city(owner_id: int, cell: Vector2i):
	var city = rules.create_city(owner_id, state.next_city_id, state.city_name_cursor, cell)
	state.next_city_id += 1
	state.city_name_cursor += 1
	state.add_city(owner_id, city)
	return city

func _find_spawn_cell_around(origin: Vector2i) -> Vector2i:
	var candidates = [
		origin + Vector2i(1, 0),
		origin + Vector2i(-1, 0),
		origin + Vector2i(0, 1),
		origin + Vector2i(0, -1),
		origin + Vector2i(1, 1),
		origin + Vector2i(-1, -1),
	]
	for cell in candidates:
		if _can_move_to(cell) and state.get_unit_at(cell) == null and state.get_city_at(cell) == null:
			return cell
	return origin

func _move_camera(delta: Vector2i) -> void:
	camera_cell += delta
	_clamp_camera()
	pending_end_turn_confirmation = false
	_sync_presentation()

func _center_camera_on(cell: Vector2i) -> void:
	camera_cell = cell - Vector2i(int(view_tiles.x / 2), int(view_tiles.y / 2))
	_clamp_camera()

func _clamp_camera() -> void:
	camera_cell.x = clampi(camera_cell.x, 0, max(0, map_size.x - view_tiles.x))
	camera_cell.y = clampi(camera_cell.y, 0, max(0, map_size.y - view_tiles.y))

func _on_viewport_size_changed() -> void:
	_update_map_view_size_from_viewport()
	_recalculate_view_tiles()
	world_view.set_view_tiles(view_tiles)
	_clamp_camera()
	_sync_presentation()

func _update_map_view_size_from_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var available_width = int(viewport_size.x) - HUD_RESERVED_WIDTH - MAP_MARGIN_PIXELS.x * 2
	var available_height = int(viewport_size.y) - MAP_MARGIN_PIXELS.y * 2
	map_view_size_pixels = Vector2i(
		max(MIN_MAP_VIEW_SIZE_PIXELS.x, available_width),
		max(MIN_MAP_VIEW_SIZE_PIXELS.y, available_height)
	)

func _recalculate_view_tiles() -> void:
	view_tiles = Vector2i(
		max(8, int(floor(float(map_view_size_pixels.x) / float(grid.cell_size)))),
		max(6, int(floor(float(map_view_size_pixels.y) / float(grid.cell_size))))
	)

func _on_zoom_requested(direction: int, focus_cell: Vector2i) -> void:
	var old_cell_size = grid.cell_size
	var new_cell_size = clampi(old_cell_size + direction * ZOOM_STEP_PIXELS, MIN_CELL_SIZE, MAX_CELL_SIZE)
	if new_cell_size == old_cell_size:
		return

	grid.cell_size = new_cell_size
	_recalculate_view_tiles()
	world_view.set_view_tiles(view_tiles)

	if state.in_bounds(focus_cell):
		camera_cell = focus_cell - Vector2i(int(view_tiles.x / 2), int(view_tiles.y / 2))
	_clamp_camera()
	pending_end_turn_confirmation = false
	_sync_presentation()

func _zoom_around_camera(direction: int) -> void:
	var focus_cell = camera_cell + Vector2i(int(view_tiles.x / 2), int(view_tiles.y / 2))
	_on_zoom_requested(direction, focus_cell)

func _on_drag_pan_requested(delta_cells: Vector2i) -> void:
	if delta_cells == Vector2i.ZERO:
		return
	camera_cell += delta_cells
	_clamp_camera()
	pending_end_turn_confirmation = false
	_sync_presentation()

func _on_tile_hovered(cell: Vector2i) -> void:
	hover_cell = cell
	_sync_presentation()

func _on_tile_clicked(cell: Vector2i, button_index: int) -> void:
	if state.winner_player_id != -1:
		return
	var current = state.get_current_player()
	if current == null or not current.is_human:
		return
	if not state.in_bounds(cell):
		return
	if not current.visible_cells.has(_key(cell)):
		state.log("Solo puedes interactuar con casillas visibles.")
		_sync_presentation()
		return

	pending_end_turn_confirmation = false
	if button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(cell, current)
	elif button_index == MOUSE_BUTTON_RIGHT:
		var unit = _selected_unit()
		if unit != null:
			_issue_unit_order(unit, cell)

	_sync_presentation()

func _handle_left_click(cell: Vector2i, current) -> void:
	var own_unit = state.get_unit_at(cell)
	if own_unit != null and own_unit.owner_id == current.id:
		state.selected_unit_id = own_unit.id
		state.selected_city_id = -1
		_center_camera_on(cell)
		return

	var own_city = state.get_city_at(cell)
	if own_city != null and own_city.owner_id == current.id:
		state.selected_city_id = own_city.id
		state.selected_unit_id = -1
		_center_camera_on(cell)
		return

	var selected = _selected_unit()
	if selected != null:
		_issue_unit_order(selected, cell)
	else:
		state.clear_selection()

func _selected_unit():
	var current = state.get_current_player()
	if current == null:
		return null
	return state.find_unit_in_player(current, state.selected_unit_id)

func _selected_city():
	var current = state.get_current_player()
	if current == null:
		return null
	return state.find_city_in_player(current, state.selected_city_id)

func _issue_unit_order(unit, target_cell: Vector2i) -> void:
	if unit.moves_left <= 0:
		state.log("La unidad ya no tiene movimientos.")
		return

	pending_end_turn_confirmation = false
	var target_unit = state.get_unit_at(target_cell)
	if target_unit != null and target_unit.owner_id != unit.owner_id:
		if grid.distance(unit.cell, target_cell) != 1:
			state.log("Solo puedes atacar objetivos adyacentes.")
			return
		if unit.attack <= 0:
			state.log("Este tipo de unidad no puede atacar.")
			return
		_resolve_combat(unit, target_unit)
		_select_next_idle_unit(false)
		return

	var target_city = state.get_city_at(target_cell)
	if target_city != null and target_city.owner_id != unit.owner_id and unit.attack <= 0:
		state.log("Un colono no puede capturar ciudades.")
		return

	var reachable = _reachable_map_for_unit(unit, true)
	var key = _key(target_cell)
	if not reachable.has(key):
		state.log("Destino fuera de alcance o bloqueado.")
		return

	var path = _reconstruct_path(reachable, target_cell)
	if path.is_empty():
		return
	_move_unit_along_path(unit, path, true)
	_capture_if_on_enemy_city(unit)
	_check_victory()
	if unit.moves_left <= 0:
		_select_next_idle_unit(false)

func _resolve_combat(attacker, defender) -> void:
	var defender_cell = defender.cell
	var terrain_id: String = state.tiles[defender.cell.y][defender.cell.x]
	var result: Dictionary = combat_service.resolve(attacker, defender, terrain_id, rules, rng)

	if bool(result["defender_died"]):
		state.log("%s derrota a %s." % [rules.unit_info(attacker.type_id)["name"], rules.unit_info(defender.type_id)["name"]])
		state.remove_unit(defender)
		if attacker.hp > 0:
			attacker.cell = defender_cell
	else:
		state.log("%s inflige %d de dano." % [rules.unit_info(attacker.type_id)["name"], int(result["damage_to_defender"])])

	if bool(result["attacker_died"]):
		state.log("%s cae en combate." % [rules.unit_info(attacker.type_id)["name"]])
		state.remove_unit(attacker)

	_check_victory()

func _can_move_to(cell: Vector2i) -> bool:
	if not state.in_bounds(cell):
		return false
	var terrain: String = state.tiles[cell.y][cell.x]
	return rules.terrain_move_cost(terrain) < 999

func _reachable_map_for_unit(unit, allow_enemy_city_destination: bool) -> Dictionary:
	var visited = {}
	visited[_key(unit.cell)] = {"cost": 0, "prev": "", "cell": unit.cell}
	var frontier: Array = [unit.cell]

	while not frontier.is_empty():
		var best_index = 0
		var best_cost = int(visited[_key(frontier[0])]["cost"])
		for i in range(1, frontier.size()):
			var c = int(visited[_key(frontier[i])]["cost"])
			if c < best_cost:
				best_cost = c
				best_index = i
		var current: Vector2i = frontier[best_index]
		frontier.remove_at(best_index)

		for neighbor in grid.neighbors(current):
			if not _can_move_to(neighbor):
				continue
			var terrain: String = state.tiles[neighbor.y][neighbor.x]
			var move_cost = rules.terrain_move_cost(terrain)
			var new_cost = int(visited[_key(current)]["cost"]) + move_cost
			if new_cost > unit.moves_left:
				continue

			var blocker = state.get_unit_at(neighbor)
			if blocker != null and blocker.id != unit.id:
				continue

			var city = state.get_city_at(neighbor)
			if city != null and city.owner_id != unit.owner_id and not allow_enemy_city_destination:
				continue

			var n_key = _key(neighbor)
			if not visited.has(n_key) or new_cost < int(visited[n_key]["cost"]):
				visited[n_key] = {"cost": new_cost, "prev": _key(current), "cell": neighbor}
				if neighbor not in frontier:
					frontier.append(neighbor)

	visited.erase(_key(unit.cell))
	return visited

func _reconstruct_path(visited: Dictionary, target_cell: Vector2i) -> Array:
	var out: Array = []
	var cursor = _key(target_cell)
	while cursor != "":
		if not visited.has(cursor):
			break
		var entry: Dictionary = visited[cursor]
		out.push_front(entry["cell"])
		cursor = str(entry["prev"])
	return out

func _move_unit_along_path(unit, path: Array, center_camera: bool) -> void:
	var current = unit.cell
	for step in path:
		if step == current:
			continue
		var occupant = state.get_unit_at(step)
		if occupant != null and occupant.id != unit.id:
			break
		var move_cost = rules.terrain_move_cost(state.tiles[step.y][step.x])
		if unit.moves_left < move_cost:
			break
		unit.cell = step
		unit.moves_left -= move_cost
		current = step
	if center_camera:
		_center_camera_on(unit.cell)

func _capture_if_on_enemy_city(unit) -> void:
	var city = state.get_city_at(unit.cell)
	if city != null and city.owner_id != unit.owner_id and unit.attack > 0:
		state.capture_city(city, unit.owner_id)
		city.queue_type = "warrior"
		city.hp = max(12, city.hp)
		state.log("%s captura %s." % [state.get_player_by_id(unit.owner_id).name, city.name])

func _check_victory() -> void:
	var alive = state.alive_players()
	if alive.size() == 1:
		state.winner_player_id = alive[0].id
		state.log("%s domina el mundo." % [alive[0].name])

func _on_found_city_requested() -> void:
	pending_end_turn_confirmation = false
	_try_found_city_from_selected()

func _try_found_city_from_selected() -> void:
	var current = state.get_current_player()
	if current == null or not current.is_human or state.winner_player_id != -1:
		return
	var unit = _selected_unit()
	if unit == null:
		return
	if not _can_found_city(unit):
		state.log("No puedes fundar una ciudad en esta casilla.")
		_sync_presentation()
		return
	var city = _create_city(unit.owner_id, unit.cell)
	state.remove_unit(unit)
	state.selected_unit_id = -1
	state.selected_city_id = city.id
	state.log("%s funda %s." % [current.name, city.name])
	_refresh_visibility(current)
	_check_victory()
	_sync_presentation()

func _can_found_city(unit) -> bool:
	if not unit.can_found_city:
		return false
	if state.tiles[unit.cell.y][unit.cell.x] == "water":
		return false
	if state.get_city_at(unit.cell) != null:
		return false
	for city in state.all_cities():
		if grid.distance(city.cell, unit.cell) < 5:
			return false
	return true

func _on_queue_requested(unit_type: String) -> void:
	var current = state.get_current_player()
	if current == null or not current.is_human:
		return
	var city = _selected_city()
	if city == null:
		return
	if unit_type == "settler" and city.population < 2:
		state.log("La ciudad necesita poblacion 2 para entrenar colonos.")
		_sync_presentation()
		return
	pending_end_turn_confirmation = false
	city.queue_type = unit_type
	state.log("%s empieza a entrenar %s." % [city.name, rules.unit_info(unit_type)["name"]])
	_sync_presentation()

func _on_end_turn_requested() -> void:
	_end_turn_from_human()

func _end_turn_from_human() -> void:
	var current = state.get_current_player()
	if current == null or not current.is_human or state.winner_player_id != -1:
		return
	var pending_units = _count_idle_units(current)
	if pending_units > 0 and not pending_end_turn_confirmation:
		pending_end_turn_confirmation = true
		state.log("Aun tienes %d unidad(es) con movimientos. Pulsa 'Terminar Turno' de nuevo para confirmar." % [pending_units])
		_sync_presentation()
		return

	pending_end_turn_confirmation = false
	_process_end_of_turn(current)
	state.advance_player()

	while state.winner_player_id == -1 and state.get_current_player() != null and not state.get_current_player().is_human:
		var ai_player = state.get_current_player()
		_start_current_player_turn()
		_run_ai_turn(ai_player)
		_process_end_of_turn(ai_player)
		if state.winner_player_id != -1:
			break
		state.advance_player()

	if state.winner_player_id == -1:
		_start_current_player_turn()
		state.log("Turno %d - %s." % [state.turn_number, state.get_current_player().name])

	_sync_presentation()

func _on_new_game_requested() -> void:
	_new_game()

func _start_current_player_turn() -> void:
	var current = state.get_current_player()
	if current == null:
		return
	for unit in current.units:
		unit.moves_left = unit.max_moves
	_refresh_visibility(current)
	if current.is_human:
		_select_next_idle_unit(true)
		pending_end_turn_confirmation = false
	_check_victory()

func _process_end_of_turn(player) -> void:
	for city in player.cities:
		var yield_data = _compute_city_yield(city)
		city.food_stock += yield_data["food"]
		city.production_stock += yield_data["production"]
		player.gold += yield_data["gold"]
		player.science += max(1, int((yield_data["food"] + yield_data["production"]) / 2))

		var growth_cost = 8 + city.population * 4
		if city.food_stock >= growth_cost:
			city.food_stock -= growth_cost
			city.population += 1
			city.hp = min(city.hp + 2, 18 + city.population * 2)
			if player.is_human:
				state.log("%s crece a poblacion %d." % [city.name, city.population])

		if city.queue_type != "":
			var unit_info: Dictionary = rules.unit_info(city.queue_type)
			if city.production_stock >= int(unit_info["cost"]):
				var spawn_cell = _find_spawn_cell_around(city.cell)
				if state.get_unit_at(spawn_cell) == null:
					city.production_stock -= int(unit_info["cost"])
					_spawn_unit(player.id, city.queue_type, spawn_cell)
					if player.is_human:
						state.log("%s completa %s." % [city.name, unit_info["name"]])
					city.queue_type = ""

	if not player.is_human:
		ai_service.choose_city_queue(player, state, rules)

	_refresh_visibility(player)
	_check_victory()

func _compute_city_yield(city) -> Dictionary:
	var center_terrain: String = state.tiles[city.cell.y][city.cell.x]
	var center_yield: Dictionary = rules.terrain_yield(center_terrain)
	var out = {
		"food": int(center_yield["food"]) + 1,
		"production": int(center_yield["production"]) + 1,
		"gold": int(center_yield["gold"]) + 1,
	}

	var worked = _worked_tiles(city)
	for cell in worked:
		var terrain: String = state.tiles[cell.y][cell.x]
		var y: Dictionary = rules.terrain_yield(terrain)
		out["food"] += int(y["food"])
		out["production"] += int(y["production"])
		out["gold"] += int(y["gold"])
	return out

func _worked_tiles(city) -> Array:
	var scored: Array = []
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue
			var cell = city.cell + Vector2i(ox, oy)
			if not state.in_bounds(cell):
				continue
			var terrain = state.tiles[cell.y][cell.x]
			if terrain == "water":
				continue
			var y = rules.terrain_yield(terrain)
			var score = int(y["food"]) * 2 + int(y["production"]) * 2 + int(y["gold"])
			scored.append({"cell": cell, "score": score})

	scored.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	var out: Array = []
	var max_count = max(0, city.population - 1)
	for i in range(min(max_count, scored.size())):
		out.append(scored[i]["cell"])
	return out

func _run_ai_turn(player) -> void:
	state.log("%s esta resolviendo su turno." % [player.name])
	ai_service.choose_city_queue(player, state, rules)
	var units = player.units.duplicate()
	for unit in units:
		if not player.units.has(unit):
			continue
		if unit.type_id == "settler":
			_run_ai_settler(unit)
			continue
		if _attack_adjacent_enemy(unit):
			continue
		var target = ai_service.nearest_enemy_target_cell(unit, state, grid)
		_move_unit_toward(unit, target, true)
		_capture_if_on_enemy_city(unit)
		_attack_adjacent_enemy(unit)

func _run_ai_settler(unit) -> void:
	if _can_found_city(unit) and ai_service.score_city_site(unit.cell, state, rules) >= 16:
		var city = _create_city(unit.owner_id, unit.cell)
		state.remove_unit(unit)
		state.log("%s funda %s." % [state.get_player_by_id(city.owner_id).name, city.name])
		return
	var target = ai_service.best_settler_site(unit, state, rules, grid)
	_move_unit_toward(unit, target, false)
	if _can_found_city(unit) and ai_service.score_city_site(unit.cell, state, rules) >= 16:
		var city = _create_city(unit.owner_id, unit.cell)
		state.remove_unit(unit)
		state.log("%s funda %s." % [state.get_player_by_id(city.owner_id).name, city.name])

func _attack_adjacent_enemy(unit) -> bool:
	if unit.attack <= 0 or unit.moves_left <= 0:
		return false
	for cell in grid.neighbors(unit.cell):
		if not state.in_bounds(cell):
			continue
		var enemy = state.get_unit_at(cell)
		if enemy != null and enemy.owner_id != unit.owner_id:
			_resolve_combat(unit, enemy)
			return true
		var city = state.get_city_at(cell)
		if city != null and city.owner_id != unit.owner_id:
			var move_cost = rules.terrain_move_cost(state.tiles[cell.y][cell.x])
			if unit.moves_left >= move_cost:
				unit.cell = cell
				unit.moves_left -= move_cost
				_capture_if_on_enemy_city(unit)
				return true
	return false

func _move_unit_toward(unit, target: Vector2i, allow_enemy_city_destination: bool, center_camera: bool = false) -> void:
	if unit.moves_left <= 0:
		return
	var reachable = _reachable_map_for_unit(unit, allow_enemy_city_destination)
	var best_key = ""
	var best_distance = 999999
	var best_cost = 999999
	for key in reachable.keys():
		var cell: Vector2i = reachable[key]["cell"]
		var distance = grid.distance(cell, target)
		var cost = int(reachable[key]["cost"])
		if distance < best_distance or (distance == best_distance and cost < best_cost):
			best_distance = distance
			best_cost = cost
			best_key = key
	if best_key == "":
		return
	var path = _reconstruct_path(reachable, reachable[best_key]["cell"])
	_move_unit_along_path(unit, path, center_camera)

func _refresh_visibility(player) -> void:
	player.visible_cells.clear()
	var reveal = func(center: Vector2i, radius: int) -> void:
		for oy in range(-radius, radius + 1):
			for ox in range(-radius, radius + 1):
				var cell = center + Vector2i(ox, oy)
				if not state.in_bounds(cell):
					continue
				if abs(ox) + abs(oy) > radius:
					continue
				player.visible_cells[_key(cell)] = true
				player.explored_cells[_key(cell)] = true

	for unit in player.units:
		reveal.call(unit.cell, unit.vision)
	for city in player.cities:
		reveal.call(city.cell, 3)

func _sync_presentation() -> void:
	var current = state.get_current_player()
	var selected_unit = _selected_unit()
	var selected_city = _selected_city()

	var reachable_cells: Array = []
	var preview_path: Array = []
	hover_path_steps = -1
	hover_path_cost = -1
	hover_combat_preview = ""
	if selected_unit != null:
		var reach_map = _reachable_map_for_unit(selected_unit, true)
		for key in reach_map.keys():
			reachable_cells.append(reach_map[key]["cell"])
		if state.in_bounds(hover_cell):
			var hover_key = _key(hover_cell)
			if reach_map.has(hover_key):
				preview_path = _reconstruct_path(reach_map, hover_cell)
				hover_path_steps = preview_path.size()
				hover_path_cost = int(reach_map[hover_key]["cost"])
		hover_combat_preview = _combat_preview_text(selected_unit, hover_cell)

	world_view.set_state(state)
	world_view.set_camera(camera_cell)
	world_view.set_selection(selected_unit, selected_city, reachable_cells, preview_path)

	if current != null:
		hud.update_stats(state.turn_number, current.name, current.gold, current.science, current.cities.size(), current.units.size())
	else:
		hud.update_stats(state.turn_number, "-", 0, 0, 0, 0)

	hud.update_selection(_selection_mode(selected_unit, selected_city), _selection_text(selected_unit, selected_city))
	hud.update_tile_info(_hover_coords_text(), _hover_tile_text())
	hud.update_logs(state.logs)
	var pending_units = 0
	if current != null and current.is_human:
		pending_units = _count_idle_units(current)
	hud.update_pending_units(pending_units)
	hud.set_next_unit_state(current != null and current.is_human and pending_units > 0 and state.winner_player_id == -1)
	hud.set_end_turn_prompt(pending_end_turn_confirmation, pending_units)
	hud.update_phase(_phase_text(), current != null and current.is_human and state.winner_player_id == -1)
	hud.set_action_state(
		current != null and current.is_human and state.winner_player_id == -1,
		selected_unit != null and _can_found_city(selected_unit) and current != null and current.is_human,
		selected_city != null and current != null and current.is_human,
		selected_city != null and selected_city.population >= 2 and current != null and current.is_human
	)

	var winner_text = ""
	if state.winner_player_id != -1:
		var winner = state.get_player_by_id(state.winner_player_id)
		if winner != null:
			winner_text = "%s domina el mundo. Pulsa 'Nuevo Mundo' para reiniciar." % [winner.name]
	hud.set_winner_text(winner_text)

func _selection_mode(selected_unit, selected_city) -> String:
	if selected_unit != null:
		return str(rules.unit_info(selected_unit.type_id)["name"])
	if selected_city != null:
		return selected_city.name
	return "Nada"

func _selection_text(selected_unit, selected_city) -> String:
	if selected_unit != null:
		return "Posicion: %d, %d\nHP: %d/%d\nMovimientos: %d/%d\nAtaque: %d\nVision: %d" % [
			selected_unit.cell.x,
			selected_unit.cell.y,
			selected_unit.hp,
			selected_unit.max_hp,
			selected_unit.moves_left,
			selected_unit.max_moves,
			selected_unit.attack,
			selected_unit.vision,
		]
	if selected_city != null:
		var queue_name = "Sin produccion"
		if selected_city.queue_type != "":
			queue_name = str(rules.unit_info(selected_city.queue_type)["name"])
		return "Poblacion: %d\nComida: %d\nProduccion: %d\nCola: %s\nHP urbano: %d" % [
			selected_city.population,
			selected_city.food_stock,
			selected_city.production_stock,
			queue_name,
			selected_city.hp,
		]
	return "Selecciona una unidad o ciudad para ver detalles."

func _hover_coords_text() -> String:
	if hover_cell.x < 0 or hover_cell.y < 0 or not state.in_bounds(hover_cell):
		return "-"
	return "%d, %d" % [hover_cell.x, hover_cell.y]

func _hover_tile_text() -> String:
	if hover_cell.x < 0 or hover_cell.y < 0 or not state.in_bounds(hover_cell):
		return "Mueve el cursor sobre el mapa."
	var human = state.get_player_by_id(0)
	if human == null or not human.explored_cells.has(_key(hover_cell)):
		return "Territorio no explorado."
	var terrain: String = state.tiles[hover_cell.y][hover_cell.x]
	var info = rules.terrain_info(terrain)
	var tile_yield = rules.terrain_yield(terrain)
	var lines = [
		"Terreno: %s" % [info["name"]],
		"Rendimiento: +%d comida, +%d produccion, +%d oro" % [tile_yield["food"], tile_yield["production"], tile_yield["gold"]],
		"Movimiento: %s" % ["Bloqueado" if int(info["move_cost"]) >= 999 else str(info["move_cost"])],
	]
	if hover_path_steps > 0 and hover_path_cost >= 0:
		lines.append("Ruta: %d pasos, costo %d PM." % [hover_path_steps, hover_path_cost])
	if hover_combat_preview != "":
		lines.append(hover_combat_preview)
	var city = state.get_city_at(hover_cell)
	if city != null and human.visible_cells.has(_key(hover_cell)):
		lines.append("Ciudad: %s (%s)" % [city.name, state.get_player_by_id(city.owner_id).name])
		lines.append("Poblacion: %d" % [city.population])
	var unit = state.get_unit_at(hover_cell)
	if unit != null and human.visible_cells.has(_key(hover_cell)):
		lines.append("Unidad: %s (%s)" % [rules.unit_info(unit.type_id)["name"], state.get_player_by_id(unit.owner_id).name])
		lines.append("HP: %d/%d" % [unit.hp, unit.max_hp])
	return "\n".join(lines)

func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _count_idle_units(player) -> int:
	var count = 0
	for unit in player.units:
		if unit.moves_left > 0:
			count += 1
	return count

func _idle_units(player) -> Array:
	var out: Array = []
	for unit in player.units:
		if unit.moves_left > 0:
			out.append(unit)
	return out

func _select_next_idle_unit(center_camera: bool) -> bool:
	var current = state.get_current_player()
	if current == null or not current.is_human:
		return false
	var candidates = _idle_units(current)
	if candidates.is_empty():
		state.selected_unit_id = -1
		return false

	var selected = _selected_unit()
	var next_index = 0
	if selected != null:
		for i in range(candidates.size()):
			if candidates[i].id == selected.id:
				next_index = (i + 1) % candidates.size()
				break
	var next_unit = candidates[next_index]
	state.selected_unit_id = next_unit.id
	state.selected_city_id = -1
	if center_camera:
		_center_camera_on(next_unit.cell)
	return true

func _on_next_unit_requested() -> void:
	var current = state.get_current_player()
	if state.winner_player_id != -1 or current == null or not current.is_human:
		return
	pending_end_turn_confirmation = false
	if not _select_next_idle_unit(true):
		state.log("No hay unidades pendientes este turno.")
	_sync_presentation()

func _center_camera_on_selection() -> void:
	var unit = _selected_unit()
	if unit != null:
		_center_camera_on(unit.cell)
		return
	var city = _selected_city()
	if city != null:
		_center_camera_on(city.cell)

func _phase_text() -> String:
	if state.winner_player_id != -1:
		return "Partida finalizada"
	var current = state.get_current_player()
	if current == null:
		return "-"
	if current.is_human:
		return "Tu turno"
	return "Turno IA: %s" % [current.name]

func _combat_preview_text(attacker, target_cell: Vector2i) -> String:
	if attacker == null or attacker.attack <= 0:
		return ""
	if not state.in_bounds(target_cell):
		return ""
	if grid.distance(attacker.cell, target_cell) != 1:
		return ""
	var defender = state.get_unit_at(target_cell)
	if defender == null or defender.owner_id == attacker.owner_id:
		return ""
	var terrain_id: String = state.tiles[target_cell.y][target_cell.x]
	var defense_bonus = rules.terrain_defense_bonus(terrain_id)
	var attack_base = attacker.attack + 2 + int(attacker.hp / 3)
	var defense_base = defender.attack + defense_bonus + 2 + int(defender.hp / 4)
	var dealt = max(2, attack_base - int(defense_base / 2))
	var retaliation = max(1, int(defense_base / 2))
	return "Combate estimado: infliges ~%d, recibes ~%d." % [dealt, retaliation]

func _process_edge_pan(delta: float) -> void:
	var current = state.get_current_player()
	if current == null or not current.is_human or state.winner_player_id != -1:
		edge_pan_accumulator = 0.0
		return
	var mouse_screen = get_viewport().get_mouse_position()
	var mouse_local = world_view.to_local(mouse_screen)
	if not world_view.is_point_inside_map(mouse_local):
		edge_pan_accumulator = 0.0
		return

	var pan_delta = Vector2i.ZERO
	var map_pixel_width = float(view_tiles.x * grid.cell_size)
	var map_pixel_height = float(view_tiles.y * grid.cell_size)
	if mouse_local.x <= EDGE_PAN_MARGIN_PIXELS:
		pan_delta.x -= 1
	elif mouse_local.x >= map_pixel_width - EDGE_PAN_MARGIN_PIXELS:
		pan_delta.x += 1
	if mouse_local.y <= EDGE_PAN_MARGIN_PIXELS:
		pan_delta.y -= 1
	elif mouse_local.y >= map_pixel_height - EDGE_PAN_MARGIN_PIXELS:
		pan_delta.y += 1

	if pan_delta == Vector2i.ZERO:
		edge_pan_accumulator = 0.0
		return

	edge_pan_accumulator += delta
	var moved = false
	while edge_pan_accumulator >= EDGE_PAN_INTERVAL:
		edge_pan_accumulator -= EDGE_PAN_INTERVAL
		camera_cell += pan_delta
		_clamp_camera()
		moved = true

	if moved:
		_sync_presentation()
