extends SceneTree
## Headless test for SpellSession: duplicate detection (exact,
## normalized, mechanism signature) and codex recording.
##
##   godot --headless --path . -s res://tests/spell_session_test.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := SpellSession.new()

	var fireball: Dictionary = SpellValidator.validate(LocalSpellRegistry.lookup("火球术"))["spell"]
	var fireball_alias: Dictionary = SpellValidator.validate(LocalSpellRegistry.lookup("火球"))["spell"]
	var ice_arrow: Dictionary = SpellValidator.validate(LocalSpellRegistry.lookup("寒冰箭"))["spell"]

	# Nothing recorded yet: everything passes.
	_expect(session.check("火球术", "火球术", fireball)["ok"], "fresh session allows 火球术")

	# Record 火球术.
	session.record("火球术", "火球术", fireball)
	_expect(session.codex.size() == 1, "codex records one entry")

	# Exact duplicate.
	_expect(not session.check("火球术", "火球术", fireball)["ok"],
			"exact text blocked")
	# Normalized duplicate (punctuation variant).
	_expect(not session.check("火球术！", "火球术", fireball)["ok"],
			"normalized variant blocked")
	# Mechanism duplicate under a different name (火球 vs 火球术).
	_expect(session.check("火球", "火球", fireball_alias)["reason"] == "duplicate_mechanism",
			"火球 collides with 火球术 by mechanism")
	# Genuinely different spell passes.
	_expect(session.check("寒冰箭", "寒冰箭", ice_arrow)["ok"],
			"寒冰箭 is distinct")

	# Fresh session (new adventure) forgets everything.
	var fresh := SpellSession.new()
	_expect(fresh.check("火球术", "火球术", fireball)["ok"],
			"new adventure resets uniqueness")

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES: %d" % _failures)
		quit(1)


func _expect(cond: bool, what: String) -> void:
	if cond:
		print("PASS  " + what)
	else:
		_failures += 1
		print("FAIL  " + what)
