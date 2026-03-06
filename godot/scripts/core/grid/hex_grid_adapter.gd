class_name HexGridAdapter
extends GridAdapter

# Placeholder adapter for future hex migration.
# This keeps the architecture stable while square remains active.
func neighbors(cell: Vector2i) -> Array:
	var is_even_row := cell.y % 2 == 0
	var offsets := []
	if is_even_row:
		offsets = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(0, 1), Vector2i(-1, 1)]
	else:
		offsets = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(0, 1)]
	var out: Array = []
	for offset in offsets:
		out.append(cell + offset)
	return out

func distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

func cell_to_local(cell: Vector2i, camera_cell: Vector2i) -> Vector2:
	var relative := cell - camera_cell
	var x_offset := 0.5 * cell_size if (relative.y % 2) != 0 else 0.0
	return Vector2(relative.x * cell_size + x_offset, relative.y * (cell_size * 0.86))

func local_to_cell(local_position: Vector2, camera_cell: Vector2i) -> Vector2i:
	var row := int(floor(local_position.y / (cell_size * 0.86)))
	var x_offset := 0.5 * cell_size if (row % 2) != 0 else 0.0
	var col := int(floor((local_position.x - x_offset) / float(cell_size)))
	return camera_cell + Vector2i(col, row)
