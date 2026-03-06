class_name SquareGridAdapter
extends GridAdapter

func neighbors(cell: Vector2i) -> Array:
	return [
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x, cell.y + 1),
		Vector2i(cell.x, cell.y - 1),
	]

func distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func cell_to_local(cell: Vector2i, camera_cell: Vector2i) -> Vector2:
	var relative := cell - camera_cell
	return Vector2(relative.x * cell_size, relative.y * cell_size)

func local_to_cell(local_position: Vector2, camera_cell: Vector2i) -> Vector2i:
	var cx := int(floor(local_position.x / float(cell_size)))
	var cy := int(floor(local_position.y / float(cell_size)))
	return camera_cell + Vector2i(cx, cy)
