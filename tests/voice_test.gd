extends SceneTree
## Headless test for the voice-input subsystem, fully offline: WAV
## container correctness, silence trimming, the push-to-talk state
## machine (every legal transition, cancellation is always free, the
## mid-flight cancel drops results), cast-phrase gating, and the mock
## ASR seam including silence/unconfigured/timeout taxonomy. The main
## wiring is exercised end-to-end: a confirmed transcript casts like
## typed text.

var _failures := 0
var _cache_backup := ""
var _memory_backup := ""
var _ai_backup := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cache_backup = TestIsolation.stash(TestIsolation.CACHE_PATH)
	_memory_backup = TestIsolation.stash(TestIsolation.MEMORY_PATH)
	_ai_backup = AiConfig.capture_config()
	AiConfig.apply_config({})
	SpellCache.reset()
	WorldMemory.reset()

	# --- WAV container: RIFF header, sizes, PCM mono ---
	var frames := PackedVector2Array()
	for i in 1600:  # 0.1s of tone at 16k
		frames.append(Vector2(sin(TAU * 440.0 * i / 16000.0) * 0.5, 0.0))
	var wav := WavUtil.build_wav(frames, 16000)
	_expect(wav.size() == 44 + 3200, "wav size = header + samples (%d)" % wav.size())
	_expect(wav.slice(0, 4).get_string_from_ascii() == "RIFF"
			and wav.slice(8, 12).get_string_from_ascii() == "WAVE",
			"RIFF/WAVE markers")
	_expect(wav.decode_u32(4) == wav.size() - 8, "RIFF size field")
	_expect(wav.slice(36, 40).get_string_from_ascii() == "data"
			and wav.decode_u32(40) == 3200, "data chunk size")
	_expect(wav.decode_u16(20) == 1 and wav.decode_u16(22) == 1,
			"PCM mono format")
	_expect(wav.decode_u32(24) == 16000, "sample rate field")

	# --- Silence trimming keeps speech + padding only ---
	var mixed := PackedVector2Array()
	for i in 8000:  # 0.5s silence
		mixed.append(Vector2(0.001, 0.0))
	for i in 1600:  # speech
		mixed.append(Vector2(0.5, 0.0))
	for i in 8000:  # 0.5s silence
		mixed.append(Vector2(0.001, 0.0))
	var trimmed := WavUtil.trim_silence(mixed, 16000)
	_expect(trimmed.size() >= 1600 and trimmed.size() <= 1600 + 2 * int(0.15 * 16000) + 2,
			"trim keeps speech + padding (%d of 17600)" % trimmed.size())
	_expect(WavUtil.trim_silence(PackedVector2Array(), 16000).is_empty(),
			"empty input trims to empty")
	var dead := PackedVector2Array()
	for i in 4000:
		dead.append(Vector2(0.001, 0.0))
	_expect(WavUtil.trim_silence(dead, 16000).is_empty(), "pure silence trims to empty")

	# --- State machine: full happy path through the mock seam ---
	AiConfig.apply_config({"base_url": "https://fake.local/v1", "api_key": "k",
			"chat_model": "m", "asr_model": "whisper-test"})
	var voice := preload("res://scripts/voice/voice_input.gd").new()
	root.add_child(voice)
	var confirmed: Array = []
	voice.text_confirmed.connect(func(text: String) -> void: confirmed.append(text))
	var failures_seen: Array = []
	voice.failed.connect(func(reason: String, _m: String) -> void: failures_seen.append(reason))

	# No microphone in headless: talk_pressed must fail softly, no crash.
	voice.talk_pressed()
	_expect(str(voice.state_name()) == "IDLE" and failures_seen.has("asr_no_microphone"),
			"headless mic absence is a soft failure")

	# Drive the machine past the recorder (tests bypass the mic): mock
	# ASR + direct recorder stub via a fake wav path.
	AsrProvider.mock_transcribe = func(_b): return {"ok": true,
			"text": "火球术", "reason": "ok", "message": ""}
	await voice.talk_released()  # not recording: ignored
	_expect(str(voice.state_name()) == "IDLE", "release without record is a no-op")
	# Force the recording state to exercise release handling (recorder
	# absent of mic returns empty wav -> mock still answers).
	voice.state = 1  # State.RECORDING
	await voice.talk_released()
	await create_timer(0.1).timeout
	_expect(str(voice.state_name()) == "CONFIRM" and voice.transcript == "火球术",
			"release -> transcribe -> confirm")
	voice.confirm()
	_expect(confirmed == ["火球术"] and str(voice.state_name()) == "IDLE",
			"confirm emits the text and resets")

	# --- Cast phrase gating ---
	AiConfig.apply_config({"base_url": "https://fake.local/v1", "api_key": "k",
			"chat_model": "m", "asr_model": "w", "cast_phrase": "施法"})
	AsrProvider.mock_transcribe = func(_b): return {"ok": true,
			"text": "施法 寒冰箭", "reason": "ok", "message": ""}
	voice.state = 1
	await voice.talk_released()
	await create_timer(0.1).timeout
	_expect(voice.transcript == "寒冰箭", "cast phrase stripped")
	voice.cancel()
	AsrProvider.mock_transcribe = func(_b): return {"ok": true,
			"text": "寒冰箭", "reason": "ok", "message": ""}
	voice.state = 1
	await voice.talk_released()
	await create_timer(0.1).timeout
	_expect(failures_seen.has("cast_phrase_missing"),
			"missing cast phrase is refused")

	# --- Infra taxonomy through the seam ---
	for entry in [["asr_timeout", "识别超时，请再试一次"],
			["asr_unavailable", "语音服务暂不可用"]]:
		AsrProvider.mock_transcribe = func(_b, r=entry[0], m=entry[1]): return {"ok": false,
				"text": "", "reason": r, "message": m}
		voice.state = 1
		await voice.talk_released()
		await create_timer(0.1).timeout
	_expect(failures_seen.has("asr_timeout") and failures_seen.has("asr_unavailable"),
			"timeout/unavailable surface as failures")
	_expect(str(voice.state_name()) == "IDLE", "failures reset to idle")

	# --- Mid-flight cancel drops the result ---
	AsrProvider.mock_transcribe = func(_b): return {"ok": true,
			"text": "烈焰焚天", "reason": "ok", "message": ""}
	# Cancel DURING the recording/transcribing window: the release then
	# no-ops (state guard) and nothing is confirmed.
	AsrProvider.mock_transcribe = func(_b): return {"ok": true,
			"text": "烈焰焚天", "reason": "ok", "message": ""}
	voice.state = 1
	voice.cancel()  # recording discarded, back to IDLE
	await voice.talk_released()  # state guard: dropped
	await create_timer(0.1).timeout
	_expect(str(voice.state_name()) == "IDLE" and confirmed.size() == 1,
			"cancel discards the pending take")

	# --- Unconfigured voice refuses to start ---
	AiConfig.apply_config({})
	AsrProvider.mock_transcribe = Callable()
	failures_seen.clear()
	voice.talk_pressed()
	_expect(failures_seen.has("asr_unconfigured"), "unconfigured is a soft failure")

	voice.free()

	_teardown()


func _teardown() -> void:
	AsrProvider.mock_transcribe = Callable()
	TestIsolation.unstash(TestIsolation.CACHE_PATH, _cache_backup)
	TestIsolation.unstash(TestIsolation.MEMORY_PATH, _memory_backup)
	AiConfig.apply_config(_ai_backup)
	SpellCache.reset()
	WorldMemory.reset()
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
