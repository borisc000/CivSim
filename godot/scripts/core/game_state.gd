class_name GameState
extends RefCounted

var map_width: int = 0
var map_height: int = 0
var tiles: Array = []
var players: Array = []

var current_player_index: int = 0
var turn_number: int = 1
var winner_player_id: int = -1

var selected_unit_id: int = -1
var selected_city_id: int = -1

var next_unit_id: int = 1
var next_city_id: int = 1
var city_name_cursor: int = 0

var logs: Array[String] = []

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < map_width and cell.y < map_height

func get_current_player():
	if players.is_empty():
		return null
	return players[current_player_index]

func get_player_by_id(player_id: int):
	for player in players:
		if player.id == player_id:
			return player
	return null

func all_units() -> Array:
	var units: Array = []
	for player in players:
		for unit in player.units:
			units.append(unit)
	return units

func all_cities() -> Array:
	var cities: Array = []
	for player in players:
		for city in player.cities:
			cities.append(city)
	return cities

func get_unit_at(cell: Vector2i):
	for player in players:
		for unit in player.units:
			if unit.cell == cell:
				return unit
	return null

func get_city_at(cell: Vector2i):
	for player in players:
		for city in player.cities:
			if city.cell == cell:
				return city
	return null

func remove_unit(unit) -> void:
	for player in players:
		if unit in player.units:
			player.units.erase(unit)
			if selected_unit_id == unit.id:
				selected_unit_id = -1
			return

func remove_city(city) -> void:
	for player in players:
		if city in player.cities:
			player.cities.erase(city)
			if selected_city_id == city.id:
				selected_city_id = -1
			return

func add_unit(player_id: int, unit) -> void:
	var owner = get_player_by_id(player_id)
	if owner != null:
		owner.units.append(unit)

func add_city(player_id: int, city) -> void:
	var owner = get_player_by_id(player_id)
	if owner != null:
		owner.cities.append(city)

func capture_city(city, new_owner_id: int) -> void:
	var old_owner = get_player_by_id(city.owner_id)
	if old_owner != null:
		old_owner.cities.erase(city)
	var new_owner = get_player_by_id(new_owner_id)
	if new_owner != null:
		city.owner_id = new_owner_id
		new_owner.cities.append(city)

func find_unit_in_player(player, unit_id: int):
	for unit in player.units:
		if unit.id == unit_id:
			return unit
	return null

func find_city_in_player(player, city_id: int):
	for city in player.cities:
		if city.id == city_id:
			return city
	return null

func clear_selection() -> void:
	selected_unit_id = -1
	selected_city_id = -1

func advance_player() -> void:
	current_player_index = (current_player_index + 1) % players.size()
	if current_player_index == 0:
		turn_number += 1
	clear_selection()

func log(message: String) -> void:
	logs.append(message)
	if logs.size() > 12:
		logs = logs.slice(logs.size() - 12, logs.size())

func alive_players() -> Array:
	var alive: Array = []
	for player in players:
		if not player.units.is_empty() or not player.cities.is_empty():
			alive.append(player)
	return alive
