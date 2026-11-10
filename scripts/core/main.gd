extends Node2D
## Main scene entry: world + player + HUD (mana bar, cast input).
## UI never parses spells — text submission goes straight to
## MagicFacade, which owns the casting pipeline (AGENTS.md §6.1).

const MAGIC := preload("res://scripts/magic/magic_facade.gd")

@onready var player: CharacterBody2D = $Player
@onready var mana_bar: ProgressBar = $HUD/ManaBar
@onready var hp_bar: ProgressBar = $HUD/HpBar
@onready var cast_result: Label = $HUD/CastResult
@onready var cast_input: LineEdit = $HUD/CastInput

var _result_clear_timer: SceneTreeTimer


func _ready() -> void:
	# Reparent the player into the world's y-sorted props layer so the
	# player interleaves correctly with tree canopies while walking.
	player.reparent($World.get_entity_parent(), true)
	cast_input.text_submitted.connect(_on_cast_submitted)
	GameManager.set_state(GameManager.GameState.PLAYING)


func _process(_delta: float) -> void:
	mana_bar.value = player.mana
	hp_bar.value = player.hp


func _on_cast_submitted(text: String) -> void:
	cast_input.clear()
	cast_input.release_focus()
	var result: Dictionary = MAGIC.cast(text, player, $World)
	cast_result.text = result["message"]
	if result["ok"]:
		cast_result.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
		GameManager.log_info("cast '%s' ok, cost %d" % [text, result["cost"]])
	else:
		cast_result.add_theme_color_override("font_color", Color(1.0, 0.65, 0.6))
		GameManager.log_info("cast '%s' failed: %s" % [text, result["reason"]])
	_result_clear_timer = get_tree().create_timer(3.0)
	_result_clear_timer.timeout.connect(func(): cast_result.text = "")
