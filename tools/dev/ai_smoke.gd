extends SceneTree
## Dev-only REAL-network smoke for the AI caster leg. Reads the local
## config/ai.json, casts three free-form incantations through the full
## pipeline, then probes one infrastructure path (dead URL) to confirm
## the soft-failure rules against a live socket. user:// files are
## stashed/restored so the dev machine stays clean.
##
##   godot --headless --path . -s res://tools/dev/ai_smoke.gd

const MAGIC := preload("res://scripts/magic/magic_facade.gd")

const PHRASES := ["烈焰风暴", "冰霜新星", "雷暴之环"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cache_b := TestIsolation.stash(TestIsolation.CACHE_PATH)
	var mem_b := TestIsolation.stash(TestIsolation.MEMORY_PATH)
	SpellCache.reset()
	WorldMemory.reset()

	if not AiConfig.is_configured():
		print("[smoke] AI 未配置：复制 config/ai.example.json 为 ai.json 并填写")
		_finish(cache_b, mem_b)
		return
	print("[smoke] model=", AiConfig.chat_model(), " url=", AiConfig.chat_url())

	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	var player: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(500, 300)
	world.get_entity_parent().add_child(player)
	await physics_frame
	await physics_frame

	var failures := 0
	for phrase in PHRASES:
		player.mana = 100.0
		var session := SpellSession.new()
		var r: Dictionary = await MAGIC.cast(phrase, player, world, session)
		if r["ok"]:
			var sp: Dictionary = r["spell"]
			print("[smoke] PASS %s -> %s · %s/%s · dmg=%.0f cost=%d" % [phrase,
					sp.get("display", "?"), sp.get("element", "?"), sp.get("shape", "?"),
					float(sp.get("parameters", {}).get("damage", 0.0)), int(r["cost"])])
		else:
			failures += 1
			print("[smoke] FAIL %s -> reason=%s msg=%s" % [phrase, r["reason"], r["message"]])

	# Cache hit check: a variant of phrase 1 must skip the network.
	player.mana = 100.0
	var r_var: Dictionary = await MAGIC.cast(PHRASES[0] + "！", player, world, SpellSession.new())
	if r_var["ok"] and r_var["source"] in ["cache_exact", "cache_normalized"]:
		print("[smoke] PASS variant phrase served from cache (%s)" % r_var["source"])
	else:
		failures += 1
		print("[smoke] FAIL variant phrase: %s" % str(r_var["reason"]))

	# Infrastructure path: dead URL must soft-fail without mana loss.
	AiConfig.apply_config({"base_url": "http://127.0.0.1:1", "api_key": "magpie",
			"chat_model": "x", "request_timeout_seconds": 4})
	var mana_before: float = player.mana
	var r_dead: Dictionary = await MAGIC.cast("无人知晓的咒语", player, world, SpellSession.new())
	if not r_dead["ok"] and r_dead["reason"].begins_with("ai_") \
			and absf(player.mana - mana_before) < 0.001:
		print("[smoke] PASS dead-url soft failure (%s), mana kept" % r_dead["reason"])
	else:
		failures += 1
		print("[smoke] FAIL dead-url path: ok=%s reason=%s mana %.1f->%.1f" % [r_dead["ok"],
				r_dead["reason"], mana_before, player.mana])
	AiConfig.apply_config({})

	world.free()
	print("[smoke] result: %s (%d failures)" % ["ALL PASS" if failures == 0 else "FAILURES", failures])
	_finish(cache_b, mem_b)


func _finish(cache_b: String, mem_b: String) -> void:
	TestIsolation.unstash(TestIsolation.CACHE_PATH, cache_b)
	TestIsolation.unstash(TestIsolation.MEMORY_PATH, mem_b)
	SpellCache.reset()
	WorldMemory.reset()
	AiConfig.apply_config({})
	quit(0 if true else 1)
