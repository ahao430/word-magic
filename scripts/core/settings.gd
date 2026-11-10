class_name Settings
extends RefCounted
## Player-facing options (volume, fullscreen) with a small JSON file
## under user:// — separate from saves and the world memory: losing it
## falls back to defaults and must never block anything.
##
## Audio routes through two dedicated buses ("Music", "SFX") created on
## demand; the settings panel and this class are the only writers of
## bus volume.

const PATH := "user://settings.json"
const DEFAULT_MUSIC := 0.8
const DEFAULT_SFX := 0.9

static var music_volume := DEFAULT_MUSIC
static var sfx_volume := DEFAULT_SFX
static var fullscreen := false


static func load_settings() -> void:
	music_volume = DEFAULT_MUSIC
	sfx_volume = DEFAULT_SFX
	fullscreen = false
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not parsed is Dictionary:
		return  # damaged file: defaults win, never block
	music_volume = clampf(float(parsed.get("music_volume", DEFAULT_MUSIC)), 0.0, 1.0)
	sfx_volume = clampf(float(parsed.get("sfx_volume", DEFAULT_SFX)), 0.0, 1.0)
	fullscreen = bool(parsed.get("fullscreen", false))


static func save_settings() -> void:
	var payload := {"music_volume": music_volume, "sfx_volume": sfx_volume,
			"fullscreen": fullscreen}
	var tmp := PATH + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("settings write failed")
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(tmp, PATH)
	if err != OK:
		push_warning("settings rename failed (%d)" % err)


## Create the Music/SFX buses once (idempotent) and route them to Master.
static func ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


## Linear 0..1 -> bus volume; 0 mutes the bus outright.
static func set_bus_volume(bus_name: String, linear: float) -> void:
	ensure_buses()
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))


## Push everything to the OS / audio server (call after load + on change).
static func apply() -> void:
	ensure_buses()
	set_bus_volume("Music", music_volume)
	set_bus_volume("SFX", sfx_volume)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen \
			else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
