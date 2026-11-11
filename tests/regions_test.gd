extends SceneTree
## Headless test for the second region (迷雾湿地, X1 skeleton): the map
## extension to 64x32, deterministic ponds, the boundary gate, the
## wetland population (3 slimes + the elite), the region weather bias,
## and the permanent first-entry world memory event.

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

	# --- Pure statics: region naming + pond determinism ---
	var world_script: GDScript = load("res://scripts/world/world.gd")
	var weather_script: GDScript = load("res://scripts/world/weather_system.gd")
	_expect(world_script.region_name_at(Vector2(100, 100)) == "森林"
			and world_script.region_name_at(Vector2(48 * 32 + 5, 100)) == "迷雾湿地",
			"region naming splits at the gate column")
	var ponds: Dictionary = world_script.wetland_pond_cells()
	_expect(ponds.size() > 60, "wetland has a real pond count (%d cells)" % ponds.size())
	var all_east := true
	for cell: Vector2i in ponds:
		if cell.x < world_script.WETLAND_START:
			all_east = false
	_expect(all_east, "ponds never leak west of the gate")
	_expect(world_script.wetland_pond_cells().size() == ponds.size(),
			"ponds are seed-deterministic")

	# --- Weather bias weights (pure) ---
	var forest_w: Dictionary = weather_script.state_weights("forest")
	var wet_w: Dictionary = weather_script.state_weights("wetland")
	_expect(float(forest_w["rain"]) == 1.0 and float(wet_w["rain"]) == 2.0
			and float(wet_w["storm"]) == 2.0 and float(wet_w["clear"]) == 1.0,
			"wetland doubles the wet states, forest stays uniform")

	# --- World integration: map, gate, population ---
	var discover_count := {"n": 0}
	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	world.region_discovered.connect(func(_n: String) -> void: discover_count["n"] = int(discover_count["n"]) + 1)
	root.add_child(world)
	await physics_frame
	await physics_frame
	_expect(world.map_pixel_size() == Vector2(64.0 * 32.0, 32.0 * 32.0),
			"map extended to 2048x1024 (%s)" % world.map_pixel_size())
	_expect(world.get_entity_parent().get_node_or_null("Gate_Pillar_N") != null
			and world.get_entity_parent().get_node_or_null("Gate_Pillar_S") != null,
			"boundary gate pillars flank the path row")
	var elite: CharacterBody2D = world.get_entity_parent().get_node_or_null("SlimeElite_58_10")
	_expect(elite != null and absf(float(elite.get("hp")) - 60.0) < 0.01,
			"deep-swamp elite holds its post at 60hp")
	var wetland_slimes := 0
	for child in world.get_entity_parent().get_children():
		if child is CharacterBody2D and child.name.begins_with("Slime_"):
			if child.global_position.x >= float(world_script.WETLAND_START) * 32.0:
				wetland_slimes += 1
	_expect(wetland_slimes == 3, "three regular slimes populate the wetland (%d)" % wetland_slimes)

	# --- Ponds are painted and impassable ---
	var ground: TileMapLayer = world.get_node("GroundLayer")
	var painted_water := 0
	for cell: Vector2i in ponds:
		if cell.y == 16:
			continue  # the path row paints stone (boardwalk), no collision
		var row := ground.get_cell_atlas_coords(cell).y
		if row >= 6 and row <= 10:
			painted_water += 1
	_expect(painted_water >= ponds.size() - 16,
			"pond cells paint into the water family (%d/%d)"
					% [painted_water, ponds.size()])
	var blocked_probe := false
	var probed := 0
	for cell: Vector2i in ponds:
		if cell.y == 16 or probed >= 3:
			continue
		probed += 1
		if world.is_blocked_ground(Vector2(cell) * 32.0 + Vector2(16.0, 16.0)):
			blocked_probe = true
	_expect(blocked_probe, "pond cells block movement (collision rides the tiles)")

	# --- Region poll: bias flips and discovery records once ---
	var player: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(24 * 32 + 16, 16 * 32 + 16)
	player.hp = 9999.0
	world.get_entity_parent().add_child(player)
	await physics_frame
	await physics_frame
	_expect(str(world.get_weather().region_bias) == "forest",
			"west of the gate the bias stays forest")
	player.global_position = Vector2(50 * 32 + 16, 16 * 32 + 16)
	for i in 50:
		await physics_frame
	_expect(str(world.get_weather().region_bias) == "wetland",
			"crossing the gate flips the weather bias")
	_expect(world.wetland_discovered
			and WorldMemory.has_event(WorldMemory.EVENT_REGION),
			"first entry is a permanent world-memory event")
	player.global_position = Vector2(24 * 32 + 16, 16 * 32 + 16)
	for i in 50:
		await physics_frame
	_expect(str(world.get_weather().region_bias) == "forest",
			"walking home restores the forest bias")
	player.global_position = Vector2(50 * 32 + 16, 16 * 32 + 16)
	for i in 50:
		await physics_frame
	_expect(world.wetland_discovered and int(discover_count["n"]) == 1,
			"re-entry never re-fires the discovery (%d)" % int(discover_count["n"]))

	# --- Elite drop: the swamp heart is a permanent world fact ---
	player.hp_max = 30.0
	elite.call("take_damage", 999.0, Vector2.RIGHT)
	for i in 20:
		await physics_frame
	_expect(not is_instance_valid(elite) and WorldMemory.has_event(WorldMemory.EVENT_ELITE),
			"elite death records the swamp heart")
	player.apply_swamp_heart()
	_expect(absf(player.hp_max - 40.0) < 0.01, "swamp heart raises max hp 30->40")

	# --- The blessing spring: one interact, one permanent fact ---
	var spring: Node2D = world.get_entity_parent().get_node_or_null("SwampSpring")
	_expect(spring != null, "the spring stands in the wetland")
	player.mana_max = 100.0
	var bless: Dictionary = spring.call("interact", player)
	_expect(bool(bless["ok"]) and absf(player.mana_max - 110.0) < 0.01
			and WorldMemory.has_event(WorldMemory.EVENT_SPRING),
			"spring grants +10 max mana once (%s)" % bless["message"])
	var again: Dictionary = spring.call("interact", player)
	_expect(not bool(again["ok"]), "a dried spring refuses politely")
	player.hp = player.hp_max

	# --- Wetland idioms resolve from the local registry ---
	var m1: Dictionary = await MagicFacade.cast("沼泽缠绕", player, world, SpellSession.new())
	_expect(m1["ok"] and m1["source"] == "registry" and m1["cost"] == 38,
			"沼泽缠绕 casts from the registry at 38 (%s/%d)" % [m1["source"], m1["cost"]])
	var m2: Dictionary = await MagicFacade.cast("激流冲击", player, world, SpellSession.new())
	_expect(m2["ok"] and m2["source"] == "registry" and m2["cost"] == 21,
			"激流冲击 casts from the registry at 21 (%s/%d)" % [m2["source"], m2["cost"]])

	# --- Discovery replays from world memory on a fresh world ---
	var events: Dictionary = WorldMemory.capture()
	world.free()
	await physics_frame
	WorldMemory.reset()
	WorldMemory.apply(events)
	var world2: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world2)
	await physics_frame
	await physics_frame
	_expect(world2.wetland_discovered,
			"world memory replays the discovery on rebuild")
	_expect(world2.get_entity_parent().get_node_or_null("SlimeElite_58_10") == null,
			"the elite stays dead across rebuilds")
	var spring2: Node2D = world2.get_entity_parent().get_node_or_null("SwampSpring")
	_expect(spring2 != null and not bool(spring2.call("interact", null)["ok"]),
			"the blessed spring rebuilds already dry")
	world2.free()

	_teardown()


func _teardown() -> void:
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
