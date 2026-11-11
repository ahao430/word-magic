extends Area2D
## Persistent field zone (whitelist shapes "field" and "tornado"):
## a tinted AoE footprint that ticks damage to enemies inside, with an
## optional freeze mechanic. The tornado variant spins and shoves.
## Godot owns execution; the spell payload is plain data.

const ZONE_TEXTURE := "res://assets/sprites/effects/field_zone_128.png"
const FROST_COLOR := Color(0.65, 0.85, 1.2)
const GALE_COLOR := Color(0.85, 0.95, 1.1)
const FREEZE_PER_TICK := 0.6  # seconds of freeze applied per tick
## Wind drift factor per shape: tornadoes ride the gale, frost fields
## only creep — placing them upwind becomes part of the craft.
const DRIFT_FACTOR := {"field": 0.10, "tornado": 0.22}

static var _scene: PackedScene

const DAMAGE_MASK := 4  # enemies only


static func _get_scene() -> PackedScene:
	if _scene == null:
		_scene = load("res://scenes/effects/field_zone.tscn")
	return _scene


static func spawn(spell: Dictionary, center: Vector2, parent: Node2D) -> Area2D:
	var zone: Area2D = _get_scene().instantiate()
	zone.set("spell", spell)
	zone.position = center
	parent.add_child(zone)
	return zone


var spell: Dictionary = {}
var _elapsed := 0.0
var _tick_acc := 0.0

@onready var disc: Sprite2D = $Disc


func _ready() -> void:
	collision_mask = DAMAGE_MASK
	var params: Dictionary = spell.get("parameters", {})
	var radius: float = params.get("radius", 80.0)
	# Fresh shape per instance: sub_resource shapes are shared between
	# instantiations, so resizing in place would leak into other zones.
	var circle := CircleShape2D.new()
	circle.radius = radius
	$Shape.shape = circle
	disc.scale = Vector2.ONE * (radius * 2.0 / 128.0)
	disc.modulate = _zone_color()


func _physics_process(delta: float) -> void:
	var params: Dictionary = spell.get("parameters", {})
	var duration: float = params.get("duration", 0.0)
	var tick := 0.4 if spell.get("shape", "") == "tornado" else 0.5
	_elapsed += delta
	_tick_acc += delta
	# The wind carries the zone: lead your placement upwind.
	position += Weather.wind_vector() * float(DRIFT_FACTOR.get(
			spell.get("shape", "field"), 0.1)) * delta
	if _tick_acc >= tick:
		_tick_acc = 0.0
		_tick_damage()
	if spell.get("shape", "") == "tornado":
		disc.rotation += 6.0 * delta
	if _elapsed >= duration:
		set_physics_process(false)
		var tween := create_tween()
		tween.tween_property(disc, "modulate:a", 0.0, 0.25)
		tween.tween_callback(queue_free)


func _tick_damage() -> void:
	var damage: float = Weather.scale_damage(
			spell.get("parameters", {}).get("damage", 0.0),
			spell.get("element", "ice"))
	var mechanics: Array = spell.get("mechanics", [])
	var hit: Array = []
	for body in get_overlapping_bodies():
		if body == null or not body.has_method("take_damage"):
			continue
		var dir := (body.global_position - global_position).normalized()
		body.call("take_damage", damage, dir)
		hit.append(body)
		if mechanics.has("freeze") and body.has_method("apply_freeze"):
			body.call("apply_freeze", FREEZE_PER_TICK)
		if spell.get("shape", "") == "tornado" and body.has_method("apply_push"):
			# Strong enough to overcome chase AI for the gale fantasy.
			body.call("apply_push", dir * 420.0)
	# Wet-weather lightning chains outward from the first victim (the
	# tick's own victims are excluded — same rule as the blast).
	if not hit.is_empty():
		ChainArc.on_hit(spell, hit[0], damage, hit.slice(1))


func _zone_color() -> Color:
	if spell.get("shape", "") == "tornado":
		return GALE_COLOR
	return FROST_COLOR
