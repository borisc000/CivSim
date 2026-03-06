class_name Ruleset
extends RefCounted

const TERRAIN_DATA = {
	"water": {"name": "Agua", "move_cost": 999, "defense": 0, "food": 1, "production": 0, "gold": 1, "color": Color("#2d628e"), "accent": Color("#4d8ec2")},
	"grass": {"name": "Pradera", "move_cost": 1, "defense": 0, "food": 2, "production": 1, "gold": 1, "color": Color("#6ca969"), "accent": Color("#8fcc7d")},
	"plains": {"name": "Llanura", "move_cost": 1, "defense": 0, "food": 1, "production": 2, "gold": 1, "color": Color("#bda969"), "accent": Color("#dfca87")},
	"forest": {"name": "Bosque", "move_cost": 2, "defense": 1, "food": 1, "production": 2, "gold": 0, "color": Color("#3f7644"), "accent": Color("#77b85f")},
	"hill": {"name": "Colina", "move_cost": 2, "defense": 2, "food": 0, "production": 2, "gold": 2, "color": Color("#8c7656"), "accent": Color("#caa57d")},
}

const UNIT_DATA = {
	"settler": {"name": "Colono", "hp": 10, "attack": 0, "moves": 2, "vision": 3, "cost": 18, "can_found_city": true},
	"warrior": {"name": "Guerrero", "hp": 12, "attack": 4, "moves": 2, "vision": 3, "cost": 14, "can_found_city": false},
	"scout": {"name": "Explorador", "hp": 8, "attack": 2, "moves": 3, "vision": 4, "cost": 10, "can_found_city": false},
}

const CITY_NAMES = [
	"Aurora",
	"Helios",
	"Argos",
	"Vesta",
	"Nova",
	"Lumen",
	"Orion",
	"Atlas",
	"Delta",
	"Pax",
]

const UnitData = preload("res://scripts/core/data/unit_data.gd")
const CityData = preload("res://scripts/core/data/city_data.gd")

func terrain_info(terrain_id: String) -> Dictionary:
	return TERRAIN_DATA.get(terrain_id, TERRAIN_DATA["grass"])

func unit_info(unit_type: String) -> Dictionary:
	return UNIT_DATA.get(unit_type, UNIT_DATA["warrior"])

func terrain_move_cost(terrain_id: String) -> int:
	return int(terrain_info(terrain_id).get("move_cost", 1))

func terrain_defense_bonus(terrain_id: String) -> int:
	return int(terrain_info(terrain_id).get("defense", 0))

func terrain_yield(terrain_id: String) -> Dictionary:
	var info = terrain_info(terrain_id)
	return {
		"food": int(info.get("food", 0)),
		"production": int(info.get("production", 0)),
		"gold": int(info.get("gold", 0)),
	}

func create_unit(unit_type: String, owner_id: int, cell: Vector2i, unit_id: int):
	var info = unit_info(unit_type)
	return UnitData.new(
		unit_id,
		unit_type,
		owner_id,
		cell,
		int(info["hp"]),
		int(info["attack"]),
		int(info["moves"]),
		int(info["vision"]),
		bool(info["can_found_city"])
	)

func create_city(owner_id: int, city_id: int, city_name_cursor: int, cell: Vector2i):
	var name = "%s%d" % [CITY_NAMES[city_name_cursor % CITY_NAMES.size()], int(city_name_cursor / CITY_NAMES.size()) + 1]
	return CityData.new(city_id, owner_id, name, cell)
