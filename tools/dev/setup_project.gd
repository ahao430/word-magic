extends SceneTree
## One-shot project configuration script (run headless, then it quits):
##
##   godot --headless --path . -s res://tools/dev/setup_project.gd
##
## Registers the GameManager autoload and the input actions defined in
## PLAN.md §2.2 (WASD/arrows, attack, interact, pause). Using a script
## instead of hand-edited [input] serialization lets the engine write
## canonical InputEvent objects itself.

const AUTOLOADS := {
	"GameManager": "*res://scripts/core/game_manager.gd",
}


func _init() -> void:
	for name in AUTOLOADS:
		ProjectSettings.set_setting("autoload/" + name, AUTOLOADS[name])
		print("[setup] autoload registered: ", name)

	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("attack", [KEY_SPACE], [MOUSE_BUTTON_LEFT])
	_add_key_action("interact", [KEY_E], [MOUSE_BUTTON_RIGHT])
	_add_key_action("pause", [KEY_ESCAPE])

	var err := ProjectSettings.save()
	if err != OK:
		push_error("[setup] failed to save project.godot: %s" % err)
	else:
		print("[setup] project.godot saved")
	quit()


func _add_key_action(action: String, keys: Array, mouse_buttons: Array = []) -> void:
	var events: Array = []
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		events.append(ev)
	for button in mouse_buttons:
		var mb := InputEventMouseButton.new()
		mb.button_index = button
		events.append(mb)
	ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	print("[setup] input action registered: ", action)
