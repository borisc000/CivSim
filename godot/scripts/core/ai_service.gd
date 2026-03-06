class_name AIService
extends RefCounted

func choose_city_queue(player, state, rules) -> void:
	var settler_count = 0
	for unit in player.units:
		if unit.type_id == "settler":
			settler_count += 1

	for city in player.cities:
		if city.queue_type != "":
			continue
		if player.cities.size() < 2 and settler_count == 0 and city.population >= 2:
			city.queue_type = "settler"
		elif player.units.size() < player.cities.size() * 3:
			city.queue_type = "warrior"
		else:
			city.queue_type = "scout"

func nearest_enemy_target_cell(unit, state, grid) -> Vector2i:
	var best_cell = unit.cell
	var best_distance = 999999
	for player in state.players:
		if player.id == unit.owner_id:
			continue
		for city in player.cities:
			var d = grid.distance(unit.cell, city.cell)
			if d < best_distance:
				best_distance = d
				best_cell = city.cell
		for enemy_unit in player.units:
			var d = grid.distance(unit.cell, enemy_unit.cell)
			if d < best_distance:
				best_distance = d
				best_cell = enemy_unit.cell
	return best_cell

func best_settler_site(unit, state, rules, grid) -> Vector2i:
	var best_cell = unit.cell
	var best_score = -999999
	for y in range(max(1, unit.cell.y - 6), min(state.map_height - 1, unit.cell.y + 7)):
		for x in range(max(1, unit.cell.x - 6), min(state.map_width - 1, unit.cell.x + 7)):
			var cell = Vector2i(x, y)
			if not can_settle_at(cell, state):
				continue
			var score = score_city_site(cell, state, rules) - grid.distance(unit.cell, cell)
			if score > best_score:
				best_score = score
				best_cell = cell
	return best_cell

func score_city_site(cell: Vector2i, state, rules) -> int:
	var score = 0
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var check = cell + Vector2i(ox, oy)
			if not state.in_bounds(check):
				score -= 2
				continue
			var terrain = state.tiles[check.y][check.x]
			var tile_yield = rules.terrain_yield(terrain)
			score += int(tile_yield["food"]) * 2 + int(tile_yield["production"]) * 2 + int(tile_yield["gold"])
			if terrain == "water":
				score -= 2
	return score

func can_settle_at(cell: Vector2i, state) -> bool:
	if not state.in_bounds(cell):
		return false
	if state.tiles[cell.y][cell.x] == "water":
		return false
	if state.get_unit_at(cell) != null or state.get_city_at(cell) != null:
		return false
	for city in state.all_cities():
		if abs(city.cell.x - cell.x) + abs(city.cell.y - cell.y) < 5:
			return false
	return true
