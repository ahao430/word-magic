class_name AsrProvider
extends RefCounted
## OpenAI-compatible speech-to-text (POST {base}/audio/transcriptions,
## multipart: model + wav file). Same trust rules as the chat seam: the
## transcript is TEXT for the player to confirm — it never casts by
## itself. Failure taxonomy mirrors ChatProvider; the key never leaks
## into logs or errors.

## Test seam (offline suite).
static var mock_transcribe: Callable = Callable()


## Returns {"ok": bool, "text": String, "reason": String, "message": String}.
static func transcribe(wav_bytes: PackedByteArray) -> Dictionary:
	if mock_transcribe.is_valid():
		return mock_transcribe.call(wav_bytes)
	if wav_bytes.is_empty():
		return {"ok": false, "text": "", "reason": "asr_silence",
				"message": "没有听到声音"}
	if not AiConfig.is_voice_available():
		return {"ok": false, "text": "", "reason": "asr_unconfigured",
				"message": "语音识别未配置（config/ai.json 的 asr_model）"}

	var url := "%s/audio/transcriptions" % AiConfig.asr_base_url()
	var boundary := "wordmagic-boundary-7f3a"
	var body := PackedByteArray()
	body.append_array(("--%s\r\n" % boundary).to_utf8_buffer())
	body.append_array(('Content-Disposition: form-data; name="model"\r\n\r\n').to_ascii_buffer())
	body.append_array(AiConfig.asr_model().to_utf8_buffer())
	body.append_array(("\r\n--%s\r\n" % boundary).to_utf8_buffer())
	body.append_array(('Content-Disposition: form-data; name="file"; filename="audio.wav"\r\n').to_ascii_buffer())
	body.append_array(("Content-Type: audio/wav\r\n\r\n").to_ascii_buffer())
	body.append_array(wav_bytes)
	body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
	var headers := PackedStringArray([
		"Content-Type: multipart/form-data; boundary=" + boundary,
		"Authorization: Bearer " + AiConfig.api_key(),
	])

	var http := HTTPRequest.new()
	http.timeout = AiConfig.timeout_seconds()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return {"ok": false, "text": "", "reason": "asr_unavailable",
				"message": "语音服务暂不可用"}
	tree.root.add_child(http)
	# request_raw: binary body (the WAV); plain request() is String-only.
	var err := http.request_raw(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "text": "", "reason": "asr_unavailable",
				"message": "语音服务暂不可用"}
	var parts: Array = await http.request_completed
	http.queue_free()

	var result: int = int(parts[0])
	var code: int = int(parts[1])
	var text_resp := (parts[3] as PackedByteArray).get_string_from_utf8()
	if result == HTTPRequest.RESULT_TIMEOUT:
		return {"ok": false, "text": "", "reason": "asr_timeout",
				"message": "识别超时，请再试一次"}
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "text": "", "reason": "asr_unavailable",
				"message": "语音服务暂不可用"}
	if code == 429:
		return {"ok": false, "text": "", "reason": "asr_rate_limited",
				"message": "语音服务繁忙，稍后再试"}
	if code < 200 or code >= 300:
		return {"ok": false, "text": "", "reason": "asr_unavailable",
				"message": "语音服务响应异常（HTTP %d）" % code}
	var parsed = JSON.parse_string(text_resp)
	if parsed == null or not parsed is Dictionary or not str(parsed.get("text", "")).strip_edges():
		return {"ok": false, "text": "", "reason": "asr_invalid_response",
				"message": "识别结果异常"}
	return {"ok": true, "text": str(parsed["text"]).strip_edges(),
			"reason": "ok", "message": ""}
