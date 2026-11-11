extends CharacterBody2D
## Top-down player: four-direction movement with camera smoothing,
## directional idle/walk animations, and a mana pool for spell casting.
## Sprite feet sit on the body origin so y-sorting matches props.

const ProjectileScript := preload("res://scripts/effects/projectile.gd")

## Basic attack (LMB/Space): a free arcane bolt toward the cursor.
## Not a text spell — no pipeline, no mana, no session cost.
const BASIC_BOLT := {"display": "奥术飞弹", "element": "arcane", "shape": "projectile",
		"mechanics": ["damage"], "parameters": {"damage": 6.0, "radius": 6.0,
		"speed": 360.0, "duration": 1.2}, "cost": 0}
const BASIC_COOLDOWN := 0.35

## Spell echo (RMB): a weakened repeat of the last successful text
## cast — words create the miracle once, the mouse releases its echo.
const ECHO_DAMAGE_RATIO := 0.5
const ECHO_COST_RATIO := 0.4
const ECHO_COOLDOWN := 0.8

const SPEED := 160.0
const MANA_MAX := 100.0
const MANA_REGEN := 2.0
const HP_MAX := 30.0
const INVULN_TIME := 0.8
const KNOCKBACK := 140.0
## Dev-map respawn point (the stone crossing); real save/spawn handling
## arrives with the save system phase.
const RESPAWN_POSITION := Vector2(784, 528)

@onready var sprite: AnimatedSprite2D = $PlayerSprite

var _facing := "down"
var _invuln_timer := 0.0
var _basic_cd := 0.0
var _echo_cd := 0.0
var last_spell: Dictionary = {}
var shield_timer := 0.0
var _shield_fx: Sprite2D = null
var mana := MANA_MAX
var hp := HP_MAX


func _physics_process(_delta: float) -> void:
	mana = minf(mana + MANA_REGEN * _delta, MANA_MAX)
	_basic_cd = maxf(_basic_cd - _delta, 0.0)
	_echo_cd = maxf(_echo_cd - _delta, 0.0)
	if shield_timer > 0.0:
		shield_timer -= _delta
		if _shield_fx != null:
			_shield_fx.visible = true
			_shield_fx.rotation += 1.5 * _delta
	elif _shield_fx != null:
		_shield_fx.visible = false
	if _invuln_timer > 0.0:
		_invuln_timer -= _delta
		# Blink while invulnerable.
		sprite.visible = fmod(_invuln_timer, 0.2) < 0.1
	else:
		sprite.visible = true

	if _is_typing():
		velocity = Vector2.ZERO
		_play("idle_" + _facing)
		return

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	move_and_slide()
	if dir != Vector2.ZERO:
		_facing = _facing_from(dir)
		_play("walk_" + _facing)
	else:
		_play("idle_" + _facing)


func take_damage(amount: float, from_dir: Vector2) -> void:
	if _invuln_timer > 0.0:
		return
	# 守护之壁: while the shield holds, damage is cut to 40%.
	if shield_timer > 0.0:
		amount *= 0.4
	hp -= amount
	_invuln_timer = INVULN_TIME
	Sfx.play("sfx_hurt")
	# Red flash on top of the invulnerability blink.
	sprite.modulate = Color(1.8, 0.45, 0.45)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	# Small knockback away from the attacker.
	global_position += from_dir * 6.0
	if hp <= 0.0:
		_respawn()


func _respawn() -> void:
	hp = HP_MAX
	mana = MANA_MAX
	_invuln_timer = INVULN_TIME
	global_position = RESPAWN_POSITION
	# Teleport: snap the camera instead of gliding across the map.
	var cam := get_node_or_null("Camera2D")
	if cam != null:
		cam.reset_smoothing()
	GameManager.log_info("player fell; respawned at the crossing")


func try_consume_mana(amount: float) -> bool:
	if mana < amount:
		return false
	mana -= amount
	return true


func refund_mana(amount: float) -> void:
	mana = minf(mana + amount, MANA_MAX)


## LMB/Space attack: one free arcane bolt along aim_dir. Returns false
## while on cooldown.
func try_basic_attack(aim_dir: Vector2) -> bool:
	if _basic_cd > 0.0:
		return false
	_basic_cd = BASIC_COOLDOWN
	var dir := aim_dir.normalized()
	if dir.length() < 0.5:
		dir = get_facing_vector()
	ProjectileScript.spawn(BASIC_BOLT, global_position + dir * 20.0, dir, get_parent())
	return true


## Echo cost/data (RMB). The echo is executor-only: same element and
## shape, halved damage — it never re-enters the text pipeline, so the
## session uniqueness of the original spell stays intact.
func echo_cost() -> int:
	return ceili(float(last_spell.get("cost", 0)) * ECHO_COST_RATIO)


func make_echo_spell() -> Dictionary:
	var echo := last_spell.duplicate(true)
	var params: Dictionary = echo.get("parameters", {})
	params["damage"] = maxf(float(params.get("damage", 0.0)) * ECHO_DAMAGE_RATIO, 1.0)
	echo["display"] = str(echo.get("display", "回响")) + "·回响"
	echo["parameters"] = params
	echo["cost"] = echo_cost()
	return echo


func echo_ready() -> bool:
	return _echo_cd <= 0.0 and not last_spell.is_empty()


func consume_echo_cooldown() -> void:
	_echo_cd = ECHO_COOLDOWN


## Pure aim helper (Diablo-style snap): if an enemy sits within
## snap_px of the cursor, aim straight at it; otherwise aim at the
## cursor itself. candidates: [{pos: Vector2, name: String}].
static func aim_direction(from: Vector2, mouse_world: Vector2,
		candidates: Array, snap_px := 28.0) -> Vector2:
	var best: Vector2 = mouse_world
	var best_dist := snap_px
	for c in candidates:
		var pos: Vector2 = c["pos"]
		var d := pos.distance_to(mouse_world)
		if d <= best_dist:
			best_dist = d
			best = pos
	var dir := best - from
	return dir.normalized() if dir.length() > 1.0 else Vector2.RIGHT


## 守护之壁 (shield spell): damage mitigation for the duration, with a
## spinning translucent ring as the visual.
func apply_shield(duration: float) -> void:
	shield_timer = maxf(shield_timer, duration)
	if _shield_fx == null:
		_shield_fx = Sprite2D.new()
		_shield_fx.name = "ShieldFx"
		_shield_fx.texture = load("res://assets/sprites/effects/field_zone_128.png")
		_shield_fx.modulate = Color(0.6, 1.2, 0.8, 0.5)
		_shield_fx.scale = Vector2(0.55, 0.55)
		add_child(_shield_fx)


func get_facing_vector() -> Vector2:
	match _facing:
		"up":
			return Vector2.UP
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
	return Vector2.DOWN


func _is_typing() -> bool:
	# While the cast LineEdit holds focus, movement input is suspended so
	# WASD goes to the text field instead of the body.
	return get_viewport().gui_get_focus_owner() is LineEdit


func _facing_from(dir: Vector2) -> String:
	# Horizontal wins ties so diagonal input keeps a clear profile view.
	if absf(dir.x) >= absf(dir.y):
		return "right" if dir.x > 0.0 else "left"
	return "down" if dir.y > 0.0 else "up"


func _play(anim_name: String) -> void:
	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)
