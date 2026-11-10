class_name Music
extends RefCounted
## Single looping music player for scene BGM (PLAN.md §9.3). One shared
# player on the scene root; switching tracks reuses it without
# restarting if the same track is already playing.


static var _player: AudioStreamPlayer = null


static func play(resource_name: String, volume_db := -12.0) -> void:
	var path := "res://assets/audio/music/%s.tres" % resource_name
	if not ResourceLoader.exists(path):
		return  # unknown track: silent, never an error mid-game
	var stream: AudioStream = load(path)
	if _player == null:
		var root := (Engine.get_main_loop() as SceneTree).root
		_player = AudioStreamPlayer.new()
		_player.name = "Music"
		_player.bus = "Music"  # volume owned by the settings panel
		root.add_child(_player)
		# Stop playback and drop the static reference at teardown so the
		# WAV stream/playback do not outlive the tree at exit.
		root.tree_exiting.connect(func():
			_player.stop()
			_player = null)
	if _player.playing and _player.stream == stream:
		return
	_player.stream = stream
	_player.volume_db = volume_db
	_player.play()


static func stop() -> void:
	if _player != null:
		_player.stop()
