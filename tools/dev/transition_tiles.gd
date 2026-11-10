extends RefCounted
## Generates the 16 grass->dirt transition tiles for the forest ground
## TileSet. Deterministic, procedural, and derived purely from the two
## validated production tiles (grass_dense fringe over a dirt_plain
## base) so the art style stays consistent by construction.
##
## Bitmask convention (tile index == mask value):
##   bit 1 = N neighbor is grass, 2 = E, 4 = S, 8 = W.
## A set bit paints a grass fringe encroaching onto the dirt base from
## that side; adjacent sides blend into a rounded corner automatically
## because the bias fields add up.

const TILE := 32
const BAND := 11.0    # nominal fringe depth reach from a grass side (px)
const THRESH := 5.0   # bias above this becomes grass; depth = BAND - THRESH
const NOISE_AMP := 3.5
const DITHER := 1.0   # half-width of the mixed-pixel boundary band

const GRASS_TEX := "res://assets/tilesets/forest/ground/grass_dense.png"
const DIRT_TEX := "res://assets/tilesets/forest/ground/dirt_plain.png"

const BIT_N := 1
const BIT_E := 2
const BIT_S := 4
const BIT_W := 8


static func generate() -> Array[Image]:
	var grass: Image = load(GRASS_TEX).get_image()
	var dirt: Image = load(DIRT_TEX).get_image()
	var out: Array[Image] = []
	for mask in 16:
		out.append(_build_tile(mask, grass, dirt))
	return out


static func _build_tile(mask: int, grass: Image, dirt: Image) -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y in TILE:
		for x in TILE:
			var v := _bias(mask, x, y) + _noise(x, y, mask) * NOISE_AMP
			var px: Color
			if v > THRESH + DITHER:
				px = grass.get_pixel(x, y)
			elif v > THRESH - DITHER:
				px = grass.get_pixel(x, y) if _noise(x, y, mask + 101) > 0.0 else dirt.get_pixel(x, y)
			else:
				px = dirt.get_pixel(x, y)
			img.set_pixel(x, y, px)
	return img


static func _bias(mask: int, x: int, y: int) -> float:
	# Each side contributes only within its band; opposite sides must not
	# cancel out (a raw sum would carve dirt into the middle of a fringe).
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
	# Cheap deterministic 2D hash in [-1, 1]; two octaves to avoid lattice artifacts.
	var h1 := _hash(x, y, seed)
	var h2 := _hash(int(x * 0.577), int(y * 0.577), seed + 7)
	return (h1 * 0.65 + h2 * 0.35) * 2.0 - 1.0


static func _hash(x: int, y: int, seed: int) -> float:
	var v := (x * 374761393 + y * 668265263 + seed * 1274126177) % 1000003
	return float(v) / 1000003.0
