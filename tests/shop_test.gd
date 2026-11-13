extends SceneTree
## Headless test for the expedition economy (X9): marks awards (first
## run 5, record 3, routine 1), the keeper's shop (buy applies the
## boost, deducts marks, refuses when short), and the counter replay on
## a fresh main (bought stats survive restarts).

var _failures := 0
var _cache_backup := ""
var _memory_backup := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_memory_backup = TestIsolation.stash(TestIsolation.MEMORY_PATH)
	_cache_backup = TestIsolation.stash(TestIsolation.CACHE_PATH)
	SpellCache.reset()
	WorldMemory.reset()
	Weather.reset()

	# --- Marks award matrix through real expeditions ---
	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	for i in 2:
		await physics_frame
	var keeper: Node2D = world.get_entity_parent().get_node_or_null("Keeper")
	WorldMemory.record_and_persist(WorldMemory.EVENT_QUEST_DONE)
	var go: Dictionary = keeper.call("confirm_action", null, "accept_expedition")
	_expect(bool(go["ok"]), "expedition accepted")
	var echo: CharacterBody2D = world.get_entity_parent().get_node_or_null("SlimeEliteEcho")
	echo.call("take_damage", 999.0, Vector2.RIGHT)
	await physics_frame
	_expect(WorldMemory.counter("expedition_marks") == 5,
			"the first run pays 5 marks (got %d)" % WorldMemory.counter("expedition_marks"))

	# Second run, slower (the clock ticks first): routine +1.
	keeper.call("confirm_action", null, "accept_expedition")
	var echo2: CharacterBody2D = world.get_entity_parent().get_node_or_null("SlimeEliteEcho")
	for i in 45:
		await physics_frame
	echo2.call("take_damage", 999.0, Vector2.RIGHT)
	await physics_frame
	_expect(WorldMemory.counter("expedition_marks") == 6,
			"a slower routine run pays 1 mark (got %d)" % WorldMemory.counter("expedition_marks"))

	# Third run, even slower than the record: routine +1 again.
	keeper.call("confirm_action", null, "accept_expedition")
	var echo3: CharacterBody2D = world.get_entity_parent().get_node_or_null("SlimeEliteEcho")
	for i in 60:
		await physics_frame
	echo3.call("take_damage", 999.0, Vector2.RIGHT)
	await physics_frame
	_expect(WorldMemory.counter("expedition_marks") == 7,
			"another routine run pays 1 mark (got %d)" % WorldMemory.counter("expedition_marks"))

	# --- The shop: buy, deduct, refuse when short ---
	var player: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	player.hp = 9999.0
	world.get_entity_parent().add_child(player)
	await physics_frame
	var shop: PanelContainer = load("res://scripts/ui/shop_panel.gd").new()
	root.add_child(shop)
	shop.call("open", player)
	var goods: VBoxContainer = shop.get_node("Margin/Rows/Goods")
	_expect(goods.get_child_count() == 3, "three goods on the shelves")
	# Two more routine runs elsewhere brought the tally to 12.
	WorldMemory.bump_counter("expedition_marks", 5)
	var wind_row: HBoxContainer = goods.get_child(2)
	var buy_button: Button = wind_row.get_child(2)
	buy_button.emit_signal("pressed")
	await physics_frame
	_expect(WorldMemory.counter("expedition_marks") == 4
			and absf(float(player.get("speed_mult")) - 1.15) < 0.001,
			"the windrunner costs 8 and speeds up the player")
	# Marks are short now (4 < 3 is false — buy a bottle instead to
	# drain below the next price: 4-3=1).
	# _refresh rebuilds every row after a purchase: re-fetch nodes.
	var mana_row: HBoxContainer = goods.get_child(0)
	(mana_row.get_child(2) as Button).emit_signal("pressed")
	await physics_frame
	_expect(WorldMemory.counter("expedition_marks") == 1
			and WorldMemory.counter("bought_mana") == 1,
			"the mana bottle drains to 1")
	# Now every further purchase is refused (1 < 3) — fresh nodes again.
	var wind2: HBoxContainer = goods.get_child(2)
	(wind2.get_child(2) as Button).emit_signal("pressed")
	await physics_frame
	_expect(WorldMemory.counter("expedition_marks") == 1
			and WorldMemory.counter("bought_windrunner") == 1,
			"a purchase without marks is refused")
	# Direct _buy call (button path already covered): another bottle.
	WorldMemory.bump_counter("expedition_marks", 3)
	shop.call("_buy", "mana_bottle")
	_expect(WorldMemory.counter("bought_mana") == 2
			and absf(120.0 - float(player.get("mana_max"))) < 0.01,
			"a second bottle stacks the max mana")
	WorldMemory.bump_counter("expedition_marks", 3)
	shop.call("_buy", "ironfruit")
	_expect(WorldMemory.counter("bought_hp") == 1
			and absf(40.0 - float(player.get("hp_max"))) < 0.01,
			"the ironfruit applies +10 max hp")
	shop.call("close")
	await physics_frame

	# --- Replay on a fresh main ---
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 4:
		await physics_frame
	var p2: CharacterBody2D = find_player(main)
	_expect(p2 != null and absf(float(p2.get("mana_max")) - 120.0) < 0.01
			and absf(float(p2.get("hp_max")) - 40.0) < 0.01
			and absf(float(p2.get("speed_mult")) - 1.15) < 0.001,
			"shop purchases replay on a fresh build")
	main.queue_free()
	await physics_frame
	shop.free()
	await physics_frame

	_teardown()


func find_player(main: Node2D) -> CharacterBody2D:
	for child in main.get_node("World").get_entity_parent().get_children():
		if child is CharacterBody2D and child.name == "Player":
			return child
	return null


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
