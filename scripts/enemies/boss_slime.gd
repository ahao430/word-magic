extends CharacterBody2D
## The Slime King: a heavyweight boss with a telegraphed skill cycle.
## Dormant until approached, then chase → wind-up (squash + red pulse,
## dash direction locked at wind-up start so it is dodgeable) → dash
## slam with area damage on landing → recover. Same layer convention
## as the slime: layer 4 (enemy), mask 1 (world/props).

signal aggroed
signal died

enum State { DORMANT, CHASE, WINDUP, SLAM, COOLDOWN }

const AGGRO_RADIUS := 200.0
const LOSE_RADIUS := 420.0
const CHASE_SPEED := 55.0
const DASH_SPEED := 380.0
const CHASE_TIME := 3.0
const WINDUP_TIME := 0.7
const SLAM_TIME := 0.4
const COOLDOWN_TIME := 0.9
const CONTACT_DAMAGE := 8.0
const CONTACT_RADIUS := 30.0
const SLAM_DAMAGE := 12.0
const SLAM_RADIUS := 80.0

# Plain var (not const) so the HUD can duck-type read hp_max.
var hp_max := 120.0
var hp := hp_max
var state := State.DORMANT
var aggro := false
var alive := true

var _state_timer := 0.0
var _dash_dir := Vector2.ZERO
var _player: Node2D = null
var _visual_tween: Tween = null
var _ring_tween: Tween = null
var _freeze_timer := 0.0


@onready var sprite: AnimatedSprite2D = $BossSprite
@onready var telegraph: Sprite2D = $Telegraph


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if _freeze_timer > 0.0:
		# Frozen mid-cycle: the timer runs, the king does not.
		_freeze_timer -= delta
		velocity = Vector2.ZERO
		sprite.modulate = Color(0.55, 0.8, 1.25)
		move_and_slide()
		return
	_player = _find_player()
	_state_timer -= delta
	match state:
		State.DORMANT:
			velocity = Vector2.ZERO
			if _player != null \
					and global_position.distance_to(_player.global_position) <= AGGRO_RADIUS:
				aggro = true
				aggroed.emit()
				_enter(State.CHASE)
		State.CHASE:
			velocity = Vector2.ZERO
			if _player != null:
				var dist := global_position.distance_to(_player.global_position)
				if dist > LOSE_RADIUS:
					# Player escaped (or died far away): settle back down.
					aggro = false
					_enter(State.DORMANT)
					return
				velocity = (_player.global_position - global_position).normalized() * CHASE_SPEED
				if dist < CONTACT_RADIUS and _player.has_method("take_damage"):
					_player.call("take_damage", CONTACT_DAMAGE,
							(_player.global_position - global_position).normalized())
			if _state_timer <= 0.0:
				_enter(State.WINDUP)
		State.WINDUP:
			# Telegraph: locked in place while charging the dash.
			velocity = Vector2.ZERO
			if _state_timer <= 0.0:
				_enter(State.SLAM)
		State.SLAM:
			velocity = _dash_dir * DASH_SPEED
			if _state_timer <= 0.0:
				_slam_impact()
				_enter(State.COOLDOWN)
		State.COOLDOWN:
			velocity = Vector2.ZERO
			if _state_timer <= 0.0:
				_enter(State.CHASE)
	move_and_slide()


func take_damage(amount: float, from_dir: Vector2) -> void:
	if not alive:
		return
	hp -= amount
	# Heavy: barely flinches — a 2px nudge, no real knockback.
	global_position += from_dir * 2.0
	sprite.modulate = Color(1.6, 0.6, 0.6)
	var flash := create_tween()
	flash.tween_property(sprite, "modulate", Color.WHITE, 0.18)
	if hp <= 0.0:
		_die()


## Freeze mechanic (冰封千里): pauses the skill cycle; thaw resumes it.
func apply_freeze(duration: float) -> void:
	_freeze_timer = maxf(_freeze_timer, duration)


## Gale mechanic (风卷残云): the king is too heavy to shove far, but a
## stagger nudge keeps the fantasy consistent.
func apply_push(force: Vector2) -> void:
	global_position += force.normalized() * 4.0


## Area damage on landing: one hit to everything close by (the player's
## invulnerability window prevents rapid re-hits).
func _slam_impact() -> void:
	telegraph.visible = false
	Sfx.play("sfx_slam")
	if _player != null \
			and global_position.distance_to(_player.global_position) <= SLAM_RADIUS \
			and _player.has_method("take_damage"):
		_player.call("take_damage", SLAM_DAMAGE,
				(_player.global_position - global_position).normalized())


func _die() -> void:
	alive = false
	aggro = false
	set_physics_process(false)
	velocity = Vector2.ZERO
	telegraph.visible = false
	_kill_visual_tween()
	Sfx.play("sfx_boss_die")
	died.emit()
	var tween := create_tween()
	tween.tween_property(sprite, "scale:y", 0.12, 0.5)
	tween.parallel().tween_property(sprite, "scale:x", 1.6, 0.5)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func _enter(next: State) -> void:
	state = next
	_kill_visual_tween()
	match next:
		State.DORMANT:
			_state_timer = 0.0
			telegraph.visible = false
			_visual_tween = create_tween()
			_visual_tween.tween_property(sprite, "scale", Vector2.ONE, 0.3)
		State.CHASE:
			_state_timer = CHASE_TIME
		State.WINDUP:
			_state_timer = WINDUP_TIME
			# Lock the dash direction now, at charge start, so the player
			# can sidestep during the telegraph.
			if _player != null:
				_dash_dir = (_player.global_position - global_position).normalized()
			# Predicted landing ring (top_level: world coords, does not
			# ride along once the dash starts).
			telegraph.global_position = global_position \
					+ _dash_dir * (DASH_SPEED * SLAM_TIME)
			telegraph.visible = true
			telegraph.modulate.a = 0.55
			# Blink pulse: motion reads as "incoming", not decoration.
			_ring_tween = create_tween().set_loops(3)
			_ring_tween.tween_property(telegraph, "modulate:a", 1.0, 0.12)
			_ring_tween.tween_property(telegraph, "modulate:a", 0.55, 0.12)
			_visual_tween = create_tween()
			_visual_tween.tween_property(sprite, "scale", Vector2(1.15, 0.75), WINDUP_TIME)
		State.SLAM:
			_state_timer = SLAM_TIME
			_visual_tween = create_tween()
			_visual_tween.tween_property(sprite, "scale", Vector2(0.85, 1.3), SLAM_TIME)
		State.COOLDOWN:
			_state_timer = COOLDOWN_TIME
			_visual_tween = create_tween()
			_visual_tween.tween_property(sprite, "scale", Vector2.ONE, 0.25)


func _kill_visual_tween() -> void:
	if _visual_tween != null and _visual_tween.is_valid():
		_visual_tween.kill()
	_visual_tween = null
	if _ring_tween != null and _ring_tween.is_valid():
		_ring_tween.kill()
	_ring_tween = null


func _find_player() -> Node2D:
	# Sibling lookup under the shared y-sort layer (same as the slime).
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is CharacterBody2D and child.name == "Player":
			return child
	return null
