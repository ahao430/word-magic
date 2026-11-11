extends PanelContainer
## Self-contained pause overlay: Esc toggles it, and because the panel
## runs in PROCESS_MODE_ALWAYS it keeps working while the tree is
## paused. Buttons resume, restart the scene, or return to the title.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$Margin/Rows/ResumeButton.pressed.connect(_resume)
	$Margin/Rows/RestartButton.pressed.connect(_restart)
	$Margin/Rows/TitleButton.pressed.connect(_to_title)


func _process(_delta: float) -> void:
	# Voice owns Esc while recording or confirming (AGENTS.md §9:
	# cancel is always one keystroke away). VoiceInput lives on Main,
	# two levels up from this HUD child.
	var main := get_parent().get_parent()
	var voice := main.get_node_or_null("VoiceInput")
	var vc := main.get_node_or_null("HUD/VoiceConfirm")
	if voice != null and (str(voice.call("state_name")) in ["RECORDING", "CONFIRM"]
			or (vc != null and vc.visible)):
		if Input.is_action_just_pressed("pause"):
			voice.call("cancel")
		return
	if Input.is_action_just_pressed("pause"):
		if visible:
			_resume()
		else:
			visible = true
			get_tree().paused = true
			GameManager.set_state(GameManager.GameState.PAUSED)
			$Margin/Rows/ResumeButton.grab_focus()


func _resume() -> void:
	visible = false
	get_tree().paused = false
	GameManager.set_state(GameManager.GameState.PLAYING)


func _restart() -> void:
	get_tree().paused = false
	GameManager.set_state(GameManager.GameState.PLAYING)
	get_tree().reload_current_scene()


func _to_title() -> void:
	get_tree().paused = false
	GameManager.set_state(GameManager.GameState.MENU)
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
