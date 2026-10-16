extends RefCounted
## Project-authored toy furniture. Call once after the building's basic furniture.
## All positions are local floor coordinates; the central x[-1.5, 1.5] lane
## stays empty. Small supported goods are cosmetic, not separate physics bodies.


static func furnish(main: Node3D, building: Node3D, title: String) -> void:
	var p: Dictionary = main.PALETTE
	var wall := building.get_node_or_null("WestWall") as StaticBody3D
	if wall != null:
		var shape := wall.get_child(1) as CollisionShape3D
		var depth: float = shape.shape.size.z
		var width := absf(wall.position.x) * 2.0
		# A flush, supported interior finish replaces grass or exterior paving.
		# Keep the two thresholds effectively level, not a raised room platform.
		_box(main, building, "InteriorFloor", Vector3(width - 0.3, 0.02, depth - 0.3), Vector3(0, 0.01, 0), p.cream, true)
	match title:
		"TownHall":
			var desk := _table(main, building, "CivicReception", Vector3(-3.5, 0, 1.4), Vector2(2.4, 1.0))
			_papers(main, desk, Vector3(0, 1.02, 0))
			_sign(main, desk, "INFORMATION", Vector3(0, 1.42, 0.1))
			_mailboxes(main, building, "RecordsCabinet", Vector3(3.8, 0, -2.3))
			_bench(main, building, "WaitingBench", Vector3(3.6, 0, 1.8), p.teal)
		"NorthWest", "Homes":
			_bed(main, building, "HomeBed", Vector3(-2.65, 0, 1.6), p.coral)
			var table := _table(main, building, "BreakfastTable", Vector3(2.65, 0, -2.7), Vector2(1.5, 0.8))
			_cup(main, table, Vector3(0, 1.02, 0), p.teal)
			if title == "NorthWest":
				_cabinet(main, building, "KitchenDresser", Vector3(3.5, 0, 1.4), p.teal)
		"NorthEast":
			var desk := _table(main, building, "DrawingDesk", Vector3(-3.1, 0, 1.3), Vector2(2.2, 1.0))
			_papers(main, desk, Vector3(0, 1.02, 0))
			_easel(main, building, Vector3(3.0, 0, -1.9))
			var cabinet := _cabinet(main, building, "PaintDresser", Vector3(3.3, 0, 1.5), p.coral)
			_cup(main, cabinet, Vector3(0, 1.08, 0), p.teal)
		"GardenCafe", "Cafe":
			var table := _table(main, building, "TeaTable", Vector3(-2.7, 0, 1.4), Vector2(1.6, 1.0))
			_cup(main, table, Vector3(-0.35, 1.02, 0), p.coral)
			_cup(main, table, Vector3(0.35, 1.02, 0), p.teal)
			_bench(main, building, "TeaBench", Vector3(-2.7, 0, 2.65), p.teal)
			var station := _cabinet(main, building, "CoffeeStation", Vector3(2.65, 0, -2.7), p.teal)
			_coffee_machine(main, station)
		"Bakery":
			var oven := _cabinet(main, building, "BreadOven", Vector3(2.65, 0, -2.7), p.cream)
			_box(main, oven, "OvenWindow", Vector3(0.95, 0.42, 0.06), Vector3(0, 0.58, 0.46), p.slate)
			_box(main, oven, "OvenHandle", Vector3(0.75, 0.09, 0.13), Vector3(0, 0.87, 0.5), p.sand)
			var table := _table(main, building, "DoughTable", Vector3(-2.65, 0, 1.6), Vector2(1.65, 1.0))
			_box(main, table, "BakingTray", Vector3(1.2, 0.05, 0.65), Vector3(0, 1.045, 0), p.slate)
			for i in 3:
				main._add_round_detail(table, "Loaf%d" % i, Vector3(-0.38 + i * 0.38, 1.17, 0), Vector3(0.16, 0.1, 0.24), p.sand)
		"Workshop":
			var bench := _table(main, building, "RepairBench", Vector3(-2.65, 0, 1.5), Vector2(1.7, 1.0))
			_box(main, bench, "ViseBase", Vector3(0.5, 0.12, 0.38), Vector3(0.4, 1.08, 0.2), p.slate)
			_box(main, bench, "ViseJaw", Vector3(0.45, 0.25, 0.14), Vector3(0.4, 1.25, 0.2), p.teal)
			_toolboard(main, building, Vector3(2.65, 0, -2.7))
		"Apartments":
			_mailboxes(main, building, "TenantMail", Vector3(2.65, 0, -2.7))
			_bench(main, building, "LobbyBench", Vector3(-2.65, 0, 1.6), p.coral)
			_sign(main, building, "RESIDENTS 1-3", Vector3(-2.65, 2.1, 1.94), 0.0)
		"Library":
			var table := _table(main, building, "ReadingDesk", Vector3(-2.65, 0, 1.6), Vector2(1.7, 1.0))
			_papers(main, table, Vector3(0, 1.02, 0))
			_bookshelf(main, building, Vector3(2.65, 0, -2.7))
		"Clinic":
			_bed(main, building, "ExaminationBed", Vector3(-2.65, 0, 1.6), p.teal)
			var cabinet := _cabinet(main, building, "MedicalCabinet", Vector3(2.65, 0, -2.7), p.cream)
			_box(main, cabinet, "CrossVertical", Vector3(0.12, 0.46, 0.04), Vector3(0, 0.62, 0.47), p.coral)
			_box(main, cabinet, "CrossHorizontal", Vector3(0.42, 0.12, 0.04), Vector3(0, 0.62, 0.5), p.coral)
			_cup(main, cabinet, Vector3(0.45, 1.08, 0), p.teal)
		"Market", "MarketStore":
			_produce_stand(main, building, Vector3(-2.65, 0, 1.6))
			var packing := _table(main, building, "PackingTable", Vector3(2.65, 0, -2.7), Vector2(1.6, 0.8))
			_box(main, packing, "Parcel", Vector3(0.65, 0.45, 0.5), Vector3(0, 1.245, 0), p.sand)
			_box(main, packing, "ParcelBand", Vector3(0.12, 0.025, 0.51), Vector3(0, 1.4825, 0), p.cream)
			if title == "MarketStore":
				_bookshelf(main, building, Vector3(3.4, 0, 1.6))
		"PostOffice":
			_mailboxes(main, building, "SortingPigeonholes", Vector3(3.2, 0, -2.6))
			var desk := _table(main, building, "PostalDesk", Vector3(-3.1, 0, 1.5), Vector2(2.0, 1.0))
			_papers(main, desk, Vector3(0, 1.02, 0))
			_sign(main, desk, "POST", Vector3(0, 1.45, 0.1))
			var box := _cabinet(main, building, "LetterBox", Vector3(3.2, 0, 1.7), p.coral)
			_box(main, box, "LetterSlot", Vector3(0.75, 0.09, 0.04), Vector3(0, 0.8, 0.47), p.slate)
		"CommunityRoom":
			var table := _table(main, building, "GamesTable", Vector3(-3.0, 0, 0.8), Vector2(2.0, 1.2))
			_box(main, table, "GameBoard", Vector3(1.1, 0.05, 0.8), Vector3(0, 1.045, 0), p.teal)
			for i in 4:
				main._add_round_detail(table, "GamePiece%d" % i, Vector3(-0.36 + i * 0.24, 1.12, 0), Vector3.ONE * 0.05, p.coral if i % 2 == 0 else p.cream)
			_bench(main, building, "GamesBench", Vector3(-3.0, 0, 2.3), p.teal)
			_bookshelf(main, building, Vector3(3.2, 0, -1.5))
		"GardenPavilion":
			var table := _table(main, building, "PottingBench", Vector3(-3.1, 0, 1.2), Vector2(2.0, 1.0))
			for i in 2:
				var x := -0.45 + i * 0.9
				_box(main, table, "Pot%d" % i, Vector3(0.5, 0.35, 0.5), Vector3(x, 1.195, 0), p.coral)
				main._add_round_detail(table, "Plant%d" % i, Vector3(x, 1.57, 0), Vector3(0.26, 0.23, 0.26), p.grass)
			_bench(main, building, "GardenSeat", Vector3(3.1, 0, 1.2), p.teal)
			_toolboard(main, building, Vector3(3.1, 0, -2.5))


static func _assembly(parent: Node3D, title: String, position: Vector3) -> Node3D:
	var item := Node3D.new()
	item.name = title
	item.position = position
	parent.add_child(item)
	return item


static func _box(main: Node3D, parent: Node3D, title: String, size: Vector3, position: Vector3, color: Color, solid := false) -> void:
	main._add_detail_box(parent, title, size, position, color, solid)


static func _table(main: Node3D, parent: Node3D, title: String, position: Vector3, size: Vector2) -> Node3D:
	var item := _assembly(parent, title, position)
	_box(main, item, "Top", Vector3(size.x, 0.14, size.y), Vector3(0, 0.95, 0), main.PALETTE.sand, true)
	for x in [-1, 1]:
		for z in [-1, 1]:
			_box(main, item, "Leg%s%s" % [x, z], Vector3(0.16, 0.88, 0.16), Vector3(x * (size.x * 0.5 - 0.13), 0.44, z * (size.y * 0.5 - 0.13)), main.PALETTE.slate, true)
	return item


static func _cabinet(main: Node3D, parent: Node3D, title: String, position: Vector3, color: Color) -> Node3D:
	var item := _assembly(parent, title, position)
	_box(main, item, "Plinth", Vector3(1.4, 0.15, 0.8), Vector3(0, 0.075, 0), main.PALETTE.slate, true)
	_box(main, item, "Cabinet", Vector3(1.6, 0.85, 0.85), Vector3(0, 0.575, 0), color, true)
	_box(main, item, "Cap", Vector3(1.7, 0.08, 0.95), Vector3(0, 1.04, 0), main.PALETTE.sand, true)
	for x in [-0.4, 0.4]:
		_box(main, item, "Door%s" % x, Vector3(0.73, 0.68, 0.04), Vector3(x, 0.58, 0.445), main.PALETTE.cream)
		_box(main, item, "Pull%s" % x, Vector3(0.2, 0.07, 0.07), Vector3(x, 0.7, 0.48), main.PALETTE.slate)
	return item


static func _bench(main: Node3D, parent: Node3D, title: String, position: Vector3, color: Color) -> void:
	var item := _assembly(parent, title, position)
	_box(main, item, "Seat", Vector3(1.7, 0.18, 0.65), Vector3(0, 0.54, 0), color, true)
	_box(main, item, "Back", Vector3(1.7, 0.65, 0.16), Vector3(0, 0.9, 0.27), color, true)
	for x in [-0.6, 0.6]:
		_box(main, item, "Foot%s" % x, Vector3(0.18, 0.45, 0.55), Vector3(x, 0.225, 0), main.PALETTE.slate, true)


static func _bed(main: Node3D, parent: Node3D, title: String, position: Vector3, color: Color) -> void:
	var item := _assembly(parent, title, position)
	for x in [-0.65, 0.65]:
		_box(main, item, "Foot%s" % x, Vector3(0.18, 0.15, 1.7), Vector3(x, 0.075, 0), main.PALETTE.slate, true)
	_box(main, item, "Frame", Vector3(1.65, 0.35, 2.0), Vector3(0, 0.325, 0), main.PALETTE.sand, true)
	_box(main, item, "Mattress", Vector3(1.55, 0.22, 1.9), Vector3(0, 0.61, 0), main.PALETTE.cream, true)
	_box(main, item, "Blanket", Vector3(1.57, 0.08, 1.15), Vector3(0, 0.76, 0.3), color)
	_box(main, item, "Pillow", Vector3(0.95, 0.15, 0.45), Vector3(0, 0.795, -0.62), main.PALETTE.cream)
	_box(main, item, "Headboard", Vector3(1.65, 0.95, 0.14), Vector3(0, 0.475, -1.0), color, true)


static func _papers(main: Node3D, parent: Node3D, position: Vector3) -> void:
	for i in 3:
		_box(main, parent, "PaperStack%d" % i, Vector3(0.65, 0.03, 0.5), position + Vector3(i * 0.025, 0.015 + i * 0.03, 0), main.PALETTE.cream)
	_box(main, parent, "Pencil", Vector3(0.45, 0.04, 0.04), position + Vector3(0, 0.02, 0.35), main.PALETTE.coral)


static func _cup(main: Node3D, parent: Node3D, position: Vector3, color: Color) -> void:
	var item := _assembly(parent, "Cup", position)
	_box(main, item, "Mug", Vector3(0.22, 0.26, 0.22), Vector3(0, 0.13, 0), color)
	_box(main, item, "Drink", Vector3(0.15, 0.02, 0.15), Vector3(0, 0.265, 0), main.PALETTE.slate)
	_box(main, item, "Handle", Vector3(0.1, 0.13, 0.09), Vector3(0.15, 0.14, 0), color)


static func _sign(main: Node3D, parent: Node3D, text: String, position: Vector3, base_height := 1.02) -> void:
	var post_height := position.y - 0.2 - base_height
	_box(main, parent, "NoticePost", Vector3(0.12, post_height, 0.12), Vector3(position.x, base_height + post_height * 0.5, position.z), main.PALETTE.sand, true)
	_box(main, parent, "NoticeBacking", Vector3(1.6, 0.4, 0.08), position, main.PALETTE.teal, true)
	main._add_label_to(parent, "NoticeText", text, position + Vector3(0, 0, 0.05), main.PALETTE.cream)
	parent.get_node("NoticeText").scale = Vector3.ONE * 0.24


static func _mailboxes(main: Node3D, parent: Node3D, title: String, position: Vector3) -> void:
	var item := _assembly(parent, title, position)
	_box(main, item, "Base", Vector3(1.6, 0.35, 0.7), Vector3(0, 0.175, 0), main.PALETTE.sand, true)
	_box(main, item, "Case", Vector3(1.7, 1.45, 0.65), Vector3(0, 1.075, 0), main.PALETTE.teal, true)
	for row in 3:
		for col in 3:
			var pos := Vector3(-0.54 + col * 0.54, 0.6 + row * 0.46, 0.35)
			_box(main, item, "Door%d%d" % [row, col], Vector3(0.46, 0.38, 0.04), pos, main.PALETTE.cream)
			_box(main, item, "Slot%d%d" % [row, col], Vector3(0.3, 0.045, 0.025), pos + Vector3(0, 0.07, 0.035), main.PALETTE.slate)


static func _bookshelf(main: Node3D, parent: Node3D, position: Vector3) -> void:
	var item := _assembly(parent, "Bookcase", position)
	_box(main, item, "Back", Vector3(1.65, 1.9, 0.12), Vector3(0, 0.95, -0.28), main.PALETTE.sand, true)
	for x in [-0.78, 0.78]:
		_box(main, item, "Side%s" % x, Vector3(0.12, 1.9, 0.65), Vector3(x, 0.95, 0), main.PALETTE.teal, true)
	for row in 3:
		var y := 0.12 + row * 0.58
		_box(main, item, "Shelf%d" % row, Vector3(1.5, 0.1, 0.65), Vector3(0, y, 0), main.PALETTE.sand, true)
		for book in 5:
			_box(main, item, "Book%d%d" % [row, book], Vector3(0.19, 0.36 + (book % 2) * 0.08, 0.4), Vector3(-0.55 + book * 0.24, y + 0.23 + (book % 2) * 0.04, 0), main.PALETTE.coral if book % 2 == 0 else main.PALETTE.cream)


static func _toolboard(main: Node3D, parent: Node3D, position: Vector3) -> void:
	var item := _cabinet(main, parent, "ToolStation", position, main.PALETTE.teal)
	_box(main, item, "ToolBoard", Vector3(1.65, 1.1, 0.12), Vector3(0, 1.65, -0.32), main.PALETTE.sand, true)
	for i in 3:
		var x := -0.5 + i * 0.5
		_box(main, item, "ToolHandle%d" % i, Vector3(0.1, 0.42, 0.1), Vector3(x, 1.6, -0.2), main.PALETTE.coral)
		_box(main, item, "ToolHead%d" % i, Vector3(0.3, 0.12, 0.16), Vector3(x, 1.86, -0.2), main.PALETTE.slate)


static func _easel(main: Node3D, parent: Node3D, position: Vector3) -> void:
	var item := _assembly(parent, "StudioEasel", position)
	for x in [-0.6, 0.6]:
		_box(main, item, "Upright%s" % x, Vector3(0.16, 2.1, 0.65), Vector3(x, 1.05, 0), main.PALETTE.sand, true)
	_box(main, item, "Canvas", Vector3(1.4, 1.05, 0.13), Vector3(0, 1.45, 0.2), main.PALETTE.cream, true)
	_box(main, item, "PaintedHorizon", Vector3(1.15, 0.25, 0.025), Vector3(0, 1.2, 0.28), main.PALETTE.teal)
	main._add_round_detail(item, "PaintedSun", Vector3(0.3, 1.65, 0.28), Vector3(0.18, 0.18, 0.025), main.PALETTE.coral)


static func _coffee_machine(main: Node3D, parent: Node3D) -> void:
	_box(main, parent, "CoffeeMachine", Vector3(0.85, 0.55, 0.5), Vector3(0, 1.355, -0.1), main.PALETTE.slate)
	_box(main, parent, "CoffeeSpout", Vector3(0.14, 0.12, 0.2), Vector3(0, 1.32, 0.25), main.PALETTE.cream)
	_cup(main, parent, Vector3(0, 1.08, 0.3), main.PALETTE.coral)


static func _produce_stand(main: Node3D, parent: Node3D, position: Vector3) -> void:
	var item := _table(main, parent, "ProduceStand", position, Vector2(1.7, 1.0))
	for i in 2:
		var x := -0.4 + i * 0.8
		_box(main, item, "Tray%d" % i, Vector3(0.7, 0.08, 0.75), Vector3(x, 1.06, 0), main.PALETTE.sand)
		for j in 3:
			main._add_round_detail(item, "Produce%d%d" % [i, j], Vector3(x - 0.2 + j * 0.2, 1.2, 0), Vector3(0.1, 0.1, 0.18), main.PALETTE.coral if i == 0 else main.PALETTE.grass)
