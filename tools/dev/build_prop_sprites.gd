extends SceneTree
## One-shot: generate the forest prop sprites (trees, rocks, bushes)
## procedurally, sampling the palette from the validated production
## ground tiles so the style stays consistent. Real alpha cutouts.
##
##   godot --headless --path . -s res://tools/dev/build_prop_sprites.gd
##   godot --headless --path . --import   # afterwards
##
## Output: assets/sprites/props/*.png
##   tree_XX.png  32x48  (trunk base at bottom-center, node anchor)
##   rock_XX.png  24x18
##   bush_XX.png  20x14

const OUT_DIR := "res://assets/sprites/props"
const GROUND := "res://assets/tilesets/forest/ground"

const TREE_W := 32
const TREE_H := 48
const ROCK_W := 24
const ROCK_H := 18
const BUSH_W := 20
const BUSH_H := 14


func _init() -> void:
	# Palettes sampled from the production tiles (luminance percentiles).
	var greens := _palette("%s/grass_dense.png" % GROUND, [0.15, 0.5, 0.8])
	var browns := _palette("%s/dirt_variant.png" % GROUND, [0.2, 0.55])
	var grays := _palette("%s/stone_paving.png" % GROUND, [0.2, 0.5, 0.8])

	_save("tree_01.png", _tree(greens, browns, 1))
	_save("tree_02.png", _tree(greens, browns, 2))
	_save("rock_01.png", _rock(grays, greens, 1))
	_save("rock_02.png", _rock(grays, greens, 2))
	_save("bush_01.png", _bush(greens, 1))
	_save("bush_02.png", _bush(greens, 2))
	print("[props] 6 sprites saved to " + OUT_DIR)
	quit()


func _save(file_name: String, img: Image) -> void:
	var path := "%s/%s" % [OUT_DIR, file_name]
	var err := img.save_png(path)
	if err != OK:
		push_error("[props] save failed: " + path)
		quit(1)


func _palette(tex_path: String, quantiles: Array) -> Array[Color]:
	## Returns one representative color per luminance quantile (dark -> light).
	var img: Image = load(tex_path).get_image()
	var samples: Array = []
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			samples.append([c.r * 0.299 + c.g * 0.587 + c.b * 0.114, c])
	samples.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array[Color] = []
	for q in quantiles:
		out.append(samples[int(q * (samples.size() - 1))][1])
	return out


func _hash(x: int, y: int, seed: int) -> float:
	var v := (x * 374761393 + y * 668265263 + seed * 1274126177) % 1000003
	return float(v) / 1000003.0


func _inside(x: float, y: float, cx: float, cy: float, r: float, seed: int) -> bool:
	var d := Vector2(x - cx, y - cy).length()
	return d <= r + (_hash(int(x), int(y), seed) - 0.5) * 1.8


func _tree(greens: Array[Color], browns: Array[Color], variant: int) -> Image:
	var img := Image.create(TREE_W, TREE_H, false, Image.FORMAT_RGBA8)
	var seed := 700 + variant * 13
	var mirror := variant == 2
	var blobs: Array = [
		[16.0, 14.0, 11.0],
		[10.0, 18.0, 6.5],
		[22.0, 17.0, 6.5],
	]
	for y in TREE_H:
		for x in TREE_W:
			var px := float(x)
			var py := float(y)
			var filled := false
			for b in blobs:
				var bx: float = b[0] if not mirror else TREE_W - b[0]
				if _inside(px, py, bx, b[1], b[2], seed):
					filled = true
					break
			if not filled:
				continue
			# Simple NE lighting: light top-left of crown, shadow bottom-right.
			var light := (px - 16.0) + (py - 14.0) + (_hash(x, y, seed + 5) - 0.5) * 5.0
			if light < -5.0:
				img.set_pixel(x, y, greens[2])
			elif light > 7.0:
				img.set_pixel(x, y, greens[0])
			else:
				img.set_pixel(x, y, greens[1])
	# Trunk with dark side edges and a small root flare at the base.
	for y in range(26, TREE_H):
		var wide := y >= 44
		for x in range(13 if wide else 14, (20 if wide else 18)):
			var c := browns[1]
			if x == (13 if wide else 14) or x == ((19 if wide else 17)):
				c = browns[0]
			img.set_pixel(x, y, c)
	return img


func _rock(grays: Array[Color], greens: Array[Color], variant: int) -> Image:
	var img := Image.create(ROCK_W, ROCK_H, false, Image.FORMAT_RGBA8)
	var seed := 900 + variant * 29
	for y in ROCK_H:
		for x in ROCK_W:
			if not _inside(x, y, ROCK_W * 0.5, ROCK_H * 0.55, ROCK_H * 0.42, seed):
				# Wider than tall: second ellipse test.
				if not _inside(x, y, ROCK_W * 0.5, ROCK_H * 0.6, ROCK_W * 0.42, seed + 3):
					continue
			var light := (x - ROCK_W * 0.5) * 0.6 + (y - ROCK_H * 0.5) + (_hash(x, y, seed + 7) - 0.5) * 3.0
			var c: Color
			if light < -3.0:
				c = grays[2]
			elif light > 3.5:
				c = grays[0]
			else:
				c = grays[1]
			if y < 6 and _hash(x, y, seed + 11) > 0.72:
				c = greens[1]
			img.set_pixel(x, y, c)
	return img


func _bush(greens: Array[Color], variant: int) -> Image:
	var img := Image.create(BUSH_W, BUSH_H, false, Image.FORMAT_RGBA8)
	var seed := 1100 + variant * 31
	for y in BUSH_H:
		for x in BUSH_W:
			if not _inside(x, y, BUSH_W * 0.5, BUSH_H * 0.55, BUSH_H * 0.5, seed):
				if not _inside(x, y, BUSH_W * 0.5, BUSH_H * 0.62, BUSH_W * 0.4, seed + 3):
					continue
			var light := (x - BUSH_W * 0.5) * 0.8 + (y - BUSH_H * 0.5) + (_hash(x, y, seed + 5) - 0.5) * 2.5
			img.set_pixel(x, y, greens[2] if light < -1.5 else (greens[0] if light > 4.0 else greens[1]))
	# A few berry specks for variant 2.
	if variant == 2:
		for i in 4:
			var bx := 4 + int(_hash(i, 3, seed) * (BUSH_W - 8))
			var by := 4 + int(_hash(i, 7, seed) * (BUSH_H - 8))
			img.set_pixel(bx, by, Color(0.95, 0.85, 0.4))
	return img
