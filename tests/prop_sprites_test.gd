extends SceneTree
## Headless test for the generated forest prop sprites.
##
##   godot --headless --path . -s res://tests/prop_sprites_test.gd
##
## Verifies files exist with correct sizes, are true alpha cutouts
## (both transparent and opaque pixels), tree trunk base is solid
## brown at bottom-center, and rock/bush silhouettes are centered.

const PROPS_DIR := "res://assets/sprites/props"

const EXPECTED := {
	"tree_01.png": Vector2i(32, 48),
	"tree_02.png": Vector2i(32, 48),
	"rock_01.png": Vector2i(24, 18),
	"rock_02.png": Vector2i(24, 18),
	"bush_01.png": Vector2i(20, 14),
	"bush_02.png": Vector2i(20, 14),
}

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for file_name in EXPECTED:
		var path := "%s/%s" % [PROPS_DIR, file_name]
		var tex: Texture2D = load(path)
		_expect(tex != null, "%s loads" % file_name)
		if tex == null:
			continue
		var img := tex.get_image()
		_expect(Vector2i(img.get_size()) == EXPECTED[file_name],
				"%s size %s" % [file_name, EXPECTED[file_name]])
		_expect(_is_cutout(img), "%s is a true alpha cutout" % file_name)
		if file_name.begins_with("tree"):
			_expect(_trunk_base_solid(img), "%s trunk base solid brown" % file_name)
			_expect(img.get_pixel(0, 0).a < 0.1, "%s top-left corner transparent" % file_name)

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
	var has_clear := false
	var has_opaque := false
	for y in img.get_height():
		for x in img.get_width():
			var a := img.get_pixel(x, y).a
			if a < 0.1:
				has_clear = true
			elif a > 0.95:
				has_opaque = true
	return has_clear and has_opaque


func _trunk_base_solid(img: Image) -> bool:
	# Bottom-center 4x3 region must be opaque and brown-ish (r > g).
	var opaque_brown := 0
	for y in range(img.get_height() - 3, img.get_height()):
		for x in range(14, 18):
			var c := img.get_pixel(x, y)
			if c.a > 0.95 and c.r > c.g:
				opaque_brown += 1
	return opaque_brown >= 10
