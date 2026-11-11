class_name AiConfig
extends RefCounted
## AI provider configuration (AGENTS.md §8): loaded from a local file
## the project owner fills in — config/ai.json (gitignored) or
## user://ai_config.json as an export-friendly fallback. Keys never
## enter the repository and are never logged. An absent or placeholder
## config simply means "AI off": everything local keeps working.

const RES_PATH := "res://config/ai.json"
const USER_PATH := "user://ai_config.json"
const KEY_PLACEHOLDER := "在此填入"

static var _cached: Dictionary = {}


## Re-read the config file (res:// first, then user://). A missing or
## damaged file leaves the config empty — never an error path.
## (Named load_from: "reload" collides with Script.reload.)
static func load_from(path := "") -> void:
	_cached = {}
	var text := ""
	if path != "":
		text = _read_text(path)
	else:
		text = _read_text(RES_PATH)
		if text == "":
			text = _read_text(USER_PATH)
	if text == "":
		return
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_warning("ai config unreadable: ignoring")
		return
	_cached = parsed


static func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


## True when base_url / api_key / chat_model are all filled with real
## values (placeholders don't count).
static func is_configured() -> bool:
	return base_url() != "" and api_key() != "" and chat_model() != ""


## Tests inject a parsed config directly; {} restores "AI off".
static func apply_config(cfg: Dictionary) -> void:
	_cached = cfg.duplicate(true)


static func base_url() -> String:
	var v := str(_cached.get("base_url", "")).strip_edges()
	if v.is_empty() or v.contains("example.com"):
		return ""
	return v.rstrip("/")


static func api_key() -> String:
	var v := str(_cached.get("api_key", "")).strip_edges()
	if v.is_empty() or v.contains(KEY_PLACEHOLDER):
		return ""
	return v


static func chat_model() -> String:
	var v := str(_cached.get("chat_model", "")).strip_edges()
	if v.is_empty() or v.contains(KEY_PLACEHOLDER):
		return ""
	return v


static func embedding_model() -> String:
	return str(_cached.get("embedding_model", "")).strip_edges()


static func timeout_seconds() -> float:
	return clampf(float(_cached.get("request_timeout_seconds", 12.0)), 3.0, 60.0)


## Full chat-completions endpoint for the configured base URL.
static func chat_url() -> String:
	return "%s/chat/completions" % base_url()
