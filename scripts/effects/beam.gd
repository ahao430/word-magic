extends Area2D
## Beam (whitelist shape "beam"): a directed damage ray held for the
## spell duration, ticking everything inside a long thin rectangle.
## The polygon visual is tinted by element at runtime.

const BEAM_WIDTH := 24.0
## Tick cadence owned by SpellBalance (single source: pricing and
## execution share one number).
var _tick_interval: float = SpellBalance.CHANNEL_TICKS["beam"]

static var _scene: PackedScene

const DAMAGE_MASK := 4  # enemies only


static func _get_scene() -> PackedScene:
	if _scene == null:
		# Same trick as blast: lazy scene load avoids the cyclic
		# compile dependency in headless -s runs.
		_scene = load("res://scenes/effects/beam.tscn")
	return _scene


## origin = caster position; dir = facing. The beam spans origin +
## dir * length, centered along the ray.
static func spawn(spell: Dictionary, origin: Vector2, dir: Vector2, parent: Node2D) -> Area2D:
	var beam: Area2D = _get_scene().instantiate()
	beam.set("spell", spell)
	beam.set("_origin", origin)
	beam.set("_dir", dir.normalized())
	parent.add_child(beam)
	return beam


var spell: Dictionary = {}
var _origin := Vector2.ZERO
var _dir := Vector2.RIGHT
var _elapsed := 0.0
var _tick_acc := 0.0


func _ready() -> void:
	collision_mask = DAMAGE_MASK
	var params: Dictionary = spell.get("parameters", {})
	var length: float = maxf(params.get("radius", 80.0) * 2.0, 32.0)
	# Geometry: centered on the ray's midpoint, rotated to the facing.
	position = _origin + _dir * (length * 0.5)
	rotation = _dir.angle()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, BEAM_WIDTH)
	$Shape.shape = rect
	var poly: Polygon2D = $BeamPoly
	var half := BEAM_WIDTH * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-length * 0.5, -half), Vector2(length * 0.5, -half),
		Vector2(length * 0.5, half), Vector2(-length * 0.5, half)])
	poly.color = _beam_color()
	var col: Color = poly.color
	poly.color = Color(col.r, col.g, col.b, 0.55)


func _physics_process(delta: float) -> void:
	var duration: float = spell.get("parameters", {}).get("duration", 0.0)
	_elapsed += delta
	_tick_acc += delta
	if _tick_acc >= _tick_interval:
		_tick_acc = 0.0
		_tick_damage()
	var poly: Polygon2D = $BeamPoly
	var fade := clampf(1.0 - _elapsed / maxf(duration, 0.01), 0.25, 1.0)
	poly.color.a = 0.55 * fade
	if _elapsed >= duration:
		queue_free()


func _tick_damage() -> void:
	var damage: float = Weather.scale_damage(
			spell.get("parameters", {}).get("damage", 0.0),
			spell.get("element", "lightning"))
	var hit: Array = []
	for body in get_overlapping_bodies():
		if body != null and body.has_method("take_damage"):
			body.call("take_damage", damage, _dir)
			hit.append(body)
	# Wet-weather lightning chains outward from the first victim (the
	# beam's own victims excluded — same rule as the blast).
	if not hit.is_empty():
		ChainArc.on_hit(spell, hit[0], damage, hit.slice(1))


func _beam_color() -> Color:
	return ProjectileScript.ELEMENT_TINT.get(spell.get("element", "lightning"), Color.WHITE)


const ProjectileScript := preload("res://scripts/effects/projectile.gd")
