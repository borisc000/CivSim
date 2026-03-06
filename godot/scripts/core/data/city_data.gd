class_name CityData
extends RefCounted

var id: int
var owner_id: int
var name: String
var cell: Vector2i
var population: int = 1
var food_stock: int = 0
var production_stock: int = 0
var hp: int = 16
var queue_type: String = "warrior"

func _init(p_id: int, p_owner_id: int, p_name: String, p_cell: Vector2i) -> void:
	id = p_id
	owner_id = p_owner_id
	name = p_name
	cell = p_cell
