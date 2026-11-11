class_name ChainArc
extends RefCounted
## Rain/storm lightning cross-effect (Weather.gd): when a lightning hit
## lands in wet weather the discharge arcs to nearby enemies, decaying
## per hop. Shared by every damage site so the rule stays identical
## everywhere; Godot owns the execution, Weather owns the numbers.

const ENEMY_LAYER := 4  # same predicate the damage overlaps use


## Called after a lightning `damage` lands on `victim`. `exclude` lists
## bodies already hit by the same effect (blast/zone/beam ticks) so a
## multi-hit never chains into its own victims. Returns the chained
## bodies — empty in dry weather or with no neighbours in range.
static func on_hit(spell: Dictionary, victim: Node2D, damage: float,
		exclude: Array = []) -> Array:
	if spell.get("element", "") != "lightning" or Weather.chain_hops() <= 0:
		return []
	if victim == null or not is_instance_valid(victim):
		return []
	var parent := victim.get_parent()
	if parent == null:
		return []
	var chained: Array = []
	var from: Node2D = victim
	var power: float = damage * Weather.CHAIN_DECAY
	# The victim itself sits at distance 0 from the first hop's origin:
	# it must be in the skip list or the arc bites its own source.
	var skip: Array = [victim] + exclude
	for _i in Weather.chain_hops():
		var next: Node2D = _nearest_enemy(parent, from.global_position,
				skip + chained)
		if next == null:
			break
		var dir := (next.global_position - from.global_position).normalized()
		next.call("take_damage", power, dir)
		_draw_arc(from.global_position, next.global_position, parent)
		chained.append(next)
		from = next
		power *= Weather.CHAIN_DECAY
	return chained


## Nearest enemy-layer body within CHAIN_RADIUS that is alive and not
## already part of this discharge.
static func _nearest_enemy(parent: Node2D, from: Vector2, skip: Array) -> Node2D:
	var nearest: Node2D = null
	var best := Weather.CHAIN_RADIUS
	for child in parent.get_children():
		if not (child is CharacterBody2D):
			continue
		if child.collision_layer & ENEMY_LAYER == 0:
			continue
		if child in skip or child.is_queued_for_deletion():
			continue
		var dist: float = child.global_position.distance_to(from)
		if dist <= best:
			best = dist
			nearest = child
	return nearest


## Jagged lightning segment between two points: 3 jittered midpoints,
## quick flash, self-freeing.
static func _draw_arc(a: Vector2, b: Vector2, parent: Node2D) -> void:
	var line := Line2D.new()
	line.name = "ChainArc"
	var points := PackedVector2Array([a])
	for i in 3:
		var t := (i + 1) / 4.0
		var jitter := Vector2.from_angle(randf() * TAU) * (6.0 + 10.0 * randf())
		points.append(a.lerp(b, t) + jitter)
	points.append(b)
	line.points = points
	line.width = 3.0
	line.default_color = Color(1.0, 1.0, 0.55, 0.9)
	line.top_level = true
	parent.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.18)
	tween.tween_callback(line.queue_free)
