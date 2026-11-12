class_name Achievements
extends RefCounted
## Achievement layer (AGENTS §10.3): pure DATA definitions + a pure
## evaluator. The unlocked set lives in the permanent world memory as
## one event (idempotent overwrite); polling is driven by main (the
## data layers stay单向 — WorldMemory never calls back here).
## DEFS kinds:
##   counter         — counters[key] reached `at`
##   event           — the world-memory event exists
##   expedition_best — the expedition record is <= `at` seconds

const EVENT_KEY := "achievements_unlocked"

## Every definition: {id, name, desc, kind, ...params}. Order = the
## journey page's display order.
const DEFS := [
	{"id": "first_blood", "name": "初次交锋", "desc": "击倒第一只史莱姆",
			"kind": "counter", "key": "slain_slimes", "at": 1},
	{"id": "fly_sweeper", "name": "蝇群终结者", "desc": "击落 5 只沼泽蝇",
			"kind": "counter", "key": "slain_flies", "at": 5},
	{"id": "words_alight", "name": "言语成炬", "desc": "成功施法 10 次",
			"kind": "counter", "key": "casts_ok", "at": 10},
	{"id": "unbroken", "name": "屡败屡战", "desc": "倒下 3 次仍愿前行",
			"kind": "counter", "key": "deaths", "at": 3},
	{"id": "echo_slayer", "name": "回响征服者", "desc": "完成一次远征",
			"kind": "counter", "key": "expedition_runs", "at": 1},
	{"id": "swift_hunter", "name": "疾风猎手", "desc": "远征纪录低于 30 秒",
			"kind": "expedition_best", "at": 30.0},
	{"id": "wetland_far", "name": "石门之外", "desc": "踏入迷雾湿地",
			"kind": "event", "event": "region_wetland_discovered"},
	{"id": "heart_taker", "name": "取心者", "desc": "完成取心委托",
			"kind": "event", "event": "quest_swamp_heart_done"},
	{"id": "king_slayer", "name": "弑王者", "desc": "史莱姆王陨落",
			"kind": "event", "event": "boss_slime_defeated"},
]


## Pure evaluator: snapshot = {"counters": Dictionary, "events": Dictionary,
## "expedition_best": float} — everything the checks may read, as data.
## Returns the ids from `candidates` that qualify (already-unlocked ids
## are filtered by the CALLER, keeping this function stateless).
static func evaluate(snapshot: Dictionary, candidates: Array) -> Array:
	var counters: Dictionary = snapshot.get("counters", {})
	var events: Dictionary = snapshot.get("events", {})
	var best: float = float(snapshot.get("expedition_best", -1.0))
	var out: Array = []
	for id in candidates:
		var def: Dictionary = def_by_id(str(id))
		if def.is_empty():
			continue
		match str(def["kind"]):
			"counter":
				if int(counters.get(str(def["key"]), 0)) >= int(def["at"]):
					out.append(id)
			"event":
				if events.has(str(def["event"])):
					out.append(id)
			"expedition_best":
				# >= 0.0: a same-frame headless kill is a legal (perfect)
				# run; real players never hit zero but tests may.
				if best >= 0.0 and best <= float(def["at"]):
					out.append(id)
	return out


static func def_by_id(id: String) -> Dictionary:
	for def in DEFS:
		if str(def["id"]) == id:
			return def
	return {}


## Names of everything already unlocked (permanent tier).
static func unlocked_ids() -> Array:
	var payload: Dictionary = WorldMemory.get_event(EVENT_KEY)
	return payload.get("unlocked", [])


## Poll the permanent tier: evaluate everything not yet unlocked; the
## newly qualified ids are recorded at once and returned so the caller
## can toast them (one call may return several — e.g. after a big run).
static func poll_new() -> Array:
	var unlocked: Array = unlocked_ids()
	var candidates: Array = []
	for def in DEFS:
		if not unlocked.has(str(def["id"])):
			candidates.append(str(def["id"]))
	if candidates.is_empty():
		return []
	var snapshot := {"counters": WorldMemory.capture_counters(),
			"events": WorldMemory.capture(),
			"expedition_best": float(WorldMemory.get_event(
					WorldMemory.EVENT_EXPEDITION).get("best_seconds", -1.0))}
	var newly: Array = evaluate(snapshot, candidates)
	if newly.is_empty():
		return []
	var merged: Array = unlocked + newly
	WorldMemory.record_and_persist(EVENT_KEY, {"unlocked": merged})
	return newly
