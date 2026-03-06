class_name GridAdapter
extends RefCounted

var cell_size: int = 32

func _init(p_cell_size: int = 32) -> void:
	cell_size = p_cell_size

func neighbors(_cell: Vector2i) -> Array:
	return []

func distance(_a: Vector2i, _b: Vector2i) -> int:
	return 0

func cell_to_local(_cell: Vector2i, _camera_cell: Vector2i) -> Vector2:
	return Vector2.ZERO

func local_to_cell(_local_position: Vector2, _camera_cell: Vector2i) -> Vector2i:
	return Vector2i.ZERO
