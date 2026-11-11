extends CharacterBody2D

signal died

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
## 畏水 probe distance: how far ahead the slime tests for impassable
## ground before committing to a step (weather-aware enemy AI).
const BLOCK_PROBE := 24.0

var hp := MAX_HP
var _wander_dir := Vector2.ZERO
var _wander_timer := 0.0
var _knockback := Vector2.ZERO
var _freeze_timer := 0.0
var _push_timer := 0.0
var _player: Node2D = null

@onready var sprite: AnimatedSprite2D = $SlimeSprite


func _physics_process(delta: float) -> void:
	if _freeze_timer > 0.0:
		# Frozen: rooted in place, frosted over, and too stiff to bite.
		_freeze_timer -= delta
		velocity = Vector2.ZERO
		_knockback = Vector2.ZERO
		sprite.modulate = Color(0.55, 0.8, 1.25)
		move_and_slide()
		return
	if _push_timer > 0.0:
		# Blown off its feet: momentum only, no steering while airborne.
		_push_timer -= delta
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		return
	_player = _find_player()
	var move := Vector2.ZERO
	var chasing := false
	if _player != null:
		var dist := global_position.distance_to(_player.global_position)
		if dist <= CHASE_RADIUS:
			chasing = true
			# Wet weather bogs the slime down (Weather.gd cross table).
			move = (_player.global_position - global_position).normalized() \
					* CHASE_SPEED * Weather.enemy_speed_scale()
		else:
			move = _wander(delta)
	else:
		move = _wander(delta)

	# 畏水: refuse to step toward impassable ground — chasers stare
	# across the river, wanderers pick a new heading instead.
	if move != Vector2.ZERO and _ground_blocked_ahead(move):
		move = Vector2.ZERO
		if not chasing:
			_wander_timer = 0.0

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


## Freeze mechanic (冰封千里): root the slime in place for a while.
## While frozen the sprite stays frosted; thawing restores normal tint.
func apply_freeze(duration: float) -> void:
	_freeze_timer = maxf(_freeze_timer, duration)


## Gale mechanic (风卷残云): a shove that also takes the slime off its
## feet — momentum only while the gust carries it.
func apply_push(force: Vector2) -> void:
	_knockback += force
	_push_timer = maxf(_push_timer, 0.25)


func _die() -> void:
	died.emit()
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(sprite, "scale:y", 0.15, 0.22)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.22)
	tween.tween_callback(queue_free)


## Probe BLOCK_PROBE px along the intended move for river-family
## ground; climbs to the owning world for the tile query (slimes in a
## bare lab simply never report blocked).
func _ground_blocked_ahead(move: Vector2) -> bool:
	var node := get_parent()
	while node != null and not node.has_method("is_blocked_ground"):
		node = node.get_parent()
	if node == null:
		return false
	return bool(node.call("is_blocked_ground",
			global_position + move.normalized() * BLOCK_PROBE))


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
