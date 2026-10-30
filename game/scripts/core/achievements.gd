extends RefCounted
## Persistent badges earned across runs. Written when a victory unlocks new ones.

const Data = preload("res://scripts/core/data.gd")

static var path := "user://achievements.save"


static func unlocked() -> Array:
	var data := _read()
	var out: Array = []
	for id in data.get("unlocked", []):
		if typeof(id) == TYPE_STRING and Data.ACHIEVEMENTS.has(id):
			out.append(id)
	return out


static func is_unlocked(id: String) -> bool:
	return id in unlocked()


## Marks the given badge ids as unlocked. Returns only those that were newly earned.
static func unlock(ids: Array) -> Array:
	var data := _read()
	var have: Array = data.get("unlocked", []).duplicate()
	var fresh: Array = []
	for id in ids:
		if typeof(id) != TYPE_STRING or not Data.ACHIEVEMENTS.has(id):
			continue
		if id in have:
			continue
		have.append(id)
		fresh.append(id)
	if not fresh.is_empty():
		data["unlocked"] = have
		_write(data)
	return fresh


static func clear() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"unlocked": []}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"unlocked": []}
	var data = f.get_var()
	if typeof(data) != TYPE_DICTIONARY:
		return {"unlocked": []}
	if typeof(data.get("unlocked", null)) != TYPE_ARRAY:
		return {"unlocked": []}
	return data


static func _write(data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_var(data)
