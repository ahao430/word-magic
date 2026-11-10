class_name MagicFacade
extends RefCounted
## Orchestrates the offline casting pipeline (AGENTS.md §7.1):
## normalize -> local registry -> validation -> balance -> factory ->
## executor. Cache layers, AI parsing and duplicate detection attach
## between registry and validation in later phases; every producer
## feeds the SAME validation path.
##
## Returns {"ok": bool, "reason": String, "message": String,
##          "spell": Dictionary, "cost": int}.


static func cast(raw_text: String, caster: Node, world: Node) -> Dictionary:
	var fail := func(reason: String, message: String) -> Dictionary:
		return {"ok": false, "reason": reason, "message": message, "spell": {}, "cost": 0}

	var normalized := TextNormalizer.normalize(raw_text)
	if normalized.is_empty():
		return fail.call("empty", "没有听到任何咒语")

	var draft: Dictionary = LocalSpellRegistry.lookup(normalized)
	if draft.is_empty():
		return fail.call("unknown", "「%s」尚未被语言之力理解（AI 解析后续开放）" % raw_text.strip_edges())

	var checked := SpellValidator.validate(draft)
	if not checked["valid"]:
		return fail.call("invalid", "咒语失稳：" + "；".join(checked["errors"]))

	var cost: int = SpellBalance.compute_cost(checked["spell"])
	if caster.has_method("try_consume_mana") and not caster.call("try_consume_mana", float(cost)):
		return fail.call("no_mana", "魔力不足（需要 %d）" % cost)

	var spell: Dictionary = SpellFactory.build(checked["spell"], cost)
	var result: Dictionary = SpellExecutor.execute(spell, caster, world)
	if not result.get("ok", false):
		# Execution refused: refund the mana so the player is not taxed
		# for an unimplemented shape (infrastructure, not instability).
		if caster.has_method("refund_mana"):
			caster.call("refund_mana", float(cost))
		return {"ok": false, "reason": result.get("reason", "exec_failed"),
				"message": result.get("message", "施法失败"), "spell": spell, "cost": 0}

	return {"ok": true, "reason": "ok", "message": result.get("message", ""),
			"spell": spell, "cost": cost}
