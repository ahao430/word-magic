extends SceneTree
## Headless boss battle test: sprite assets, scene defaults, world
## integration (arena seat + defeat flag), aggro, the chase → wind-up →
## slam → recover cycle, slam area damage, and the save-tier capture /
## restore of the boss.

var _failures := 0
## Lambdas capture locals by value in GDScript, so signal callbacks set
## flags through this dict (captured by reference).
var _flags := {}


func _flag(name: String) -> void:
	_flags[name] = true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# --- Sprites: dimensions, alpha cutout, crown, highlight, frames ---
	var f1: Image = load("res://assets/sprites/enemies/boss_slime_idle_01.png").get_image()
	var f2: Image = load("res://assets/sprites/enemies/boss_slime_idle_02.png").get_image()
	_expect(f1.get_size() == Vector2i(56, 44) and f2.get_size() == Vector2i(56, 44),
			"frames are 56x44")
	var corner_clear: bool = f1.get_pixel(0, 0).a < 0.1 and f1.get_pixel(55, 0).a < 0.1 \
			and f1.get_pixel(0, 43).a < 0.1 and f1.get_pixel(55, 43).a < 0.1
	_expect(corner_clear, "corners are true alpha cutout")
	var gold := 0
	var gem := 0
	var light := 0
	var diff := 0
	for y in 44:
		for x in 56:
			var a := f1.get_pixel(x, y)
			var b := f2.get_pixel(x, y)
			if a.a > 0.9:
				if absf(a.r - 0.95) < 0.03 and absf(a.g - 0.78) < 0.03:
					gold += 1
				elif a.r > 0.7 and a.g < 0.4 and a.b < 0.4:
					gem += 1
				elif absf(a.r - 0.52) < 0.05 and absf(a.g - 0.82) < 0.05:
					light += 1
			if absf(a.r - b.r) > 0.05 or absf(a.g - b.g) > 0.05 or absf(a.a - b.a) > 0.05:
				diff += 1
	_expect(gold >= 80, "golden crown present (%d px)" % gold)
	_expect(gem >= 1, "ruby gem on the crown")
	_expect(light > 0, "NE highlight present (%d px)" % light)
	_expect(diff > 50, "bounce frames differ (%d px)" % diff)
	var shadow: Image = load("res://assets/sprites/effects/boss_shadow_28x12.png").get_image()
	_expect(shadow.get_size() == Vector2i(28, 12) and shadow.get_pixel(14, 6).a > 0.3
			and shadow.get_pixel(0, 0).a < 0.05, "boss shadow 28x12 radial alpha")
	var frames: SpriteFrames = load("res://assets/sprites/enemies/boss_frames.tres")
	_expect(frames.get_frame_count(&"default") == 2, "SpriteFrames has 2 frames")

	# --- Scene defaults ---
	var boss: CharacterBody2D = load("res://scenes/enemies/boss_slime.tscn").instantiate()
	_expect(float(boss.get("hp")) == 120.0 and float(boss.get("hp_max")) == 120.0,
			"boss starts at 120 hp")
	_expect(bool(boss.get("alive")) and not bool(boss.get("aggro"))
			and int(boss.get("state")) == 0, "starts dormant")
	_expect(boss.collision_layer == 4 and boss.collision_mask == 1, "enemy layering")

	# --- World integration: arena seat + capture defaults ---
	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var seat: Node2D = world.get_boss()
	_expect(seat != null and is_instance_valid(seat), "world seats the boss")
	if seat == null:
		_finish()
		return
	_expect(seat.global_position.distance_to(Vector2(38.0 * 32.0 + 16.0, 8.0 * 32.0 + 26.0)) < 2.0,
			"boss seated in the NE arena (at %s)" % seat.global_position)
	var cap: Dictionary = world.capture_state()
	var cap_boss: Dictionary = cap["boss"]
	_expect(cap_boss["alive"] == true and absf(float(cap_boss["hp"]) - 120.0) < 0.01,
			"capture records a living boss")

	# --- Aggro + chase approach (dummy player: no take_damage method) ---
	var arena := Node2D.new()
	arena.name = "Arena"
	root.add_child(arena)
	var dummy := CharacterBody2D.new()
	dummy.name = "Player"
	dummy.position = seat.global_position + Vector2(150, 0)
	world.get_entity_parent().add_child(dummy)
	var aggro_fired := false
	seat.connect("aggroed", Callable(self, "_flag").bind("aggroed"))
	for i in 30:
		await physics_frame
	aggro_fired = bool(_flags.get("aggroed", false))
	_expect(aggro_fired and bool(seat.get("aggro")), "boss aggros when approached")
	var dist_after := dummy.global_position.distance_to(seat.global_position)
	_expect(150.0 - dist_after > 20.0, "boss closed the gap (%.0f -> %.0f)" % [150.0, dist_after])

	# --- Skill cycle: chase -> wind-up -> slam -> recover -> chase ---
	var saw_windup := false
	var saw_slam := false
	var saw_recover := false
	var back_to_chase := false
	for i in 480:
		await physics_frame
		var s: int = int(seat.get("state"))
		if s == 2:
			saw_windup = true
		elif s == 3:
			saw_slam = true
		elif s == 4:
			saw_recover = true
		elif s == 1 and saw_recover:
			back_to_chase = true
			break
	_expect(saw_windup and saw_slam and saw_recover and back_to_chase,
			"full skill cycle observed (w=%s s=%s r=%s c=%s)" % [saw_windup, saw_slam, saw_recover, back_to_chase])
	dummy.queue_free()

	# --- Slam area damage: near hurts 12, far is safe ---
	var holder := Node2D.new()
	holder.name = "SlamLab"
	root.add_child(holder)
	var boss2: CharacterBody2D = load("res://scenes/enemies/boss_slime.tscn").instantiate()
	holder.add_child(boss2)
	var player2: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	player2.position = Vector2(60, 0)
	holder.add_child(player2)
	await physics_frame
	var hp_before: float = player2.hp
	boss2.call("_slam_impact")
	_expect(absf(player2.hp - (hp_before - 12.0)) < 0.01, "slam hits for 12 in radius")
	for i in 55:
		await physics_frame  # invulnerability window expires
	player2.global_position = Vector2(200, 0)
	var hp_safe: float = player2.hp
	boss2.call("_slam_impact")
	_expect(absf(player2.hp - hp_safe) < 0.01, "slam out of radius is harmless")
	holder.queue_free()

	# --- Death: signal, world flag, capture flips, node freed ---
	seat.connect("died", Callable(self, "_flag").bind("died"))
	seat.call("take_damage", 999.0, Vector2.RIGHT)
	var died_fired := bool(_flags.get("died", false))
	_expect(died_fired and not bool(seat.get("alive")), "died signal fires")
	_expect(world.boss_defeated, "world records the defeat")
	var cap2: Dictionary = world.capture_state()
	_expect(cap2["boss"]["defeated"] == true and cap2["boss"]["alive"] == false,
			"capture flips to defeated")
	for i in 45:
		await physics_frame
	_expect(not is_instance_valid(seat), "boss node freed after death tween")

	# --- Restore: living boss re-seated at hp/position; dead boss removed ---
	var w2: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(w2)
	await physics_frame
	await physics_frame
	var b2: Node2D = w2.get_boss()
	w2.restore_state({"boss": {"defeated": false, "alive": true,
			"hp": 60.0, "x": 500.0, "y": 300.0}})
	_expect(b2 != null and absf(float(b2.get("hp")) - 60.0) < 0.01
			and b2.global_position.distance_to(Vector2(500, 300)) < 1.0,
			"restore re-seats a wounded boss")
	var w3: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(w3)
	await physics_frame
	await physics_frame
	w3.restore_state({"boss": {"defeated": true, "alive": false}})
	for i in 5:
		await physics_frame
	_expect(w3.get_boss() == null, "restore removes a defeated boss")

	# Free everything we staged so the exit leak report stays clean.
	for child in root.get_children():
		child.free()
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
