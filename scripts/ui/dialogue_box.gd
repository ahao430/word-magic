extends PanelContainer
## Bottom dialogue box (code-built UI, no scene file): speaker name,
## wrapped text, key hint. E advances (main routes the key), Esc closes
## at any page; the pause panel yields to an open dialogue.

## closed(via_advance): true when the last page was E-confirmed;
## false on Esc — quest offers only commit on via_advance.
signal closed(via_advance: bool)

## Emitted when the player clicks an end-page option button; the box
## closes first, main routes the action (shop, etc.).
signal option_chosen(action: String)

var _speaker_label: Label
var _option_row: HBoxContainer
var _text_label: Label
var _hint_label: Label
var _lines: Array = []
var _options: Array = []
var _index := 0


func _init() -> void:
	name = "DialogueBox"
	visible = false
	custom_minimum_size = Vector2(680, 128)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM,
			Control.PRESET_MODE_MINSIZE, 20)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var rows := VBoxContainer.new()
	margin.add_child(rows)
	_option_row = HBoxContainer.new()
	_option_row.add_theme_constant_override("separation", 10)
	rows.add_child(_option_row)
	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 18)
	rows.add_child(_speaker_label)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(640, 0)
	rows.add_child(_text_label)
	_hint_label = Label.new()
	_hint_label.modulate = Color(1, 1, 1, 0.6)
	_hint_label.text = "E 继续 · Esc 结束"
	rows.add_child(_hint_label)


func _process(_delta: float) -> void:
	# Esc while open ends the conversation (the pause panel yields).
	if visible and Input.is_action_just_pressed("pause"):
		close(false)


func open(speaker: String, lines: Array, options: Array = []) -> void:
	_lines = lines
	_options = options
	_index = 0
	_speaker_label.text = speaker
	visible = true
	_render()


## One E press: next page, or close on the last. Returns true while
## the conversation continues.
func advance() -> bool:
	if not visible:
		return false
	_index += 1
	if _index >= _lines.size():
		close(true)
		return false
	_render()
	return true


func close(via_advance := false) -> void:
	visible = false
	_lines = []
	_options = []
	_index = 0
	closed.emit(via_advance)


func _render() -> void:
	_text_label.text = str(_lines[_index])
	_hint_label.text = "E 结束" if _index >= _lines.size() - 1 else "E 继续 · Esc 结束"
	for child in _option_row.get_children():
		child.free()
	var on_last := _index >= _lines.size() - 1
	_option_row.visible = on_last and not _options.is_empty()
	if not _option_row.visible:
		return
	for opt: Dictionary in _options:
		var button := Button.new()
		button.text = str(opt.get("label", "?"))
		var action: String = str(opt.get("action", ""))
		button.pressed.connect(func() -> void:
			close(false)
			option_chosen.emit(action))
		_option_row.add_child(button)
