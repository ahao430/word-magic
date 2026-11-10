extends Node2D
## Dev-only: instances the real main scene, captures two screenshots
## (idle, and after walking right) to verify map rendering, player
## visibility and camera follow outside the editor.
##
##   godot --path . res://scenes/dev/gameplay_screenshot.tscn --quit-after 600

const SHOT_A := "/tmp/wm_gameplay_idle.png"
const SHOT_B := "/tmp/wm_gameplay_moved.png"


func _ready() -> void:
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_capture(SHOT_A)
	print("[shot] idle saved")

	Input.action_press("move_right")
	for i in 90:
		await RenderingServer.frame_post_draw
	Input.action_release("move_right")
	await RenderingServer.frame_post_draw
	_capture(SHOT_B)
	print("[shot] moved saved")

	get_tree().quit()


func _capture(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img.save_png(path) != OK:
		push_error("[shot] failed to save " + path)
