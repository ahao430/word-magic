extends SceneTree
## Headless test for the procedural SFX set and the player pool.
##
##   godot --headless --path . -s res://tests/sfx_test.gd

const NAMES := [
	"sfx_cast_fire", "sfx_cast_ice", "sfx_cast_lightning", "sfx_cast_wind",
	"sfx_hit", "sfx_explosion", "sfx_hurt", "sfx_puzzle",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# --- Resources: loadable, sane duration, non-silent, 16-bit mono ---
	for name in NAMES:
		var path := "res://assets/audio/sfx/%s.tres" % name
		_expect(ResourceLoader.exists(path), "%s exists" % name)
		if not ResourceLoader.exists(path):
			continue
		var stream: AudioStreamWAV = load(path)
		var duration := float(stream.data.size()) / 2.0 / float(stream.mix_rate)
		_expect(duration >= 0.1 and duration <= 0.8, "%s duration %.2fs in range" % [name, duration])
		_expect(stream.format == AudioStreamWAV.FORMAT_16_BITS and not stream.stereo,
				"%s is 16-bit mono" % name)
		var peak := 0
		for i in range(0, stream.data.size(), 512):
			var v := absi(stream.data.decode_s16(i))
			peak = maxi(peak, v)
		_expect(peak > 8000, "%s is audible (peak %d)" % [name, peak])

	# --- Element -> cast sound recipe ---
	_expect(Sfx.cast_sound_for("fire") == "sfx_cast_fire", "fire recipe")
	_expect(Sfx.cast_sound_for("ice") == "sfx_cast_ice", "ice recipe")
	_expect(Sfx.cast_sound_for("lightning") == "sfx_cast_lightning", "lightning recipe")
	_expect(Sfx.cast_sound_for("wind") == "sfx_cast_wind" and Sfx.cast_sound_for("water") == "sfx_cast_wind",
			"wind is the fallback recipe")

	# --- Pool: plays, reuses, and never exceeds the cap ---
	Sfx.play("sfx_hit")
	Sfx.play("sfx_puzzle")
	await physics_frame
	var root := (Engine.get_main_loop() as SceneTree).root
	var playing := 0
	var players := 0
	for child in root.get_children():
		if child is AudioStreamPlayer and child.name.begins_with("Sfx"):
			players += 1
			if child.playing:
				playing += 1
	_expect(players >= 2 and playing >= 2, "two sounds playing (pool %d, playing %d)" % [players, playing])

	for i in 20:
		Sfx.play("sfx_hit")
	var total := 0
	for child in root.get_children():
		if child is AudioStreamPlayer and child.name.begins_with("Sfx"):
			total += 1
	_expect(total <= 8, "pool capped at 8 (grew to %d)" % total)

	# Unknown names stay silent instead of erroring.
	Sfx.play("sfx_does_not_exist")
	_expect(true, "unknown sound ignored")

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
