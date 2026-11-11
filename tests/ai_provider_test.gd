extends SceneTree
## Headless test for the AI provider layer — fully offline via the
## ChatProvider mock seam: config file semantics + gitignore, URL
## joining, response parsing (fences/prose/garbage), the facade's AI
## leg (source "ai", clamping, caching, session gate) and the soft
## failure rules for infrastructure errors (no mana, no record).
##
##   godot --headless --path . -s res://tests/ai_provider_test.gd

var _ai_backup := {}
var _failures := 0
var _cache_backup := ""
var _memory_backup := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_ai_backup = AiConfig.capture_config()
	AiConfig.apply_config({})
	_cache_backup = TestIsolation.stash(TestIsolation.CACHE_PATH)
	_memory_backup = TestIsolation.stash(TestIsolation.MEMORY_PATH)
	SpellCache.reset()
	WorldMemory.reset()

	# --- Config: file load, placeholders, gitignore ---
	AiConfig.apply_config({})
	_expect(not AiConfig.is_configured(), "empty config = AI off")
	AiConfig.load_from("res://tests/fixtures/ai_fixture.json")
	_expect(AiConfig.is_configured(), "fixture config enables AI")
	_expect(AiConfig.chat_url() == "https://fake.api.local/v1/chat/completions",
			"url joins without double slash")
	AiConfig.apply_config({"base_url": "https://x.example/v1/", "api_key": "k",
			"chat_model": "m"})
	_expect(AiConfig.chat_url() == "https://x.example/v1/chat/completions",
			"trailing slash normalized")
	AiConfig.apply_config({"base_url": "https://api.example.com/v1",
			"api_key": "在此填入你的 API Key", "chat_model": "m"})
	_expect(not AiConfig.is_configured(), "placeholder key does not enable AI")
	var gitignore := FileAccess.open("res://.gitignore", FileAccess.READ).get_as_text()
	_expect(gitignore.contains("config/ai.json"), "real config file is gitignored")
	AiConfig.apply_config({})

	# --- SpellParser.parse_response: pure text -> draft ---
	var ok1: Dictionary = SpellParser.parse_response(
			'{"display":"星火","element":"fire","shape":"projectile",'
			+ '"mechanics":["damage"],"parameters":{"damage":10,"radius":8,'
			+ '"speed":300,"duration":2}}')
	_expect(ok1["ok"] and ok1["draft"]["element"] == "fire", "plain JSON parses")
	var ok2: Dictionary = SpellParser.parse_response(
			"```json\n{\"display\":\"霜刃\",\"element\":\"ice\",\"shape\":\"projectile\","
			+ "\"mechanics\":[\"damage\"],\"parameters\":{}}\n```")
	_expect(ok2["ok"] and ok2["draft"]["display"] == "霜刃", "fenced JSON parses")
	var ok3: Dictionary = SpellParser.parse_response(
			"好的，结果如下：{\"display\":\"风蚀\",\"element\":\"wind\",\"shape\":\"beam\","
			+ "\"mechanics\":[],\"parameters\":{\"damage\":5}} 以上。")
	_expect(ok3["ok"], "prose-wrapped JSON extracted")
	_expect(not SpellParser.parse_response("完全不是 JSON")["ok"], "garbage refused")
	_expect(not SpellParser.parse_response('{"element":"fire"}')["ok"],
			"missing shape refused")

	# --- Facade AI leg via the mock seam (no network) ---
	AiConfig.apply_config({"base_url": "https://fake.local/v1", "api_key": "k",
			"chat_model": "m"})
	var ai_draft := '{"display":"烈焰风暴","element":"fire","shape":"explosion",' + '"mechanics":["damage"],"parameters":{"damage":9999,"radius":120,' + '"speed":0,"duration":0.5}}'
	var mock_ok: Dictionary = {"ok": true, "content": ai_draft, "reason": "ok", "message": ""}
	ChatProvider.mock_complete = func(_m, _t) -> Dictionary: return mock_ok

	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	var player: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(500, 300)
	world.get_entity_parent().add_child(player)
	await physics_frame
	await physics_frame

	var session := SpellSession.new()
	var r1: Dictionary = await MagicFacade.cast("烈焰风暴", player, world, session)
	_expect(r1["ok"] and r1["source"] == "ai", "free incantation casts via AI (%s)" % r1["source"])
	_expect(float(r1["spell"]["parameters"]["damage"]) == 60.0,
			"AI damage clamped to the ceiling (%.0f)" % float(r1["spell"]["parameters"]["damage"]))
	_expect(float(player.mana) < 100.0, "AI cast charges mana")

	# The AI draft is cached: a variant phrase skips the network.
	var calls := {"n": 0}
	var counter := func(_m, _t) -> Dictionary:
		calls["n"] = int(calls["n"]) + 1
		return {"ok": true, "content": ai_draft, "reason": "ok", "message": ""}
	ChatProvider.mock_complete = counter
	var session2 := SpellSession.new()
	var r2: Dictionary = await MagicFacade.cast("烈焰风暴！！", player, world, session2)
	_expect(r2["ok"] and r2["source"] == "cache_normalized" and int(calls["n"]) == 0,
			"AI result cached; variant hits cache without a call")

	# Same session repeat: duplicate gate still applies to AI spells.
	var r3: Dictionary = await MagicFacade.cast("烈焰风暴", player, world, session)
	_expect(not r3["ok"] and r3["reason"].begins_with("duplicate"),
			"AI spell obeys session uniqueness (%s)" % r3["reason"])

	# --- Infra failures are soft: no mana, no record, retry works ---
	var mana_before: float = player.mana
	var session3 := SpellSession.new()
	ChatProvider.mock_complete = func(_m, _t): return {"ok": false, "content": "",
			"reason": "ai_timeout", "message": "咒语回声消散（AI 超时）"}
	var r4: Dictionary = await MagicFacade.cast("未知的雷暴", player, world, session3)
	_expect(not r4["ok"] and r4["reason"] == "ai_timeout", "timeout surfaces as its own reason")
	_expect(absf(player.mana - mana_before) < 0.001, "infra failure charges no mana")
	_expect(session3.codex.is_empty(), "infra failure records nothing")
	ChatProvider.mock_complete = func(_m, _t): return {"ok": true, "content":
			'{"display":"雷暴","element":"lightning","shape":"explosion","mechanics":["damage"],"parameters":{"damage":30}}',
			"reason": "ok", "message": ""}
	var r5: Dictionary = await MagicFacade.cast("未知的雷暴", player, world, session3)
	_expect(r5["ok"] and r5["source"] == "ai",
			"same phrase succeeds after the infra failure (no punishment)")

	# --- Unconfigured: unknown phrases stay local-unknown ---
	AiConfig.apply_config({})
	var r6: Dictionary = await MagicFacade.cast("完全未知的词", player, world, session3)
	_expect(not r6["ok"] and r6["reason"] == "unknown", "AI off keeps the local fallback")
	# Registered spells never touch the provider.
	var provider_hit := {"n": 0}
	var hit_counter := func(_m, _t) -> Dictionary:
		provider_hit["n"] = int(provider_hit["n"]) + 1
		return {"ok": true, "content": ai_draft, "reason": "ok", "message": ""}
	ChatProvider.mock_complete = hit_counter
	AiConfig.apply_config({"base_url": "https://fake.local/v1", "api_key": "k",
			"chat_model": "m"})
	player.mana = 100.0
	var session4 := SpellSession.new()
	var r7: Dictionary = await MagicFacade.cast("火球术", player, world, session4)
	_expect(r7["ok"] and r7["source"] == "registry" and int(provider_hit["n"]) == 0,
			"registered spells skip the network entirely")

	# --- Semantic layer: config gating + provider seam + facade wiring ---
	AiConfig.apply_config({"base_url": "https://fake.local/v1", "api_key": "k",
			"chat_model": "m", "embedding_model": "e"})
	_expect(AiConfig.is_embedding_configured()
			and AiConfig.embedding_url() == "https://fake.local/v1/embeddings",
			"embedding model gates the semantic layer on")
	AiConfig.apply_config({"base_url": "https://x.example/v1", "api_key": "k",
			"chat_model": "m", "embedding_model": "在此填入"})
	_expect(not AiConfig.is_embedding_configured(),
			"placeholder embedding model keeps it off")
	AiConfig.apply_config({})
	var e0: Dictionary = await EmbeddingProvider.embed("x")
	_expect(e0["reason"] == "embedding_unconfigured",
			"unconfigured embedding refuses softly")
	AiConfig.apply_config({"base_url": "https://fake.local/v1", "api_key": "k",
			"chat_model": "m", "embedding_model": "e"})
	var e1: Dictionary = await EmbeddingProvider.embed("  ")
	_expect(e1["reason"] == "embedding_empty", "blank phrases never embed")
	EmbeddingProvider.mock_embed = func(_t): return {"ok": true, "vector": [1.0, 0.0],
			"reason": "ok", "message": ""}
	var e2: Dictionary = await EmbeddingProvider.embed("abc")
	_expect(e2["ok"] and e2["vector"] == [1.0, 0.0], "mock seam passes vectors through")
	EmbeddingProvider.mock_embed = func(_t): return {"ok": false, "vector": [],
			"reason": "embedding_timeout", "message": "语义比对超时"}
	_expect((await EmbeddingProvider.embed("abc"))["reason"] == "embedding_timeout",
			"embedding timeout taxonomy passes through")

	# Facade: an AI hit stores its vector; a paraphrase then resolves
	# from the semantic cache without another chat call.
	var probe := {"display": "玄冰穿心刺", "element": "ice", "shape": "projectile",
			"mechanics": ["damage"], "parameters": {"damage": 25.0, "speed": 300.0}}
	var probe_json := JSON.stringify(probe)
	EmbeddingProvider.mock_embed = func(_t): return {"ok": true, "vector": [1.0, 0.0],
			"reason": "ok", "message": ""}
	var chat_calls := {"n": 0}
	ChatProvider.mock_complete = func(_m, _t) -> Dictionary:
		chat_calls["n"] = int(chat_calls["n"]) + 1
		return {"ok": true, "content": probe_json, "reason": "ok", "message": ""}
	player.mana = 100.0
	var q1: Dictionary = await MagicFacade.cast("玄冰穿心刺", player, world, SpellSession.new())
	_expect(q1["ok"] and q1["source"] == "ai", "novel phrase parses via AI (%s)" % q1["source"])
	var q2: Dictionary = await MagicFacade.cast("给我来一发玄冰穿心刺", player, world, SpellSession.new())
	_expect(q2["ok"] and q2["source"] == "cache_semantic" and int(chat_calls["n"]) == 1,
			"paraphrase hits the semantic cache (source=%s, chat=%d)"
					% [q2["source"], chat_calls["n"]])
	var q3: Dictionary = await MagicFacade.cast("再来一次玄冰穿心刺", player, world, SpellSession.new())
	_expect(q3["ok"] and q3["source"] == "cache_semantic",
			"semantic reuse is per-phrase, not one-shot")

	# Embedding infra failure mid-lookup: soft fallthrough to the AI.
	EmbeddingProvider.mock_embed = func(_t): return {"ok": false, "vector": [],
			"reason": "embedding_unavailable", "message": "语义服务暂不可用"}
	player.mana = 100.0
	var q4: Dictionary = await MagicFacade.cast("寒光利刃", player, world, SpellSession.new())
	_expect(q4["ok"] and q4["source"] == "ai",
			"embedding failure falls through to the AI (%s)" % q4["source"])

	# Embedding off: paraphrases re-parse (no semantic store happens).
	EmbeddingProvider.mock_embed = Callable()
	AiConfig.apply_config({"base_url": "https://fake.local/v1", "api_key": "k",
			"chat_model": "m"})
	player.mana = 100.0
	var q5: Dictionary = await MagicFacade.cast("烈焰回旋", player, world, SpellSession.new())
	_expect(q5["ok"] and q5["source"] == "ai", "AI works with embeddings off")
	var calls_before: int = int(chat_calls["n"])
	var q6: Dictionary = await MagicFacade.cast("烈焰回旋哈", player, world, SpellSession.new())
	_expect(q6["ok"] and q6["source"] == "ai" and int(chat_calls["n"]) == calls_before + 1,
			"without embeddings paraphrases re-parse (source=%s)" % q6["source"])

	# Teardown.
	ChatProvider.mock_complete = Callable()
	EmbeddingProvider.mock_embed = Callable()
	AiConfig.apply_config({})
	world.free()

	TestIsolation.unstash(TestIsolation.CACHE_PATH, _cache_backup)
	TestIsolation.unstash(TestIsolation.MEMORY_PATH, _memory_backup)
	SpellCache.reset()
	WorldMemory.reset()
	AiConfig.apply_config(_ai_backup)
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
