extends Node2D
## Dev-only: instances the real main scene, captures three screenshots
## (idle, after walking right, and mid-cast with a fireball flying) to
## verify map/player/casting rendering outside the editor.
##
##   godot --path . res://scenes/dev/gameplay_screenshot.tscn --quit-after 900

const SHOT_A := "/tmp/wm_gameplay_idle.png"
const SHOT_B := "/tmp/wm_gameplay_moved.png"
const SHOT_C := "/tmp/wm_gameplay_cast.png"
const SHOT_D := "/tmp/wm_gameplay_spellbook.png"
const SHOT_E := "/tmp/wm_gameplay_puzzle.png"

const MAGIC := preload("res://scripts/magic/magic_facade.gd")

## This dev scene kills the boss and builds the ford and casts spells —
## all persist to real user:// files. Stash and restore them so the
## screenshot run never touches the developer's meta-progress.
var _memory_backup := ""
var _cache_backup := ""


func _ready() -> void:
	_memory_backup = TestIsolation.stash(TestIsolation.MEMORY_PATH)
	_cache_backup = TestIsolation.stash(TestIsolation.CACHE_PATH)
	WorldMemory.reset()
	SpellCache.reset()

	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_capture(SHOT_A)
	print("[shot] idle saved")

	Input.action_press("move_right")
	for i in 90:
		await RenderingServer.frame_post_draw
	Input.action_release("move_right")
	await RenderingServer.frame_post_draw
	_capture(SHOT_B)
	print("[shot] moved saved")

	# Cast a fireball at a slime placed right of the player and catch
	# the impact frame.
	var player: CharacterBody2D = null
	for child in main.get_node("World").get_entity_parent().get_children():
		if child is CharacterBody2D and child.name == "Player":
			player = child
			break
	var slime: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	slime.position = player.global_position + Vector2(150, 0)
	main.get_node("World").get_entity_parent().add_child(slime)
	await RenderingServer.frame_post_draw

	Input.action_press("move_right")
	await RenderingServer.frame_post_draw
	Input.action_release("move_right")

	var result: Dictionary = await MAGIC.cast("火球术", player, main.get_node("World"), SpellSession.new())
	print("[shot] cast: ", result["message"], " cost ", result["cost"])
	for i in 18:
		await RenderingServer.frame_post_draw  # ~impact at 150px / 300px/s
	_capture(SHOT_C)
	print("[shot] cast saved")

	# Open the spellbook panel to show the codex entry.
	main.get_node("HUD/Spellbook").visible = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_capture(SHOT_D)
	print("[shot] spellbook saved")
	main.get_node("HUD/Spellbook").visible = false

	# Walk the puzzle path: stand by the rune stone, cast ice, catch
	# the awakened stone with the new ford across the river.
	var world: Node2D = main.get_node("World")
	player.position = Vector2(13 * 32 + 16, 12 * 32 + 40)
	await RenderingServer.frame_post_draw
	var puzzle_result: Dictionary = await MAGIC.cast("寒冰箭", player, world, SpellSession.new())
	if puzzle_result["ok"]:
		# Mirror main.gd: forward the cast to puzzle nodes.
		print("[shot] puzzle: ", world.on_spell_cast(puzzle_result["spell"], player.global_position))
	else:
		print("[shot] puzzle cast failed: ", puzzle_result["reason"])
	for i in 45:
		await RenderingServer.frame_post_draw
	_capture(SHOT_E)
	print("[shot] puzzle saved")

	# Water animation proof: teleport by the river source, capture two
	# frames half a second apart (waterfall scroll + water shimmer).
	player.position = Vector2(14 * 32 + 16, 6 * 32 + 16)
	for i in 5:
		await RenderingServer.frame_post_draw
	_capture("/tmp/wm_river_t0.png")
	print("[shot] river t0 saved")
	for i in 30:
		await RenderingServer.frame_post_draw
	_capture("/tmp/wm_river_t1.png")
	print("[shot] river t1 saved")

	# Boss encounter: step into the NE arena, catch the king aggro'd with
	# the HUD health bar, then defeat him and catch the toast + death pose.
	player.position = Vector2(38 * 32 + 16, 8 * 32 + 26) + Vector2(-140, 60)
	for i in 40:
		await RenderingServer.frame_post_draw
	_capture("/tmp/wm_boss_aggro.png")
	print("[shot] boss aggro saved")

	# Pause overlay: show the panel exactly as Esc would.
	var pause_panel: PanelContainer = main.get_node("HUD/PausePanel")
	pause_panel.visible = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_capture("/tmp/wm_pause.png")
	print("[shot] pause saved")
	pause_panel.visible = false

	var boss: Node2D = main.get_node("World").get_boss()
	if boss != null and is_instance_valid(boss):
		# Catch a wind-up frame so the telegraph ring is in the shot —
		# mid-wind-up, once the squash and ring pulse are readable.
		for i in 400:
			await RenderingServer.frame_post_draw
			if int(boss.get("state")) == 2:
				for j in 24:
					await RenderingServer.frame_post_draw
				break
		_capture("/tmp/wm_boss_windup.png")
		print("[shot] boss windup saved")
		boss.call("take_damage", 999.0, Vector2.RIGHT)
	for i in 12:
		await RenderingServer.frame_post_draw
	_capture("/tmp/wm_boss_dying.png")
	print("[shot] boss dying saved")
	for i in 50:
		await RenderingServer.frame_post_draw
	_capture("/tmp/wm_boss_defeated.png")
	print("[shot] boss defeated saved")

	_restore_memory()
	get_tree().quit()


func _restore_memory() -> void:
	TestIsolation.unstash(TestIsolation.MEMORY_PATH, _memory_backup)
	TestIsolation.unstash(TestIsolation.CACHE_PATH, _cache_backup)
	WorldMemory.reset()
	SpellCache.reset()


func _capture(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img.save_png(path) != OK:
		push_error("[shot] failed to save " + path)
