class_name LocalSpellRegistry
extends RefCounted
## Local spell rules (AGENTS.md §7.1): a curated idiom -> draft-spell
## table so basic casting works fully offline. Draft parameters are
## SUGGESTIONS ONLY — the validator clamps them and the balance module
## computes the real cost; nothing here is trusted at execution time.
## AI parsing (when added) fills the same draft shape and passes
## through the same validation path.

# Element colors are owned by the executor, not the registry.
const DRAFTS := {
	"烈焰焚天": {
		"display": "烈焰焚天", "element": "fire", "shape": "explosion",
		"mechanics": ["damage"],
		"parameters": {"damage": 40, "radius": 120, "speed": 0, "duration": 0.0},
	},
	"火球术": {
		"display": "火球术", "element": "fire", "shape": "projectile",
		"mechanics": ["damage"],
		"parameters": {"damage": 20, "radius": 8, "speed": 300, "duration": 2.0},
	},
	"火球": {
		"display": "火球", "element": "fire", "shape": "projectile",
		"mechanics": ["damage"],
		"parameters": {"damage": 22, "radius": 8, "speed": 300, "duration": 2.0},
	},
	"寒冰箭": {
		"display": "寒冰箭", "element": "ice", "shape": "projectile",
		"mechanics": ["damage", "slow"],
		"parameters": {"damage": 16, "radius": 8, "speed": 260, "duration": 2.0},
	},
	"冰封千里": {
		"display": "冰封千里", "element": "ice", "shape": "field",
		"mechanics": ["damage", "freeze"],
		"parameters": {"damage": 12, "radius": 140, "speed": 0, "duration": 3.0},
	},
	"落雷": {
		"display": "落雷", "element": "lightning", "shape": "projectile",
		"mechanics": ["damage"],
		"parameters": {"damage": 30, "radius": 6, "speed": 420, "duration": 1.5},
	},
	"风卷残云": {
		"display": "风卷残云", "element": "wind", "shape": "tornado",
		"mechanics": ["damage", "knockback"],
		"parameters": {"damage": 10, "radius": 90, "speed": 0, "duration": 4.0},
	},
}


static func lookup(normalized_text: String) -> Dictionary:
	return DRAFTS.get(normalized_text, {})
