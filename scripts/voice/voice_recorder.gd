extends Node
## Microphone capture (engine-native): a dedicated bus with an
## AudioEffectCapture, pulled by an AudioStreamMicrophone player — the
## standard Godot pattern, zero plugins. Headless/no-mic machines make
## start() fail cleanly; nothing here throws.

const BUS_NAME := "VoiceRec"
const MAX_HOLD := 10.0  # hard cap on a single hold (auto-stops)

var _bus_idx := -1
var _capture: AudioEffectCapture
var _player: AudioStreamPlayer
var _frames := PackedVector2Array()
var _held := 0.0
var _recording := false


func is_available() -> bool:
	# Dummy audio drivers (headless CI) expose no input devices.
	return AudioServer.get_input_device_list().size() > 0 \
			and AudioServer.input_device != "Default"


func is_recording() -> bool:
	return _recording


func start() -> bool:
	if _recording or not is_available():
		return false
	_ensure_graph()
	_frames = PackedVector2Array()
	_held = 0.0
	_capture.clear_buffer()
	_player.play()
	_recording = true
	return true


## Drain buffered frames; call every frame while recording.
func _process(delta: float) -> void:
	if not _recording:
		return
	_held += delta
	var avail := _capture.get_frames_available()
	if avail > 0:
		_frames.append_array(_capture.get_frames(avail))
	if _held >= MAX_HOLD:
		stop()


## Finish the take; returns WAV bytes ("" when only silence/nothing).
func stop() -> PackedByteArray:
	if not _recording:
		return PackedByteArray()
	_recording = false
	var avail := _capture.get_frames_available()
	if avail > 0:
		_frames.append_array(_capture.get_frames(avail))
	_player.stop()
	var trimmed := WavUtil.trim_silence(_frames, _capture.get_mix_rate())
	if trimmed.is_empty():
		return PackedByteArray()
	return WavUtil.build_wav(trimmed, _capture.get_mix_rate())


## Discard the take entirely (AGENTS.md §9: cancellation is free).
func cancel() -> void:
	if not _recording:
		return
	_recording = false
	var avail := _capture.get_frames_available()
	if avail > 0:
		_capture.get_frames(avail)  # drain
	_capture.clear_buffer()
	_player.stop()
	_frames = PackedVector2Array()


func _ensure_graph() -> void:
	if _bus_idx != -1:
		return
	if AudioServer.get_bus_index(BUS_NAME) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_NAME)
		AudioServer.set_bus_send(idx, "Master")
		AudioServer.set_bus_mute(idx, true)  # capture only, no monitor
	_bus_idx = AudioServer.get_bus_index(BUS_NAME)
	_capture = AudioEffectCapture.new()
	_capture.buffer_bytes = 1 << 19  # ~5.8s at 48k stereo; ring per chunk
	AudioServer.add_bus_effect(_bus_idx, _capture)
	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = BUS_NAME
	add_child(_player)
