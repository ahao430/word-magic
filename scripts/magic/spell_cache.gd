class_name SpellCache
extends RefCounted
## Global spell cache (AGENTS.md §7.1 / §11 tier 3): parsed-spell drafts
## reused across adventures, keyed by exact and normalized text so a
## phrase that "worked" before resolves instantly without any parser.
##
## Trust rules (the cache is a convenience, never an authority):
## - A cache hit still passes SpellValidator (params clamped) and the
##   session duplicate gate, and still costs mana.
## - Unknown / incompatible cache files are dropped, never fatal —
##   casting must work with a totally cold cache.
## - Only locally-registered drafts are stored for now; the AI parser
##   will join as a third producer writing the same shape (Phase 5).

const EVENT_STORE := "spell_cache"

static var _exact: Dictionary = {}
static var _normalized: Dictionary = {}
static var _loaded := false


## In-memory forget (tests, simulated cold start). Never touches disk.
static func reset() -> void:
	_exact = {}
	_normalized = {}
	_loaded = true


## Force a fresh read (a "restart" inside one process).
static func reload_from_disk() -> void:
	_loaded = false
	_ensure_loaded()


static func lookup_exact(raw_text: String) -> Dictionary:
	_ensure_loaded()
	var draft: Dictionary = _exact.get(raw_text, {})
	return draft.duplicate(true)


static func lookup_normalized(normalized_text: String) -> Dictionary:
	_ensure_loaded()
	var draft: Dictionary = _normalized.get(normalized_text, {})
	return draft.get("draft", {}).duplicate(true)


## Store a draft under both keys in one call (idempotent: a repeated
## store overwrites with identical content). Deep-copied so later
## mutations of the caller's copy cannot poison the cache.
static func store(raw_text: String, normalized_text: String, draft: Dictionary) -> void:
	_ensure_loaded()
	var entry := {"raw": raw_text, "draft": draft}
	_exact[raw_text] = draft.duplicate(true)
	_normalized[normalized_text] = entry.duplicate(true)
	var result: Dictionary = persist()
	if not result["ok"]:
		push_warning("spell cache persist failed: " + result["error"])


## Number of distinct normalized entries (diagnostics / tests).
static func size() -> int:
	_ensure_loaded()
	return _normalized.size()


## Full snapshot for tests / future migrations.
static func capture() -> Dictionary:
	_ensure_loaded()
	return {"exact": _exact.duplicate(true),
			"normalized": _normalized.duplicate(true)}


static func persist() -> Dictionary:
	_ensure_loaded()
	return SaveManager.save_spell_cache({"exact": _exact, "normalized": _normalized})


## Dev/test reset that also deletes the file.
static func clear_persisted() -> Dictionary:
	var result: Dictionary = SaveManager.delete_spell_cache()
	reset()
	return result


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var result: Dictionary = SaveManager.load_spell_cache()
	if result["ok"]:
		var cache: Dictionary = result["cache"]
		_exact = cache.get("exact", {})
		_normalized = cache.get("normalized", {})
	else:
		# Cold start on any disk problem: gameplay never blocks on cache
		# state; the pipeline falls through to the local registry.
		push_warning("spell cache starts empty: " + result["error"])
