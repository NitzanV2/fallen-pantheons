extends Control
## The act map backdrop and its dotted paths. Node medallions are added as children.

const DOT_STEP := 14.0
const STYLES := {
	"normal": {"color": Color(0.85, 0.8, 0.72, 0.38), "radius": 2.2},
	"taken": {"color": Color(1.0, 0.82, 0.4, 0.95), "radius": 3.2},
	"next": {"color": Color(1.0, 0.9, 0.5, 1.0), "radius": 3.4},
}

var background: Texture2D
## [from, to, style, from radius, to radius]
var paths: Array = []
var pulse := 0.0


func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()


func _draw() -> void:
	if background:
		draw_texture_rect(background, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.05, 0.25))
	for p in paths:
		var style: Dictionary = STYLES[p[2]]
		var a: Vector2 = p[0]
		var b: Vector2 = p[1]
		var length := a.distance_to(b)
		var dir: Vector2 = (b - a) / maxf(length, 0.001)
		var t: float = p[3] + 6.0
		var k := 0
		while t < length - p[4] - 6.0:
			var color: Color = style["color"]
			if p[2] == "next":
				color.a = 0.55 + 0.45 * sin(pulse * 4.0 - k * 0.6)
			draw_circle(a + dir * t, style["radius"], color, true, -1.0, true)
			t += DOT_STEP
			k += 1
