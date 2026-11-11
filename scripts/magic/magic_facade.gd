class_name MagicFacade
extends RefCounted
## Orchestrates the casting pipeline (AGENTS.md §7.1): normalize ->
## exact cache -> normalized cache -> local registry -> AI parser ->
## validation -> balance -> duplicate detection -> factory -> executor.
## Every producer feeds the SAME validation path; cache hits still pass
## the session duplicate gate. AI infra failures return before mana is
## charged and are never recorded (AGENTS.md §7.7).
##
## NOTE: cast() is a coroutine (the AI leg awaits the network) — all
## callers must `await` it. Local-only paths complete synchronously.
##
## Returns {"ok": bool, "reason": String, "message": String,
##          "spell": Dictionary, "cost": int, "source": String}.

# Preloads instead of global names: headless -s runs resolve new global
# classes through .godot's cache, which lags until an editor refresh.
const AiConfigScript := preload("res://scripts/ai/ai_config.gd")
const SpellParserScript := preload("res://scripts/ai/spell_parser.gd")
const EmbeddingProviderScript := preload("res://scripts/ai/embedding_provider.gd")


static func cast(raw_text: String, caster: Node, world: Node, session: SpellSession) -> Dictionary:
	var fail := func(reason: String, message: String) -> Dictionary:
		return {"ok": false, "reason": reason, "message": message, "spell": {}, "cost": 0,
				"source": ""}

	var normalized := TextNormalizer.normalize(raw_text)
	if normalized.is_empty():
		return fail.call("empty", "没有听到任何咒语")

	# Cache layers first (AGENTS.md §7.1 order): exact text, then the
	# normalized key. A hit skips lookup but NOT validation, balance,
	# the session duplicate gate, or mana — the cache is a convenience,
	# never an authority.
	var draft: Dictionary = SpellCache.lookup_exact(raw_text)
	var source := "cache_exact"
	if draft.is_empty():
		draft = SpellCache.lookup_normalized(normalized)
		source = "cache_normalized"
	if draft.is_empty():
		draft = LocalSpellRegistry.lookup(normalized)
		source = "registry"
	# Semantic layer (§7.1): a paraphrase of a previously parsed spell
	# resolves by vector similarity before the AI is bothered. Infra
	# failures here are a soft fallthrough — the AI leg still runs.
	var phrase_vec: Array = []
	if draft.is_empty() and AiConfigScript.is_embedding_configured():
		var embedded: Dictionary = await EmbeddingProviderScript.embed(normalized)
		if embedded["ok"]:
			phrase_vec = embedded["vector"]
			var near: Dictionary = SpellCache.lookup_semantic(phrase_vec)
			if not near.is_empty():
				draft = near["draft"]
				source = "cache_semantic"
	if draft.is_empty() and AiConfigScript.is_configured():
		# AI leg: free-form incantations the local table doesn't know.
		# Infra failures (timeout/rate limit/unavailable/garbage) fail
		# soft — no mana, no session record, retry stays possible.
		var ai: Dictionary = await SpellParserScript.parse(raw_text)
		if ai["ok"]:
			draft = ai["draft"]
			source = "ai"
		else:
			return fail.call(ai["reason"], ai["message"])
	if draft.is_empty():
		return fail.call("unknown", "「%s」尚未被语言之力理解（AI 未配置或未收录）" % raw_text.strip_edges())

	var checked := SpellValidator.validate(draft)
	if not checked["valid"]:
		return fail.call("invalid", "咒语失稳：" + "；".join(checked["errors"]))

	# A fresh registry/AI hit is remembered for future adventures; cache
	# hits are re-stored harmlessly (idempotent overwrite).
	SpellCache.store(raw_text, normalized, draft)
	# AI-parsed spells with a live embedding also enter the semantic
	# store (same vector the lookup used — one request per novel phrase).
	if source == "ai" and not phrase_vec.is_empty():
		SpellCache.store_semantic(raw_text, normalized, phrase_vec, draft)

	var cost: int = SpellBalance.compute_cost(checked["spell"])

	# Session uniqueness BEFORE mana is charged (AGENTS.md §7.5).
	var gate: Dictionary = session.check(raw_text, normalized, checked["spell"])
	if not gate["ok"]:
		var why := "同样的咒语本局已然失效"
		if gate["reason"] == "duplicate_mechanism":
			why = "同样的法术机制本局已然失效"
		return fail.call(gate["reason"], why)

	if caster.has_method("try_consume_mana") and not caster.call("try_consume_mana", float(cost)):
		return fail.call("no_mana", "魔力不足（需要 %d）" % cost)

	var spell: Dictionary = SpellFactory.build(checked["spell"], cost)
	var result: Dictionary = SpellExecutor.execute(spell, caster, world)
	if not result.get("ok", false):
		# Execution refused: refund the mana so the player is not taxed
		# for an unimplemented shape (infrastructure, not instability),
		# and do NOT record it — the spell never truly happened.
		if caster.has_method("refund_mana"):
			caster.call("refund_mana", float(cost))
		return {"ok": false, "reason": result.get("reason", "exec_failed"),
				"message": result.get("message", "施法失败"), "spell": spell, "cost": 0,
				"source": source}

	session.record(raw_text, normalized, spell)
	return {"ok": true, "reason": "ok", "message": result.get("message", ""),
			"spell": spell, "cost": cost, "source": source}
