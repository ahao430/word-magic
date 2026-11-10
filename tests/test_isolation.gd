class_name TestIsolation
extends RefCounted
## Shared test isolation for user:// files that real gameplay persists
## (world memory, spell cache): stash the developer's real file before
## a suite runs, unstash afterwards, so test batches never leave traces
## on the dev machine and suites run hermetically.

const MEMORY_PATH := "user://world_memory.json"
const CACHE_PATH := "user://spell_cache.json"


## Remove the file, returning its content ("" when absent) for unstash.
static func stash(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return text


## Restore what stash() returned. Empty stash = the early-return branch
## never runs; the file did not exist before the suite, so remove
## whatever the suite wrote.
static func unstash(path: String, stashed: String) -> void:
	if stashed == "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(stashed)
	f.close()
