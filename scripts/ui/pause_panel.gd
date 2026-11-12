extends PanelContainer
## Self-contained pause overlay: Esc toggles it, and because the panel
## runs in PROCESS_MODE_ALWAYS it keeps working while the tree is
## paused. Buttons resume, restart the scene, or return to the title.

var _journey: PanelContainer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$Margin/Rows/ResumeButton.pressed.connect(_resume)
	$Margin/Rows/RestartButton.pressed.connect(_restart)
	$Margin/Rows/TitleButton.pressed.connect(_to_title)
	# 旅程: a code-built stats page between Restart and Title.
	var journey_button := Button.new()
	journey_button.name = "JourneyButton"
	journey_button.text = "旅程"
	journey_button.pressed.connect(_open_journey)
	$Margin/Rows.add_child(journey_button)
	_journey = load("res://scripts/ui/journey_panel.gd").new()
	# Deferred: _ready runs while the scene root is still setting up
	# children (same trap as the Music player) — a direct add_child is
	# rejected there and the page would silently never exist.
	get_parent().get_parent().get_node("HUD").add_child.call_deferred(_journey)


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
	# An open journey page owns Esc (it closes itself in ALWAYS mode).
	if _journey != null and _journey.visible:
		return
	# An open dialogue owns Esc (it closes itself in its own
	# _process); pausing mid-conversation would be jarring.
	var dbox := main.get_node_or_null("HUD/DialogueBox")
	if dbox != null and dbox.visible:
		return
	if Input.is_action_just_pressed("pause"):
		if visible:
			_resume()
		else:
			visible = true
			get_tree().paused = true
			GameManager.set_state(GameManager.GameState.PAUSED)
			$Margin/Rows/ResumeButton.grab_focus()


func _open_journey() -> void:
	visible = false
	get_tree().paused = true  # journey runs in ALWAYS mode regardless
	_journey.open()


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
