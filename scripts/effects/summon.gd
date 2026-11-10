extends Node2D
## Summon (whitelist shape "summon"): a small nature spirit orbits the
## caster and periodically zaps the nearest enemy for the spell
## duration, then dissolves. Pure-node attack: no projectile physics.

const ORB_TEXTURE := "res://assets/sprites/effects/orb_16.png"
const TICK := 1.0

static var _scene: PackedScene


static func _get_scene() -> PackedScene:
	if _scene == null:
		_scene = load("res://scenes/effects/summon.tscn")
	return _scene


static func spawn(spell: Dictionary, caster: Node2D, parent: Node2D) -> Node2D:
	var summon: Node2D = _get_scene().instantiate()
	summon.set("spell", spell)
	summon.set("_caster", caster)
	parent.add_child(summon)
	return summon


var spell: Dictionary = {}
var _caster: Node2D = null
var _elapsed := 0.0
var _orbit := 0.0

@onready var orb: Sprite2D = $Orb


func _ready() -> void:
	orb.modulate = _spirit_color()


func _physics_process(delta: float) -> void:
	var duration: float = spell.get("parameters", {}).get("duration", 0.0)
	_elapsed += delta
	_orbit += delta * 2.4
	if _caster != null and is_instance_valid(_caster):
		# Orbit the caster with a gentle bob.
		var radius: float = maxf(spell.get("parameters", {}).get("radius", 90.0) * 0.35, 24.0)
		position = _caster.global_position + Vector2.from_angle(_orbit) * radius \
				+ Vector2(0, -14 + 4.0 * sin(_elapsed * 3.0))
	var damage: float = spell.get("parameters", {}).get("damage", 0.0)
	_tick_acc += delta
	if _tick_acc >= TICK:
		_tick_acc = 0.0
		_zap_nearest(damage)
	if _elapsed >= duration:
		queue_free()


var _tick_acc := 0.0


func _zap_nearest(damage: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var nearest: Node2D = null
	var best := INF
	for child in parent.get_children():
		if child == self or not (child is CharacterBody2D):
			continue
		if not (child.name.begins_with("Slime") or child.name.begins_with("BossSlime")):
			continue
		if child.get("alive") == false:
			continue
		var dist: float = child.global_position.distance_to(global_position)
		if dist < best and dist <= _zap_range():
			best = dist
			nearest = child
	if nearest != null:
		var dir := (nearest.global_position - global_position).normalized()
		nearest.call("take_damage", damage, dir)
		# A brief flash on the spirit as the zap lands.
		var tw := create_tween()
		tw.tween_property(orb, "modulate", Color(1.8, 1.8, 1.8), 0.08)
		tw.tween_property(orb, "modulate", _spirit_color(), 0.15)


func _zap_range() -> float:
	return maxf(spell.get("parameters", {}).get("radius", 90.0), 40.0)


func _spirit_color() -> Color:
	return ProjectileScript.ELEMENT_TINT.get(spell.get("element", "nature"), Color.WHITE)


const ProjectileScript := preload("res://scripts/effects/projectile.gd")
