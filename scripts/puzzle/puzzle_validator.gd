class_name PuzzleValidator
extends RefCounted
## Rule-based puzzle validation (AGENTS.md §10.2): puzzles declare
## their own rules (elements, shapes, mechanics, min strength); the
## GAME decides whether a validated spell satisfies them. No AI ever
## declares puzzle success.
##
## Rules dictionary:
##   {"elements": [...], "shapes": [...], "mechanics": [...]}
## Each list is optional; an empty/missing list matches anything.
## A spell satisfies the puzzle when it matches EVERY declared list.


static func evaluate(rules: Dictionary, spell: Dictionary) -> Dictionary:
	if not _matches(rules.get("elements", []), spell.get("element", "")):
		return {"ok": false, "reason": "element"}
	if not _matches(rules.get("shapes", []), spell.get("shape", "")):
		return {"ok": false, "reason": "shape"}
	for m in spell.get("mechanics", []):
		if rules.get("mechanics", []).has(m):
			return {"ok": true, "reason": "mechanics"}
	if not rules.get("mechanics", []).is_empty():
		return {"ok": false, "reason": "mechanics"}
	return {"ok": true, "reason": ""}


static func _matches(allowed: Array, value: String) -> bool:
	return allowed.is_empty() or allowed.has(value)
