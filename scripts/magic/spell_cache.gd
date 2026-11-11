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

## Semantic similarity threshold: cosine >= this counts as "the same
## idea, different words" and reuses the stored draft (which still
## passes the validator and the session gate — §7.5).
const SEMANTIC_THRESHOLD := 0.86

static var _exact: Dictionary = {}
static var _normalized: Dictionary = {}
static var _semantic: Array = []
static var _loaded := false


## In-memory forget (tests, simulated cold start). Never touches disk.
static func reset() -> void:
	_exact = {}
	_normalized = {}
	_semantic = []
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


## --- Semantic layer (§7.1, between the normalized cache and the AI) ---

## Remember an AI-parsed draft under its phrase vector so a later
## paraphrase resolves without another network call. Dimension changes
## (a different embedding model) simply never match old entries.
static func store_semantic(raw_text: String, normalized_text: String,
		vector: Array, draft: Dictionary) -> void:
	_ensure_loaded()
	if vector.is_empty():
		return
	for entry in _semantic:
		if entry["norm"] == normalized_text:
			entry["vec"] = vector.duplicate()
			entry["draft"] = draft.duplicate(true)
			var refresh: Dictionary = persist()
			if not refresh["ok"]:
				push_warning("spell cache persist failed: " + refresh["error"])
			return
	_semantic.append({"raw": raw_text, "norm": normalized_text,
			"vec": vector.duplicate(), "draft": draft.duplicate(true)})
	var result: Dictionary = persist()
	if not result["ok"]:
		push_warning("spell cache persist failed: " + result["error"])


## Best match above SEMANTIC_THRESHOLD, or {}. Returns
## {"draft": Dictionary, "score": float, "raw": String}.
static func lookup_semantic(vector: Array) -> Dictionary:
	_ensure_loaded()
	var best := {"draft": {}, "score": 0.0, "raw": ""}
	for entry in _semantic:
		var score := cosine(vector, entry["vec"])
		if score >= SEMANTIC_THRESHOLD and score > best["score"]:
			best = {"draft": entry["draft"].duplicate(true),
					"score": score, "raw": entry["raw"]}
	return best.duplicate(true) if not best["draft"].is_empty() else {}


## Cosine similarity of two plain float arrays (0.0 when shapes differ
## or either is zero — never a crash, never a match).
static func cosine(a: Array, b: Array) -> float:
	if a.is_empty() or a.size() != b.size():
		return 0.0
	var dot := 0.0
	var na := 0.0
	var nb := 0.0
	for i in a.size():
		var x := float(a[i])
		var y := float(b[i])
		dot += x * y
		na += x * x
		nb += y * y
	if na <= 0.0 or nb <= 0.0:
		return 0.0
	return dot / sqrt(na) / sqrt(nb)


## Full snapshot for tests / future migrations.
static func capture() -> Dictionary:
	_ensure_loaded()
	return {"exact": _exact.duplicate(true),
			"normalized": _normalized.duplicate(true),
			"semantic": _semantic.duplicate(true)}


static func persist() -> Dictionary:
	_ensure_loaded()
	return SaveManager.save_spell_cache({"exact": _exact, "normalized": _normalized,
			"semantic": _semantic})


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
		# Older cache files predate the semantic layer: absent key is a
		# cold semantic store, never an error (AGENTS.md §11 migrations).
		_semantic = cache.get("semantic", [])
	else:
		# Cold start on any disk problem: gameplay never blocks on cache
		# state; the pipeline falls through to the local registry.
		push_warning("spell cache starts empty: " + result["error"])
