extends Control
## Draws the connections between map nodes. Node buttons are added as children.

var lines: Array = []


func _draw() -> void:
	for l in lines:
		draw_line(l[0], l[1], l[2], l[3], true)
