extends Node2D
## Main scene entry. Phase 0: confirm boot, show minimal status UI.


func _ready() -> void:
	GameManager.set_state(GameManager.GameState.MENU)
	var label := Label.new()
	label.text = "Word Magic — Phase 0\n(ground tile test: scenes/dev/ground_tile_test.tscn)"
	label.position = Vector2(32, 32)
	add_child(label)
