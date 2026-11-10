extends SceneTree
## One-shot: generate the elemental orb sprite (16x16 radial white orb
## with a soft blue rim) used as the tintable projectile base.
##
##   godot --headless --path . -s res://tools/dev/build_orb_sprite.gd
##   godot --headless --path . --import   # afterwards

const OUT := "res://assets/sprites/effects/orb_16.png"
const SIZE := 16

const CORE := Color(1.0, 1.0, 1.0)
const MID := Color(0.85, 0.92, 1.0)
const RIM := Color(0.55, 0.72, 1.0)


func _init() -> void:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var d := Vector2(x - 7.5, y - 7.5).length()
			if d > 7.4:
				continue
			var c: Color
			if d < 2.6:
				c = CORE
			elif d < 5.0:
				c = MID
			else:
				c = RIM
			img.set_pixel(x, y, c)
	var err := img.save_png(OUT)
	if err != OK:
		push_error("[orb] save failed")
		quit(1)
		return
	print("[orb] saved " + OUT)
	quit()
