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
		"parameters": {"damage": 8, "radius": 140, "speed": 0, "duration": 2.5},
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
	"烈光贯日": {
		"display": "烈光贯日", "element": "lightning", "shape": "beam",
		"mechanics": ["damage"],
		"parameters": {"damage": 18, "radius": 80, "speed": 0, "duration": 1.2},
	},
	"大地脉动": {
		"display": "大地脉动", "element": "nature", "shape": "area",
		"mechanics": ["damage", "knockback"],
		"parameters": {"damage": 18, "radius": 100, "speed": 0, "duration": 0.0},
	},
	"守护之壁": {
		"display": "守护之壁", "element": "nature", "shape": "shield",
		"mechanics": [],
		"parameters": {"damage": 0, "radius": 0, "speed": 0, "duration": 3.0},
	},
	"唤灵术": {
		"display": "唤灵术", "element": "nature", "shape": "summon",
		"mechanics": ["damage"],
		"parameters": {"damage": 8, "radius": 90, "speed": 0, "duration": 4.0},
	},
	"沼泽缠绕": {
		"display": "沼泽缠绕", "element": "water", "shape": "field",
		"mechanics": ["damage", "freeze"],
		"parameters": {"damage": 10, "radius": 110, "speed": 0, "duration": 2.0},
	},
	"激流冲击": {
		"display": "激流冲击", "element": "water", "shape": "projectile",
		"mechanics": ["damage", "knockback"],
		"parameters": {"damage": 14, "radius": 8, "speed": 340, "duration": 1.5},
	},
}


## Quest-taught idioms: hidden until their world-memory event fires
## (AGENTS §7.1 keeps them in the SAME local-rules layer — they pass
## the identical validation/balance path once unlocked).
## "event" mirrors WorldMemory.EVENT_QUEST_DONE ("quest_swamp_heart_done"):
## the keeper teaches 「激流贯射」 when the swamp heart is returned.
const UNLOCKABLE := {
	"激流贯射": {
		"event": "quest_swamp_heart_done",
		"draft": {
			"display": "激流贯射", "element": "water", "shape": "beam",
			"mechanics": ["damage"],
			"parameters": {"damage": 12, "radius": 80, "speed": 0, "duration": 1.2},
		},
	},
}


static func lookup(normalized_text: String) -> Dictionary:
	var draft: Dictionary = DRAFTS.get(normalized_text, {})
	if not draft.is_empty():
		return draft
	var gated: Dictionary = UNLOCKABLE.get(normalized_text, {})
	if not gated.is_empty() and WorldMemory.has_event(str(gated.get("event", ""))):
		return (gated["draft"] as Dictionary).duplicate(true)
	return {}


## Registry view including unlocked idioms (diagnostics/tests).
static func known_drafts() -> Array:
	var all: Array = DRAFTS.values()
	for key in UNLOCKABLE:
		var gated: Dictionary = UNLOCKABLE[key]
		if WorldMemory.has_event(str(gated.get("event", ""))):
			all.append((gated["draft"] as Dictionary).duplicate(true))
	return all
