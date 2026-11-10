extends Control
## Title screen (PLAN.md flow): start a fresh adventure, continue the
## last session save when one exists, or quit. Music starts here too —
## the loop carries over into the game scene seamlessly.

@onready var start_button: Button = $Margin/Rows/StartButton
@onready var continue_button: Button = $Margin/Rows/ContinueButton
@onready var quit_button: Button = $Margin/Rows/QuitButton


func _ready() -> void:
	GameManager.set_state(GameManager.GameState.MENU)
	Music.play("explore_loop")
	# "Continue" only lights up when a session save exists.
	continue_button.disabled = not FileAccess.file_exists(SaveManager.slot_path("slot_01"))
	start_button.pressed.connect(_on_start)
	continue_button.pressed.connect(_on_continue)
	quit_button.pressed.connect(func() -> void: get_tree().quit())


func _on_start() -> void:
	GameManager.pending_load_session = false
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _on_continue() -> void:
	GameManager.pending_load_session = true
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
