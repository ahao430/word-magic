extends SceneTree
## One-shot: soft elliptical drop shadow (16x8, black with radial
## alpha falloff) placed under characters/props.
##
##   godot --headless --path . -s res://tools/dev/build_shadow_sprite.gd
##   godot --headless --path . --import   # afterwards

const OUT := "res://assets/sprites/effects/shadow_16x8.png"
const W := 16
const H := 8


func _init() -> void:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var d := Vector2((x - 7.5) / 7.5, (y - 3.5) / 3.5).length()
			if d >= 1.0:
				continue
			# Softer falloff: half strength at the rim edge, none outside.
			var a := clampf((1.0 - d) * 1.5, 0.0, 1.0) * 0.5
			img.set_pixel(x, y, Color(0, 0, 0, a))
	var err := img.save_png(OUT)
	if err != OK:
		push_error("[shadow] save failed")
		quit(1)
		return
	print("[shadow] saved " + OUT)
	quit()
