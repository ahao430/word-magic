class_name MagicFacade
extends RefCounted
## Orchestrates the offline casting pipeline (AGENTS.md §7.1):
## normalize -> local registry -> validation -> balance -> duplicate
## detection -> factory -> executor. Cache layers and AI parsing attach
## between registry and validation in later phases; every producer
## feeds the SAME validation path, and cache hits still pass the
## session duplicate gate.
##
## Returns {"ok": bool, "reason": String, "message": String,
##          "spell": Dictionary, "cost": int}.


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
		if draft.is_empty():
			return fail.call("unknown", "「%s」尚未被语言之力理解（AI 解析后续开放）" % raw_text.strip_edges())

	var checked := SpellValidator.validate(draft)
	if not checked["valid"]:
		return fail.call("invalid", "咒语失稳：" + "；".join(checked["errors"]))

	# A fresh registry hit is remembered for future adventures; cache
	# hits are re-stored harmlessly (idempotent overwrite).
	SpellCache.store(raw_text, normalized, draft)

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
