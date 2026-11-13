extends PanelContainer
## 守林人的行囊 (shop panel): a tiny code-built store fed by the
## expedition-marks economy. Buying applies instantly and records a
## counter so main's replay re-applies growth on every rebuild. Esc
## closes; the pause panel yields to it like the dialogue.

signal closed

## {id, name, desc, price, apply} — apply is the player method name
## called per purchase; main's replay maps the counter key to it.
const GOODS := [
	{"id": "mana_bottle", "name": "灵气瓶", "desc": "魔力上限 +10",
			"price": 3, "counter": "bought_mana", "apply": "apply_spring_blessing"},
	{"id": "ironfruit", "name": "生命果", "desc": "生命上限 +10",
			"price": 3, "counter": "bought_hp", "apply": "apply_swamp_heart"},
	{"id": "windrunner", "name": "疾风靴", "desc": "移动速度 +15%（一次性）",
			"price": 8, "counter": "bought_windrunner", "apply": "apply_windrunner"},
]

var _marks_label: Label
var _rows: VBoxContainer
var _player: Node2D = null


func _init() -> void:
	name = "ShopPanel"
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = UI_SIZE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	for m in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(m, 18)
	for m in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 12)
	add_child(margin)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 6)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "—— 守林人的行囊 ——"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	_marks_label = Label.new()
	_marks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_marks_label)

	_rows = VBoxContainer.new()
	_rows.name = "Goods"
	rows.add_child(_rows)

	var hint := Label.new()
	hint.text = "Esc 收起行囊"
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(hint)


## Width/height for the panel (a named const keeps _init tidy).
const UI_SIZE := Vector2(460, 300)


func _process(_delta: float) -> void:
	if visible and Input.is_action_just_pressed("pause"):
		close()


func open(player: Node2D) -> void:
	_player = player
	_refresh()
	visible = true


func close() -> void:
	visible = false
	_player = null
	closed.emit()


func _refresh() -> void:
	_marks_label.text = "远征徽记：%d" % WorldMemory.counter("expedition_marks")
	for child in _rows.get_children():
		child.free()
	for good: Dictionary in GOODS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label := Label.new()
		name_label.text = "%s · %s" % [good["name"], good["desc"]]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var price := Label.new()
		price.text = "%d 徽记" % int(good["price"])
		row.add_child(price)
		var button := Button.new()
		button.text = "购买"
		var good_id: String = str(good["id"])
		button.pressed.connect(func() -> void: _buy(good_id))
		row.add_child(button)
		_rows.add_child(row)


func _buy(good_id: String) -> void:
	var good: Dictionary = {}
	for g in GOODS:
		if str(g["id"]) == good_id:
			good = g
			break
	if good.is_empty() or _player == null:
		return
	var marks: int = WorldMemory.counter("expedition_marks")
	var price: int = int(good["price"])
	if marks < price:
		return
	WorldMemory.bump_counter("expedition_marks", -price)
	WorldMemory.bump_counter(str(good["counter"]))
	if _player.has_method(str(good["apply"])):
		_player.call(str(good["apply"]))
	_refresh()
