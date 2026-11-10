extends Node2D
## Ancient rune stone (semantic puzzle, PLAN.md §3.2): casting a
## water/ice spell NEAR the dormant stone awakens it and "channels the
## water" — the river row below gains a stone ford. All validation is
## rule-based (PuzzleValidator); state machine per plan §3.2.

const RULES := {"elements": ["water", "ice"], "shapes": [], "mechanics": []}
const ACTIVATE_RADIUS := 96.0
const ACTIVATING_TIME := 0.6

enum State { INACTIVE, ACTIVATING, ACTIVATED }

var state := State.INACTIVE

var _world: Node2D = null
var _sprite: Sprite2D

@onready var inactive_tex: Texture2D = load("res://assets/sprites/puzzles/rune_inactive.png")
@onready var active_tex: Texture2D = load("res://assets/sprites/puzzles/rune_active.png")


func setup(world: Node2D, cell: Vector2i) -> void:
	_world = world
	position = Vector2(cell) * 32.0 + Vector2(16.0, 20.0)
	_sprite = Sprite2D.new()
	_sprite.texture = inactive_tex
	_sprite.position = Vector2(0, -14)
	add_child(_sprite)


## Returns {"ok": bool, "reason": String, "message": String}.
func try_activate(spell: Dictionary, cast_position: Vector2) -> Dictionary:
	if state != State.INACTIVE:
		return {"ok": false, "reason": "already", "message": "符文已然苏醒"}
	if position.distance_to(cast_position) > ACTIVATE_RADIUS:
		return {"ok": false, "reason": "too_far", "message": ""}
	var verdict: Dictionary = PuzzleValidator.evaluate(RULES, spell)
	if not verdict["ok"]:
		return {"ok": false, "reason": "not_satisfied",
				"message": "符文纹丝不动（元素不合：%s）" % spell.get("element", "?")}

	state = State.ACTIVATING
	_sprite.texture = active_tex
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1.6, 1.6, 1.6), 0.3)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.3)
	tween.tween_callback(_finish_activation)
	return {"ok": true, "reason": "ok", "message": "符文苏醒——水到渠成！"}


func _finish_activation() -> void:
	state = State.ACTIVATED
	if _world != null and _world.has_method("build_ford"):
		_world.call("build_ford")
	GameManager.log_info("rune stone activated: ford built across the river")


## Restore path: jump straight to ACTIVATED (no tween, no ford call —
## the world replays the ford itself) for loaded sessions.
func force_activate() -> void:
	state = State.ACTIVATED
	if _sprite != null:
		_sprite.texture = active_tex
