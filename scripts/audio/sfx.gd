class_name Sfx
extends RefCounted
## Tiny static SFX player pool (PLAN.md §9 / AGENTS.md §13): streams are
## procedural AudioStreamWAV resources; every play() gets a slight
## pitch variation so repeated sounds do not machine-gun. Pool players
## are attached to the scene root and reused.

const DIR := "res://assets/audio/sfx"
const MAX_PLAYERS := 8
const PITCH_VARIATION := 0.08

static var _cache := {}
static var _pool: Array[AudioStreamPlayer] = []


static func play(sfx_name: String, volume_db := 0.0) -> void:
	var stream: AudioStream = _cache.get(sfx_name)
	if stream == null:
		var path := "%s/%s.tres" % [DIR, sfx_name]
		if not ResourceLoader.exists(path):
			return  # unknown sound: stay silent rather than error mid-game
		stream = load(path)
		_cache[sfx_name] = stream
	var player := _acquire()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-PITCH_VARIATION, PITCH_VARIATION)
	player.play()


static func _acquire() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	if _pool.size() >= MAX_PLAYERS:
		return _pool[0]  # steal the oldest when saturated
	var root := (Engine.get_main_loop() as SceneTree).root
	var p := AudioStreamPlayer.new()
	p.name = "Sfx%d" % _pool.size()
	root.add_child(p)
	_pool.append(p)
	return p


## Element -> cast-sound recipe (AGENTS.md §13: element_sound).
static func cast_sound_for(element: String) -> String:
	match element:
		"fire":
			return "sfx_cast_fire"
		"ice":
			return "sfx_cast_ice"
		"lightning":
			return "sfx_cast_lightning"
	return "sfx_cast_wind"
