extends SceneTree
## One-shot: generate the app icon (256x256, forest-green rounded
## square with a violet arcane orb) used by project.godot and the
## macOS/Windows export presets.
##
##   godot --headless --path . -s res://tools/dev/build_app_icon.gd
##   godot --headless --path . --import   # afterwards

const OUT := "res://assets/sprites/ui/app_icon_256.png"
const SIZE := 256
const RADIUS := 56.0

const BG_IN := Color(0.10, 0.22, 0.14)
const BG_OUT := Color(0.05, 0.12, 0.08)
const ORB_CORE := Color(0.96, 0.92, 1.0)
const ORB_MID := Color(0.78, 0.55, 1.0)
const ORB_RIM := Color(0.42, 0.22, 0.72)
const SPARK := Color(0.9, 1.0, 0.95)


func _init() -> void:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(SIZE * 0.5, SIZE * 0.54)
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x, y)
			if not _in_rounded(p):
				continue
			# Vignette: lighter center, darker corners.
			var t := clampf((p.distance_to(Vector2.ONE * (SIZE * 0.5)) / (SIZE * 0.72)), 0.0, 1.0)
			var c: Color = BG_IN.lerp(BG_OUT, t)
			# The orb: layered radial falloff over the vignette.
			var d := p.distance_to(center)
			if d < 78.0:
				var glow := clampf(1.0 - d / 78.0, 0.0, 1.0)
				c = c.lerp(ORB_RIM, pow(glow, 2.2) * 0.9)
			if d < 52.0:
				c = c.lerp(ORB_MID, clampf(1.0 - d / 52.0, 0.0, 1.0))
			if d < 18.0:
				c = c.lerp(ORB_CORE, clampf(1.0 - d / 18.0, 0.0, 1.0) * 0.95)
			img.set_pixel(x, y, c)
	# Sparkles: four crisp motes around the orb.
	for s in [[136, 92, 5.0], [176, 148, 3.5], [118, 176, 4.0], [158, 210, 2.5]]:
		_sparkle(img, Vector2(s[0], s[1]), s[2])
	var err := img.save_png(OUT)
	if err != OK:
		push_error("[icon] save failed")
		quit(1)
		return
	print("[icon] saved " + OUT)
	quit()


func _in_rounded(p: Vector2) -> bool:
	# Rounded-square test: clamp the point into the inner rect and
	# measure the distance to it; inside when within the corner radius.
	var half := SIZE * 0.5
	var inner := Rect2(Vector2(RADIUS, RADIUS),
			Vector2(SIZE - RADIUS * 2.0, SIZE - RADIUS * 2.0))
	var clamped := Vector2(
			clampf(p.x, inner.position.x, inner.end.x),
			clampf(p.y, inner.position.y, inner.end.y))
	return p.distance_to(clamped) <= RADIUS and p.x >= 0 and p.y >= 0 \
			and p.x < half * 2.0 and p.y < half * 2.0


func _sparkle(img: Image, at: Vector2, radius: float) -> void:
	for y in range(int(at.y - radius * 2.0), int(at.y + radius * 2.0) + 1):
		for x in range(int(at.x - radius * 2.0), int(at.x + radius * 2.0) + 1):
			if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
				continue
			var d := Vector2(x, y).distance_to(at)
			if d <= radius:
				var c: Color = img.get_pixel(x, y).lerp(SPARK,
						clampf(1.0 - d / radius, 0.0, 1.0))
				img.set_pixel(x, y, c)
