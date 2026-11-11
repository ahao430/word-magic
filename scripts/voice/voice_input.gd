extends Node
## Voice-input state machine (AGENTS.md §9): push-to-talk record ->
## transcribe -> PLAYER CONFIRMS -> emit text_confirmed. Cancellation
## and every infra failure are free (no mana, no session cost, no
## backlash); the optional cast_phrase prefix marks real casts.
##
## States: IDLE -> RECORDING (key held) -> TRANSCRIBING -> CONFIRM
##           CONFIRM --confirm--> IDLE (+ text_confirmed signal)
##           any ----cancel----> IDLE

signal state_changed(state_name: String)
signal text_confirmed(text: String)
signal failed(reason: String, message: String)

enum State { IDLE, RECORDING, TRANSCRIBING, CONFIRM }

var state := State.IDLE
var transcript := ""

var _recorder: Node
var _pending_wav := PackedByteArray()


func _ready() -> void:
	_recorder = preload("res://scripts/voice/voice_recorder.gd").new()
	_recorder.name = "Recorder"
	add_child(_recorder)


func is_configured() -> bool:
	return AiConfig.is_voice_available()


## Push-to-talk press.
func talk_pressed() -> void:
	if state != State.IDLE:
		return
	if not is_configured():
		_failed("asr_unconfigured", "语音识别未配置（config/ai.json 的 asr_model）")
		return
	if not _recorder.is_available():
		_failed("asr_no_microphone", "未检测到麦克风")
		return
	if _recorder.start():
		_set_state(State.RECORDING)


## Push-to-talk release: take the audio and transcribe.
func talk_released() -> void:
	if state != State.RECORDING:
		return
	_set_state(State.TRANSCRIBING)
	_pending_wav = _recorder.stop()
	var resp: Dictionary = await AsrProvider.transcribe(_pending_wav)
	if state != State.TRANSCRIBING:
		return  # cancelled mid-flight; drop the result silently
	if not resp["ok"]:
		_failed(resp["reason"], resp["message"])
		return
	var text := str(resp["text"])
	# Optional spoken prefix ("施法" etc.) marks real casts; configures
	# in config/ai.json, empty = everything is a cast.
	var phrase := AiConfig.cast_phrase()
	if phrase != "":
		if not text.begins_with(phrase):
			_failed("cast_phrase_missing", "未听到口令「%s」，已忽略" % phrase)
			return
		text = text.substr(phrase.length()).strip_edges()
	if text.is_empty():
		_failed("asr_empty", "没有听清，请再试一次")
		return
	transcript = text
	_set_state(State.CONFIRM)


## Player accepted the transcript.
func confirm() -> void:
	if state != State.CONFIRM:
		return
	var text := transcript
	transcript = ""
	_set_state(State.IDLE)
	text_confirmed.emit(text)


## Player rejected it — completely free (AGENTS.md §9).
func cancel() -> void:
	if state == State.RECORDING:
		_recorder.cancel()
	elif state == State.TRANSCRIBING:
		pass  # result will be dropped by the state guard
	transcript = ""
	_set_state(State.IDLE)


## True while the hardware key is (probably) still held — used by the
## host to catch a missed release (focus loss etc.).
func is_recording_held() -> bool:
	return state == State.RECORDING


func state_name() -> String:
	return State.keys()[state]


func _set_state(next: State) -> void:
	state = next
	state_changed.emit(state_name())


func _failed(reason: String, message: String) -> void:
	transcript = ""
	_set_state(State.IDLE)
	failed.emit(reason, message)
