class_name PlayerData
extends RefCounted

var id: int
var name: String
var color: Color
var dark_color: Color
var is_human: bool
var gold: int = 10
var science: int = 0
var units: Array = []
var cities: Array = []
var visible_cells: Dictionary = {}
var explored_cells: Dictionary = {}

func _init(p_id: int, p_name: String, p_color: Color, p_dark_color: Color, p_is_human: bool) -> void:
	id = p_id
	name = p_name
	color = p_color
	dark_color = p_dark_color
	is_human = p_is_human
