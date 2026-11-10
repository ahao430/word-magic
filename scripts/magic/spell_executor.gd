class_name SpellExecutor
extends RefCounted
## Spell executor (AGENTS.md §7.1): the ONLY module that turns spell
## data into scene nodes. Godot owns all gameplay execution — the
## pipeline upstream produces validated data, never code.
## Implemented shapes: projectile, explosion, field, tornado. The rest
## of the whitelist (area/beam/shield/summon) remains "not unlocked"
## and refunds the mana gracefully.

# Preload instead of the Projectile global class: headless -s runs
# resolve globals through .godot's class cache, which lags behind new
# classes until an editor session refreshes them.
const ProjectileScript := preload("res://scripts/effects/projectile.gd")
const BlastScript := preload("res://scripts/effects/blast.gd")
const ZoneScript := preload("res://scripts/effects/field_zone.gd")


static func execute(spell: Dictionary, caster: Node2D, world: Node2D) -> Dictionary:
	match spell["shape"]:
		"projectile":
			return _execute_projectile(spell, caster, world)
		"explosion":
			return _execute_explosion(spell, caster, world)
		"field", "tornado":
			return _execute_zone(spell, caster, world)
		_:
			return {"ok": false, "reason": "not_unlocked",
					"message": "「%s」的形态尚未觉醒" % spell.get("display", spell["shape"])}


static func _execute_projectile(spell: Dictionary, caster: Node2D, world: Node2D) -> Dictionary:
	var direction := Vector2.RIGHT
	if caster.has_method("get_facing_vector"):
		direction = caster.call("get_facing_vector")
	var parent := _spawn_parent(world)
	var proj := ProjectileScript.spawn(spell, caster.global_position + direction * 20.0, direction, parent)
	if proj == null:
		return {"ok": false, "reason": "spawn_failed", "message": "法术具现失败"}
	return {"ok": true, "message": "「%s」离手而去" % spell.get("display", "?")}


static func _execute_explosion(spell: Dictionary, caster: Node2D, world: Node2D) -> Dictionary:
	var direction := Vector2.RIGHT
	if caster.has_method("get_facing_vector"):
		direction = caster.call("get_facing_vector")
	var parent := _spawn_parent(world)
	var landing: Vector2 = caster.global_position + direction * 96.0
	BlastScript.spawn(spell, landing, parent)
	return {"ok": true, "message": "「%s」轰然炸裂" % spell.get("display", "?")}


static func _execute_zone(spell: Dictionary, caster: Node2D, world: Node2D) -> Dictionary:
	var parent := _spawn_parent(world)
	ZoneScript.spawn(spell, caster.global_position, parent)
	var message := "「%s」寒霜漫开" if spell.get("shape", "") == "field" else "「%s」狂风大作"
	return {"ok": true, "message": message % spell.get("display", "?")}


static func _spawn_parent(world: Node2D) -> Node2D:
	if world.has_method("get_entity_parent"):
		return world.call("get_entity_parent")
	return world
