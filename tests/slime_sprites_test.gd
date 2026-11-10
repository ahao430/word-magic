extends SceneTree
## Headless test for the generated slime sprites.
##
##   godot --headless --path . -s res://tests/slime_sprites_test.gd

const DIR := "res://assets/sprites/enemies"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for frame in ["slime_idle_01", "slime_idle_02"]:
		var tex: Texture2D = load("%s/%s.png" % [DIR, frame])
		_expect(tex != null, "%s loads" % frame)
		if tex == null:
			continue
		var img := tex.get_image()
		_expect(Vector2i(img.get_size()) == Vector2i(24, 20), "%s size 24x20" % frame)
		_expect(_is_cutout(img), "%s is a true alpha cutout" % frame)
		_expect(_green_ratio(img) >= 0.4, "%s is green-dominant" % frame)
		_expect(_has_dark_eyes(img), "%s has dark eye pixels" % frame)
		_expect(_bottom_row_opaque(img), "%s bottom row solid (grounded)" % frame)

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


func _is_cutout(img: Image) -> bool:
	var clear := false
	var opaque := false
	for y in img.get_height():
		for x in img.get_width():
			var a := img.get_pixel(x, y).a
			if a < 0.1:
				clear = true
			elif a > 0.95:
				opaque = true
	return clear and opaque


func _green_ratio(img: Image) -> float:
	var total := 0
	var green := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			total += 1
			if c.g > c.r and c.g > c.b:
				green += 1
	return float(green) / float(max(total, 1))


func _has_dark_eyes(img: Image) -> bool:
	var dark := 0
	for y in range(8, 14):
		for x in range(6, 18):
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and c.r < 0.2 and c.g < 0.25:
				dark += 1
	return dark >= 6


func _bottom_row_opaque(img: Image) -> bool:
	var solid := 0
	for x in range(6, 18):
		if img.get_pixel(x, 19).a > 0.95:
			solid += 1
	return solid >= 6
