class_name SpellValidator
extends RefCounted
## Schema + skill validation (AGENTS.md §7.1/§7.4): every draft spell,
## whether from the local registry or a future AI parser, passes
## through here. Unknown elements/shapes/mechanics and out-of-bounds
## numbers are rejected; parameters are clamped in place to the caps.

const SCHEMA_VERSION := "1.0"

const ELEMENTS := ["fire", "ice", "lightning", "nature", "wind", "water"]
const SHAPES := ["projectile", "area", "beam", "field", "tornado", "shield", "summon", "explosion"]
const MECHANICS := ["damage", "slow", "freeze", "knockback"]

const MAX_DAMAGE := 60.0
const MAX_RADIUS := 160.0
const MAX_DURATION := 5.0
const MAX_SPEED := 420.0


## Returns {"valid": bool, "errors": [String], "spell": Dictionary}.
## "spell" is the clamped draft when valid, empty when not.
static func validate(draft: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if draft.get("schema_version", SCHEMA_VERSION) != SCHEMA_VERSION:
		errors.append("unsupported schema version")
	var element: String = draft.get("element", "")
	if not ELEMENTS.has(element):
		errors.append("unsupported element: " + element)
	var shape: String = draft.get("shape", "")
	if not SHAPES.has(shape):
		errors.append("unsupported shape: " + shape)
	for m in draft.get("mechanics", []):
		if not MECHANICS.has(m):
			errors.append("unsupported mechanic: " + str(m))

	var params: Dictionary = draft.get("parameters", {})
	var clamped := {
		"damage": clampf(params.get("damage", 0.0), 0.0, MAX_DAMAGE),
		"radius": clampf(params.get("radius", 0.0), 0.0, MAX_RADIUS),
		"speed": clampf(params.get("speed", 0.0), 0.0, MAX_SPEED),
		"duration": clampf(params.get("duration", 0.0), 0.0, MAX_DURATION),
	}

	if errors.is_empty():
		var spell := draft.duplicate(true)
		spell["schema_version"] = SCHEMA_VERSION
		spell["parameters"] = clamped
		return {"valid": true, "errors": errors, "spell": spell}
	return {"valid": false, "errors": errors, "spell": {}}
