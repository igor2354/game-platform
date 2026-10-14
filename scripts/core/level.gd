class_name CoreMovementLevel
extends Node2D

const WIDTH := 5900.0
const FLOOR := 760.0
const FALL_LIMIT := 1120.0
const SPAWN := Vector2(160,760)
const ZOMBIE_TEST_SPAWN := Vector2(4980,760)
var floors: Array[Rect2] = [Rect2(0,760,960,100),Rect2(1160,760,WIDTH-1160,100)]
var platforms: Array[Rect2] = [Rect2(1340,540,420,20),Rect2(1780,540,460,20),Rect2(1780,350,460,20)]
var obstacles: Array[Rect2] = [Rect2(640,690,90,70)]
var ladders: Array[Rect2] = [Rect2(1428,540,36,220),Rect2(2000,350,36,410)]
var enemies: Array[CoreEnemyDummy] = []
var zombie: CoreZombie
# Continuous hills: ramp, flat crest, opposite ramp. Heights give 20° and 35°.
var slopes: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(3180,760),Vector2(3510,760-330*tan(deg_to_rad(20))),Vector2(3610,760-330*tan(deg_to_rad(20))),Vector2(3940,760),Vector2(3940,860),Vector2(3180,860)]),
	PackedVector2Array([Vector2(4060,760),Vector2(4320,760-260*tan(deg_to_rad(35))),Vector2(4420,760-260*tan(deg_to_rad(35))),Vector2(4680,760),Vector2(4680,860),Vector2(4060,860)])]

func _ready() -> void:
	for rect in floors+obstacles: _solid(rect,false)
	for rect in platforms: _solid(rect,true)
	for points in slopes:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionPolygon2D.new()
		shape.polygon = points
		body.add_child(shape)
		add_child(body)
	_solid(Rect2(-40,0,40,1200),false)
	_solid(Rect2(WIDTH,0,40,1200),false)
	for i in 3:
		var dummy := CoreEnemyDummy.new()
		dummy.position = Vector2(2460+i*230,FLOOR)
		dummy.body_size = [Vector2(32,64),Vector2(40,80),Vector2(28,56)][i]
		dummy.identifier = "%02d" % (i+1)
		add_child(dummy)
		enemies.append(dummy)
	zombie = preload("res://scenes/core/zombie.tscn").instantiate()
	zombie.position = Vector2(5400,FLOOR)
	add_child(zombie)
	enemies.append(zombie)

func _solid(rect: Rect2,one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 8 if one_way else 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.get_center()
	shape.one_way_collision = one_way
	shape.one_way_collision_margin = 4
	body.add_child(shape)
	add_child(body)

func _draw() -> void:
	for x in range(0,int(WIDTH)+1,64): draw_line(Vector2(x,180),Vector2(x,900),Color("253039"),1)
	for y in range(192,901,64): draw_line(Vector2(0,y),Vector2(WIDTH,y),Color("253039"),1)
	for rect in floors+platforms+obstacles:
		draw_rect(rect,Color("43525b"))
		draw_line(rect.position,Vector2(rect.end.x,rect.position.y),Color("829398"),3)
	for rect in ladders:
		var color := Color("b4af83")
		# Rails above the landing let a human-sized climber keep a handhold.
		draw_line(rect.position-Vector2(0,72),Vector2(rect.position.x,rect.end.y),color,3)
		draw_line(Vector2(rect.end.x,rect.position.y-72),rect.end,color,3)
		for y in range(int(rect.position.y)-60,int(rect.end.y),24):
			draw_line(Vector2(rect.position.x,y),Vector2(rect.end.x,y),color,2)
	var font := ThemeDB.fallback_font
	for i in slopes.size():
		var points := slopes[i]
		draw_colored_polygon(points,Color("43525b"))
		for edge in 3: draw_line(points[edge],points[edge+1],Color("81c6a7"),3)
		draw_string(font,Vector2(points[0].x+80,803),"%d° · ПОДЪЁМ / СПУСК" % [20 if i == 0 else 35],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("81c6a7"))
	draw_string(font,Vector2(3230,480),"05 · НАКЛОННЫЕ ПОВЕРХНОСТИ",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("a4b4ba"))
	draw_string(font,Vector2(4980,570),"06 · ЗОМБИ · T — К ЗОНЕ",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("a0bb87"))
	if is_instance_valid(zombie):
		var home := to_local(zombie.home)+Vector2(0,10)
		draw_line(home-Vector2(zombie.tuning.patrol_radius,0),home+Vector2(zombie.tuning.patrol_radius,0),Color("a0bb87"),2)
	for item in [[Vector2(96,612),"01 · ХОДЬБА / СПРИНТ"],[Vector2(805,612),"02 · ПРЫЖОК / ДЭШ"],[Vector2(1360,284),"03 · ЛЕСТНИЦЫ"],[Vector2(2400,612),"04 · ЗАГЛУШКИ ВРАГОВ"]]:
		draw_string(font,item[0],item[1],HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("a4b4ba"))
	draw_line(SPAWN-Vector2(0,90),SPAWN,Color("81c6a7"),2)
	draw_string(font,SPAWN-Vector2(40,102),"СТАРТ",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("81c6a7"))
	draw_string(font,Vector2(975,803),"200 px",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("a4b4ba"))
