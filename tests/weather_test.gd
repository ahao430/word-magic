extends SceneTree
## Headless test for the weather layer: static helpers (damage
## scaling, wind arrow/band), the system's state machine and particle
## wiring, ballistic wind on projectiles, rain-shifted combat math
## (fire dampened / lightning empowered), and the session save tier.

var _failures := 0
var _cache_backup := ""
var _memory_backup := ""
var _ai_backup := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cache_backup = TestIsolation.stash(TestIsolation.CACHE_PATH)
	_memory_backup = TestIsolation.stash(TestIsolation.MEMORY_PATH)
	_ai_backup = AiConfig.capture_config()
	AiConfig.apply_config({})
	SpellCache.reset()
	WorldMemory.reset()
	Weather.reset()

	# --- Statics: defaults, damage scale, arrow/band ---
	_expect(Weather.state_name == "clear" and Weather.wind == Vector2.ZERO,
			"reset restores calm defaults")
	Weather.state_name = "rain"
	_expect(absf(Weather.damage_scale("fire") - 0.75) < 0.001
			and absf(Weather.damage_scale("lightning") - 1.25) < 0.001
			and Weather.damage_scale("ice") == 1.0,
			"rain rescales fire/lightning only")
	_expect(absf(Weather.scale_damage(20.0, "fire") - 15.0) < 0.001,
			"scale_damage math (20 fire -> 15 in rain)")
	Weather.state_name = "storm"
	_expect(Weather.damage_scale("fire") == 0.75, "storm keeps rain's mods")
	Weather.state_name = "windy"
	_expect(Weather.damage_scale("fire") == 1.0, "wind leaves damage alone")
	Weather.wind = Vector2(200, 0)
	_expect(Weather.wind_arrow() == "→", "east wind arrow")
	Weather.wind = Vector2(0, -100)
	_expect(Weather.wind_arrow() == "↑", "north wind arrow")
	Weather.wind = Vector2(-50, 50)
	_expect(Weather.wind_arrow() == "↙", "south-west wind arrow")
	Weather.wind = Vector2(0, 0)
	_expect(Weather.wind_arrow() == "" and Weather.wind_band() == "",
			"calm wind has no arrow/band")
	Weather.wind = Vector2(120, 0)
	_expect(Weather.wind_band() == "中", "wind band 中 at 120")

	# --- Cross-effect statics: chain hops, mana blessing, HUD hint ---
	Weather.state_name = "clear"
	_expect(Weather.chain_hops() == 0 and absf(Weather.mana_regen_scale() - 1.5) < 0.001,
			"clear: no chain, 1.5x mana regen")
	_expect(Weather.tactical_hint() == "·回蓝", "clear hint is 回蓝")
	Weather.state_name = "windy"
	_expect(Weather.chain_hops() == 0 and Weather.tactical_hint() == "",
			"windy: no chain, no hint")
	Weather.state_name = "rain"
	_expect(Weather.chain_hops() == 1 and Weather.tactical_hint() == "·链电",
			"rain: 1 chain hop, hint 链电")
	Weather.state_name = "storm"
	_expect(Weather.chain_hops() == 2 and absf(Weather.mana_regen_scale() - 1.0) < 0.001,
			"storm: 2 chain hops, regen untouched")

	# --- System node: states, particles, wind picking ---
	var system: Node = load("res://scripts/world/weather_system.gd").new()
	root.add_child(system)
	await physics_frame
	system.force_state("windy")
	await physics_frame
	_expect(Weather.state_name == "windy"
			and Weather.wind.length() > 60.0 and Weather.wind.length() < 160.0,
			"windy picks a wind inside its band (%.0f)" % Weather.wind.length())
	_expect(bool(system.get_node("Leaves").emitting)
			and not bool(system.get_node("Rain").emitting),
			"leaves on, rain off in windy")
	system.force_state("storm")
	await physics_frame
	_expect(bool(system.get_node("Rain").emitting)
			and bool(system.get_node("Leaves").emitting),
			"storm drives both particle fields")
	_expect(Weather.wind.length() >= 130.0, "storm wind is strong (%.0f)" % Weather.wind.length())
	var rain_gravity_x: float = system.get_node("Rain").gravity.x
	_expect(signf(rain_gravity_x) == signf(Weather.wind.x),
			"rain slant follows the wind (g.x=%.0f wind.x=%.0f)" % [rain_gravity_x, Weather.wind.x])
	system.force_state("clear")
	await physics_frame
	_expect(not bool(system.get_node("Rain").emitting)
			and not bool(system.get_node("Leaves").emitting),
			"clear silences both fields")

	# --- Ballistic wind bends projectiles ---
	# Free the system first: its per-frame lerp toward the state target
	# would fight the crisp manual wind values below.
	system.free()
	system = null  # freed refs cannot cross typed call boundaries
	Weather.wind = Vector2(200, 0)  # direct override for a crisp number
	var lab := Node2D.new()
	root.add_child(lab)
	var proj: Area2D = load("res://scenes/effects/projectile.tscn").instantiate()
	proj.spell = {"element": "fire", "parameters": {"damage": 10.0, "speed": 300.0,
			"duration": 2.0}}
	proj.velocity = Vector2(300, 0)
	proj.set("_base_velocity", Vector2(300, 0))
	lab.add_child(proj)
	await physics_frame
	_expect(absf(proj.velocity.x - (300.0 + 200.0 * Weather.WIND_SENSITIVITY)) < 0.01,
			"tailwind adds 0.35x wind to the bolt (%.1f)" % proj.velocity.x)
	Weather.wind = Vector2(-200, 0)
	await physics_frame
	_expect(absf(proj.velocity.x - (300.0 - 70.0)) < 0.01,
			"headwind slows it symmetrically (%.1f)" % proj.velocity.x)
	lab.free()
	Weather.wind = Vector2.ZERO

	# --- Combat math under rain: fire dampened, lightning empowered ---
	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	var player: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(500, 300)
	player.hp = 9999.0
	world.get_entity_parent().add_child(player)
	await physics_frame
	await physics_frame
	world.get_weather().force_state("rain")
	Weather.wind = Vector2.ZERO  # keep ballistics out of the assertion
	# Face right so the projectiles fly toward the placed slimes.
	Input.action_press("move_right")
	await physics_frame
	Input.action_release("move_right")

	var s1: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	s1.position = player.global_position + Vector2(60, 0)
	s1.hp = 200.0
	world.get_entity_parent().add_child(s1)
	await physics_frame
	var hp0: float = s1.hp
	var r1: Dictionary = await MagicFacade.cast("火球术", player, world, SpellSession.new())
	_expect(r1["ok"], "rain fireball casts")
	for i in 60:
		await physics_frame
	_expect(absf((hp0 - s1.hp) - 15.0) < 0.5,
			"fireball hits for 15 in rain (got %.1f)" % (hp0 - s1.hp))

	# The fireball's knockback sends s1 on a lap — clear it so the bolt
	# probe measures the one-shot alone (wet-slowed slimes return too
	# slowly to vacate the flight path within the window).
	await _clear_enemies(world)
	var s2: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	s2.position = player.global_position + Vector2(60, 0)
	s2.hp = 30.0
	world.get_entity_parent().add_child(s2)
	await physics_frame
	var r2: Dictionary = await MagicFacade.cast("落雷", player, world, SpellSession.new())
	_expect(r2["ok"], "rain lightning casts")
	for i in 60:
		await physics_frame
		if not is_instance_valid(s2):
			break
	_expect(not is_instance_valid(s2),
			"lightning one-shots a 30hp slime in rain (37.5 dmg)")

	# --- Chain lightning: a rain bolt arcs to the next slime over ---
	await _clear_enemies(world)
	world.get_weather().force_state("rain")
	Weather.wind = Vector2.ZERO
	var c1: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	c1.position = player.global_position + Vector2(60, 0)
	c1.hp = 200.0
	world.get_entity_parent().add_child(c1)
	var c2: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	c2.position = player.global_position + Vector2(150, 0)
	c2.hp = 200.0
	world.get_entity_parent().add_child(c2)
	await physics_frame
	c1.apply_freeze(4.0)
	c2.apply_freeze(4.0)
	var h1: float = c1.hp
	var h2: float = c2.hp
	var r3: Dictionary = await MagicFacade.cast("落雷", player, world, SpellSession.new())
	_expect(r3["ok"], "chain probe lightning casts")
	for i in 60:
		await physics_frame
	_expect(absf((h1 - c1.hp) - 37.5) < 0.5 and absf((h2 - c2.hp) - 22.5) < 0.5,
			"rain bolt 37.5 chains for 22.5 (got %.1f/%.1f)" % [h1 - c1.hp, h2 - c2.hp])

	# --- ChainArc semantics in a bare lab (storm: 2 decaying hops) ---
	var arc_lab: Node2D = Node2D.new()
	root.add_child(arc_lab)
	var arc_spell := {"element": "lightning", "shape": "projectile",
			"parameters": {"damage": 30.0}}
	var a1 := _frozen_slime(arc_lab, Vector2(0, 0))
	var a2 := _frozen_slime(arc_lab, Vector2(100, 0))
	var a3 := _frozen_slime(arc_lab, Vector2(200, 0))
	Weather.state_name = "storm"
	var chained: Array = ChainArc.on_hit(arc_spell, a1, 37.5)
	_expect(chained.size() == 2 and chained[0] == a2 and chained[1] == a3,
			"storm arcs two decaying hops")
	_expect(absf((200.0 - a2.hp) - 22.5) < 0.01 and absf((200.0 - a3.hp) - 13.5) < 0.01,
			"hop damage decays 0.6/0.36 (got %.1f/%.1f)" % [200.0 - a2.hp, 200.0 - a3.hp])
	# Dry weather: no arc at all.
	Weather.state_name = "clear"
	a2.hp = 200.0
	a3.hp = 200.0
	_expect(ChainArc.on_hit(arc_spell, a1, 37.5).is_empty()
			and a2.hp == 200.0 and a3.hp == 200.0,
			"clear weather never chains")
	# Non-lightning never chains even in a storm.
	Weather.state_name = "storm"
	var fire_spell := {"element": "fire", "shape": "projectile",
			"parameters": {"damage": 30.0}}
	_expect(ChainArc.on_hit(fire_spell, a1, 30.0).is_empty(),
			"fire never chains")
	# Blast-style exclude list: the nearest neighbour is skipped, so the
	# arc lands on the next one in range.
	a2.hp = 200.0
	a3.hp = 200.0
	var a4 := _frozen_slime(arc_lab, Vector2(80, 0))
	var excl: Array = ChainArc.on_hit(arc_spell, a1, 37.5, [a2])
	_expect(excl.size() == 1 and excl[0] == a4 and a2.hp == 200.0
			and absf((200.0 - a4.hp) - 22.5) < 0.01,
			"excluded neighbours are skipped by the arc")
	arc_lab.free()
	Weather.state_name = "rain"

	# --- Clear-sky blessing: mana regen 1.5x sun vs 1.0x rain ---
	world.get_weather().force_state("clear")
	player.mana = 40.0
	for i in 60:
		await physics_frame
	_expect(absf(player.mana - 43.0) < 0.15,
			"clear regen +3.0/s (got %.2f)" % player.mana)
	world.get_weather().force_state("rain")
	player.mana = 40.0
	for i in 60:
		await physics_frame
	_expect(absf(player.mana - 42.0) < 0.15,
			"rain regen +2.0/s (got %.2f)" % player.mana)

	# --- Enemy weather AI: wet slimes bog down to 0.7x chase ---
	await _clear_enemies(world)
	world.get_weather().force_state("clear")
	Weather.wind = Vector2.ZERO
	var wet: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	wet.position = player.global_position + Vector2(120, 0)
	wet.hp = 999.0
	world.get_entity_parent().add_child(wet)
	await physics_frame
	var wd0: float = wet.global_position.distance_to(player.global_position)
	for i in 60:
		await physics_frame
	var closed_clear: float = wd0 - wet.global_position.distance_to(player.global_position)
	_expect(closed_clear > 70.0 and closed_clear < 95.0,
			"clear chase closes ~85px/s (got %.1f)" % closed_clear)
	world.get_weather().force_state("rain")
	wet.position = player.global_position + Vector2(120, 0)
	await physics_frame
	var wd1: float = wet.global_position.distance_to(player.global_position)
	for i in 60:
		await physics_frame
	var closed_rain: float = wd1 - wet.global_position.distance_to(player.global_position)
	_expect(closed_rain > 45.0 and closed_rain < 70.0,
			"rain chase bogged to ~59.5px/s (got %.1f)" % closed_rain)
	wet.free()

	# --- 畏水: a chasing slime refuses to step into the river ---
	world.get_weather().force_state("clear")
	var water: Dictionary = world.river_cells()
	var pick_y := -1
	var wx_max := -1
	for y in range(2, 30):
		var row_max := -1
		var row_count := 0
		for cell: Vector2i in water:
			if cell.y == y:
				row_count += 1
				row_max = maxi(row_max, cell.x)
		if row_count == 3:
			pick_y = y
			wx_max = row_max
			break
	_expect(pick_y > 0, "found a 3-wide river row (y=%d)" % pick_y)
	var bank_px := float(wx_max + 1) * 32.0
	var y_px := pick_y * 32.0 + 16.0
	var dread: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	dread.position = Vector2(bank_px + 44.0, y_px)
	dread.hp = 999.0
	world.get_entity_parent().add_child(dread)
	player.global_position = Vector2(bank_px - 100.0, y_px)
	await physics_frame
	await physics_frame
	_expect(absf(dread.global_position.y - y_px) < 10.0
			and dread.global_position.distance_to(player.global_position) < 150.0,
			"slime settled on the bank, player in chase range")
	var x0: float = dread.global_position.x
	for i in 90:
		await physics_frame
	_expect(dread.global_position.x > bank_px + 22.0,
			"slime halts a probe short of the water (%.1f > %.1f)"
					% [dread.global_position.x, bank_px + 22.0])
	_expect(dread.global_position.x < x0 + 4.0,
			"it pressed toward the bank then stopped, not fled (%.1f→%.1f)"
					% [x0, dread.global_position.x])
	dread.free()
	player.global_position = Vector2(500, 300)

	# --- Boss storm fury: faster chase, shorter recovery, stacks ---
	var boss: CharacterBody2D = load("res://scenes/enemies/boss_slime.tscn").instantiate()
	boss.position = player.global_position + Vector2(160, 0)
	world.get_entity_parent().add_child(boss)
	await physics_frame
	world.get_weather().force_state("clear")
	_expect(absf(float(boss.call("_chase_speed")) - 55.0) < 0.01
			and absf(float(boss.call("_cooldown_time")) - 0.9) < 0.001,
			"clear boss: 55 speed / 0.9 cooldown")
	world.get_weather().force_state("storm")
	_expect(absf(float(boss.call("_chase_speed")) - 68.75) < 0.01
			and absf(float(boss.call("_cooldown_time")) - 0.63) < 0.001,
			"storm boss: 68.75 speed / 0.63 cooldown")
	boss.set("enraged", true)
	_expect(absf(float(boss.call("_chase_speed")) - 106.25) < 0.01
			and absf(float(boss.call("_cooldown_time")) - 0.35) < 0.001,
			"storm stacks with enrage: 106.25 / 0.35")
	boss.set("enraged", false)
	var bd0: float = boss.global_position.distance_to(player.global_position)
	for i in 60:
		await physics_frame
	var closed_boss: float = bd0 - boss.global_position.distance_to(player.global_position)
	_expect(closed_boss > 55.0 and closed_boss < 80.0,
			"storm boss closes at ~68.75px/s (got %.1f)" % closed_boss)
	boss.free()

	# --- Session save tier ---
	var snap: Dictionary = world.get_weather().capture_state()
	_expect(snap.has("state") and snap.has("wind_x"),
			"weather captures into the save payload")
	world.get_weather().force_state("clear")
	world.get_weather().apply_state(snap)
	_expect(Weather.state_name == str(snap["state"]),
			"apply_state restores the weather")

	# --- Wind drift: zones ride the gale (tornado harder than field) ---
	# Free the system first: its eased lerp would fight the crisp manual
	# wind value below (same trick as the ballistics section).
	var wsys: Node = world.get_weather()
	if is_instance_valid(wsys):
		wsys.free()
	Weather.wind = Vector2(200, 0)
	Weather.state_name = "windy"
	var drift_lab := Node2D.new()
	root.add_child(drift_lab)
	var zone_script := load("res://scripts/effects/field_zone.gd")
	var field: Area2D = zone_script.spawn({"element": "ice", "shape": "field",
			"parameters": {"damage": 1.0, "radius": 60.0, "duration": 8.0}},
			Vector2(0, 0), drift_lab)
	var gale: Area2D = zone_script.spawn({"element": "wind", "shape": "tornado",
			"parameters": {"damage": 1.0, "radius": 60.0, "duration": 8.0}},
			Vector2(0, 200), drift_lab)
	await physics_frame
	var f0: Vector2 = field.position
	var g0: Vector2 = gale.position
	for i in 90:
		await physics_frame
	# 90 physics frames = 1.5s: field 200*0.10*1.5=30px, tornado 66px.
	_expect(absf(field.position.x - f0.x - 30.0) < 6.0,
			"field creeps with the wind (%.1f px)" % (field.position.x - f0.x))
	_expect(absf(gale.position.x - g0.x - 66.0) < 8.0,
			"tornado rides the gale harder (%.1f px)" % (gale.position.x - g0.x))
	Weather.wind = Vector2.ZERO
	Weather.state_name = "clear"
	drift_lab.free()

	_teardown(world, system)


## Map slimes wander: free every enemy-layer body so chain/drift probes
## measure exactly the slimes we place.
func _clear_enemies(world: Node2D) -> void:
	for child in world.get_entity_parent().get_children():
		if child is CharacterBody2D and (child.collision_layer & 4) != 0:
			child.queue_free()
	await physics_frame
	await physics_frame


## A rooted 200hp slime at `pos` under `lab`: positions stay crisp for
## chain-distance assertions.
func _frozen_slime(lab: Node2D, pos: Vector2) -> CharacterBody2D:
	var s: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	s.position = pos
	s.hp = 200.0
	lab.add_child(s)
	s.apply_freeze(4.0)
	return s


func _teardown(world: Node2D, system: Node) -> void:
	if is_instance_valid(world):
		world.free()
	if system != null and is_instance_valid(system):
		system.free()
	Weather.reset()
	TestIsolation.unstash(TestIsolation.CACHE_PATH, _cache_backup)
	TestIsolation.unstash(TestIsolation.MEMORY_PATH, _memory_backup)
	AiConfig.apply_config(_ai_backup)
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
