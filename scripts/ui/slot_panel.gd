extends Control
## Save-slot chooser, shared by the in-game F5/F9 shortcuts and the
## title screen's "continue" button. Two modes:
## - save: every slot is choosable (writing overwrites),
## - load: empty slots are disabled.
## Rows show the slot's meta card (timestamp + summary) or "empty".

signal slot_chosen(slot: String)
signal closed

const SLOT_COUNT := 3  # mirrors SaveManager.SLOT_COUNT

var _mode := "save"

@onready var title_label: Label = $Panel/Margin/Rows/TitleLabel
@onready var rows: VBoxContainer = $Panel/Margin/Rows/SlotRows


func _ready() -> void:
	visible = false
	for i in SLOT_COUNT:
		_add_slot_row(i)


func open_save_mode() -> void:
	_open("save")


func open_load_mode() -> void:
	_open("load")


func _open(mode: String) -> void:
	_mode = mode
	_refresh_rows()
	visible = true
	var first := _choose_button(0)
	if first != null:
		first.grab_focus()


func _process(_delta: float) -> void:
	if visible and Input.is_action_just_pressed("pause"):
		_close()


func _close() -> void:
	visible = false
	closed.emit()


func _refresh_rows() -> void:
	title_label.text = "保存冒险" if _mode == "save" else "读取冒险"
	for i in SLOT_COUNT:
		var slot := SaveManager.slot_id(i + 1)
		var exists := SaveManager.slot_exists(slot)
		var meta := {}
		if exists:
			meta = SaveManager.load_game(slot)["meta"]
		var summary := "（空槽）"
		if exists:
			summary = "%s · %s" % [str(meta.get("saved_at", "未知时间")),
					str(meta.get("summary", ""))]
		_summary_label(i).text = summary
		var choose := _choose_button(i)
		choose.text = "保存到此" if _mode == "save" else "读取"
		# Saving may overwrite anything; loading needs an existing save.
		choose.disabled = _mode == "load" and not exists
		choose.focus_mode = Control.FOCUS_NONE if choose.disabled else Control.FOCUS_ALL
		_delete_button(i).visible = exists


func _on_choose_pressed(index: int) -> void:
	visible = false
	slot_chosen.emit(SaveManager.slot_id(index + 1))


func _on_delete_pressed(index: int) -> void:
	SaveManager.delete_slot(SaveManager.slot_id(index + 1))
	_refresh_rows()
	var first := _choose_button(0)
	if first != null:
		first.grab_focus()


func _choose_button(index: int) -> Button:
	return rows.get_node("Slot%d/ChooseButton" % (index + 1))


func _delete_button(index: int) -> Button:
	return rows.get_node("Slot%d/DeleteButton" % (index + 1))


func _summary_label(index: int) -> Label:
	return rows.get_node("Slot%d/Info/SummaryLabel" % (index + 1))


## Row factory: builds the three slot cards once, wiring the buttons.
func _add_slot_row(index: int) -> void:
	var row := HBoxContainer.new()
	row.name = "Slot%d" % (index + 1)
	var info := VBoxContainer.new()
	info.name = "Info"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = "槽位 %d" % (index + 1)
	info.add_child(name_label)
	var summary := Label.new()
	summary.name = "SummaryLabel"
	summary.modulate = Color(0.7, 0.75, 0.7)
	info.add_child(summary)
	row.add_child(info)
	var choose := Button.new()
	choose.name = "ChooseButton"
	choose.text = "保存到此"
	choose.pressed.connect(_on_choose_pressed.bind(index))
	row.add_child(choose)
	var delete := Button.new()
	delete.name = "DeleteButton"
	delete.text = "删除"
	delete.pressed.connect(_on_delete_pressed.bind(index))
	row.add_child(delete)
	rows.add_child(row)


func _ready_add_rows() -> void:
	for i in SLOT_COUNT:
		_add_slot_row(i)
