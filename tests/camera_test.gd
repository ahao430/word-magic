extends SceneTree
## Headless test for the camera: limits clamp to the map rectangle,
## smoothing is on, teleports (respawn / session load) snap instead of
## glide, and the screen center follows the player inside bounds.
##
##   godot --headless --path . -s res://tests/camera_test.gd

var _failures := 0
var _cache_backup := ""
var _memory_backup := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cache_backup = TestIsolation.stash(TestIsolation.CACHE_PATH)
	_memory_backup = TestIsolation.stash(TestIsolation.MEMORY_PATH)
	SpellCache.reset()
	WorldMemory.reset()

	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.4).timeout

	var player: CharacterBody2D = main.get_node("World").get_entity_parent().get_node("Player")
	var cam: Camera2D = player.get_node("Camera2D")
	for child in main.get_node("World").get_entity_parent().get_children():
		if child.name.begins_with("Slime_"):
			child.free()
	await physics_frame

	# --- Wiring: smoothing on, limits at the map rectangle ---
	var map_px: Vector2 = main.get_node("World").map_pixel_size()
	_expect(cam.position_smoothing_enabled and cam.position_smoothing_speed > 0.0,
			"smoothing enabled (speed %.0f)" % cam.position_smoothing_speed)
	_expect(cam.limit_left == 0 and cam.limit_top == 0
			and cam.limit_right == int(map_px.x) and cam.limit_bottom == int(map_px.y),
			"limits clamp to the map (r=%d b=%d)" % [cam.limit_right, cam.limit_bottom])

	# --- Corner clamps: the viewport never shows void ---
	player.global_position = Vector2(100, 100)
	cam.reset_smoothing()
	await physics_frame
	await physics_frame
	var center: Vector2 = cam.get_screen_center_position()
	_expect(center.distance_to(Vector2(640, 360)) < 2.0,
			"top-left corner clamps the view (center %s)" % center)

	player.global_position = map_px - Vector2(48, 24)
	cam.reset_smoothing()
	await physics_frame
	await physics_frame
	center = cam.get_screen_center_position()
	_expect(center.distance_to(Vector2(map_px.x - 640.0, map_px.y - 360.0)) < 2.0,
			"bottom-right corner clamps the view (center %s)" % center)

	# --- Free roam: the view centers on the player ---
	player.global_position = Vector2(784, 528)
	cam.reset_smoothing()
	await physics_frame
	await physics_frame
	center = cam.get_screen_center_position()
	_expect(center.distance_to(Vector2(784, 528)) < 2.0,
			"mid-map view centers on the player (%s)" % center)

	# --- Respawn snaps the camera (no cross-map glide) ---
	player.global_position = Vector2(200, 900)
	cam.reset_smoothing()
	await physics_frame
	player.take_damage(999.0, Vector2.RIGHT)
	await physics_frame
	await physics_frame
	_expect(player.global_position.distance_to(Vector2(784, 528)) < 1.0,
			"respawned at the crossing")
	center = cam.get_screen_center_position()
	_expect(center.distance_to(Vector2(784, 528)) < 2.0,
			"camera snapped to the respawn point (%s)" % center)

	title_free(main)

	TestIsolation.unstash(TestIsolation.CACHE_PATH, _cache_backup)
	TestIsolation.unstash(TestIsolation.MEMORY_PATH, _memory_backup)
	SpellCache.reset()
	WorldMemory.reset()
	_finish()


## Free the staged main scene (by reference — never the autoloads).
func title_free(main: Node2D) -> void:
	main.free()
	paused = false


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
