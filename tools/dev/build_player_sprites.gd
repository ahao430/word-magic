extends SceneTree
## One-shot: generate the player character sprites (32x48, hooded mage
## in a slate-blue robe) for four directions with idle + two walk
## frames each. True alpha cutouts; feet at the bottom edge.
##
##   godot --headless --path . -s res://tools/dev/build_player_sprites.gd
##   godot --headless --path . --import   # afterwards
##
## Output: assets/sprites/player/player_{down|up|left|right}_{idle|a|b}.png

const OUT_DIR := "res://assets/sprites/player"
const W := 32
const H := 48

# Slate-blue family keeps the identity of the polygon placeholder.
const ROBE_LIGHT := Color(0.20, 0.34, 0.56)
const ROBE_MID := Color(0.13, 0.25, 0.45)
const ROBE_DARK := Color(0.08, 0.16, 0.30)
const OUTLINE := Color(0.09, 0.08, 0.13)
const SKIN := Color(0.95, 0.79, 0.62)
const EYE := Color(0.12, 0.10, 0.14)
const BOOT := Color(0.24, 0.19, 0.15)
const CLASP := Color(0.85, 0.70, 0.30)


func _init() -> void:
	for frame in [["idle", 0], ["a", 1], ["b", 2]]:
		_save("down", frame[0], _front_back(true, frame[1]))
		_save("up", frame[0], _front_back(false, frame[1]))
		_save("left", frame[0], _profile(frame[1]))
		_save("right", frame[0], _mirror(_profile(frame[1])))
	print("[player] 12 sprites saved to " + OUT_DIR)
	quit()


func _save(dir_name: String, frame: String, img: Image) -> void:
	var err := img.save_png("%s/player_%s_%s.png" % [OUT_DIR, dir_name, frame])
	if err != OK:
		push_error("[player] save failed: " + dir_name + "/" + frame)
		quit(1)


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, c)


## Down/up frames share the symmetric silhouette. `face` toggles the
## front view; `phase` 0=idle, 1/2 = walk strides (1px body bob +
## alternating boot lift).
func _front_back(face: bool, phase: int) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var bob := 1 if phase > 0 else 0

	# Hood: outline circle, mid fill, light top arc.
	for y in range(6 - bob, 22 - bob):
		for x in range(6, 26):
			var d := Vector2(x - 16.0, y - 14.0 + bob).length()
			if d <= 6.6 and d > 5.2:
				_px(img, x, y, OUTLINE)
			elif d <= 5.2:
				_px(img, x, y, ROBE_LIGHT if y - bob < 12 else ROBE_MID)
	if face:
		# Face patch + eyes inside the hood (eyes one pixel closer than
		# before: the wide gap read as startled).
		for y in range(11 - bob, 19 - bob):
			for x in range(11, 21):
				if Vector2((x - 16.0) / 3.6, (y - 15.0 + bob) / 3.0).length() <= 1.0:
					_px(img, x, y, SKIN)
		_px(img, 15, 15 - bob, EYE)
		_px(img, 18, 15 - bob, EYE)
		_px(img, 16, 22 - bob, CLASP)
		_px(img, 16, 23 - bob, CLASP)
	else:
		# Back view: hood seam, no face.
		for y in range(8 - bob, 19 - bob):
			_px(img, 16, y, ROBE_DARK)

	# Robe: trapezoid from shoulders (y20) to hem (y40), edge shading.
	for y in range(20 - bob, 41 - bob):
		var hw := 5.0 + 0.26 * float(y + bob - 20)
		for x in range(int(16 - hw), int(16 + hw) + 1):
			var c := ROBE_MID
			if x <= int(16 - hw) + 1:
				c = ROBE_LIGHT
			elif x >= int(16 + hw) - 1:
				c = ROBE_DARK
			if (y + bob) == 27:
				c = ROBE_DARK  # belt
			if (y + bob) >= 39:
				c = ROBE_DARK  # hem
			_px(img, x, y, c)
	# Arms alongside the robe.
	for y in range(21 - bob, 30 - bob):
		_px(img, 8, y, ROBE_DARK)
		_px(img, 9, y, ROBE_MID)
		_px(img, 23, y, ROBE_DARK)
		_px(img, 24, y, ROBE_MID)
	_px(img, 9, 30 - bob, SKIN)
	_px(img, 23, 30 - bob, SKIN)

	# Boots: idle = both planted; strides alternate the lifted foot.
	var left_top := 42
	var right_top := 42
	if phase == 1:
		left_top = 43
	elif phase == 2:
		right_top = 43
	for y in range(left_top, 47):
		for x in range(12, 15):
			_px(img, x, y, BOOT)
	for y in range(right_top, 47):
		for x in range(18, 21):
			_px(img, x, y, BOOT)
	return img


## Left-facing profile; right is mirrored in _save().
func _profile(phase: int) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var bob := 1 if phase > 0 else 0

	for y in range(6 - bob, 22 - bob):
		for x in range(6, 26):
			var d := Vector2(x - 16.0, y - 14.0 + bob).length()
			if d <= 6.6 and d > 5.2:
				_px(img, x, y, OUTLINE)
			elif d <= 5.2:
				_px(img, x, y, ROBE_LIGHT if y - bob < 12 else ROBE_MID)
	# Face patch on the left side of the hood + one eye.
	for y in range(11 - bob, 19 - bob):
		for x in range(9, 16):
			if Vector2((x - 12.0) / 2.8, (y - 15.0 + bob) / 3.0).length() <= 1.0:
				_px(img, x, y, SKIN)
	_px(img, 11, 15 - bob, EYE)

	# Narrower profile robe with a single visible arm.
	for y in range(20 - bob, 41 - bob):
		var hw := 4.0 + 0.19 * float(y + bob - 20)
		for x in range(int(16 - hw), int(16 + hw) + 1):
			var c := ROBE_MID
			if x <= int(16 - hw) + 1:
				c = ROBE_LIGHT
			elif x >= int(16 + hw) - 1:
				c = ROBE_DARK
			if (y + bob) == 27:
				c = ROBE_DARK
			if (y + bob) >= 39:
				c = ROBE_DARK
			_px(img, x, y, c)
	for y in range(21 - bob, 29 - bob):
		_px(img, 15, y, ROBE_DARK)
		_px(img, 16, y, ROBE_DARK)

	# Stride: boots split forward/back on walk phases.
	var front_x := 13
	var back_x := 18
	if phase == 1:
		front_x = 11
		back_x = 18
	elif phase == 2:
		front_x = 14
		back_x = 20
	for y in range(42, 47):
		for x in range(front_x, front_x + 3):
			_px(img, x, y, BOOT)
		for x in range(back_x, back_x + 3):
			_px(img, x, y, BOOT)
	return img


func _mirror(img: Image) -> Image:
	var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			out.set_pixel(W - 1 - x, y, img.get_pixel(x, y))
	return out
