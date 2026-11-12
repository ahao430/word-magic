extends PanelContainer
## 旅程面板 (Journey page): the world-memory visualization — lifetime
## counters (kills, casts, deaths, expeditions) plus the permanent
## event timeline. Read-only, built in code, lives on the HUD next to
## the pause panel; Esc closes it before the pause resumes.

signal closed

var _stats_rows: VBoxContainer
var _timeline_rows: VBoxContainer


func _init() -> void:
	name = "JourneyPanel"
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(520, 420)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER,
			Control.PRESET_MODE_MINSIZE)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	for m in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(m, 20)
	for m in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 14)
	add_child(margin)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 8)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "—— 旅程 ——"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)

	_stats_rows = VBoxContainer.new()
	rows.add_child(_stats_rows)

	var divider := HSeparator.new()
	rows.add_child(divider)

	var timeline_title := Label.new()
	timeline_title.text = "世界记忆"
	timeline_title.add_theme_font_size_override("font_size", 16)
	timeline_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timeline_title.modulate = Color(1, 1, 1, 0.75)
	rows.add_child(timeline_title)

	_timeline_rows = VBoxContainer.new()
	rows.add_child(_timeline_rows)

	var hint := Label.new()
	hint.text = "Esc 返回暂停菜单"
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(hint)


## Refresh straight from the permanent tier, then show.
func open() -> void:
	_refresh()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _process(_delta: float) -> void:
	if visible and Input.is_action_just_pressed("pause"):
		close()


func _refresh() -> void:
	for child in _stats_rows.get_children():
		child.free()
	for child in _timeline_rows.get_children():
		child.free()

	# --- Lifetime counters ---
	var entries := [
		["击倒史莱姆", str(WorldMemory.counter("slain_slimes"))],
		["击落沼泽蝇", str(WorldMemory.counter("slain_flies"))],
		["施法成功", str(WorldMemory.counter("casts_ok"))],
		["倒下次数", str(WorldMemory.counter("deaths"))],
	]
	var runs := WorldMemory.counter("expedition_runs")
	if runs > 0:
		var best: Dictionary = WorldMemory.get_event(WorldMemory.EVENT_EXPEDITION)
		var best_text := "—" if best.is_empty() else "%.1f 秒" % float(best.get("best_seconds", 0.0))
		entries.append(["远征次数", "%d · 最佳 %s" % [runs, best_text]])
	for entry in entries:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = entry[0]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var value := Label.new()
		value.text = entry[1]
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		_stats_rows.add_child(row)

	# --- Permanent event timeline ---
	var timeline := [
		[WorldMemory.EVENT_RUNE, "✦ 符文石苏醒"],
		[WorldMemory.EVENT_FORD, "✦ 渡口落成"],
		[WorldMemory.EVENT_REGION, "✦ 踏入迷雾湿地"],
		[WorldMemory.EVENT_SPRING, "✦ 沼泽灵泉取用"],
		[WorldMemory.EVENT_ELITE, "✦ 深沼精英陨落"],
		[WorldMemory.EVENT_QUEST_TAKEN, "✦ 接受取心委托"],
		[WorldMemory.EVENT_QUEST_DONE, "✦ 委托完成 · 习得激流贯射"],
		[WorldMemory.EVENT_BOSS, "✦ 史莱姆王陨落"],
	]
	for entry in timeline:
		if WorldMemory.has_event(entry[0]):
			var line := Label.new()
			line.text = entry[1]
			line.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8))
			_timeline_rows.add_child(line)
	if _timeline_rows.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "（世界还记得 nothing——你的故事才刚开始）"
		empty.modulate = Color(1, 1, 1, 0.6)
		_timeline_rows.add_child(empty)
