extends StaticBody2D
## 守林人 (the Forest Keeper): the first NPC, standing by the wetland
## gate. Reads the world's permanent memory and comments on it — the
## plan.md "NPC 长期反馈" seed — and runs the first quest (「取回沼泽之心」):
## E on the final offer page accepts, Esc postpones. Quest state lives
## in world memory (permanent tier); the reward is the keeper's blessing
## (+25% mana regen, applied by main on both turn-in and replay).

const TEX := "res://assets/sprites/npc/keeper.png"

const ACTION_ACCEPT := "accept_quest"
const ACTION_TURN_IN := "turn_in_quest"

signal quest_accepted
signal quest_turned_in


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


## Interact seam (main routes E to the nearest `interact` node). The
## payload may carry a pending_action that commits ONLY when the player
## E-confirms the final page (main dispatches it back here).
func interact(_player: Node2D) -> Dictionary:
	var state := {
		"boss_dead": WorldMemory.has_event(WorldMemory.EVENT_BOSS),
		"wetland_found": WorldMemory.has_event(WorldMemory.EVENT_REGION),
		"elite_dead": WorldMemory.has_event(WorldMemory.EVENT_ELITE),
		"quest_taken": WorldMemory.has_event(WorldMemory.EVENT_QUEST_TAKEN),
		"quest_done": WorldMemory.has_event(WorldMemory.EVENT_QUEST_DONE),
	}
	var payload: Dictionary = build_lines(state)
	var out := {"ok": true, "dialogue": {
			"speaker": "守林人", "lines": payload["lines"]}}
	if payload.has("action"):
		out["pending_action"] = payload["action"]
	return out


## Commit an E-confirmed action (main calls this when the dialogue
## closed on the final page). Returns {"ok": bool, "message": String}.
func confirm_action(player: Node2D, action: String) -> Dictionary:
	match action:
		ACTION_ACCEPT:
			if WorldMemory.has_event(WorldMemory.EVENT_QUEST_TAKEN):
				return {"ok": false, "message": "委托早已记下"}
			WorldMemory.record_and_persist(WorldMemory.EVENT_QUEST_TAKEN, {"quest": "swamp_heart"})
			quest_accepted.emit()
			return {"ok": true, "message": "已接受委托：取回沼泽之心（深沼在湿地东北）"}
		ACTION_TURN_IN:
			if WorldMemory.has_event(WorldMemory.EVENT_QUEST_DONE):
				return {"ok": false, "message": "这份谢意早已送出"}
			if not WorldMemory.has_event(WorldMemory.EVENT_ELITE):
				return {"ok": false, "message": "还没有那颗心的消息……"}
			WorldMemory.record_and_persist(WorldMemory.EVENT_QUEST_DONE, {"quest": "swamp_heart"})
			if player != null and player.has_method("apply_keepers_blessing"):
				player.call("apply_keepers_blessing")
			quest_turned_in.emit()
			return {"ok": true, "message": "守林人的祝福：魔力回复 +25%"}
	return {"ok": false, "message": "……"}


## Pure line builder: the keeper's memory of the world. Lines change
## with permanent progress; the quest appends an actionable final page
## (E confirms, Esc postpones — never a misclick penalty).
static func build_lines(state: Dictionary) -> Dictionary:
	var out := ["旅行者……你也是听见咒语之声的人吗？"]
	if state.get("boss_dead", false):
		out.append("东北空地的王倒下了。森林好久没有这么安静——多亏了你。")
	else:
		out.append("东北空地的史莱姆王仍在沉睡……或者说，在等一个挑战者。")
	if state.get("wetland_found", false):
		out.append("你已经踏入石门后的湿地了。那口灵泉，还有深沼里的老家伙，都值得一探。")
	else:
		out.append("石门之后的事，要你自己去看。带一把伞。")
	# The quest thread weaves in last so its page is always actionable.
	if state.get("quest_done", false):
		out.append("愿言语与你同行——你的咒语声，如今比初见时清晰多了。")
		return {"lines": out}
	if state.get("elite_dead", false):
		if state.get("quest_taken", false):
			out.append("你真的取回了它……这份祝福收下吧——再赠你一句咒语：「激流贯射」。愿魔力如泉涌。（E 交付委托）")
			return {"lines": out, "action": ACTION_TURN_IN}
		out.append("深沼的家伙倒了？它吞着的那颗心，本来该由我保管的。可惜了。")
		out.append("愿言语与你同行。")
		return {"lines": out}
	if state.get("quest_taken", false):
		out.append("委托还挂着呢——深沼在湿地东北，那家伙的心脏越早取出越好。")
		out.append("愿言语与你同行。")
		return {"lines": out}
	out.append("愿言语与你同行。")
	out.append("对了——深沼的老家伙吞了一颗沼泽之心，替我取回来，我自有谢礼。（E 接受 / Esc 再想想）")
	return {"lines": out, "action": ACTION_ACCEPT}
