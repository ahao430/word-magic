extends Node2D
## Dev-only: instances the real main scene, captures three screenshots
## (idle, after walking right, and mid-cast with a fireball flying) to
## verify map/player/casting rendering outside the editor.
##
##   godot --path . res://scenes/dev/gameplay_screenshot.tscn --quit-after 900

const SHOT_A := "/tmp/wm_gameplay_idle.png"
const SHOT_B := "/tmp/wm_gameplay_moved.png"
const SHOT_C := "/tmp/wm_gameplay_cast.png"

const MAGIC := preload("res://scripts/magic/magic_facade.gd")


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

	# Cast a fireball at a slime placed right of the player and catch
	# the impact frame.
	var player: CharacterBody2D = null
	for child in main.get_node("World").get_entity_parent().get_children():
		if child is CharacterBody2D and child.name == "Player":
			player = child
			break
	var slime: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	slime.position = player.global_position + Vector2(150, 0)
	main.get_node("World").get_entity_parent().add_child(slime)
	await RenderingServer.frame_post_draw

	Input.action_press("move_right")
	await RenderingServer.frame_post_draw
	Input.action_release("move_right")

	var result: Dictionary = MAGIC.cast("火球术", player, main.get_node("World"))
	print("[shot] cast: ", result["message"], " cost ", result["cost"])
	for i in 18:
		await RenderingServer.frame_post_draw  # ~impact at 150px / 300px/s
	_capture(SHOT_C)
	print("[shot] cast saved")

	get_tree().quit()


func _capture(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img.save_png(path) != OK:
		push_error("[shot] failed to save " + path)
