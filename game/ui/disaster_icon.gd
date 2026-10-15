extends Control

@export var ink_color := DisasterPartyUI.INK

var disaster_id := "":
	set(value):
		disaster_id = value
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size / 48.0)
	var ink := ink_color
	match disaster_id:
		"health":
			draw_colored_polygon(PackedVector2Array([Vector2(24, 43), Vector2(5, 24), Vector2(5, 13), Vector2(13, 6), Vector2(24, 13), Vector2(35, 6), Vector2(43, 13), Vector2(43, 24)]), DisasterPartyUI.CORAL)
		"survivors":
			draw_circle(Vector2(17, 14), 8, ink)
			draw_circle(Vector2(35, 15), 6, ink)
			draw_style_box(_person_style(ink), Rect2(5, 26, 24, 16))
			draw_style_box(_person_style(ink), Rect2(31, 27, 12, 15))
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
		"rain":
			for x in [12, 24, 36]:
				draw_line(Vector2(x, 8), Vector2(x - 6, 36), ink, 4, true)
				draw_circle(Vector2(x - 6, 38), 3, ink)
		"snowfall":
			for index in 6:
				var direction := Vector2.from_angle(index * TAU / 6.0)
				draw_line(Vector2(24, 24), Vector2(24, 24) + direction * 21, ink, 3, true)
				var tip := Vector2(24, 24) + direction * 13
				draw_line(tip, tip + direction.rotated(PI * 0.7) * 8, ink, 3, true)
				draw_line(tip, tip + direction.rotated(-PI * 0.7) * 8, ink, 3, true)
		"rockslide":
			draw_colored_polygon(PackedVector2Array([Vector2(3, 42), Vector2(17, 8), Vector2(26, 42)]), ink)
			for point in [Vector2(30, 13), Vector2(37, 25), Vector2(41, 39)]:
				draw_circle(point, 5, ink)
		"volcano":
			draw_colored_polygon(PackedVector2Array([Vector2(3, 43), Vector2(18, 18), Vector2(30, 18), Vector2(45, 43)]), ink)
			for x in [13, 24, 35]:
				draw_line(Vector2(24, 14), Vector2(x, 3), ink, 3, true)
		"ufo":
			var oval := PackedVector2Array()
			for index in 24:
				oval.append(Vector2(24, 22) + Vector2(cos(index * TAU / 24) * 20, sin(index * TAU / 24) * 8))
			draw_colored_polygon(oval, ink)
			draw_arc(Vector2(24, 20), 10, PI, TAU, 16, ink, 4, true)
			for x in [14, 24, 34]:
				draw_line(Vector2(x, 32), Vector2(x, 44), ink, 3, true)
		"bees":
			draw_circle(Vector2(17, 14), 9, ink)
			draw_circle(Vector2(31, 14), 9, ink)
			draw_style_box(_person_style(ink), Rect2(12, 22, 24, 16))
			draw_line(Vector2(24, 23), Vector2(24, 37), DisasterPartyUI.WARNING, 4, true)
		"fire":
			draw_colored_polygon(PackedVector2Array([Vector2(24, 2), Vector2(34, 22), Vector2(39, 15), Vector2(44, 32), Vector2(36, 44), Vector2(13, 44), Vector2(5, 31), Vector2(15, 15), Vector2(16, 28)]), ink)
			draw_circle(Vector2(25, 35), 6, DisasterPartyUI.WARNING)


func _person_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	return style
