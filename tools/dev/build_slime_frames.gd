extends SceneTree
## One-shot: build the slime SpriteFrames resource (single "default"
## bouncing animation, 2 frames @ 3 fps).
##
##   godot --headless --path . -s res://tools/dev/build_slime_frames.gd

const DIR := "res://assets/sprites/enemies"
const OUT := "res://assets/sprites/enemies/slime_frames.tres"


func _init() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("default")
	frames.add_frame("default", load("%s/slime_idle_01.png" % DIR))
	frames.add_frame("default", load("%s/slime_idle_02.png" % DIR))
	frames.set_animation_speed("default", 3.0)
	frames.set_animation_loop("default", true)
	frames.resource_name = "SlimeFrames"
	var err := ResourceSaver.save(frames, OUT)
	if err != OK:
		push_error("[slimeframes] save failed: %s" % err)
		quit(1)
		return
	print("[slimeframes] saved " + OUT)
	quit()
