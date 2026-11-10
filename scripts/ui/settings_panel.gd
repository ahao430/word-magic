extends Control
## Title-screen settings overlay: music / SFX volume sliders and a
## fullscreen toggle, persisted through Settings on every change.

@onready var music_slider: HSlider = $Panel/Margin/Rows/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $Panel/Margin/Rows/SfxRow/SfxSlider
@onready var fullscreen_toggle: CheckButton = $Panel/Margin/Rows/FullscreenRow/FullscreenToggle
@onready var back_button: Button = $Panel/Margin/Rows/BackButton


func _ready() -> void:
	visible = false
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(_close)


## Show with current values applied (called by the title screen).
func open() -> void:
	music_slider.set_value_no_signal(Settings.music_volume)
	sfx_slider.set_value_no_signal(Settings.sfx_volume)
	fullscreen_toggle.set_pressed_no_signal(Settings.fullscreen)
	visible = true
	back_button.grab_focus()


func _close() -> void:
	visible = false
	Settings.save_settings()


func _on_music_changed(value: float) -> void:
	Settings.music_volume = value
	Settings.apply()


func _on_sfx_changed(value: float) -> void:
	Settings.sfx_volume = value
	Settings.apply()


func _on_fullscreen_toggled(pressed: bool) -> void:
	Settings.fullscreen = pressed
	Settings.apply()
