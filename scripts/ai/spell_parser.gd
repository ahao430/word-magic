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
	# 1024-token budget: reasoning models spend a large share of the
	# window thinking before the JSON lands.
	var resp: Dictionary = await ChatProvider.complete(messages, 0.2, 1024)
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
	return "你是咒语解析器，把用户的咒语转成一个 JSON 对象。只输出 JSON 本身，不要解释、不要围栏标记。\n" \
			+ "硬性规则：\n" \
			+ "- display: 字符串，咒语的中文短名\n" \
			+ "- element: 必须原样使用以下英文单词之一，禁止翻译成中文: " + str(ValidatorScript.ELEMENTS) + "\n" \
			+ "- shape: 必须原样使用以下英文单词之一，禁止翻译成中文: " + str(ValidatorScript.SHAPES) + "\n" \
			+ "- mechanics: 字符串数组，只能包含: " + str(ValidatorScript.MECHANICS) + "（可以为空数组）\n" \
			+ "- parameters: 四个数字 damage(0-60), radius(0-160), speed(0-420), duration(0-5)\n" \
			+ "\n" \
			+ "示例输入：给我来发大火球\n" \
			+ "示例输出：{\"display\":\"大火球\",\"element\":\"fire\",\"shape\":\"projectile\",\"mechanics\":[\"damage\"],\"parameters\":{\"damage\":30,\"radius\":10,\"speed\":300,\"duration\":2}}\n" \
			+ "\n" \
			+ "现在解析用户的咒语，只输出 JSON。"