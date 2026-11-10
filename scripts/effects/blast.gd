extends Area2D
## Instant explosion (whitelist shape "explosion", AGENTS.md §7.3):
## one-shot area damage at a landing point, plus a tinted shockwave
## ring. Godot owns execution; the spell payload is plain data.

const RING_TEXTURE := "res://assets/sprites/effects/blast_ring_64.png"

static var _scene: PackedScene

const DAMAGE_MASK := 4  # enemies only — the caster is never hurt


static func _get_scene() -> PackedScene:
	if _scene == null:
		_scene = load("res://scenes/effects/blast.tscn")
	return _scene


static func spawn(spell: Dictionary, origin: Vector2, parent: Node2D) -> Area2D:
	var blast: Area2D = _get_scene().instantiate()
	blast.set("spell", spell)
	blast.position = origin
	parent.add_child(blast)
	return blast


var spell: Dictionary = {}


func _ready() -> void:
	collision_mask = DAMAGE_MASK
	monitoring = true
	# Fresh shape per instance sized to the spell radius (the blast
	# scene ships without a shape — every blast has its own radius).
	var circle := CircleShape2D.new()
	circle.radius = maxf(spell.get("parameters", {}).get("radius", 80.0), 16.0)
	var col := CollisionShape2D.new()
	col.shape = circle
	add_child(col)
	# Visual first: tinted shockwave, quick pop.
	var ring := Sprite2D.new()
	ring.texture = load(RING_TEXTURE)
	ring.modulate = _element_color()
	ring.scale = Vector2.ONE * 0.6
	add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * 1.6, 0.3)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	Sfx.play("sfx_explosion")
	# Two physics frames: one to register the shape, one for the
	# broadphase to report overlaps — then settle exactly once.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_settle()


func _settle() -> void:
	var damage: float = spell.get("parameters", {}).get("damage", 0.0)
	for body in get_overlapping_bodies():
		if body != null and body.has_method("take_damage"):
			var dir := (body.global_position - global_position).normalized()
			body.call("take_damage", damage, dir)
	queue_free()


func _element_color() -> Color:
	return ProjectileScript.ELEMENT_TINT.get(spell.get("element", "fire"), Color.WHITE)


const ProjectileScript := preload("res://scripts/effects/projectile.gd")
