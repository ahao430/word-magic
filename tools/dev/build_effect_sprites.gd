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
	_save_dot()
	print("[effects] 3 sprites saved to " + OUT_DIR)
	quit()


## 4x4 opaque white dot: tinted/scaled at runtime for rain and leaves.
func _save_dot() -> void:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for y in 4:
		for x in 4:
			img.set_pixel(x, y, Color(1, 1, 1, 0.9))
	var err := img.save_png("%s/particle_dot_4.png" % OUT_DIR)
	if err != OK:
		push_error("[effects] dot save failed")
		quit(1)


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
