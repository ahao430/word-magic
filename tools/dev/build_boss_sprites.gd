extends SceneTree
## One-shot: generate the Slime King boss sprites (56x44, two heavy
## bounce frames + golden crown), a wide drop shadow, and the
## SpriteFrames resource (written as text like slime_frames.tres so the
## PNGs only need the standard import pass).
##
##   godot --headless --path . -s res://tools/dev/build_boss_sprites.gd
##   godot --headless --path . --import   # afterwards

const OUT_DIR := "res://assets/sprites/enemies"
const SHADOW_OUT := "res://assets/sprites/effects/boss_shadow_28x12.png"
const FRAMES_OUT := "res://assets/sprites/enemies/boss_frames.tres"
const W := 56
const H := 44

## Deeper green than the regular slime: the king reads as the same
## species but heavier and older.
const MID := Color(0.36, 0.66, 0.30)
const LIGHT := Color(0.52, 0.82, 0.38)
const DARK := Color(0.20, 0.42, 0.20)
const OUTLINE := Color(0.09, 0.19, 0.10)
const EYE := Color(0.08, 0.10, 0.08)
const GOLD := Color(0.95, 0.78, 0.25)
const GOLD_DARK := Color(0.72, 0.55, 0.15)
const GEM := Color(0.85, 0.15, 0.20)


func _init() -> void:
	_save("boss_slime_idle_01", _blob(24.0, 15.0, 28.0, 27.0, 26))
	_save("boss_slime_idle_02", _blob(26.0, 13.5, 28.0, 28.5, 28))
	_save_shadow()
	_save_frames()
	print("[boss] 2 sprites + shadow + frames saved to " + OUT_DIR)
	quit()


func _save(name: String, img: Image) -> void:
	var err := img.save_png("%s/%s.png" % [OUT_DIR, name])
	if err != OK:
		push_error("[boss] save failed: " + name)
		quit(1)


## King blob: same dome recipe as the slime, scaled up, with the crown
## drawn on top of the dome apex.
func _blob(rx: float, ry: float, cx: float, cy: float, eye_y: int) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in range(6, H):
		for x in W:
			var d := Vector2((x - cx) / rx, (y - cy) / ry).length()
			if d > 1.18:
				continue
			if d > 1.0:
				img.set_pixel(x, y, OUTLINE)
				continue
			var c := MID
			if Vector2(x - (cx - 7.0), y - (cy - 9.0)).length() < 7.0:
				c = LIGHT
			elif y >= H - 3 or d > 0.88:
				c = DARK
			img.set_pixel(x, y, c)
	_draw_crown(img, cx, cy - ry)
	# Eyes: 4x3 dark with a 2px white glint each (bigger read at boss scale).
	for ex: int in [18, 32]:
		for dy in 3:
			for dx in 4:
				img.set_pixel(ex + dx, eye_y + dy, EYE)
		img.set_pixel(ex + 3, eye_y, Color.WHITE)
		img.set_pixel(ex + 3, eye_y + 1, Color.WHITE)
	return img


## Three-spike golden crown, base band sunk 2px into the dome so it
## reads as worn rather than floating.
func _draw_crown(img: Image, cx: float, dome_top: float) -> void:
	var base_y := int(round(dome_top)) + 2
	for y in 3:
		for x in range(int(cx) - 9, int(cx) + 10):
			img.set_pixel(x, base_y - 1 + y, GOLD if y < 2 else GOLD_DARK)
	for spike: int in [-6, 0, 6]:
		var sx := int(cx) + spike
		for h in 5:
			var half: int = maxi(0, 2 - int(h / 2))
			for dx in range(-half, half + 1):
				img.set_pixel(sx + dx, base_y - 2 - h, GOLD)
	img.set_pixel(int(cx), base_y, GEM)


func _save_shadow() -> void:
	## Same radial-alpha recipe as shadow_16x8, stretched for the boss.
	var img := Image.create(28, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 28:
			var d := Vector2((x - 13.5) / 13.5, (y - 5.5) / 5.5).length()
			if d >= 1.0:
				continue
			var a := clampf((1.0 - d) * 1.5, 0.0, 1.0) * 0.5
			img.set_pixel(x, y, Color(0, 0, 0, a))
	var err := img.save_png(SHADOW_OUT)
	if err != OK:
		push_error("[boss] shadow save failed")
		quit(1)


func _save_frames() -> void:
	## Text .tres mirroring slime_frames.tres: two bouncing frames at a
	## slower, heavier tempo.
	var text := """[gd_resource type="SpriteFrames" format=3]

[ext_resource type="Texture2D" path="res://assets/sprites/enemies/boss_slime_idle_01.png" id="1_bf01"]

[ext_resource type="Texture2D" path="res://assets/sprites/enemies/boss_slime_idle_02.png" id="2_bf02"]

[resource]
resource_name = "BossSlimeFrames"
animations = [{
"frames": [{
"duration": 1.0,
"texture": ExtResource("1_bf01")
}, {
"duration": 1.0,
"texture": ExtResource("2_bf02")
}],
"loop": 1,
"name": &"default",
"speed": 2.0
}]
"""
	var file := FileAccess.open(FRAMES_OUT, FileAccess.WRITE)
	if file == null:
		push_error("[boss] frames write failed")
		quit(1)
		return
	file.store_string(text)
	file.close()
