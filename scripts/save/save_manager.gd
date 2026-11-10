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


static func slot_path(slot: String) -> String:
	return "%s/%s/save.json" % [SAVES_DIR, slot]


## Returns {"ok": bool, "error": String}.
static func save_game(state: Dictionary, slot: String = "slot_01") -> Dictionary:
	# Create the full slot directory up front (user://saves/<slot>).
	var dir_path := "%s/%s" % [SAVES_DIR, slot]
	var mk_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	if mk_err != OK:
		return {"ok": false, "error": "cannot create saves dir"}
	var full := slot_path(slot)
	var tmp := full + ".tmp"
	var payload := {"version": SAVE_VERSION, "state": state}
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


## Returns {"ok": bool, "state": Dictionary, "error": String}.
static func load_game(slot: String = "slot_01") -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"ok": false, "state": {}, "error": "no save"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "state": {}, "error": "cannot open"}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not parsed is Dictionary:
		return {"ok": false, "state": {}, "error": "corrupted save"}
	var version: int = int(parsed.get("version", 0))
	if version != SAVE_VERSION:
		return {"ok": false, "state": {}, "error": "unsupported version %d" % version}
	return {"ok": true, "state": parsed.get("state", {}), "error": ""}
