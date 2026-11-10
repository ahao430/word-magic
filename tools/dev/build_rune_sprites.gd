extends SceneTree
## One-shot: generate the rune-stone sprites (20x28 ancient slab, two
## states: dormant dark glyph / awakened cyan-glowing glyph).
##
##   godot --headless --path . -s res://tools/dev/build_rune_sprites.gd
##   godot --headless --path . --import   # afterwards

const OUT_DIR := "res://assets/sprites/puzzles"
const W := 20
const H := 28

const STONE_MID := Color(0.52, 0.54, 0.58)
const STONE_LIGHT := Color(0.65, 0.67, 0.70)
const STONE_DARK := Color(0.36, 0.38, 0.43)
const OUTLINE := Color(0.18, 0.19, 0.23)
const GLYPH_DORMANT := Color(0.24, 0.30, 0.40)
const GLYPH_AWAKE := Color(0.45, 0.95, 1.00)
const GLYPH_CORE := Color(0.90, 1.00, 1.00)


func _init() -> void:
	_save("rune_inactive.png", _slab(GLYPH_DORMANT, false))
	_save("rune_active.png", _slab(GLYPH_AWAKE, true))
	print("[rune] 2 sprites saved to " + OUT_DIR)
	quit()


func _save(file_name: String, img: Image) -> void:
	var err := img.save_png("%s/%s" % [OUT_DIR, file_name])
	if err != OK:
		push_error("[rune] save failed: " + file_name)
		quit(1)


## Rounded-top slab with NE lighting; a carved water-glyph (one trunk,
## two flow branches). Awake variant gets a white-hot glyph core.
func _slab(glyph: Color, awake: bool) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			# Slab: rectangle with rounded top corners.
			var d := Vector2(x - 9.5, y - 9.5).length()
			var in_top := y >= 8 or d <= 8.0
			var in_body := x >= 2 and x <= 17 and y >= 8 and y <= 26
			if not (in_top and in_body and x >= 2 and x <= 17):
				continue
			if y == 26 or x == 2 or x == 17 or (y < 12 and d > 7.0):
				img.set_pixel(x, y, OUTLINE)
				continue
			var c := STONE_MID
			if x + y < 22:
				c = STONE_LIGHT
			elif x - y > 4 or y > 22:
				c = STONE_DARK
			img.set_pixel(x, y, c)
	# Glyph: trunk + two branches (a carved watercourse).
	var pts: Array = [
		Vector2i(9, 8), Vector2i(9, 9), Vector2i(9, 10), Vector2i(9, 11),
		Vector2i(9, 12), Vector2i(9, 13), Vector2i(9, 14), Vector2i(9, 15),
		Vector2i(9, 16), Vector2i(9, 17), Vector2i(9, 18), Vector2i(9, 19),
		Vector2i(6, 10), Vector2i(7, 11), Vector2i(8, 12),
		Vector2i(12, 13), Vector2i(11, 14), Vector2i(10, 15),
		Vector2i(6, 16), Vector2i(7, 17), Vector2i(8, 18),
		Vector2i(12, 17), Vector2i(11, 18), Vector2i(10, 19),
	]
	for p in pts:
		img.set_pixel(p.x, p.y, glyph)
	if awake:
		for i in pts.size():
			if i % 3 == 0:
				img.set_pixel(pts[i].x, pts[i].y, GLYPH_CORE)
	return img
