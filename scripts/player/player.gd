extends CharacterBody2D
## Top-down player: four-direction movement with camera smoothing.
## Visuals are code-defined placeholder polygons until real character
## sprites are produced (see docs/ART_ASSET_IMPLEMENTATION.md §5).

const SPEED := 160.0

@onready var facing: Polygon2D = $Facing


func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	move_and_slide()
	if dir != Vector2.ZERO:
		facing.position = dir * 14.0
		facing.rotation = dir.angle()
