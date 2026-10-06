extends Control

var disaster_id := "":
	set(value):
		disaster_id = value
		queue_redraw()


func _draw() -> void:
	var ink := DisasterPartyUI.INK
	match disaster_id:
		"meteor":
			draw_circle(Vector2(30, 34), 12, ink)
			draw_line(Vector2(8, 6), Vector2(24, 22), ink, 4, true)
			draw_line(Vector2(23, 5), Vector2(35, 17), ink, 4, true)
		"flood":
			for y: int in [15, 27, 39]:
				draw_polyline(PackedVector2Array([Vector2(4, y), Vector2(14, y - 5), Vector2(24, y), Vector2(34, y - 5), Vector2(44, y)]), ink, 4, true)
		"tornado":
			for index: int in 4:
				var half_width := 20.0 - index * 4.5
				draw_line(Vector2(24 - half_width, 9 + index * 10), Vector2(24 + half_width, 9 + index * 10), ink, 5, true)
		"earthquake":
			draw_polyline(PackedVector2Array([Vector2(28, 3), Vector2(17, 18), Vector2(29, 25), Vector2(18, 45)]), ink, 5, true)
			draw_line(Vector2(3, 34), Vector2(12, 34), ink, 4, true)
			draw_line(Vector2(33, 34), Vector2(45, 34), ink, 4, true)
		"lightning":
			draw_colored_polygon(PackedVector2Array([Vector2(27, 2), Vector2(9, 27), Vector2(23, 27), Vector2(18, 46), Vector2(40, 19), Vector2(27, 19)]), ink)
		"fire":
			draw_colored_polygon(PackedVector2Array([Vector2(24, 2), Vector2(34, 22), Vector2(39, 15), Vector2(44, 32), Vector2(36, 44), Vector2(13, 44), Vector2(5, 31), Vector2(15, 15), Vector2(16, 28)]), ink)
			draw_circle(Vector2(25, 35), 6, DisasterPartyUI.WARNING)
