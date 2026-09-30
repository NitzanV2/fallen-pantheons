extends CanvasLayer
## Always-on-top playtest helpers: build number, feedback button, and a banner when a
## newer build has been deployed. Reads res://build_info.json, which deploys overwrite.

const INFO_PATH := "res://build_info.json"
const CHECK_EVERY_SEC := 180.0
const Music = preload("res://scripts/ui/music.gd")

var info := {"version": "dev", "update_url": "", "feedback_url": ""}
var banner: PanelContainer
var banner_label: Label
var mute_button: Button
var http: HTTPRequest
var offered_version := ""
var dismissed_version := ""


func _ready() -> void:
	layer = 100
	_load_info()

	var corner := HBoxContainer.new()
	corner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.position = Vector2(-12, -8)
	corner.add_theme_constant_override("separation", 10)
	add_child(corner)

	mute_button = Button.new()
	mute_button.tooltip_text = "Mute or unmute all sound (Ctrl+M)."
	mute_button.focus_mode = Control.FOCUS_NONE
	mute_button.custom_minimum_size = Vector2(84, 0)
	mute_button.add_theme_font_size_override("font_size", 12)
	mute_button.pressed.connect(_toggle_mute)
	corner.add_child(mute_button)
	_update_mute_button()

	var build := Label.new()
	build.text = "Build %s" % info["version"]
	build.add_theme_font_size_override("font_size", 12)
	build.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62))
	build.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	corner.add_child(build)

	if info["feedback_url"] != "":
		var feedback := Button.new()
		feedback.text = "Feedback"
		feedback.tooltip_text = "Report a bug or share your thoughts (opens in a new tab)."
		feedback.focus_mode = Control.FOCUS_NONE
		feedback.add_theme_font_size_override("font_size", 12)
		feedback.pressed.connect(func(): OS.shell_open(info["feedback_url"]))
		corner.add_child(feedback)

	_build_banner()
	if OS.has_feature("web") and info["version"] != "dev" and info["update_url"] != "":
		http = HTTPRequest.new()
		add_child(http)
		http.request_completed.connect(_on_check_done)
		var timer := Timer.new()
		timer.wait_time = CHECK_EVERY_SEC
		timer.autostart = true
		timer.timeout.connect(_check)
		add_child(timer)
		_check()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M and event.ctrl_pressed:
		_toggle_mute()
		get_viewport().set_input_as_handled()


func _toggle_mute() -> void:
	Music.toggle_mute()
	_update_mute_button()


func _update_mute_button() -> void:
	mute_button.text = "Sound: Off" if Music.is_muted() else "Sound: On"


func _load_info() -> void:
	var f := FileAccess.open(INFO_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		info.merge(parsed, true)


func _build_banner() -> void:
	banner = PanelContainer.new()
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.position.y = 8
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.05, 0.97)
	sb.border_color = Color(0.95, 0.75, 0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	banner.add_theme_stylebox_override("panel", sb)
	banner.visible = false
	add_child(banner)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	banner.add_child(row)
	banner_label = Label.new()
	row.add_child(banner_label)
	var close := Button.new()
	close.text = "Later"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_dismiss)
	row.add_child(close)


## raw.githubusercontent.com caches for a few minutes; the query string keeps browsers from adding more.
func _check() -> void:
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	http.request("%s?t=%d" % [info["update_url"], Time.get_unix_time_from_system()])


func _on_check_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var latest = JSON.parse_string(body.get_string_from_utf8())
	if not latest is Dictionary or not latest.has("version"):
		return
	var version: String = latest["version"]
	if version == info["version"] or version == dismissed_version:
		return
	offered_version = version
	banner_label.text = "A new version (%s) is available. Reload the page to play it - your current run will be lost." % version
	banner.visible = true


func _dismiss() -> void:
	banner.visible = false
	dismissed_version = offered_version
