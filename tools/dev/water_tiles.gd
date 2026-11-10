extends RefCounted
## Generates the forest water tiles: 4 surface variants plus 16
## land->water shore transition tiles (same 4-bit side-bitmask family
## as the grass-dirt transitions: N=1, E=2, S=4, W=8; a set bit means
## "that neighbor is land").
##
## The blue palette is sampled (luminance quantiles of blue-dominant
## pixels) from the AI-generated reference sheet
## assets/source/generated/forest_water_ref/.../forest_water_reference.png
## — see docs/ART_ASSET_IMPLEMENTATION.md §2 for its status (reference
## only; colors reused, pixels not).

const TILE := 32
const BAND := 8.0     # grass encroachment reach from a land side
const THRESH := 4.0   # bias above this is land (fringe depth ~4px)
const NOISE_AMP := 2.5

const DEEP := Color(0.008, 0.376, 0.729)
const MID := Color(0.000, 0.522, 0.855)
const LIGHT := Color(0.008, 0.620, 0.902)
const SHALLOW := Color(0.490, 0.635, 0.702)
const BANK := Color(0.047, 0.227, 0.325)

const BIT_N := 1
const BIT_E := 2
const BIT_S := 4
const BIT_W := 8

const GRASS_TEX := "res://assets/tilesets/forest/ground/grass_dense.png"


static func generate() -> Array[Image]:
	var grass: Image = load(GRASS_TEX).get_image()
	var out: Array[Image] = []
	for variant in 4:
		out.append(_surface(variant))
	for mask in 16:
		out.append(_shore(mask, grass))
	return out


static func _surface(variant: int) -> Image:
	## Flat pixel water: mid-blue base, wavy lighter bands, sparkle dots.
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var seed := 3000 + variant * 97
	var band_phase := float(variant) * 8.0
	for y in TILE:
		for x in TILE:
			var c := MID
			# Two horizontal wavy light bands (gentler frequency).
			var band1 := 9.0 + 2.5 * sin(x * 0.30 + band_phase)
			var band2 := 22.0 + 2.5 * sin(x * 0.26 + band_phase * 1.6)
			if absf(y - band1) < 1.4 or absf(y - band2) < 1.4:
				c = LIGHT
			# Occasional deep ripple shadow between the bands.
			if y == int(band1) + 3 and _hash(x, y, seed + 3) > 0.55:
				c = DEEP
			img.set_pixel(x, y, c)
	# Sparkles: denser near-white shallow glints across the upper half.
	for i in 9 + variant * 2:
		var sx := int(_hash(i, 1, seed) * (TILE - 2)) + 1
		var sy := int(_hash(i, 2, seed) * (TILE / 2)) + 2
		img.set_pixel(sx, sy, SHALLOW)
	return img


static func _shore(mask: int, grass: Image) -> Image:
	## Water base with a grass fringe from every land side, separated by
	## a dark bank line and a shallow-water band on the water side.
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y in TILE:
		for x in TILE:
			var v := _bias(mask, x, y) + _noise(x, y, mask) * NOISE_AMP
			var c: Color
			if v > THRESH + 1.0:
				c = grass.get_pixel(x, y)
			elif v > THRESH - 0.5:
				c = BANK
			elif v > THRESH - 2.5:
				c = SHALLOW
			elif _on_light_band(x, y):
				c = LIGHT
			else:
				c = MID
			img.set_pixel(x, y, c)
	return img


static func _on_light_band(x: int, y: int) -> bool:
	var band1 := 9.0 + 2.5 * sin(x * 0.30)
	var band2 := 22.0 + 2.5 * sin(x * 0.26 * 1.6)
	return absf(y - band1) < 1.4 or absf(y - band2) < 1.4


static func _bias(mask: int, x: int, y: int) -> float:
	# Clamped per-side contributions, same rule as the grass-dirt family.
	var b := 0.0
	if mask & BIT_N:
		b += maxf(0.0, BAND - y)
	if mask & BIT_E:
		b += maxf(0.0, BAND - (TILE - 1 - x))
	if mask & BIT_S:
		b += maxf(0.0, BAND - (TILE - 1 - y))
	if mask & BIT_W:
		b += maxf(0.0, BAND - x)
	return b


static func _noise(x: int, y: int, seed: int) -> float:
	var h1 := _hash(x, y, seed)
	var h2 := _hash(int(x * 0.577), int(y * 0.577), seed + 7)
	return (h1 * 0.65 + h2 * 0.35) * 2.0 - 1.0


static func _hash(x: int, y: int, seed: int) -> float:
	var v := (x * 374761393 + y * 668265263 + seed * 1274126177) % 1000003
	return float(v) / 1000003.0
