extends Node2D
## Dev-only: show the title scene alone and capture it. The Control is
## added directly under root (Window) so its full-screen anchors resolve
## against the viewport instead of a zero-size Node2D parent.
##
##   godot --path . res://scenes/dev/title_screenshot.tscn --quit-after 60

func _ready() -> void:
	var title: Control = load("res://scenes/ui/title.tscn").instantiate()
	get_tree().root.add_child.call_deferred(title)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.save_png("/tmp/wm_title.png") != OK:
		push_error("[shot] failed")
	else:
		print("[shot] title saved")
	title.free()
	get_tree().quit()
