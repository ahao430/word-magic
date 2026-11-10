extends Area2D
## Reusable elemental projectile. Tinted orb placeholder art; carries a
## plain-data spell payload and explodes on the first wall/prop hit or
## when its lifetime runs out.

const SPEED_DEFAULT := 300.0
const LIFETIME_DEFAULT := 2.0

var velocity := Vector2.ZERO
var lifetime := LIFETIME_DEFAULT
var spell: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D

# Lazily loaded: a static `load` of the scene that owns this script
# creates a cyclic compile dependency.
static var _scene: PackedScene


static func _get_scene() -> PackedScene:
	if _scene == null:
		_scene = load("res://scenes/effects/projectile.tscn")
	return _scene

static var ELEMENT_TINT := {
	"fire": Color(1.0, 0.55, 0.2),
	"ice": Color(0.5, 0.85, 1.0),
	"lightning": Color(1.0, 1.0, 0.6),
	"nature": Color(0.6, 1.0, 0.5),
	"wind": Color(0.8, 0.9, 1.0),
	"water": Color(0.45, 0.65, 1.0),
}


static func spawn(spell_data: Dictionary, origin: Vector2, direction: Vector2, parent: Node2D) -> Area2D:
	var proj: Area2D = _get_scene().instantiate()
	proj.spell = spell_data
	proj.position = origin
	var speed: float = spell_data.get("parameters", {}).get("speed", SPEED_DEFAULT)
	proj.velocity = direction.normalized() * speed
	proj.lifetime = spell_data.get("parameters", {}).get("duration", LIFETIME_DEFAULT)
	parent.add_child(proj)
	return proj


func _ready() -> void:
	sprite.modulate = ELEMENT_TINT.get(spell.get("element", "fire"), Color.WHITE)
	Sfx.play(Sfx.cast_sound_for(spell.get("element", "fire")))
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		_explode()


## Damage application lives here (gameplay execution in Godot), driven
## purely by the validated spell data payload.
func _on_body_entered(body: Node2D) -> void:
	if body != null and body.has_method("take_damage"):
		var dir := velocity.normalized()
		body.call("take_damage", spell.get("parameters", {}).get("damage", 0.0), dir)
	# Impact recipe: fire pops, everything else thumps.
	Sfx.play("sfx_explosion" if spell.get("element", "") == "fire" else "sfx_hit")
	_explode()


func _explode() -> void:
	# Placeholder impact: the orb pops with a quick scale-and-fade puff.
	set_physics_process(false)
	# Deferred: mutating monitoring inside a physics signal is blocked.
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(3.0, 3.0), 0.18)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)
