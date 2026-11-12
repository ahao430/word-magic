extends StaticBody2D
## 守林人 (the Forest Keeper): the first NPC, standing by the wetland
## gate. Reads the world's permanent memory and comments on it — the
## plan.md "NPC 长期反馈" seed. The dialogue payload is pure data;
## main's dialogue box owns all presentation.

const TEX := "res://assets/sprites/npc/keeper.png"


func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "KeeperSprite"
	sprite.texture = load(TEX)
	sprite.position = Vector2(0, -sprite.texture.get_height() * 0.5)
	add_child(sprite)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 10)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -5)
	add_child(col)


## Interact seam (main routes E to the nearest `interact` node).
func interact(_player: Node2D) -> Dictionary:
	var lines: Array = build_lines({
		"boss_dead": WorldMemory.has_event(WorldMemory.EVENT_BOSS),
		"wetland_found": WorldMemory.has_event(WorldMemory.EVENT_REGION),
		"elite_dead": WorldMemory.has_event(WorldMemory.EVENT_ELITE),
	})
	return {"ok": true, "dialogue": {"speaker": "守林人", "lines": lines}}


## Pure line builder: the keeper's memory of the world. Lines change
## with permanent progress so conversations never repeat themselves.
static func build_lines(state: Dictionary) -> Array:
	var out := ["旅行者……你也是听见咒语之声的人吗？"]
	if state.get("boss_dead", false):
		out.append("东北空地的王倒下了。森林好久没有这么安静——多亏了你。")
	else:
		out.append("东北空地的史莱姆王仍在沉睡……或者说，在等一个挑战者。")
	if state.get("wetland_found", false):
		out.append("你已经踏入石门后的湿地了。那口灵泉，还有深沼里的老家伙，都值得一探。")
		if state.get("elite_dead", false):
			out.append("深沼的家伙也倒了？它的心想必认了新主人。")
	else:
		out.append("石门之后的事，要你自己去看。带一把伞。")
	out.append("愿言语与你同行。")
	return out
