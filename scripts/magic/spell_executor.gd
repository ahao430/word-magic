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
const BeamScript := preload("res://scripts/effects/beam.gd")
const SummonScript := preload("res://scripts/effects/summon.gd")


static func execute(spell: Dictionary, caster: Node2D, world: Node2D) -> Dictionary:
	match spell["shape"]:
		"projectile":
			return _execute_projectile(spell, caster, world)
		"explosion":
			return _execute_explosion(spell, caster, world)
		"field", "tornado":
			return _execute_zone(spell, caster, world)
		"area":
			return _execute_area(spell, caster, world)
		"beam":
			return _execute_beam(spell, caster, world)
		"shield":
			return _execute_shield(spell, caster)
		"summon":
			return _execute_summon(spell, caster, world)
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


## Area burst centered on the caster (大地脉动): reuse the blast node.
static func _execute_area(spell: Dictionary, caster: Node2D, world: Node2D) -> Dictionary:
	var parent := _spawn_parent(world)
	BlastScript.spawn(spell, caster.global_position, parent)
	return {"ok": true, "message": "「%s」大地轰鸣" % spell.get("display", "?")}


## Directed ray held for the duration (烈光贯日).
static func _execute_beam(spell: Dictionary, caster: Node2D, world: Node2D) -> Dictionary:
	var direction := Vector2.RIGHT
	if caster.has_method("get_facing_vector"):
		direction = caster.call("get_facing_vector")
	var parent := _spawn_parent(world)
	BeamScript.spawn(spell, caster.global_position, direction, parent)
	return {"ok": true, "message": "「%s」光柱贯空" % spell.get("display", "?")}


## Self-buff: damage mitigation for the duration (守护之壁). Needs an
## apply_shield receiver — the player has one; anything else refuses.
static func _execute_shield(spell: Dictionary, caster: Node2D) -> Dictionary:
	if not caster.has_method("apply_shield"):
		return {"ok": false, "reason": "no_target", "message": "此身无法承载护壁"}
	var duration: float = spell.get("parameters", {}).get("duration", 0.0)
	caster.call("apply_shield", duration)
	return {"ok": true, "message": "「%s」护壁成形" % spell.get("display", "?")}


## Companion spirit that orbits and zaps (唤灵术).
static func _execute_summon(spell: Dictionary, caster: Node2D, world: Node2D) -> Dictionary:
	var parent := _spawn_parent(world)
	SummonScript.spawn(spell, caster, parent)
	return {"ok": true, "message": "「%s」灵体相随" % spell.get("display", "?")}


static func _spawn_parent(world: Node2D) -> Node2D:
	if world.has_method("get_entity_parent"):
		return world.call("get_entity_parent")
	return world
