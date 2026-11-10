extends SceneTree
## One-shot: generate the waterfall texture (32x64, vertically
## tileable: streaks run full height with a 64px-period shimmer so the
## scroll shader wraps seamlessly).
##
##   godot --headless --path . -s res://tools/dev/build_waterfall_sprite.gd
##   godot --headless --path . --import   # afterwards

const OUT := "res://assets/sprites/effects/waterfall_32x64.png"
const W := 32
const H := 64

const DEEP := Color(0.008, 0.376, 0.729)
const MID := Color(0.000, 0.522, 0.855)
const LIGHT := Color(0.008, 0.620, 0.902)
const FOAM := Color(0.80, 0.92, 0.96)


func _init() -> void:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for x in W:
		# Column streak profile: a couple of sine beats plus a hash.
		var streak := 0.5 + 0.28 * sin(x * 0.85) + 0.22 * _hash(x, 5, 31)
		for y in H:
			# 64px-period vertical shimmer keeps the wrap seamless.
			var wob := 1.0 + 0.12 * sin(TAU * float(y) / float(H) + x)
			var v := streak * wob
			var c := MID
			if v > 0.78:
				c = LIGHT
			elif v < 0.42:
				c = DEEP
			img.set_pixel(x, y, c)
	# Sparse foam flecks (full columns keep the wrap seamless).
	for x in W:
		if _hash(x, 9, 77) > 0.72:
			img.set_pixel(x, int(_hash(x, 2, 13) * H) as int, FOAM)
	var err := img.save_png(OUT)
	if err != OK:
		push_error("[waterfall] save failed")
		quit(1)
		return
	print("[waterfall] saved " + OUT)
	quit()


func _hash(x: int, y: int, seed: int) -> float:
	var v := (x * 374761393 + y * 668265263 + seed * 1274126177) % 1000003
	return float(v) / 1000003.0
