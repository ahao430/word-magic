class_name SaveManager
extends RefCounted
## JSON session-save manager (PLAN.md §13 / AGENTS.md §11):
## - slot directories under user://saves/<slot>/
## - schema version embedded; loaders refuse unknown versions
## - atomic writes (tmp file + rename) so a crash mid-save never
##   destroys the last valid save
## - corrupted files surface as an error result, never a crash

const SAVE_VERSION := 1
const SAVES_DIR := "user://saves"
const SLOT_COUNT := 3


static func slot_path(slot: String) -> String:
	return "%s/%s/save.json" % [SAVES_DIR, slot]


static func slot_id(index: int) -> String:
	return "slot_%02d" % index


## Returns {"ok": bool, "error": String}. meta is a small display
## payload (timestamp, summary) kept OUTSIDE the game state so UI can
## show slot cards without loading game data.
static func save_game(state: Dictionary, slot: String = "slot_01",
		meta: Dictionary = {}) -> Dictionary:
	# Create the full slot directory up front (user://saves/<slot>).
	var dir_path := "%s/%s" % [SAVES_DIR, slot]
	var mk_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	if mk_err != OK:
		return {"ok": false, "error": "cannot create saves dir"}
	var full := slot_path(slot)
	var tmp := full + ".tmp"
	var payload := {"version": SAVE_VERSION, "meta": meta, "state": state}
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "cannot open tmp file"}
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	# Atomic swap: rename onto the live slot only after a full write.
	var err := DirAccess.rename_absolute(tmp, full)
	if err != OK:
		return {"ok": false, "error": "rename failed (%d)" % err}
	return {"ok": true, "error": ""}


## Returns {"ok": bool, "state": Dictionary, "meta": Dictionary, "error": String}.
static func load_game(slot: String = "slot_01") -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"ok": false, "state": {}, "meta": {}, "error": "no save"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "state": {}, "meta": {}, "error": "cannot open"}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not parsed is Dictionary:
		return {"ok": false, "state": {}, "meta": {}, "error": "corrupted save"}
	var version: int = int(parsed.get("version", 0))
	if version != SAVE_VERSION:
		return {"ok": false, "state": {}, "meta": {},
				"error": "unsupported version %d" % version}
	return {"ok": true, "state": parsed.get("state", {}),
			"meta": parsed.get("meta", {}), "error": ""}


static func slot_exists(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Returns {"ok": bool, "error": String}.
static func delete_slot(slot: String) -> Dictionary:
	if not slot_exists(slot):
		return {"ok": true, "error": ""}
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot)))
	if err != OK:
		return {"ok": false, "error": "delete failed (%d)" % err}
	return {"ok": true, "error": ""}


## Occupied slots in fixed order (slot_01..slot_N).
static func list_slots() -> Array[String]:
	var out: Array[String] = []
	for i in range(1, SLOT_COUNT + 1):
		var s := slot_id(i)
		if slot_exists(s):
			out.append(s)
	return out


## --- Permanent world memory (tier 1, AGENTS.md §11) ---
## A separate file from session slots: meta-progress that outlives any
## adventure. A missing file means a fresh world, not an error.

const WORLD_MEMORY_PATH := "user://world_memory.json"
const WORLD_MEMORY_VERSION := 1


## Returns {"ok": bool, "error": String}. Atomic write like save_game.
static func save_world_memory(events: Dictionary, counters: Dictionary = {}) -> Dictionary:
	var payload := {"version": WORLD_MEMORY_VERSION, "events": events,
			"counters": counters}
	var tmp := WORLD_MEMORY_PATH + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "cannot open tmp file"}
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(tmp, WORLD_MEMORY_PATH)
	if err != OK:
		return {"ok": false, "error": "rename failed (%d)" % err}
	return {"ok": true, "error": ""}


## Returns {"ok": bool, "events": Dictionary, "error": String}. Missing
## file → ok with empty events (fresh world); damaged file → refused.
static func load_world_memory() -> Dictionary:
	if not FileAccess.file_exists(WORLD_MEMORY_PATH):
		return {"ok": true, "events": {}, "counters": {}, "error": ""}
	var file := FileAccess.open(WORLD_MEMORY_PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "events": {}, "counters": {}, "error": "cannot open"}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not parsed is Dictionary:
		return {"ok": false, "events": {}, "counters": {}, "error": "corrupted world memory"}
	var version: int = int(parsed.get("version", 0))
	if version != WORLD_MEMORY_VERSION:
		return {"ok": false, "events": {}, "counters": {}, "error": "unsupported version %d" % version}
	return {"ok": true, "events": parsed.get("events", {}),
			"counters": parsed.get("counters", {}), "error": ""}


## Dev reset: forget permanent progress. Returns {"ok", "error"}.
static func delete_world_memory() -> Dictionary:
	if not FileAccess.file_exists(WORLD_MEMORY_PATH):
		return {"ok": true, "error": ""}
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(WORLD_MEMORY_PATH))
	if err != OK:
		return {"ok": false, "error": "delete failed (%d)" % err}
	return {"ok": true, "error": ""}


## --- Global spell cache (tier 3, AGENTS.md §11) ---
## Parsed-spell reuse across adventures, keyed by exact and normalized
## text. A missing file is an empty cache; an incompatible version is
## dropped (schema migrations come later); a corrupt file never blocks
## casting — the pipeline falls through to the local registry.

const SPELL_CACHE_PATH := "user://spell_cache.json"
const SPELL_CACHE_VERSION := 1


## Returns {"ok": bool, "error": String}. Atomic write.
static func save_spell_cache(data: Dictionary) -> Dictionary:
	var payload := {"version": SPELL_CACHE_VERSION, "cache": data}
	var tmp := SPELL_CACHE_PATH + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "cannot open tmp file"}
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(tmp, SPELL_CACHE_PATH)
	if err != OK:
		return {"ok": false, "error": "rename failed (%d)" % err}
	return {"ok": true, "error": ""}


## Returns {"ok": bool, "cache": Dictionary, "error": String}. Missing
## file → ok + empty; wrong version → refused (caller drops it); corrupt
## file → refused.
static func load_spell_cache() -> Dictionary:
	if not FileAccess.file_exists(SPELL_CACHE_PATH):
		return {"ok": true, "cache": {}, "error": ""}
	var file := FileAccess.open(SPELL_CACHE_PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "cache": {}, "error": "cannot open"}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not parsed is Dictionary:
		return {"ok": false, "cache": {}, "error": "corrupted spell cache"}
	var version: int = int(parsed.get("version", 0))
	if version != SPELL_CACHE_VERSION:
		return {"ok": false, "cache": {},
				"error": "unsupported version %d" % version}
	return {"ok": true, "cache": parsed.get("cache", {}), "error": ""}


## Dev/test reset. Returns {"ok", "error"}.
static func delete_spell_cache() -> Dictionary:
	if not FileAccess.file_exists(SPELL_CACHE_PATH):
		return {"ok": true, "error": ""}
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(SPELL_CACHE_PATH))
	if err != OK:
		return {"ok": false, "error": "delete failed (%d)" % err}
	return {"ok": true, "error": ""}
