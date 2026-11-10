extends SceneTree
## Headless integration test: the player physically collides with prop
## trunks. Instantiates the real world + player, walks into the first
## tree, and asserts the body is stopped before the trunk center.
##
##   godot --headless --path . -s res://tests/prop_collision_test.gd

const FRAMES := 90

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	var player: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()

	# Find the first tree and stand one cell to its left.
	var tree: StaticBody2D = null
	for child in world.get_entity_parent().get_children():
		if child is StaticBody2D and child.name.begins_with("Tree"):
			tree = child
			break
	_expect(tree != null, "world contains at least one tree")
	if tree == null:
		_finish()
		return

	player.position = tree.position + Vector2(-32, 0)
	world.get_entity_parent().add_child(player)
	await physics_frame
	await physics_frame

	var start := player.global_position.x
	Input.action_press("move_right")
	for i in FRAMES:
		await physics_frame
	Input.action_release("move_right")

	var moved := player.global_position.x - start
	var gap := tree.position.x - player.global_position.x
	# Unblocked the player would cover 240 px; blocked it stops ~12-16 px
	# short of the trunk center (both shapes are ~8-10 px half-width).
	_expect(moved > 4.0 and moved < 40.0, "walked into the tree and stopped (moved %.1f px)" % moved)
	_expect(gap > 10.0, "body did not penetrate trunk center (gap %.1f px)" % gap)

	_finish()


func _finish() -> void:
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
