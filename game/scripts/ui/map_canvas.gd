extends Control
## The act map backdrop and its paths. Node discs are added as children.
## The softened background drifts slowly, star motes float upward, and the paths draw in when the map opens.

const GOLD := Color(0.98, 0.8, 0.42)
const SEGMENTS := 22
const DASH := 10.0
const GAP := 9.0
const MOTES := 70

var background: Texture2D
## [from, to, style ("normal", "taken", "next"), from radius, to radius]
var paths: Array = []
var pulse := 0.0
## 0..1 while the paths draw in.
var reveal := 0.0
var motes: Array = []
var vignette: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in MOTES:
		motes.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(6.0, 18.0), rng.randf_range(0.8, 2.2), rng.randf() * TAU])
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.15), Color(0.01, 0.0, 0.03, 0.7)])
	vignette = GradientTexture2D.new()
	vignette.gradient = g
	vignette.fill = GradientTexture2D.FILL_RADIAL
	vignette.fill_from = Vector2(0.5, 0.5)
	vignette.fill_to = Vector2(1.05, 1.05)
	vignette.width = 256
	vignette.height = 256
	create_tween().tween_property(self, "reveal", 1.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.06))
	if background:
		var drift := Vector2(sin(pulse * 0.07) * 16.0, cos(pulse * 0.05) * 12.0)
		var pad := size * 0.03 + Vector2(20, 20)
		draw_texture_rect(background, Rect2(-pad + drift, size + pad * 2), false)
	_draw_motes()
	for p in paths:
		_draw_path(p)
	draw_texture_rect(vignette, Rect2(Vector2.ZERO, size), false)


func _draw_motes() -> void:
	for m in motes:
		var speed: float = m[1]
		var y: float = fposmod(m[0].y * size.y - pulse * speed, size.y)
		var x: float = m[0].x * size.x + sin(pulse * 0.3 + m[3]) * 10.0
		var a: float = 0.25 + 0.2 * sin(pulse * 1.3 + m[3])
		draw_circle(Vector2(x, y), m[2] * 2.6, Color(0.75, 0.65, 1.0, a * 0.18), true, -1.0, true)
		draw_circle(Vector2(x, y), m[2], Color(0.95, 0.9, 1.0, a), true, -1.0, true)


## A gentle curve between two nodes, trimmed so it starts and ends outside their discs.
func _curve(p: Array) -> PackedVector2Array:
	var a: Vector2 = p[0]
	var b: Vector2 = p[1]
	var dir := (b - a).normalized()
	a += dir * (p[3] + 6.0)
	b -= dir * (p[4] + 6.0)
	var bend: float = sin(a.x * 0.013 + b.y * 0.021) * 0.12 * a.distance_to(b)
	var ctrl := (a + b) / 2.0 + Vector2(-dir.y, dir.x) * bend
	var pts := PackedVector2Array()
	for k in SEGMENTS + 1:
		var t := k / float(SEGMENTS)
		pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	return pts


func _draw_path(p: Array) -> void:
	var pts := _curve(p)
	var shown := int(ceil(reveal * SEGMENTS)) + 1
	if shown < 2:
		return
	pts = pts.slice(0, shown)
	match p[2]:
		"normal":
			draw_polyline(pts, Color(0.82, 0.8, 1.0, 0.16), 2.0, true)
		"taken":
			draw_polyline(pts, Color(GOLD, 0.16), 8.0, true)
			draw_polyline(pts, Color(GOLD, 0.92), 2.6, true)
		"next":
			var glow := 0.14 + 0.08 * sin(pulse * 3.0)
			draw_polyline(pts, Color(GOLD, glow), 10.0, true)
			_draw_dashes(pts)


## Dashes that flow along the path toward the next node.
func _draw_dashes(pts: PackedVector2Array) -> void:
	var lengths := [0.0]
	for k in range(1, pts.size()):
		lengths.append(lengths[-1] + pts[k - 1].distance_to(pts[k]))
	var total: float = lengths[-1]
	var period := DASH + GAP
	var start := fposmod(pulse * 34.0, period) - period
	while start < total:
		var s0 := maxf(start, 0.0)
		var s1 := minf(start + DASH, total)
		if s1 > s0:
			draw_line(_at(pts, lengths, s0), _at(pts, lengths, s1), Color(1.0, 0.92, 0.6, 0.95), 3.0, true)
		start += period


func _at(pts: PackedVector2Array, lengths: Array, s: float) -> Vector2:
	for k in range(1, pts.size()):
		if lengths[k] >= s:
			var seg: float = lengths[k] - lengths[k - 1]
			return pts[k - 1].lerp(pts[k], (s - lengths[k - 1]) / maxf(seg, 0.001))
	return pts[-1]
