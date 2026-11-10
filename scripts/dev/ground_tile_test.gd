extends Node2D
## Dev-only validation scene: renders a 10x10 patch of the production
## ground tiles and captures the viewport to a PNG so tiling quality
## (opacity, seams, filtering) can be inspected outside the editor.
##
## Run:  godot --path . res://scenes/dev/ground_tile_test.tscn --quit-after 120
## Output is written next to the project as ground_tile_test_render.png
## (absolute path if writable, otherwise user://).

const TILE_PATHS := [
	"res://assets/tilesets/forest/ground/grass_plain.png",
	"res://assets/tilesets/forest/ground/grass_dense.png",
	"res://assets/tilesets/forest/ground/grass_flowers.png",
	"res://assets/tilesets/forest/ground/dirt_plain.png",
	"res://assets/tilesets/forest/ground/dirt_variant.png",
	"res://assets/tilesets/forest/ground/dirt_grassy_edge.png",
	"res://assets/tilesets/forest/ground/stone_paving.png",
	"res://assets/tilesets/forest/ground/stone_moss.png",
]

const GRID := 10
const TILE_SIZE := 32


func _ready() -> void:
	var origin := Vector2(
		(get_viewport_rect().size.x - GRID * TILE_SIZE) * 0.5,
		(get_viewport_rect().size.y - GRID * TILE_SIZE) * 0.5
	)
	for y in GRID:
		for x in GRID:
			var sprite := Sprite2D.new()
			sprite.texture = load(TILE_PATHS[(x * GRID + y) % TILE_PATHS.size()])
			sprite.position = origin + Vector2(x, y) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
			add_child(sprite)

	# Let two frames render, then capture and quit.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_capture()
	get_tree().quit()


func _capture() -> void:
	var img := get_viewport().get_texture().get_image()
	var abs_path := ProjectSettings.globalize_path("res://") + "ground_tile_test_render.png"
	if img.save_png(abs_path) == OK:
		GameManager.log_info("tile test render saved: " + abs_path)
	else:
		var user_path := "user://ground_tile_test_render.png"
		img.save_png(user_path)
		GameManager.log_info("tile test render saved: " + ProjectSettings.globalize_path(user_path))
