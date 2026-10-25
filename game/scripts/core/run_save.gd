extends RefCounted
## The single saved run. Written whenever the run screen changes, cleared when the run ends.

const Run = preload("res://scripts/core/run.gd")
const Data = preload("res://scripts/core/data.gd")

static var path := "user://run.save"


static func write(run) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_var(run.to_save())


static func read():
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var data = f.get_var()
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var run = Run.new()
	if not run.apply_save(data):
		return null
	return run


static func clear() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func describe(run) -> String:
	var faction: String = Data.CARDS[run.patron]["faction"]
	var floor: int = run.floor_number()
	var place := "The Reliquary" if floor == 0 else "Floor %d" % floor
	if run.state == "combat":
		place += " · battle restarts"
	return "%s · Act %d · %s" % [Data.FACTION_NAMES[faction], run.act, place]
