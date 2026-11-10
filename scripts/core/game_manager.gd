extends Node
## GameManager — minimal global game-state service (Autoload).
## Phase 0 scope: track boot state and provide one log helper.
## Anything beyond this (save/load, mode switching) arrives with the
## phase that actually needs it, per AGENTS.md §3.1.

enum GameState { BOOT, MENU, PLAYING, PAUSED }

var state: GameState = GameState.BOOT

## Set by the title screen's "continue" button; main.gd consumes it on
## _ready and loads the chosen slot instead of a fresh adventure.
var pending_load_session := false
var pending_load_slot := "slot_01"


func set_state(new_state: GameState) -> void:
	if new_state == state:
		return
	var old: GameState = state
	state = new_state
	log_info("GameState %s -> %s" % [GameState.keys()[old], GameState.keys()[new_state]])


func log_info(message: String) -> void:
	# Single funnel for early logging; replace with a real logger when needed.
	print("[WordMagic] ", message)
