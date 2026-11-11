class_name SpellParser
extends RefCounted
## AI spell parser (AGENTS.md §7.1/§7.2): turns a free-form incantation
## into a draft-spell Dictionary via the chat provider. The AI is a
## TRANSLATOR ONLY — its output is plain data that must survive the
## same SpellValidator whitelist/clamps as every other producer; it
## never executes, never touches scenes, and a failed parse is an
## infrastructure result (no mana, no record), not player punishment.

const ValidatorScript := preload("res://scripts/magic/spell_validator.gd")


## Coroutine (awaits the provider). Returns
## {"ok": bool, "reason": String, "message": String, "draft": Dictionary}.
static func parse(raw_text: String) -> Dictionary:
	var messages: Array = [
		{"role": "system", "content": _system_prompt()},
		{"role": "user", "content": raw_text.strip_edges()},
	]
	var resp: Dictionary = await ChatProvider.complete(messages)
	if not resp["ok"]:
		return {"ok": false, "reason": resp["reason"], "message": resp["message"],
				"draft": {}}
	var parsed := parse_response(str(resp["content"]))
	if not parsed["ok"]:
		return {"ok": false, "reason": "ai_invalid_response",
				"message": "回响无法成形（AI 返回异常）", "draft": {}}
	return {"ok": true, "reason": "ok", "message": "", "draft": parsed["draft"]}


## Pure: model text -> draft. Tolerates code fences and surrounding
## prose by extracting the outermost {...} block before parsing.
static func parse_response(content: String) -> Dictionary:
	var text := content.strip_edges()
	if text.begins_with("```"):
		# Strip a leading fence line and a trailing fence.
		var first_nl := text.find("\n")
		if first_nl != -1:
			text = text.substr(first_nl + 1)
		var fence_end := text.rfind("```")
		if fence_end != -1:
			text = text.substr(0, fence_end)
	var open := text.find("{")
	var close := text.rfind("}")
	if open == -1 or close == -1 or close <= open:
		return {"ok": false, "draft": {}}
	var parsed = JSON.parse_string(text.substr(open, close - open + 1))
	if parsed == null or not parsed is Dictionary:
		return {"ok": false, "draft": {}}
	var d: Dictionary = parsed
	var element := str(d.get("element", ""))
	var shape := str(d.get("shape", ""))
	if element == "" or shape == "":
		return {"ok": false, "draft": {}}
	var mechanics: Array = []
	for m in d.get("mechanics", []):
		mechanics.append(str(m))
	var params_in: Dictionary = d.get("parameters", {})
	var params := {
		"damage": float(params_in.get("damage", 0.0)),
		"radius": float(params_in.get("radius", 0.0)),
		"speed": float(params_in.get("speed", 0.0)),
		"duration": float(params_in.get("duration", 0.0)),
	}
	var draft := {
		"display": str(d.get("display", element)),
		"element": element,
		"shape": shape,
		"mechanics": mechanics,
		"parameters": params,
	}
	return {"ok": true, "draft": draft}


## Prompt built from the validator's own whitelists — one source of
## truth; the model can never learn an option the game would reject.
static func _system_prompt() -> String:
	return "你是一个咒语解析器。把用户的咒语翻译成一个 JSON 对象，只输出 JSON，不要任何其他文字。\n" \
			+ "字段要求：\n" \
			+ "- display: 字符串，咒语的中文短名\n" \
			+ "- element: 必须是以下之一 %s\n" \
			+ "- shape: 必须是以下之一 %s\n" \
			+ "- mechanics: 字符串数组，只能包含 %s\n" \
			+ "- parameters: 对象，含 damage(0-60), radius(0-160), speed(0-420), duration(0-5) 四个数字\n" \
			+ "数值按咒语语气估量，保持在给定范围内。" % [
				str(ValidatorScript.ELEMENTS),
				str(ValidatorScript.SHAPES),
				str(ValidatorScript.MECHANICS)]
