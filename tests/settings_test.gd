extends SceneTree
## Headless test for the settings layer: file roundtrip + clamping, the
## Music/SFX bus wiring, live volume application from the title panel,
## and the keyboard focus chain on the title screen.
##
##   godot --headless --path . -s res://tests/settings_test.gd

var _failures := 0
var _cache_backup := ""
var _memory_backup := ""
var _settings_backup := ""
var _slot_backup := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cache_backup = TestIsolation.stash(TestIsolation.CACHE_PATH)
	_memory_backup = TestIsolation.stash(TestIsolation.MEMORY_PATH)
	_settings_backup = TestIsolation.stash("user://settings.json")
	_slot_backup = TestIsolation.stash(SaveManager.slot_path("slot_01"))
	SpellCache.reset()
	WorldMemory.reset()

	# --- Settings file: defaults, roundtrip, clamping ---
	Settings.load_settings()
	_expect(absf(Settings.music_volume - 0.8) < 0.001
			and absf(Settings.sfx_volume - 0.9) < 0.001 and not Settings.fullscreen,
			"defaults on a missing file")
	Settings.music_volume = 0.35
	Settings.sfx_volume = 0.6
	Settings.fullscreen = true
	Settings.save_settings()
	Settings.music_volume = 1.0
	Settings.load_settings()
	_expect(absf(Settings.music_volume - 0.35) < 0.001
			and absf(Settings.sfx_volume - 0.6) < 0.001 and Settings.fullscreen,
			"roundtrip preserves values")
	# Damaged file: defaults win, nothing blocks.
	var sf := FileAccess.open("user://settings.json", FileAccess.WRITE)
	sf.store_string("{ oops")
	sf.close()
	Settings.load_settings()
	_expect(absf(Settings.music_volume - 0.8) < 0.001, "damaged file falls back to defaults")

	# --- Buses: created once, linear volume, mute at zero ---
	Settings.ensure_buses()
	var music_idx := AudioServer.get_bus_index("Music")
	var sfx_idx := AudioServer.get_bus_index("SFX")
	_expect(music_idx != -1 and sfx_idx != -1, "Music/SFX buses exist")
	Settings.ensure_buses()
	_expect(AudioServer.get_bus_index("Music") == music_idx, "ensure_buses is idempotent")
	Settings.set_bus_volume("Music", 0.5)
	_expect(absf(AudioServer.get_bus_volume_db(music_idx) - linear_to_db(0.5)) < 0.01,
			"0.5 linear maps to -6 dB")
	_expect(not AudioServer.is_bus_mute(music_idx), "audible volume unmutes")
	Settings.set_bus_volume("Music", 0.0)
	_expect(AudioServer.is_bus_mute(music_idx), "zero volume mutes the bus")

	# --- Players route to their buses ---
	Sfx.play("sfx_hit")
	Music.play("explore_loop")
	await physics_frame
	var root := (Engine.get_main_loop() as SceneTree).root
	var sfx_bus := ""
	var music_bus := ""
	for child in root.get_children():
		if child is AudioStreamPlayer and child.name.begins_with("Sfx"):
			sfx_bus = child.bus
		if child is AudioStreamPlayer and child.name == "Music":
			music_bus = child.bus
	_expect(sfx_bus == "SFX", "SFX pool routes to the SFX bus")
	_expect(music_bus == "Music", "music player routes to the Music bus")
	Music.stop()

	# --- Title screen: settings panel opens, applies, closes; focus ---
	var title: Control = load("res://scenes/ui/title.tscn").instantiate()
	root.add_child(title)
	await physics_frame
	await physics_frame
	var start_btn: Button = title.get_node("Margin/Rows/StartButton")
	_expect(start_btn.has_focus(), "focus lands on the start button")
	var panel: Control = title.get_node("SettingsPanel")
	_expect(panel != null and not panel.visible, "settings panel starts hidden")
	panel.open()
	_expect(panel.visible, "settings panel opens")
	var music_slider: HSlider = panel.get_node("Panel/Margin/Rows/MusicRow/MusicSlider")
	music_slider.value = 0.25  # triggers value_changed -> Settings + bus
	await physics_frame
	_expect(absf(Settings.music_volume - 0.25) < 0.001, "slider writes through to Settings")
	_expect(absf(AudioServer.get_bus_volume_db(music_idx) - linear_to_db(0.25)) < 0.01,
			"slider drives the Music bus live")
	var back_btn: Button = panel.get_node("Panel/Margin/Rows/BackButton")
	_expect(back_btn.has_focus(), "focus moves into the panel")
	back_btn.pressed.emit()
	_expect(not panel.visible, "back button closes the panel")
	var saved := FileAccess.open("user://settings.json", FileAccess.READ)
	var saved_text := saved.get_as_text()
	saved.close()
	_expect(saved_text.contains("music_volume"), "closing persists the settings file")
	title.free()

	_test_cleanup()
	_finish()


func _test_cleanup() -> void:
	paused = false
	# -s root scripts compile before autoloads register: tree-resolve.
	var gm: Node = get_root().get_node("/root/GameManager")
	gm.pending_load_session = false
	TestIsolation.unstash(TestIsolation.CACHE_PATH, _cache_backup)
	TestIsolation.unstash(TestIsolation.MEMORY_PATH, _memory_backup)
	TestIsolation.unstash("user://settings.json", _settings_backup)
	TestIsolation.unstash(SaveManager.slot_path("slot_01"), _slot_backup)
	SpellCache.reset()
	WorldMemory.reset()
	Settings.load_settings()
	Settings.apply()


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
