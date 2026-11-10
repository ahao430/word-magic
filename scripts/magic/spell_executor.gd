class_name SpellExecutor
extends RefCounted
## Spell executor (AGENTS.md §7.1): the ONLY module that turns spell
## data into scene nodes. Godot owns all gameplay execution — the
## pipeline upstream produces validated data, never code.
## Currently implemented shapes: projectile. Other whitelist shapes
## fail gracefully with a "not yet unlocked" message.

# Preload instead of the Projectile global class: headless -s runs
# resolve globals through .godot's class cache, which lags behind new
# classes until an editor session refreshes it.
const ProjectileScript := preload("res://scripts/effects/projectile.gd")


static func execute(spell: Dictionary, caster: Node2D, world: Node2D) -> Dictionary:
	match spell["shape"]:
		"projectile":
			return _execute_projectile(spell, caster, world)
		_:
			return {"ok": false, "reason": "not_unlocked",
					"message": "「%s」的形态尚未觉醒" % spell.get("display", spell["shape"])}


static func _execute_projectile(spell: Dictionary, caster: Node2D, world: Node2D) -> Dictionary:
	var direction := Vector2.RIGHT
	if caster.has_method("get_facing_vector"):
		direction = caster.call("get_facing_vector")
	var parent := world
	if world.has_method("get_entity_parent"):
		parent = world.call("get_entity_parent")
	var proj := ProjectileScript.spawn(spell, caster.global_position + direction * 20.0, direction, parent)
	if proj == null:
		return {"ok": false, "reason": "spawn_failed", "message": "法术具现失败"}
	return {"ok": true, "message": "「%s」离手而去" % spell.get("display", "?")}
