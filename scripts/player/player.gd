extends CharacterBody2D
## Top-down player: four-direction movement with camera smoothing and
## directional idle/walk animations. Sprite feet sit on the body origin
## so y-sorting matches the props layer.

const SPEED := 160.0

@onready var sprite: AnimatedSprite2D = $PlayerSprite

var _facing := "down"


func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	move_and_slide()
	if dir != Vector2.ZERO:
		_facing = _facing_from(dir)
		_play("walk_" + _facing)
	else:
		_play("idle_" + _facing)


func _facing_from(dir: Vector2) -> String:
	# Horizontal wins ties so diagonal input keeps a clear profile view.
	if absf(dir.x) >= absf(dir.y):
		return "right" if dir.x > 0.0 else "left"
	return "down" if dir.y > 0.0 else "up"


func _play(anim_name: String) -> void:
	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)
