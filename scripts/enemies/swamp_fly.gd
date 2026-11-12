extends CharacterBody2D
## 沼泽蝇 (Swamp Fly): the wetland's flying pest. Ignores the ground
## entirely (no 畏水 — it crosses rivers and ponds to chase), weaves a
## sine hover into its pursuit, and weighs almost nothing: gusts and
## the tornado shove it much harder than ground enemies. Squishy — a
## couple of basic bolts or any real spell clears it.

signal died

const SPEED := 95.0
const CHASE_RADIUS := 180.0
const LOSE_RADIUS := 260.0
const CONTACT_DAMAGE := 3.0
const MAX_HP := 12.0

## Flying: pushes carry 2.5x (light body) and the wind itself bends
## the flight path every frame.
const WIND_DRIFT := 0.5
const PUSH_MULT := 2.5

var hp := MAX_HP
var _player: Node2D = null
var _hover_phase := 0.0
var _knockback := Vector2.ZERO
var _freeze_timer := 0.0

@onready var sprite: AnimatedSprite2D = $FlySprite


func _physics_process(delta: float) -> void:
	if _freeze_timer > 0.0:
		_freeze_timer -= delta
		velocity = Vector2.ZERO
		_knockback = Vector2.ZERO
		sprite.modulate = Color(0.55, 0.8, 1.25)
		move_and_slide()
		return
	_hover_phase += delta * 6.0
	_player = _find_player()
	var move := Vector2.ZERO
	if _player != null:
		var dist := global_position.distance_to(_player.global_position)
		if dist <= CHASE_RADIUS:
			var to_player: Vector2 = (_player.global_position - global_position).normalized()
			# Sine weave perpendicular to the pursuit: an annoying,
			# hard-to-click flight path.
			var side := Vector2(-to_player.y, to_player.x)
			move = (to_player + side * sin(_hover_phase) * 0.55).normalized() * SPEED
			if dist < 20.0 and _player.has_method("take_damage"):
				_player.call("take_damage", CONTACT_DAMAGE, to_player)
		elif dist > LOSE_RADIUS:
			move = Vector2.ZERO  # hovers in place, never wanders far
	# Flying: the wind itself drifts the flight (storms blow swarms off
	# course — and into you), and NO ground probe: water means nothing.
	velocity = move + _knockback + Weather.wind_vector() * WIND_DRIFT
	_knockback = _knockback.move_toward(Vector2.ZERO, 500.0 * delta)
	move_and_slide()
	# mask = 0 (nothing blocks a flier): clamp to the map by hand.
	var node := get_parent()
	while node != null and not node.has_method("map_pixel_size"):
		node = node.get_parent()
	if node != null:
		global_position = global_position.clamp(Vector2(16, 16),
				node.call("map_pixel_size") - Vector2(16, 16))


func take_damage(amount: float, from_dir: Vector2) -> void:
	hp -= amount
	_knockback = from_dir * 110.0
	sprite.modulate = Color(1.7, 1.6, 0.6)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if hp <= 0.0:
		_die()


## Frostbite still drops them from the air for a while.
func apply_freeze(duration: float) -> void:
	_freeze_timer = maxf(_freeze_timer, duration)


## Light body: every shove is multiplied (the tornado's signature prey).
func apply_push(force: Vector2) -> void:
	_knockback += force * PUSH_MULT


func _die() -> void:
	died.emit()
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.8, 0.2), 0.15)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)


func _find_player() -> Node2D:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is CharacterBody2D and child.name == "Player":
			return child
	return null
