extends Control
## Title screen (PLAN.md flow): start a fresh adventure, continue the
## last session save when one exists, or quit. Music starts here too —
## the loop carries over into the game scene seamlessly.

@onready var start_button: Button = $Margin/Rows/StartButton
@onready var continue_button: Button = $Margin/Rows/ContinueButton
@onready var settings_button: Button = $Margin/Rows/SettingsButton
@onready var quit_button: Button = $Margin/Rows/QuitButton
@onready var settings_panel: Control = $SettingsPanel
@onready var slot_panel: Control = $SlotPanel


func _ready() -> void:
	GameManager.set_state(GameManager.GameState.MENU)
	Settings.load_settings()
	Settings.apply()
	Music.play("explore_loop")
	# "Continue" only lights up when a session save exists; a disabled
	# button must also leave the keyboard focus chain.
	continue_button.disabled = SaveManager.list_slots().is_empty()
	if continue_button.disabled:
		continue_button.focus_mode = Control.FOCUS_NONE
	start_button.pressed.connect(_on_start)
	continue_button.pressed.connect(_on_continue)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	slot_panel.slot_chosen.connect(_on_slot_chosen)
	slot_panel.closed.connect(func() -> void: continue_button.grab_focus())
	# Keyboard navigation: land on the first action, arrows/Enter take over.
	start_button.grab_focus()


func _on_settings() -> void:
	settings_panel.open()


func _on_continue() -> void:
	slot_panel.open_load_mode()


func _on_slot_chosen(slot: String) -> void:
	GameManager.pending_load_session = true
	GameManager.pending_load_slot = slot
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _on_start() -> void:
	GameManager.pending_load_session = false
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
