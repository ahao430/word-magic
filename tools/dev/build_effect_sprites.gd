extends SceneTree
## One-shot: white effect sprites tinted at runtime by element — a
## blast shockwave ring and a persistent field-zone disc. White base +
## true alpha so ELEMENT_TINT modulate colors them cleanly.
##
##   godot --headless --path . -s res://tools/dev/build_effect_sprites.gd
##   godot --headless --path . --import   # afterwards

const OUT_DIR := "res://assets/sprites/effects"


func _init() -> void:
	_save_ring()
	_save_zone()
	print("[effects] 2 sprites saved to " + OUT_DIR)
	quit()


func _save(name: String, img: Image) -> void:
	var err := img.save_png("%s/%s.png" % [OUT_DIR, name])
	if err != OK:
		push_error("[effects] save failed: " + name)
		quit(1)


## 64x64 shockwave: hard white ring, faint inner fill.
func _save_ring() -> void:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(31.5, 31.5)
	for y in size:
		for x in size:
			var d := Vector2(x - center.x, y - center.y).length()
			if d > 30.0:
				continue
			if d > 24.0:
				img.set_pixel(x, y, Color(1, 1, 1, 0.9))
			else:
				img.set_pixel(x, y, Color(1, 1, 1, 0.14))
	_save("blast_ring_64", img)


## 128x128 zone disc: soft boundary ring + very faint fill (persistent
## AoE footprint; scaled to the spell radius at runtime).
func _save_zone() -> void:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(63.5, 63.5)
	for y in size:
		for x in size:
			var d := Vector2(x - center.x, y - center.y).length()
			if d > 62.0:
				continue
			if d > 55.0:
				img.set_pixel(x, y, Color(1, 1, 1, 0.55))
			else:
				img.set_pixel(x, y, Color(1, 1, 1, 0.10))
	_save("field_zone_128", img)
