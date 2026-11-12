extends SceneTree
## One-shot: generate the Forest Keeper NPC sprite (20x28): a hooded
## cloak figure with a staff-topped glow — the first villager of the
## world, standing by the wetland gate.
##
##   godot --headless --path . -s res://tools/dev/build_npc_sprite.gd
##   godot --headless --path . --import   # afterwards

const OUT := "res://assets/sprites/npc/keeper.png"
const W := 20
const H := 28

const HOOD := Color(0.16, 0.28, 0.18)
const HOOD_IN := Color(0.08, 0.14, 0.10)
const FACE := Color(0.85, 0.78, 0.65)
const CLOAK := Color(0.24, 0.36, 0.24)
const CLOAK_DK := Color(0.17, 0.27, 0.18)
const BELT := Color(0.35, 0.26, 0.16)
const STAFF := Color(0.38, 0.28, 0.16)
const ORB := Color(0.55, 1.0, 0.6)


func _init() -> void:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	# Cloak body: rounded silhouette from the hood down.
	for y in H:
		for x in W:
			var c: Color
			var cx := float(x) - 9.5
			if y < 3:
				continue  # breathing room at the top
			if y < 10:
				# Hood: a narrowing dome.
				var r := 3.0 + float(y - 3) * 0.8
				if absf(cx) <= r:
					c = HOOD
					if y >= 6 and absf(cx) <= r - 3.0:
						if cx > -2.0 and cx < 2.5 and y < 9:
							c = FACE  # the visible sliver of face
						else:
							c = HOOD_IN
			elif y < 22:
				# Cloak: widening, with a darker left fold.
				var r2 := 5.0 + float(y - 10) * 0.45
				if absf(cx) <= r2:
					c = CLOAK_DK if cx < -1.5 else CLOAK
					if y >= 15 and y <= 16:
						c = BELT
			if c != null:
				img.set_pixel(x, y, c)
	# Staff: a pole on the right with a small glowing head.
	for y in range(4, 24):
		img.set_pixel(15, y, STAFF)
		img.set_pixel(16, y, STAFF)
	for dp in [Vector2i(15, 3), Vector2i(16, 3), Vector2i(15, 2), Vector2i(16, 2), Vector2i(15, 1), Vector2i(16, 1)]:
		img.set_pixel(dp.x, dp.y, ORB if dp.y < 2 else Color(0.75, 1.0, 0.78))
	var err := img.save_png(OUT)
	if err != OK:
		push_error("[npc] save failed")
		quit(1)
		return
	print("[npc] saved " + OUT)
	quit()
