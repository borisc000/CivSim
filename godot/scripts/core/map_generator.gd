class_name MapGenerator
extends RefCounted

func generate(width: int, height: int, rng: RandomNumberGenerator) -> Array:
	var land_mask: Array = []
	for y in range(height):
		var row: Array = []
		for x in range(width):
			var edge_penalty := 0.18 if x < 3 or y < 3 or x > width - 4 or y > height - 4 else 0.0
			row.append(rng.randf() > (0.43 + edge_penalty))
		land_mask.append(row)

	for _pass in range(4):
		var next_mask: Array = []
		for y in range(height):
			var row: Array = []
			for x in range(width):
				var count := 0
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						if ox == 0 and oy == 0:
							continue
						var nx := x + ox
						var ny := y + oy
						if nx < 0 or ny < 0 or nx >= width or ny >= height or land_mask[ny][nx]:
							count += 1
				row.append(count >= 5)
			next_mask.append(row)
		land_mask = next_mask

	var out_tiles: Array = []
	for y in range(height):
		var row: Array = []
		for x in range(width):
			var terrain := "water"
			if land_mask[y][x]:
				var roll := rng.randf()
				if roll < 0.34:
					terrain = "grass"
				elif roll < 0.60:
					terrain = "plains"
				elif roll < 0.83:
					terrain = "forest"
				else:
					terrain = "hill"
			row.append(terrain)
		out_tiles.append(row)
	return out_tiles
