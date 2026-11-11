extends Node2D
## 沼泽灵泉 (wetland POI): a one-time blessing spring. Interact (E)
## within arm's reach grants +10 max mana, records the permanent world
## fact, and dries the pool. The world replays the memory on rebuild so
## a blessed save never re-grants.

const TEX := "res://assets/sprites/effects/field_zone_128.png"

var used := false

var _pool: Sprite2D


func _ready() -> void:
	_pool = Sprite2D.new()
	_pool.name = "Pool"
	_pool.texture = load(TEX)
	_pool.modulate = Color(0.5, 0.95, 1.0, 0.75)
	_pool.scale = Vector2(0.55, 0.35)
	add_child(_pool)
	var tw := create_tween().set_loops()
	tw.tween_property(_pool, "modulate:a", 0.45, 1.6)
	tw.tween_property(_pool, "modulate:a", 0.8, 1.6)


## Player-facing interact seam (main.gd polls for the nearest
## `interact` node). Returns {"ok": bool, "message": String}.
func interact(player: Node2D) -> Dictionary:
	if used:
		return {"ok": false, "message": "灵泉已然干涸"}
	used = true
	WorldMemory.record_and_persist(WorldMemory.EVENT_SPRING)
	if player != null and player.has_method("apply_spring_blessing"):
		player.call("apply_spring_blessing")
	_dry_up()
	return {"ok": true, "message": "沼泽灵泉赐福：魔力上限 +10"}


## World-memory replay path: mark used without re-recording or
## re-blessing (main applies the stat on build).
func force_used() -> void:
	used = true
	_dry_up()


func _dry_up() -> void:
	_pool.modulate = Color(0.45, 0.5, 0.5, 0.35)
	_pool.scale = Vector2(0.4, 0.25)
