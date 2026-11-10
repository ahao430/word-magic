class_name SpellSession
extends RefCounted
## Per-adventure spell state (AGENTS.md §7.5 / PLAN.md §2.6):
## - duplicate detection: exact text, normalized text and mechanism
##   signature (semantic/embedding similarity attaches with the AI
##   provider phase; documented stub below)
## - the spell codex: every SUCCESSFUL cast this adventure
## A session lives with the adventure — main owns one, tests make
## fresh ones per scenario.


## Codex rows: {"raw", "display", "element", "shape", "mechanics", "cost"}.
var codex: Array[Dictionary] = []

var _exact_texts := {}      # raw text as submitted
var _normalized_texts := {} # normalized text
var _signatures := {}       # mechanism signature


## Gate before mana is charged. Returns {"ok": bool, "reason": String}.
func check(raw_text: String, normalized: String, spell: Dictionary) -> Dictionary:
	if _exact_texts.has(raw_text):
		return {"ok": false, "reason": "duplicate_exact"}
	if _normalized_texts.has(normalized):
		return {"ok": false, "reason": "duplicate_normalized"}
	var sig := mechanism_signature(spell)
	if _signatures.has(sig):
		return {"ok": false, "reason": "duplicate_mechanism"}
	return {"ok": true, "reason": ""}


## Record a successful cast (called by the facade after execution).
func record(raw_text: String, normalized: String, spell: Dictionary) -> void:
	_exact_texts[raw_text] = true
	_normalized_texts[normalized] = true
	_signatures[mechanism_signature(spell)] = true
	codex.append({
		"raw": raw_text,
		"display": spell.get("display", "?"),
		"element": spell.get("element", "?"),
		"shape": spell.get("shape", "?"),
		"mechanics": spell.get("mechanics", []),
		"cost": spell.get("cost", 0),
	})


## Mechanism signature: element + shape + sorted mechanics + bucketed
## parameters. Close-but-different names with identical mechanics
## (火球术 vs 火球) collide; genuinely different spells do not.
## Semantic similarity (embeddings) joins here later as a fourth check.
static func mechanism_signature(spell: Dictionary) -> String:
	var p: Dictionary = spell.get("parameters", {})
	var mechanics: Array = spell.get("mechanics", [])
	var sorted_mechanics := []
	for m in mechanics:
		sorted_mechanics.append(str(m))
	sorted_mechanics.sort()
	return "%s|%s|%s|%d|%d|%d|%d" % [
		spell.get("element", "?"),
		spell.get("shape", "?"),
		",".join(sorted_mechanics),
		int(p.get("damage", 0.0) / 5.0),
		int(p.get("radius", 0.0) / 16.0),
		int(p.get("duration", 0.0)),
		int(p.get("speed", 0.0) / 60.0),
	]
