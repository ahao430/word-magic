extends CharacterBody2D
## Slime enemy: wanders, chases the player when close, deals contact
## damage, takes projectile damage with knockback and a squish death.
## Dev-map layer convention: layer 4 (enemy), mask 1 (world/props).

const WANDER_SPEED := 40.0
const CHASE_SPEED := 85.0
const CHASE_RADIUS := 150.0
const LOSE_RADIUS := 220.0
const CONTACT_DAMAGE := 5.0
const KNOCKBACK := 180.0
const MAX_HP := 30.0

const WANDER_INTERVAL := 1.5

var hp := MAX_HP
var _wander_dir := Vector2.ZERO
var _wander_timer := 0.0
var _knockback := Vector2.ZERO
var _player: Node2D = null

@onready var sprite: AnimatedSprite2D = $SlimeSprite


func _physics_process(delta: float) -> void:
	_player = _find_player()
	var move := Vector2.ZERO
	if _player != null:
		var dist := global_position.distance_to(_player.global_position)
		if dist <= CHASE_RADIUS:
			move = (_player.global_position - global_position).normalized() * CHASE_SPEED
		else:
			move = _wander(delta)
	else:
		move = _wander(delta)

	velocity = move + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 600.0 * delta)
	move_and_slide()

	# Contact damage to the player.
	if _player != null and global_position.distance_to(_player.global_position) < 22.0:
		if _player.has_method("take_damage"):
			_player.call("take_damage", CONTACT_DAMAGE,
					(_player.global_position - global_position).normalized())


func take_damage(amount: float, from_dir: Vector2) -> void:
	hp -= amount
	_knockback = from_dir * KNOCKBACK
	sprite.modulate = Color(1.6, 0.6, 0.6)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.18)
	if hp <= 0.0:
		_die()


func _die() -> void:
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(sprite, "scale:y", 0.15, 0.22)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.22)
	tween.tween_callback(queue_free)


func _wander(delta: float) -> Vector2:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = WANDER_INTERVAL + randf()
		if randf() < 0.35:
			_wander_dir = Vector2.ZERO
		else:
			_wander_dir = Vector2.from_angle(randf() * TAU)
	return _wander_dir * WANDER_SPEED


func _find_player() -> Node2D:
	# Sibling lookup under the shared y-sort layer; cheap for dev maps.
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is CharacterBody2D and child.name == "Player":
			return child
	return null
