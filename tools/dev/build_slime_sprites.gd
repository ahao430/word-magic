extends SceneTree
## One-shot: generate the slime enemy sprites (24x20, two idle-bounce
## frames: normal dome and squashed). True alpha cutouts; eyes with
## white glints; bottom shade band reads as ground contact.
##
##   godot --headless --path . -s res://tools/dev/build_slime_sprites.gd
##   godot --headless --path . --import   # afterwards

const OUT_DIR := "res://assets/sprites/enemies"
const W := 24
const H := 20

const MID := Color(0.45, 0.78, 0.35)
const LIGHT := Color(0.62, 0.90, 0.45)
const DARK := Color(0.28, 0.55, 0.25)
const OUTLINE := Color(0.13, 0.25, 0.14)
const EYE := Color(0.10, 0.12, 0.10)


func _init() -> void:
	_save("slime_idle_01", _blob(11.0, 8.0, 12.0, 12.0, 10))
	_save("slime_idle_02", _blob(12.0, 7.0, 12.0, 13.0, 11))
	print("[slime] 2 sprites saved to " + OUT_DIR)
	quit()


func _save(name: String, img: Image) -> void:
	var err := img.save_png("%s/%s.png" % [OUT_DIR, name])
	if err != OK:
		push_error("[slime] save failed: " + name)
		quit(1)


## Dome blob: ellipse clipped to the lower canvas, outline ring, NE
## highlight, bottom shade band, eyes with glints.
func _blob(rx: float, ry: float, cx: float, cy: float, eye_y: int) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in range(3, H):
		for x in W:
			var d := Vector2((x - cx) / rx, (y - cy) / ry).length()
			if d > 1.18:
				continue
			if d > 1.0:
				img.set_pixel(x, y, OUTLINE)
				continue
			var c := MID
			if Vector2(x - (cx - 3.0), y - (cy - 4.0)).length() < 3.4:
				c = LIGHT
			elif y >= H - 2 or d > 0.88:
				c = DARK
			img.set_pixel(x, y, c)
	# Eyes: 2x2 dark with a 1px white glint each.
	for ex in [7, 14]:
		for dy in 2:
			for dx in 2:
				img.set_pixel(ex + dx, eye_y + dy, EYE)
		img.set_pixel(ex + 1, eye_y, Color.WHITE)
	return img
