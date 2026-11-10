extends SceneTree
## Headless test for the procedural water tiles.
##
##   godot --headless --path . -s res://tests/water_tiles_test.gd
##
## Verifies surface tiles are blue-dominant and the 16 shore masks put
## grass on land sides, water in the center, with a bank line between.

const WATER := preload("res://tools/dev/water_tiles.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var tiles := WATER.generate()

	_expect(tiles.size() == 20, "tile count is 20 (got %d)" % tiles.size())
	for i in 20:
		var img: Image = tiles[i]
		_expect(img.get_width() == 32 and img.get_height() == 32, "tile %d size 32x32" % i)

	# Surfaces (indices 0-3): overwhelmingly blue pixels.
	for i in 4:
		_expect(_blue_ratio(tiles[i]) >= 0.9, "surface %d is blue-dominant" % i)

	# Shore semantics (indices 4-19 == mask 0-15).
	# mask 0 = open water, fully blue.
	_expect(_blue_ratio(tiles[4]) >= 0.95, "shore mask 0 fully water")
	# N edge (mask 1, index 5): top rows grass, bottom rows water.
	_expect(_grass_ratio(tiles[5], Rect2i(0, 0, 32, 3)) >= 0.6, "mask 1 top rows grassy")
	_expect(_blue_ratio_region(tiles[5], Rect2i(0, 20, 32, 12)) >= 0.9, "mask 1 lower half water")
	# W edge (mask 8, index 12): left cols grass, right cols water.
	_expect(_grass_ratio(tiles[12], Rect2i(0, 0, 3, 32)) >= 0.6, "mask 8 left cols grassy")
	_expect(_blue_ratio_region(tiles[12], Rect2i(20, 0, 12, 32)) >= 0.9, "mask 8 right cols water")
	# Island (mask 15, index 19): center water, ring grass.
	_expect(_blue_ratio_region(tiles[19], Rect2i(12, 12, 8, 8)) >= 0.9, "mask 15 center water")
	_expect(_grass_ratio(tiles[19], Rect2i(0, 0, 32, 2)) >= 0.6, "mask 15 top ring grassy")
	# Bank line exists on the N edge tile: a row between grass and water
	# that is darker than both families (luminance check).
	_expect(_has_bank_line(tiles[5]), "mask 1 has a dark bank line")

	if _failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES: %d" % _failures)
		quit(1)


func _expect(cond: bool, what: String) -> void:
	if cond:
		print("PASS  " + what)
	else:
		_failures += 1
		print("FAIL  " + what)


func _is_blue(c: Color) -> bool:
	return c.b > c.r and c.b > c.g


func _is_grass(c: Color) -> bool:
	return c.g > c.r and c.g > c.b


func _blue_ratio(img: Image) -> float:
	return _ratio(img, Rect2i(Vector2i.ZERO, img.get_size()), _is_blue)


func _blue_ratio_region(img: Image, region: Rect2i) -> float:
	return _ratio(img, region, _is_blue)


func _grass_ratio(img: Image, region: Rect2i) -> float:
	return _ratio(img, region, _is_grass)


func _ratio(img: Image, region: Rect2i, pred: Callable) -> float:
	var total := 0
	var hits := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			total += 1
			if pred.call(img.get_pixel(x, y)):
				hits += 1
	return float(hits) / float(max(total, 1))


func _has_bank_line(img: Image) -> bool:
	## Scan columns 8..24 for a row where a very dark pixel sits between
	## a grass pixel above and a water pixel below.
	for x in range(8, 25, 2):
		for y in range(1, 20):
			var here := img.get_pixel(x, y)
			var lum := here.r * 0.299 + here.g * 0.587 + here.b * 0.114
			if lum < 0.3 and _is_grass(img.get_pixel(x, y - 1)) and _is_blue(img.get_pixel(x, y + 1)):
				return true
	return false
