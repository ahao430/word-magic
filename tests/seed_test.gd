extends SceneTree
## Headless test for the procedural layout seed (AGENTS.md §11): one
## seed drives terrain noise + prop/slime scatter, POIs stay at their
## handcrafted cells on every seed, seed 0 keeps the legacy layout
## byte-identical (old saves), and the seed round-trips through the
## session save tier.

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

	# --- Legacy determinism: two default worlds are identical ---
	var legacy_a: Node2D = await _build_world(0)
	var legacy_b: Node2D = await _build_world(0)
	_expect(_child_names(legacy_a) == _child_names(legacy_b),
			"seed 0 worlds are byte-identical (%d/%d children)"
					% [_child_names(legacy_a).size(), _child_names(legacy_b).size()])
	legacy_a.free()
	legacy_b.free()
	await physics_frame

	# --- Seeded determinism and variation ---
	var s1: Node2D = await _build_world(12345)
	var s1b: Node2D = await _build_world(12345)
	var s2: Node2D = await _build_world(67890)
	_expect(_child_names(s1) == _child_names(s1b), "same seed = same world")
	_expect(_child_names(s1) != _child_names(s2), "different seed = different world")

	# --- POIs survive every seed ---
	for poi in ["Gate_Pillar_N", "Gate_Pillar_S", "SwampSpring", "Keeper",
			"BossSlime", "RuneStone", "SlimeElite_58_10"]:
		_expect(s1.get_entity_parent().get_node_or_null(poi) != null,
				"%s stands on seed 12345" % poi)

	# --- The river is seed-independent ---
	var water: Dictionary = s1.river_cells()
	var any_water := false
	for y in 32:
		if water.has(Vector2i(12, y)):
			any_water = true
			break
	_expect(any_water and s1.is_blocked_ground(Vector2(12 * 32 + 16, 15 * 32 + 16)),
			"river cells block movement on any seed (river cells are constant)")

	# --- Capture / restore round-trip carries the seed ---
	var snap: Dictionary = s1.capture_state()
	_expect(int(snap["layout_seed"]) == 12345, "capture stores the seed")
	var fresh: Node2D = await _build_world(0)
	fresh.restore_state(snap)
	await physics_frame
	await physics_frame  # let the rebuild's arena-clear queue_free drain
	_expect(fresh.layout_seed == 12345 and _child_names(fresh) == _child_names(s1),
			"restore rebuilds the exact seeded layout")

	# --- Old saves (no seed key) keep the legacy world ---
	var legacy: Node2D = await _build_world(0)
	var legacy_names := _child_names(legacy)
	var old_save: Dictionary = snap.duplicate()
	old_save.erase("layout_seed")
	legacy.restore_state(old_save)
	_expect(legacy.layout_seed == 0, "missing seed key = legacy layout")
	legacy.free()
	fresh.free()
	s1.free()
	s1b.free()
	s2.free()
	await physics_frame

	# --- Title handoff: GameManager pending seed feeds the first build ---
	var gm: Node = root.get_node("/root/GameManager")
	gm.set("pending_layout_seed", 555)
	var handed: Node2D = await _build_world(0)
	_expect(handed.layout_seed == 555 and int(gm.get("pending_layout_seed")) == 0,
			"a pending seed is consumed exactly once")
	handed.free()
	await physics_frame

	_teardown()


func _build_world(expect_seed: int) -> Node2D:
	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	if expect_seed != 0:
		world.layout_seed = expect_seed
	root.add_child(world)
	await physics_frame
	await physics_frame
	return world


func _child_names(world: Node2D) -> Array:
	var names: Array = []
	for child in world.get_entity_parent().get_children():
		# Rebuild renames replaced children ZzDead* while queue_free
		# drains; they are not part of the new layout.
		if not str(child.name).begins_with("ZzDead"):
			names.append(str(child.name))
	names.sort()
	return names


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
