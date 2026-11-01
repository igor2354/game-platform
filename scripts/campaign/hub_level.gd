extends CoreMovementLevel
## Isolated dry hub. No polygon fixtures, hostiles, ladder triggers or auto travel.
const HUB = preload("res://scripts/campaign/hub_geometry.gd")

func player_spawn() -> Vector2:
	return HUB.point(49,0)

func right_bound() -> float:
	return HUB.BOUNDS.end.x

func campaign_bounds() -> Rect2:
	return HUB.BOUNDS

func map_landmarks() -> Array[Dictionary]:
	return forest.map_landmarks() if forest else []

func _ready() -> void:
	floors.clear(); platforms.clear(); obstacles.clear(); ladders.clear()
	side_ladders.clear(); slopes.clear()
	forest = HUB.new()
	add_child(forest)
	var art:=preload("res://scripts/campaign/hub_visual.gd").new()
	art.geometry=forest
	add_child(art)
	forest.visual_art=art
	floors.assign(forest.floor_rects)
	obstacles.assign(forest.wall_rects)
	var stair_floors: Array[Node] = []
	for rect in floors:
		_solid(rect,false);stair_floors.append(get_child(-1))
	for rect in obstacles: _solid(rect,false)
	for points in forest.stair_flights:
		var route := preload("res://scripts/core/stair_flight.gd").new()
		route.bottom=points[0];route.top=points[1]
		add_child(route)
		for floor_body in stair_floors: route.pass_through_floors.append(route.get_path_to(floor_body))
	fuel_field = CoreFuelField.new()
	add_child(fuel_field)

func _draw() -> void:
	pass
