extends Node
## Background music: one looping track at a time, crossfading when it changes.
## Call `Music.play("theme" / "battle" / "boss")` from anywhere; the player node creates itself.
## The loops are synthesized by tools/compose_music.py.

const TRACKS := {
	"theme": "res://music/theme.ogg",
	"battle": "res://music/battle.ogg",
	"boss": "res://music/boss.ogg",
}
const VOLUME_DB := -8.0
const SILENT_DB := -40.0
const FADE := 1.5
const SETTINGS := "user://settings.cfg"

static var instance: Node = null

var players: Array[AudioStreamPlayer] = []
var active := 0
var current := ""
var tween: Tween


static func play(track: String) -> void:
	var music := _instance()
	if music != null:
		music._switch(track)


## Mutes all game audio (the Master bus), remembered between sessions.
static func set_muted(on: bool) -> void:
	AudioServer.set_bus_mute(0, on)
	var config := ConfigFile.new()
	config.load(SETTINGS)
	config.set_value("audio", "muted", on)
	config.save(SETTINGS)


static func is_muted() -> bool:
	_instance()
	return AudioServer.is_bus_mute(0)


static func toggle_mute() -> void:
	set_muted(not is_muted())


## Master volume from 0.0 to 1.0, remembered between sessions.
static func set_volume(value: float, save := true) -> void:
	_apply_volume(value)
	if not save:
		return
	var config := ConfigFile.new()
	config.load(SETTINGS)
	config.set_value("audio", "volume", value)
	config.save(SETTINGS)


static func get_volume() -> float:
	_instance()
	return db_to_linear(AudioServer.get_bus_volume_db(0))


static func _apply_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.0001)))


static func _instance() -> Node:
	if is_instance_valid(instance):
		return instance
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	instance = load("res://scripts/ui/music.gd").new()
	instance.name = "Music"
	tree.root.add_child.call_deferred(instance)
	return instance


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load(SETTINGS) == OK:
		AudioServer.set_bus_mute(0, config.get_value("audio", "muted", false))
		_apply_volume(config.get_value("audio", "volume", 1.0))
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = SILENT_DB
		add_child(p)
		players.append(p)


func _ready() -> void:
	var track := current
	current = ""
	_switch(track)


func _switch(track: String) -> void:
	if track == current:
		return
	current = track
	if not is_inside_tree():
		return
	if tween != null:
		tween.kill()
	tween = create_tween().set_parallel(true)
	var old := players[active]
	if old.playing:
		tween.tween_property(old, "volume_db", SILENT_DB, FADE)
		tween.tween_callback(old.stop).set_delay(FADE)
	if not TRACKS.has(track):
		return
	var stream: AudioStreamOggVorbis = load(TRACKS[track])
	stream.loop = true
	active = 1 - active
	var p := players[active]
	p.stream = stream
	p.volume_db = SILENT_DB
	p.play()
	tween.tween_property(p, "volume_db", VOLUME_DB, FADE)
