extends SceneTree
## Headless test for the swamp fly (X6): wind drift bends the hover,
## gusts carry the light body 2.5x farther than a slime, water means
## nothing (it crosses ponds the slime refuses), frost drops it, and
## the wetland spawns four; summon zaps them; the session save tracks
## them.

var _failures := 0
var _cache_backup := ""
var _memory_backup := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cache_backup = TestIsolation.stash(TestIsolation.CACHE_PATH)
	_memory_backup = TestIsolation.stash(TestIsolation.MEMORY_PATH)
	SpellCache.reset()
	WorldMemory.reset()
	Weather.reset()

	# --- Lab: wind drift + push multiplier ---
	var lab := Node2D.new()
	root.add_child(lab)
	var fly: CharacterBody2D = load("res://scenes/enemies/swamp_fly.tscn").instantiate()
	fly.position = Vector2(100, 100)
	fly.hp = 999.0
	lab.add_child(fly)
	var slime: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	slime.position = Vector2(100, 200)
	slime.hp = 999.0
	lab.add_child(slime)
	await physics_frame
	await physics_frame
	var fly_x0: float = fly.global_position.x
	var slime_x0: float = slime.global_position.x
	Weather.wind = Vector2(100, 0)
	for i in 30:
		await physics_frame
	var fly_drift: float = fly.global_position.x - fly_x0
	var slime_drift: float = slime.global_position.x - slime_x0
	_expect(fly_drift > slime_drift + 8.0,
			"wind bends the fly (%.1f) farther than the ground slime (%.1f)"
					% [fly_drift, slime_drift])
	Weather.wind = Vector2.ZERO
	fly.apply_push(Vector2(100, 0))
	var fly_knock: Vector2 = fly.get("_knockback")
	_expect(absf(fly_knock.length() - 250.0) < 0.01,
			"the light body multiplies shoves 2.5x (%.0f)" % fly_knock.length())

	# --- Water means nothing: the fly crosses what blocks the slime ---
	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var ponds: Dictionary = load("res://scripts/world/world.gd").wetland_pond_cells()
	_expect(ponds.size() > 0, "wetland has ponds")
	var pond_cell: Vector2i = Vector2i.ZERO
	for cell: Vector2i in ponds:
		if cell.y != 16 and world.is_blocked_ground(Vector2(cell) * 32.0 + Vector2(16, 16)):
			pond_cell = cell
			break
	_expect(pond_cell != Vector2i.ZERO, "found a blocked pond cell %s" % pond_cell)
	Weather.wind = Vector2.ZERO
	# Bait east of the pond: the fly chases you ACROSS the water while
	# the ground slime refuses to enter it. The contrast IS the test.
	var bait: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	bait.name = "Player"
	bait.hp = 9999.0
	bait.position = Vector2(pond_cell.x * 32.0 + 140.0, pond_cell.y * 32.0 + 16.0)
	world.get_entity_parent().add_child(bait)
	await physics_frame
	var ground_probe: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	ground_probe.position = Vector2(pond_cell.x * 32.0 - 24.0, pond_cell.y * 32.0 + 16.0)
	ground_probe.hp = 999.0
	world.get_entity_parent().add_child(ground_probe)
	var air_probe: CharacterBody2D = load("res://scenes/enemies/swamp_fly.tscn").instantiate()
	air_probe.position = ground_probe.global_position
	air_probe.hp = 999.0
	world.get_entity_parent().add_child(air_probe)
	await physics_frame
	var target := Vector2(pond_cell.x * 32.0 + 96.0, pond_cell.y * 32.0 + 16.0)
	ground_probe.set("_wander_dir", (target - ground_probe.global_position).normalized())
	ground_probe.set("_wander_timer", 10.0)
	air_probe.set("_hover_phase", 0.0)
	for i in 90:
		await physics_frame
	_expect(ground_probe.global_position.x < float(pond_cell.x) * 32.0,
			"the slime halts at the pond edge (%.0f < %d)"
					% [ground_probe.global_position.x, pond_cell.x * 32.0])
	_expect(air_probe.global_position.x > float(pond_cell.x + 1) * 32.0,
			"the fly crosses the pond (%.0f)" % air_probe.global_position.x)

	# --- Frost still drops them ---
	var hp0: float = air_probe.hp
	air_probe.call("apply_freeze", 1.0)
	_expect(float(air_probe.get("_freeze_timer")) > 0.0, "frost drops the fly")

	# --- Spawn count + summon zap target ---
	var flies := 0
	for child in world.get_entity_parent().get_children():
		if child.name.begins_with("SwampFly_"):
			flies += 1
	_expect(flies == 4, "four flies buzz the wetland (%d)" % flies)
	var summon: Node2D = load("res://scenes/effects/summon.tscn").instantiate()
	summon.set("spell", {"element": "nature", "shape": "summon",
			"parameters": {"damage": 8.0, "radius": 300.0, "duration": 4.0}})
	# Orbit the bait: the chasing fly is glued to the player, so IT is
	# the nearest zap target (orbiting the west-side slime would hit the
	# slime instead — nearest-wins).
	summon.set("_caster", bait)
	summon.position = air_probe.global_position
	world.get_entity_parent().add_child(summon)
	for i in 75:  # the zap ticks at 1.0s
		await physics_frame
	_expect(air_probe.hp < hp0, "the summon zaps the fly (%.0f -> %.0f)" % [hp0, air_probe.hp])

	# --- Session save tracks fly lives ---
	var snap: Dictionary = world.capture_state()
	_expect((snap["alive_slimes"] as Array).any(func(n) -> bool: return str(n).begins_with("SwampFly")),
			"the session save lists fly names")

	_teardown(world, lab)


func _teardown(world: Node2D, lab: Node2D) -> void:
	if is_instance_valid(world):
		world.free()
	if is_instance_valid(lab):
		lab.free()
	Weather.reset()
	TestIsolation.unstash(TestIsolation.CACHE_PATH, _cache_backup)
	TestIsolation.unstash(TestIsolation.MEMORY_PATH, _memory_backup)
	SpellCache.reset()
	WorldMemory.reset()
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES: %d" % _failures)
		quit(1)


func _expect(cond: bool, what: String) -> void:
	if cond:
		print("PASS  " + what)
	else:
		_failures += 1
		print("FAIL  " + what)
