extends CharacterBody2D
## Top-down player: four-direction movement with camera smoothing,
## directional idle/walk animations, and a mana pool for spell casting.
## Sprite feet sit on the body origin so y-sorting matches props.

const SPEED := 160.0
const MANA_MAX := 100.0
const MANA_REGEN := 2.0

@onready var sprite: AnimatedSprite2D = $PlayerSprite

var _facing := "down"
var mana := MANA_MAX


func _physics_process(_delta: float) -> void:
	mana = minf(mana + MANA_REGEN * _delta, MANA_MAX)

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


func try_consume_mana(amount: float) -> bool:
	if mana < amount:
		return false
	mana -= amount
	return true


func refund_mana(amount: float) -> void:
	mana = minf(mana + amount, MANA_MAX)


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
