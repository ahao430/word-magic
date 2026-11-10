extends Node2D
## Main scene entry: world + player + HUD. Phase 1.


func _ready() -> void:
	# Reparent the player into the world's y-sorted props layer so the
	# player interleaves correctly with tree canopies while walking.
	$Player.reparent($World.get_entity_parent(), true)
	GameManager.set_state(GameManager.GameState.PLAYING)
