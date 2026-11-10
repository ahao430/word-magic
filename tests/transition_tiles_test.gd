extends SceneTree
## Headless test for the procedural grass->dirt transition tiles.
##
##   godot --headless --path . -s res://tests/transition_tiles_test.gd
##
## Verifies count, size, full opacity and per-mask semantics:
##   mask 0 (no grass neighbors)  -> pure dirt, no grass pixels
##   N edge (mask 1)              -> top rows grass, bottom rows dirt
##   E edge (mask 2)              -> right cols grass, left cols dirt
##   island (mask 15)             -> grass ring, dirt center

const TRANSITIONS := preload("res://tools/dev/transition_tiles.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var tiles := TRANSITIONS.generate()

	_expect(tiles.size() == 16, "tile count is 16 (got %d)" % tiles.size())
	for mask in 16:
		var img: Image = tiles[mask]
		_expect(img.get_width() == 32 and img.get_height() == 32,
				"mask %d size 32x32 (got %dx%d)" % [mask, img.get_width(), img.get_height()])
		_expect(_all_opaque(img), "mask %d fully opaque" % mask)

	# Semantic checks. dirt_plain itself carries ~0.8% stray green flecks,
	# so dirt-side expectations allow a small green ratio.
	_expect(_grass_ratio(tiles[0]) <= 0.02, "mask 0 is pure dirt")
	_expect(_region_grass_ratio(tiles[1], Rect2i(0, 0, 32, 4)) >= 0.7, "mask 1 top rows grassy")
	_expect(_region_grass_ratio(tiles[1], Rect2i(0, 28, 32, 4)) <= 0.08, "mask 1 bottom rows dirt")
	_expect(_region_grass_ratio(tiles[2], Rect2i(28, 0, 4, 32)) >= 0.7, "mask 2 right cols grassy")
	_expect(_region_grass_ratio(tiles[2], Rect2i(0, 0, 4, 32)) <= 0.05, "mask 2 left cols dirt")
	_expect(_region_grass_ratio(tiles[15], Rect2i(0, 0, 32, 2)) >= 0.7, "mask 15 top ring grassy")
	_expect(_region_grass_ratio(tiles[15], Rect2i(12, 12, 8, 8)) <= 0.05, "mask 15 center dirt")

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


func _is_grass(c: Color) -> bool:
	return c.g > c.r and c.g > c.b


func _all_opaque(img: Image) -> bool:
	# Image.get_pixel returns components in the 0..1 range.
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a < 1.0:
				return false
	return true


func _grass_ratio(img: Image) -> float:
	return _region_grass_ratio(img, Rect2i(Vector2i.ZERO, img.get_size()))


func _region_grass_ratio(img: Image, region: Rect2i) -> float:
	var total := 0
	var grassy := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			total += 1
			if _is_grass(img.get_pixel(x, y)):
				grassy += 1
	return float(grassy) / float(max(total, 1))
