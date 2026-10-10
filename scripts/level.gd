class_name StationLevel
extends Node2D

const WIDTH := 4320.0
const LOWER := 1120.0
const MIDDLE := 820.0
const UPPER := 520.0
# Every span has a purpose: introduction, gap, arena, return route.
var spans: Array[Rect2] = [
	Rect2(0, LOWER, 951, 84), Rect2(1120, LOWER, 1273, 84), Rect2(2614, LOWER, 1706, 84),
	Rect2(335, MIDDLE, 1005, 42), Rect2(1500, MIDDLE, 860, 42),
	Rect2(2530, MIDDLE, 970, 42), Rect2(3717, MIDDLE, 603, 42),
	Rect2(812, UPPER, 1059, 42), Rect2(2114, UPPER, 1086, 42), Rect2(3370, UPPER, 950, 42)
]
var ladders: Array[Rect2] = [
	Rect2(509, MIDDLE - 20, 44, 320), Rect2(1196, UPPER - 20, 44, 320),
	Rect2(1737, MIDDLE - 20, 44, 320), Rect2(2209, UPPER - 20, 44, 320),
	Rect2(2768, MIDDLE - 20, 44, 320), Rect2(3023, UPPER - 20, 44, 320),
	Rect2(3917, UPPER - 20, 44, 320), Rect2(3917, MIDDLE - 20, 44, 320)
]
var checkpoint := Vector2(2040, MIDDLE)
var radio := Vector2(3700, UPPER)
var exit_point := Vector2(4160, LOWER)
var radio_active := false
var props: Texture2D
var scene_plates: Array[StationScenePlate] = []

func _ready() -> void:
	props = load("res://assets/art/v3/props.png")
	_build_scene_plates()
	for span in spans:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(span.size.x, 22)
		shape.shape = rectangle
		shape.position = Vector2(span.position.x + span.size.x * 0.5, span.position.y + 11)
		shape.one_way_collision = true
		shape.one_way_collision_margin = 5.0
		body.add_child(shape)
		add_child(body)
	for x in [-20.0, WIDTH + 20]:
		var wall := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(40, 2000)
		shape.shape = rect
		wall.position = Vector2(x, 600)
		wall.add_child(shape)
		add_child(wall)

func ladder_at(pos: Vector2, vertical := 0.0) -> int:
	for i in ladders.size():
		if vertical > 0 and pos.y >= ladders[i].end.y-8: continue
		if vertical < 0 and pos.y <= ladders[i].position.y+22: continue
		if ladders[i].grow(12).has_point(pos - Vector2(0, 22)):
			return i
	return -1

func tier(y: float) -> int:
	if y < 650: return 2
	if y < 970: return 1
	return 0

func span_at(pos: Vector2) -> int:
	for i in spans.size():
		if absf(pos.y - spans[i].position.y) < 70 and pos.x >= spans[i].position.x and pos.x <= spans[i].end.x:
			return i
	return -1

func safe_ahead(pos: Vector2, direction: float) -> bool:
	return span_at(pos + Vector2(direction * 40, 0)) >= 0

func route_ladder(pos: Vector2, target: Vector2) -> int:
	var from := tier(pos.y)
	var to := tier(target.y)
	var best := -1
	var distance := INF
	for i in ladders.size():
		var ladder := ladders[i]
		var bottom := tier(ladder.end.y + 20)
		var top := tier(ladder.position.y + 20)
		if (to > from and bottom == from) or (to < from and top == from):
			var candidate := absf(ladder.get_center().x - pos.x)
			# Never walk off an unrelated platform to reach a ladder.
			var floor_index := span_at(pos)
			if floor_index >= 0 and ladder.get_center().x >= spans[floor_index].position.x and ladder.get_center().x <= spans[floor_index].end.x:
				if candidate < distance:
					distance = candidate
					best = i
	return best

func _draw() -> void:
	# Functional equipment uses the same painted materials as its room.
	draw_texture_rect_region(props,Rect2(radio-Vector2(33,95),Vector2(66,95)),Rect2(824,16,382,516),Color("cbd1c7"))
	draw_circle(radio+Vector2(0,-27),1.5,Color("91ba92") if radio_active else Color("c09952"))
	draw_texture_rect_region(props,Rect2(exit_point-Vector2(64,210),Vector2(128,210)),Rect2(786,594,372,623),Color("8d9998"))
	draw_texture_rect_region(props,Rect2(checkpoint-Vector2(36,43),Vector2(72,43)),Rect2(24,757,613,369),Color("cbd1c7"))

# Each plate paints the walking floor, supporting rooms and distant view in one
# projection. UV calibration aligns original painted front lips with physics.
func _build_scene_plates() -> void:
	var assets := ["station_west","station_service","station_concourse","station_east_v2"]
	var rows := [
		PackedFloat32Array([0,386,790,1120,1504]),
		PackedFloat32Array([0,394,787,1128,1504]),
		PackedFloat32Array([0,411,778,1128,1504]),
		PackedFloat32Array([0,455,798,1207,1504])
	]
	for i in assets.size():
		var plate := StationScenePlate.new()
		plate.name = "ScenePlate%d" % i
		plate.painted_rows = rows[i]
		plate.blend_left = i > 0
		plate.build("res://assets/art/v3/%s.png" % assets[i],i*1080.0)
		add_child(plate)
		scene_plates.append(plate)

func set_effects_enabled(enabled: bool) -> void:
	for plate in scene_plates:
		plate.plate_material.set_shader_parameter("effects_enabled",enabled)
