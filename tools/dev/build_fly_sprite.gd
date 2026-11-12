extends SceneTree
## One-shot: generate the swamp-fly enemy sprites (2 frames, 14x12:
## a hovering pest — dark body, glowing eyes, blurred wings) plus the
## SpriteFrames resource with a fast flap.
##
##   godot --headless --path . -s res://tools/dev/build_fly_sprite.gd
##   godot --headless --path . --import   # afterwards

const OUT_DIR := "res://assets/sprites/enemies"
const SIZE := Vector2i(14, 12)

const BODY := Color(0.30, 0.26, 0.14)
const BODY_DK := Color(0.18, 0.16, 0.08)
const EYE := Color(0.95, 0.85, 0.30)
const WING := Color(0.75, 0.90, 0.85, 0.55)


func _init() -> void:
	for frame: int in [1, 2]:
		var img := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
		var wing_up: bool = frame == 1
		for y in SIZE.y:
			for x in SIZE.x:
				var cx := float(x) - 6.5
				var cy := float(y) - 7.0
				var c: Color
				var body_r := 3.6
				if Vector2(cx, cy).length() <= body_r:
					c = BODY if cx < 0.5 else BODY_DK
					# Glowing eyes look forward (down-right in top-down).
					if y >= 6 and (x == 8 or x == 10):
						c = EYE
				if c != null:
					img.set_pixel(x, y, c)
		# Wings: two ellipses behind the body, up on frame 1, down on 2.
		var wing_y := -3.0 if wing_up else -1.0
		for wy in 4:
			for wx in 5:
				var p := Vector2(wx - 2.0, wy - 1.5)
				if p.length() <= 2.2:
					var py := int(6 + wing_y + wy)
					if py >= 0 and py < SIZE.y:
						if 2 + wx < SIZE.x:
							img.set_pixel(2 + wx, py, WING)
						if 7 + wx < SIZE.x:
							img.set_pixel(7 + wx, py, WING)
		var err := img.save_png("%s/fly_idle_%02d.png" % [OUT_DIR, frame])
		if err != OK:
			push_error("[fly] save failed")
			quit(1)
			return
	print("[fly] saved 2 frames")
	quit()
