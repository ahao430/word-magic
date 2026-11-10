extends Node2D
## Main scene entry: world + player + HUD (mana bar, cast input).
## UI never parses spells — text submission goes straight to
## MagicFacade, which owns the casting pipeline (AGENTS.md §6.1).

const MAGIC := preload("res://scripts/magic/magic_facade.gd")

@onready var player: CharacterBody2D = $Player
@onready var mana_bar: ProgressBar = $HUD/ManaBar
@onready var mana_label: Label = $HUD/ManaLabel
@onready var hp_bar: ProgressBar = $HUD/HpBar
@onready var hp_label: Label = $HUD/HpLabel
@onready var cast_result: Label = $HUD/CastResult
@onready var cast_input: LineEdit = $HUD/CastInput
@onready var spellbook: PanelContainer = $HUD/Spellbook
@onready var spellbook_list: VBoxContainer = $HUD/Spellbook/Margin/Rows/ListScroll/List
@onready var spellbook_filter: LineEdit = $HUD/Spellbook/Margin/Rows/FilterInput
@onready var spellbook_empty: Label = $HUD/Spellbook/Margin/Rows/EmptyHint
@onready var boss_bar: ProgressBar = $HUD/BossBar
@onready var boss_label: Label = $HUD/BossLabel

## One spell session per adventure (uniqueness + codex).
var spell_session := SpellSession.new()

var _result_clear_timer: SceneTreeTimer


func _ready() -> void:
	# Reparent the player into the world's y-sorted props layer so the
	# player interleaves correctly with tree canopies while walking.
	player.reparent($World.get_entity_parent(), true)
	# Camera clamps to the map rectangle so edges never show void.
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam != null:
		var map_px: Vector2 = $World.map_pixel_size()
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = int(map_px.x)
		cam.limit_bottom = int(map_px.y)
	cast_input.text_submitted.connect(_on_cast_submitted)
	spellbook_filter.text_changed.connect(_on_spellbook_filter)
	$World.boss_died.connect(func() -> void:
		_toast("史莱姆王倒下了！森林深处恢复了平静", true))
	GameManager.set_state(GameManager.GameState.PLAYING)
	# One frame late: attaching the music player during _ready makes the
	# busy root reject add_child.
	await get_tree().process_frame
	Music.play("explore_loop")
	# Title-screen "continue" hands off through this flag (the save is
	# loaded once the whole scene is live, so toasts and restores land).
	if GameManager.pending_load_session:
		GameManager.pending_load_session = false
		_do_load()


func _process(_delta: float) -> void:
	mana_bar.value = player.mana
	hp_bar.value = player.hp
	mana_label.text = "魔力 %d/100" % roundi(player.mana)
	hp_label.text = "生命 %d/%d" % [roundi(player.hp), roundi(player.HP_MAX)]
	if Input.is_action_just_pressed("toggle_spellbook"):
		spellbook.visible = not spellbook.visible
	if Input.is_action_just_pressed("save_game"):
		_do_save()
	if Input.is_action_just_pressed("load_game"):
		_do_load()
	if Input.is_action_just_pressed("reset_world"):
		_do_world_reset()
	_update_boss_bar()


## Boss health bar: visible only while the Slime King is alive and
## aggro'd (duck-typed reads keep the HUD decoupled from the boss class).
func _update_boss_bar() -> void:
	var show_bar := false
	var boss: Node2D = $World.get_boss()
	if boss != null and is_instance_valid(boss) and bool(boss.get("alive")) \
			and bool(boss.get("aggro")):
		boss_bar.max_value = float(boss.get("hp_max"))
		boss_bar.value = float(boss.get("hp"))
		show_bar = true
	boss_bar.visible = show_bar
	boss_label.visible = show_bar


## F8 dev reset: forget permanent world progress (world memory file)
## and rebuild the scene from seed. Session save is untouched.
func _do_world_reset() -> void:
	var result: Dictionary = WorldMemory.clear_persisted()
	if not result["ok"]:
		_toast("世界记忆清除失败：" + result["error"], false)
		return
	GameManager.log_info("world memory cleared; rebuilding world from seed")
	get_tree().reload_current_scene()


func _do_save() -> void:
	var state := {
		"player": {"x": player.global_position.x, "y": player.global_position.y,
				"hp": player.hp, "mana": player.mana},
		"session": spell_session.capture_state(),
		"world": $World.capture_state(),
	}
	var result: Dictionary = SaveManager.save_game(state)
	if result["ok"]:
		_toast("冒险已记录（F9 读取）", true)
	else:
		_toast("保存失败：" + result["error"], false)


func _do_load() -> void:
	var result: Dictionary = SaveManager.load_game()
	if not result["ok"]:
		_toast("读取失败：" + result["error"], false)
		return
	var state: Dictionary = result["state"]
	var p: Dictionary = state.get("player", {})
	if not p.is_empty():
		player.global_position = Vector2(p.get("x", 784.0), p.get("y", 528.0))
		player.hp = p.get("hp", 30.0)
		player.mana = p.get("mana", 100.0)
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam != null:
			cam.reset_smoothing()
	spell_session.restore_state(state.get("session", {}))
	$World.restore_state(state.get("world", {}))
	_rebuild_codex_ui()
	_toast("冒险已恢复", true)


func _rebuild_codex_ui() -> void:
	# Immediate free: queue_free lingers a frame and duplicates rows.
	for child in spellbook_list.get_children():
		child.free()
	for row in spell_session.codex:
		_add_codex_row(row)
	spellbook_empty.visible = spell_session.codex.is_empty()
	_apply_codex_filter()


## Live filter: rows carry their search text as metadata; empty query
## shows everything.
func _on_spellbook_filter(_text: String) -> void:
	_apply_codex_filter()


func _apply_codex_filter() -> void:
	var query := spellbook_filter.text.to_lower()
	for row in spellbook_list.get_children():
		var haystack := String(row.get_meta("filter", ""))
		row.visible = query.is_empty() or query in haystack


## Rising token: only the newest toast's timer may clear the label.
var _toast_token := 0


func _toast(message: String, ok: bool) -> void:
	cast_result.text = message
	cast_result.add_theme_color_override("font_color",
			Color(0.7, 1.0, 0.7) if ok else Color(1.0, 0.65, 0.6))
	_toast_token += 1
	var token := _toast_token
	_result_clear_timer = get_tree().create_timer(3.0)
	_result_clear_timer.timeout.connect(func():
		if token == _toast_token:
			cast_result.text = "")


func _on_cast_submitted(text: String) -> void:
	cast_input.clear()
	cast_input.release_focus()
	var result: Dictionary = MAGIC.cast(text, player, $World, spell_session)
	cast_result.text = result["message"]
	if result["ok"]:
		cast_result.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
		GameManager.log_info("cast '%s' ok, cost %d" % [text, result["cost"]])
		_add_codex_row(result["spell"])
		# Puzzle reactions (rule-based, game-side validation).
		var puzzle_msg: String = $World.on_spell_cast(result["spell"], player.global_position)
		if puzzle_msg != "":
			cast_result.text = result["message"] + "\n" + puzzle_msg
			GameManager.log_info("puzzle: " + puzzle_msg)
	else:
		cast_result.add_theme_color_override("font_color", Color(1.0, 0.65, 0.6))
		GameManager.log_info("cast '%s' failed: %s" % [text, result["reason"]])
	_result_clear_timer = get_tree().create_timer(3.0)
	_result_clear_timer.timeout.connect(func(): cast_result.text = "")


func _add_codex_row(spell: Dictionary) -> void:
	var row := Label.new()
	var element: String = spell.get("element", "")
	row.text = "%s · %s · %s · %d 魔力" % [
			spell.get("display", "?"),
			_element_name(element),
			spell.get("shape", "?"),
			spell.get("cost", 0)]
	# Searchable text: name + raw and localized element (火 / fire both
	# match) + shape.
	row.set_meta("filter", ("%s %s %s %s" % [
			spell.get("display", ""),
			element,
			_element_name(element),
			spell.get("shape", "")]).to_lower())
	spellbook_list.add_child(row)
	spellbook_empty.visible = spell_session.codex.is_empty()


func _element_name(element: String) -> String:
	match element:
		"fire":
			return "火"
		"ice":
			return "冰"
		"lightning":
			return "雷"
		"nature":
			return "自然"
		"wind":
			return "风"
	return element
