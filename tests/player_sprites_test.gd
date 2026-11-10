extends SceneTree
## Headless test for the generated player character sprites.
##
##   godot --headless --path . -s res://tests/player_sprites_test.gd
##
## Verifies 12 files at 32x48, true alpha cutouts, planted boots at the
## bottom center, and direction semantics: skin visible for down (face
## front), none for up (back view), skin left-of-center for left and
## right-of-center for right.

const DIR := "res://assets/sprites/player"
const DIRECTIONS := ["down", "up", "left", "right"]
const FRAMES := ["idle", "a", "b"]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for dir_name in DIRECTIONS:
		for frame in FRAMES:
			var path := "%s/player_%s_%s.png" % [DIR, dir_name, frame]
			var tex: Texture2D = load(path)
			_expect(tex != null, "%s/%s loads" % [dir_name, frame])
			if tex == null:
				continue
			var img := tex.get_image()
			_expect(Vector2i(img.get_size()) == Vector2i(32, 48),
					"%s/%s size 32x48" % [dir_name, frame])
			_expect(_is_cutout(img), "%s/%s is a true alpha cutout" % [dir_name, frame])
			_expect(_boots_planted(img), "%s/%s boots planted at bottom" % [dir_name, frame])
			# Direction semantics via skin pixels in the head region.
			var skin_left := _skin_count(img, Rect2i(8, 10, 8, 10))
			var skin_right := _skin_count(img, Rect2i(16, 10, 8, 10))
			match dir_name:
				"down":
					_expect(skin_left > 3 and skin_right > 3, "down/%s face front" % frame)
				"up":
					_expect(skin_left == 0 and skin_right == 0, "up/%s back view (no skin)" % frame)
				"left":
					_expect(skin_left > skin_right, "left/%s face on the left" % frame)
				"right":
					_expect(skin_right > skin_left, "right/%s face on the right" % frame)

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


func _boots_planted(img: Image) -> bool:
	var planted := 0
	for y in range(44, 47):
		for x in range(11, 21):
			if img.get_pixel(x, y).a > 0.95:
				planted += 1
	return planted >= 6


func _is_skin(c: Color) -> bool:
	return c.r > 0.85 and c.g > 0.65 and c.b > 0.45 and c.b < c.g


func _skin_count(img: Image, region: Rect2i) -> int:
	var count := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if _is_skin(img.get_pixel(x, y)):
				count += 1
	return count
