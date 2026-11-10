class_name SpellFactory
extends RefCounted
## Spell factory (AGENTS.md §7.1): turns a validated draft + game-side
## cost into the runtime spell object handed to the executor. The
## runtime spell is plain data — never executable code.


static func build(validated_spell: Dictionary, cost: int) -> Dictionary:
	var spell := validated_spell.duplicate(true)
	spell["cost"] = cost
	return spell
