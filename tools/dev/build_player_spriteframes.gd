extends SceneTree
## One-shot: build the player SpriteFrames resource from the generated
## character sprites. Animations:
##   idle_{down,up,left,right}  (1 frame)
##   walk_{down,up,left,right}  (stride A, idle, stride B, idle @ 7 fps)
##
##   godot --headless --path . -s res://tools/dev/build_player_spriteframes.gd
##
## Requires the player_*.png files to be imported already.

const DIR := "res://assets/sprites/player"
const OUT_PATH := "res://assets/sprites/player/player_frames.tres"
const WALK_FPS := 7.0
const DIRECTIONS := ["down", "up", "left", "right"]


func _init() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for dir_name in DIRECTIONS:
		var idle: Texture2D = load("%s/player_%s_idle.png" % [DIR, dir_name])
		var a: Texture2D = load("%s/player_%s_a.png" % [DIR, dir_name])
		var b: Texture2D = load("%s/player_%s_b.png" % [DIR, dir_name])

		var idle_anim: String = "idle_" + dir_name
		frames.add_animation(idle_anim)
		frames.add_frame(idle_anim, idle)
		frames.set_animation_speed(idle_anim, 1.0)
		frames.set_animation_loop(idle_anim, true)

		var walk_anim: String = "walk_" + dir_name
		frames.add_animation(walk_anim)
		for tex in [a, idle, b, idle]:
			frames.add_frame(walk_anim, tex)
		frames.set_animation_speed(walk_anim, WALK_FPS)
		frames.set_animation_loop(walk_anim, true)

	frames.resource_name = "PlayerFrames"
	var err := ResourceSaver.save(frames, OUT_PATH)
	if err != OK:
		push_error("[playerframes] save failed: %s" % err)
		quit(1)
		return
	print("[playerframes] saved " + OUT_PATH)
	quit()
