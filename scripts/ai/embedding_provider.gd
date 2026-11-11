class_name EmbeddingProvider
extends RefCounted
## OpenAI-compatible embedding provider (AGENTS.md §8): turns a phrase
## into a float vector for the spell cache's semantic layer (§7.1).
## Same trust rules as the chat seam: a pure service returning result
## dictionaries — the caller (MagicFacade) treats every failure as a
## soft fallthrough, so casting works fully offline. The key lives only
## in the Authorization header.

## Test seam: when set, embed() bypasses HTTP entirely.
static var mock_embed: Callable = Callable()


## Returns {"ok": bool, "vector": Array, "reason": String, "message": String}.
static func embed(text: String) -> Dictionary:
	if mock_embed.is_valid():
		return mock_embed.call(text)
	if text.strip_edges().is_empty():
		return {"ok": false, "vector": [], "reason": "embedding_empty",
				"message": "空短语无需向量"}
	if not AiConfig.is_embedding_configured():
		return {"ok": false, "vector": [], "reason": "embedding_unconfigured",
				"message": "语义缓存未配置（config/ai.json 的 embedding_model）"}

	var url := AiConfig.embedding_url()
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + AiConfig.api_key(),
	])
	var body := JSON.stringify({"model": AiConfig.embedding_model(), "input": text})

	var http := HTTPRequest.new()
	http.timeout = AiConfig.timeout_seconds()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return {"ok": false, "vector": [], "reason": "embedding_unavailable",
				"message": "语义服务暂不可用"}
	tree.root.add_child(http)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "vector": [], "reason": "embedding_unavailable",
				"message": "语义服务暂不可用"}
	var parts: Array = await http.request_completed
	http.queue_free()

	# parts = [result, response_code, response_headers, body_bytes]
	var result: int = int(parts[0])
	var code: int = int(parts[1])
	var text_resp := (parts[3] as PackedByteArray).get_string_from_utf8()
	if result == HTTPRequest.RESULT_TIMEOUT:
		return {"ok": false, "vector": [], "reason": "embedding_timeout",
				"message": "语义比对超时"}
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "vector": [], "reason": "embedding_unavailable",
				"message": "语义服务暂不可用"}
	if code == 429:
		return {"ok": false, "vector": [], "reason": "embedding_rate_limited",
				"message": "语义服务繁忙，稍后再试"}
	if code < 200 or code >= 300:
		return {"ok": false, "vector": [], "reason": "embedding_unavailable",
				"message": "语义服务响应异常（HTTP %d）" % code}
	var parsed = JSON.parse_string(text_resp)
	if parsed == null or not parsed is Dictionary or not parsed.has("data"):
		return {"ok": false, "vector": [], "reason": "embedding_invalid_response",
				"message": "语义向量异常"}
	var data: Array = parsed["data"]
	if data.is_empty() or not data[0] is Dictionary:
		return {"ok": false, "vector": [], "reason": "embedding_invalid_response",
				"message": "语义向量异常"}
	var raw_vec = data[0].get("embedding", null)
	if raw_vec == null or not raw_vec is Array or raw_vec.is_empty():
		return {"ok": false, "vector": [], "reason": "embedding_invalid_response",
				"message": "语义向量异常"}
	var vector: Array = []
	for v in raw_vec:
		vector.append(float(v))
	return {"ok": true, "vector": vector, "reason": "ok", "message": ""}
