class_name ChatProvider
extends RefCounted
## OpenAI-compatible chat provider (AGENTS.md §8): the ONLY network
## seam of the magic engine. Pure service — returns text, never touches
## the scene tree beyond attaching its short-lived HTTPRequest node.
## Failure taxonomy per AGENTS.md §7.7: timeout / rate_limited /
## unavailable / invalid_response — every failure surfaces as a result
## dictionary, never a crash, and never blocks the caller indefinitely.
##
## The API key travels only in the Authorization header; it is never
## logged and never part of any error message.

## Test seam: when set, complete() bypasses HTTP entirely (offline
## suite coverage for the whole pipeline).
static var mock_complete: Callable = Callable()


## messages: [{"role": "system"|"user", "content": String}, ...].
## Returns {"ok": bool, "content": String, "reason": String, "message": String}.
static func complete(messages: Array, temperature := 0.2, max_tokens := 400) -> Dictionary:
	if mock_complete.is_valid():
		return mock_complete.call(messages, temperature)
	if not AiConfig.is_configured():
		return {"ok": false, "content": "", "reason": "ai_unconfigured",
				"message": "AI 未配置"}

	var url := AiConfig.chat_url()
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + AiConfig.api_key(),
	])
	var body := JSON.stringify({
		"model": AiConfig.chat_model(),
		"messages": messages,
		"temperature": temperature,
		"max_tokens": max_tokens,
	})

	var http := HTTPRequest.new()
	http.timeout = AiConfig.timeout_seconds()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return {"ok": false, "content": "", "reason": "ai_unavailable",
				"message": "AI 服务暂不可用"}
	tree.root.add_child(http)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "content": "", "reason": "ai_unavailable",
				"message": "AI 服务暂不可用"}
	var parts: Array = await http.request_completed
	http.queue_free()

	# parts = [result, response_code, response_headers, body_bytes]
	var result: int = int(parts[0])
	var code: int = int(parts[1])
	var text := (parts[3] as PackedByteArray).get_string_from_utf8()
	if result == HTTPRequest.RESULT_TIMEOUT:
		return {"ok": false, "content": "", "reason": "ai_timeout",
				"message": "咒语回声消散（AI 超时）"}
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "content": "", "reason": "ai_unavailable",
				"message": "AI 服务暂不可用"}
	if code == 429:
		return {"ok": false, "content": "", "reason": "ai_rate_limited",
				"message": "星界拥挤，稍后再试"}
	if code < 200 or code >= 300:
		return {"ok": false, "content": "", "reason": "ai_unavailable",
				"message": "AI 服务响应异常（HTTP %d）" % code}
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary or not parsed.has("choices"):
		return {"ok": false, "content": "", "reason": "ai_invalid_response",
				"message": "回响无法成形（AI 返回异常）"}
	var choices: Array = parsed["choices"]
	if choices.is_empty():
		return {"ok": false, "content": "", "reason": "ai_invalid_response",
				"message": "回响无法成形（AI 返回异常）"}
	var first: Dictionary = choices[0]
	var message: Dictionary = first.get("message", {})
	var content := str(message.get("content", ""))
	if content.strip_edges().is_empty():
		return {"ok": false, "content": "", "reason": "ai_invalid_response",
				"message": "回响无法成形（AI 返回异常）"}
	return {"ok": true, "content": content, "reason": "ok", "message": ""}
