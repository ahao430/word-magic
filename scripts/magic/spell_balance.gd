class_name SpellBalance
extends RefCounted
## Balance calculator (AGENTS.md §7.6): mana cost is ALWAYS computed by
## the game from validated parameters. Costs target PLAN.md §2.4 bands
## (simple 10-20, medium 25-40); the AI/parser side can never set it.


static func compute_cost(spell: Dictionary) -> int:
	var p: Dictionary = spell["parameters"]
	var cost := 8.0
	cost += p.get("damage", 0.0) * 0.4
	if p.get("radius", 0.0) > 16.0:
		cost += p.get("radius", 0.0) * 0.05
	cost += p.get("duration", 0.0) * 2.0
	if p.get("speed", 0.0) > 300.0:
		cost += 4.0
	return int(round(cost))
