extends SceneTree
## Headless test for the ambience round: the exploration BGM resource
## (loop, duration, audibility, energy across sections) and the Music
## single-player; plus tree sway motion bounds.
##
##   godot --headless --path . -s res://tests/ambient_test.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# --- BGM resource ---
	var stream: AudioStreamWAV = load("res://assets/audio/music/explore_loop.tres")
	_expect(stream != null, "bgm loads")
	if stream == null:
		_finish()
		return
	var frames := stream.data.size() / 2
	var duration := float(frames) / float(stream.mix_rate)
	_expect(duration > 20.0 and duration < 30.0, "bgm duration %.1fs in range" % duration)
	_expect(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end == frames,
			"bgm loops the full buffer")

	# Audibility + energy spread: RMS in three windows along the track.
	var rms := func(start: int, len: int) -> float:
		var acc := 0.0
		var count := 0
		for i in range(start, start + len, 64):
			var v := float(stream.data.decode_s16(i * 2)) / 32768.0
			acc += v * v
			count += 1
		return sqrt(acc / float(max(count, 1)))
	var sec := frames / 24.0  # samples per second-ish
	var rms_a: float = rms.call(0, int(sec * 6))
	var rms_b: float = rms.call(int(sec * 12), int(sec * 6))
	var rms_c: float = rms.call(int(sec * 18), int(sec * 6))
	_expect(rms_a > 0.03 and rms_b > 0.03 and rms_c > 0.03,
			"bgm energy across sections (%.3f/%.3f/%.3f)" % [rms_a, rms_b, rms_c])

	# --- Music player: one instance, plays, idempotent ---
	Music.play("explore_loop")
	Music.play("explore_loop")
	await physics_frame
	var players := 0
	var root := (Engine.get_main_loop() as SceneTree).root
	for child in root.get_children():
		if child is AudioStreamPlayer and child.name == "Music":
			players += 1
	_expect(players == 1, "single music player (found %d)" % players)
	var music_player: AudioStreamPlayer = root.get_node_or_null("Music")
	_expect(music_player != null and music_player.playing, "music is playing")
	Music.stop()
	_expect(not music_player.playing, "music stops")

	# --- Tree sway: rotation animates within a small bound ---
	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var tree_sprite: Sprite2D = null
	for child in world.get_entity_parent().get_children():
		if child.name.begins_with("Tree_"):
			tree_sprite = child.get_child(child.get_child_count() - 1)
			break
	_expect(tree_sprite != null, "a tree sprite found")
	if tree_sprite == null:
		_finish()
		return
	var r0 := tree_sprite.rotation
	var max_abs := absf(r0)
	for i in 45:
		await physics_frame
		max_abs = maxf(max_abs, absf(tree_sprite.rotation))
	_expect(max_abs < 0.06, "sway stays subtle (max |rot| %.3f rad)" % max_abs)
	var rotated := false
	for i in 45:
		await physics_frame
		if absf(tree_sprite.rotation - r0) > 0.005:
			rotated = true
	_expect(rotated, "tree actually sways over time")

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
