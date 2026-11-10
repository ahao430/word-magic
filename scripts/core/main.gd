extends Node2D
## Main scene entry: world + player + HUD. Phase 1.


func _ready() -> void:
	GameManager.set_state(GameManager.GameState.PLAYING)
