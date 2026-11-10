extends SceneTree
## Headless test: the player switches between directional walk/idle
## animations in response to input, matching the last facing when idle.
##
##   godot --headless --path . -s res://tests/player_animation_test.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	await physics_frame
	await physics_frame
	var sprite: AnimatedSprite2D = player.get_node("PlayerSprite")

	_expect(sprite.animation == "idle_down", "starts idle_down (got %s)" % sprite.animation)

	for step in [["move_right", "walk_right"], ["move_down", "walk_down"], ["move_left", "walk_left"], ["move_up", "walk_up"]]:
		Input.action_press(step[0])
		await physics_frame
		await physics_frame
		Input.action_release(step[0])
		_expect(sprite.animation == step[1], "%s plays %s (got %s)" % [step[0], step[1], sprite.animation])
		await physics_frame
		await physics_frame

	# After the last movement (up) the idle should keep that facing.
	_expect(sprite.animation == "idle_up", "idle keeps last facing (got %s)" % sprite.animation)
	_expect(not sprite.is_playing() or sprite.animation.begins_with("idle"), "no walk anim while still")

	if _failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES: %d" % _failures)
		quit(1)


func _expect(cond: bool, what: String) -> void:
	if cond:
		print("PASS  " + what)
	else:
		_failures += 1
		print("FAIL  " + what)
