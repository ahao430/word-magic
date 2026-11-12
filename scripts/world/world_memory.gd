class_name WorldMemory
extends RefCounted
## Permanent world progress (AGENTS.md §10.3 / §11 tier 1): durable
## world deltas — facts that survive every restart, like a defeated
## boss or a ford the player awakened. The world rebuilds
## deterministically from its seed and then replays these events, so
## progress never depends on scene nodes staying alive.
##
## Follows the Sfx/SaveManager precedent: a static class instead of an
## Autoload (global lifetime via statics, class-name access, no extra
## singleton in the tree). Disk I/O lives in SaveManager; the first
## lookup lazy-loads user://world_memory.json.

const EVENT_RUNE := "rune_awakened"
const EVENT_FORD := "ford_built"
const EVENT_BOSS := "boss_slime_defeated"
const EVENT_REGION := "region_wetland_discovered"
const EVENT_ELITE := "elite_slime_defeated"
const EVENT_SPRING := "swamp_spring_blessed"
const EVENT_QUEST_TAKEN := "quest_swamp_heart_taken"
const EVENT_QUEST_DONE := "quest_swamp_heart_done"
const EVENT_EXPEDITION := "expedition_swamp_echo"

static var _events: Dictionary = {}
static var _loaded := false


## Drop all in-memory events and mark the store loaded (so the next
## record does not lazy-load stale disk state). Tests use this to run
## hermetically; it never touches the file.
static func reset() -> void:
	_events = {}
	_loaded = true


## Force a fresh read from disk (a "restart" inside one process).
## Returns the load result from SaveManager.
static func reload_from_disk() -> Dictionary:
	_loaded = false
	_ensure_loaded()
	var result: Dictionary = SaveManager.load_world_memory()
	return result


static func record(event_id: String, payload: Dictionary = {}) -> void:
	_ensure_loaded()
	_events[event_id] = payload


## Record a permanent fact and flush it to disk immediately — losing a
## boss kill to a crash would be unacceptable.
static func record_and_persist(event_id: String, payload: Dictionary = {}) -> void:
	record(event_id, payload)
	var result: Dictionary = persist()
	if not result["ok"]:
		push_warning("world memory persist failed: " + result["error"])


static func has_event(event_id: String) -> bool:
	_ensure_loaded()
	return _events.has(event_id)


static func get_event(event_id: String) -> Dictionary:
	_ensure_loaded()
	return _events.get(event_id, {})


## Full snapshot for embedding in tests / future migrations.
static func capture() -> Dictionary:
	_ensure_loaded()
	return _events.duplicate(true)


## Merge persisted events into the store (idempotent by event id).
static func apply(events: Dictionary) -> void:
	_ensure_loaded()
	for key in events:
		_events[key] = events[key]


static func persist() -> Dictionary:
	_ensure_loaded()
	return SaveManager.save_world_memory(_events)


## Dev reset (F8): forget everything permanently and rebuild the world.
static func clear_persisted() -> Dictionary:
	var result: Dictionary = SaveManager.delete_world_memory()
	reset()
	return result


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var result: Dictionary = SaveManager.load_world_memory()
	if result["ok"]:
		apply(result["events"])
	else:
		# A missing file is a fresh world (handled as ok above); a
		# corrupt one warns and starts empty — gameplay must never block
		# on damaged meta-progress. No GameManager reference here: new
		# global classes compile before the autoload cache settles.
		push_warning("world memory starts empty: " + result["error"])
