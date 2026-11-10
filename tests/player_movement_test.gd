extends SceneTree
## Headless movement test: presses each direction, steps physics frames,
## asserts the player body actually moves (and stops when released).
##
##   godot --headless --path . -s res://tests/player_movement_test.gd
##
## Prints PASS/FAIL lines; exit code reflects failures.

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const FRAMES := 30
const MIN_DELTA := 8.0  # px over 30 physics frames at 60 Hz

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load(PLAYER_SCENE)
	var player: CharacterBody2D = packed.instantiate()
	root.add_child(player)

	# Two settling frames so _ready and first physics tick run.
	await physics_frame
	await physics_frame

	for dir_name in [["move_left", Vector2.LEFT], ["move_right", Vector2.RIGHT],
			["move_up", Vector2.UP], ["move_down", Vector2.DOWN]]:
		var before: Vector2 = player.global_position
		Input.action_press(dir_name[0])
		for i in FRAMES:
			await physics_frame
		Input.action_release(dir_name[0])
		var moved: Vector2 = player.global_position - before
		var along := moved.dot(dir_name[1])
		if along >= MIN_DELTA:
			print("PASS  %s moved %.1f px along axis" % [dir_name[0], along])
		else:
			_failures += 1
			print("FAIL  %s moved only %.1f px along axis" % [dir_name[0], along])

	# Release everything and confirm the body comes to rest.
	await physics_frame
	await physics_frame
	if player.velocity.length() < 0.01:
		print("PASS  body at rest after release (velocity %.3f)" % player.velocity.length())
	else:
		_failures += 1
		print("FAIL  body still moving (velocity %.3f)" % player.velocity.length())

	player.queue_free()
	if _failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES: %d" % _failures)
		quit(1)
