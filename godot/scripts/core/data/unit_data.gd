class_name UnitData
extends RefCounted

var id: int
var type_id: String
var owner_id: int
var cell: Vector2i
var hp: int
var max_hp: int
var attack: int
var moves_left: int
var max_moves: int
var vision: int
var can_found_city: bool

func _init(
	p_id: int,
	p_type_id: String,
	p_owner_id: int,
	p_cell: Vector2i,
	p_hp: int,
	p_attack: int,
	p_max_moves: int,
	p_vision: int,
	p_can_found_city: bool
) -> void:
	id = p_id
	type_id = p_type_id
	owner_id = p_owner_id
	cell = p_cell
	hp = p_hp
	max_hp = p_hp
	attack = p_attack
	max_moves = p_max_moves
	moves_left = p_max_moves
	vision = p_vision
	can_found_city = p_can_found_city
