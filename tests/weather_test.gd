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

	# --- Session save tier ---
	var snap: Dictionary = world.get_weather().capture_state()
	_expect(snap.has("state") and snap.has("wind_x"),
			"weather captures into the save payload")
	world.get_weather().force_state("clear")
	world.get_weather().apply_state(snap)
	_expect(Weather.state_name == str(snap["state"]),
			"apply_state restores the weather")

	_teardown(world, system)


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
