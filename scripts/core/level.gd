class_name CoreMovementLevel
extends Node2D

@export var prologue_mode := false
const PROLOGUE_START := Vector2(12400,760)
const PROLOGUE_FLOOR := Rect2(12000,760,12000,100)

func player_spawn() -> Vector2:
	return PROLOGUE_START if prologue_mode else SPAWN

func right_bound() -> float:
	return PROLOGUE_FLOOR.end.x if prologue_mode else WIDTH

const WIDTH := 5900.0
const LEFT_BOUND := -6500.0
const CONCEPT_ZOMBIE_TEST_SPAWN := Vector2(-6240,760)
const EXPLOSION_TEST_SPAWN := Vector2(-1420,760)
const BARREL_RAMP_SPAWN := Vector2(-3300,610)
const HANGING_TEST_SPAWN := Vector2(-4800,760)
const HANGING_BEAM := Rect2(-4870,270,1260,18)
const FLOOR := 760.0
const FALL_LIMIT := 1120.0
const SPAWN := Vector2(160,760)
const ZOMBIE_TEST_SPAWN := Vector2(4980,760)
var floors: Array[Rect2] = [Rect2(LEFT_BOUND,760,960-LEFT_BOUND,100),Rect2(1160,760,WIDTH-1160,100)]
var platforms: Array[Rect2] = [Rect2(1340,540,420,20),Rect2(1780,540,460,20),Rect2(1780,350,460,20)]
var obstacles: Array[Rect2] = [Rect2(640,690,90,70)]
var ladders: Array[Rect2] = [Rect2(1428,540,36,220),Rect2(2000,350,36,410)]
var enemies: Array[CoreEnemyDummy] = []
var zombie: CoreZombie
var concept_zombie: CoreConceptZombie
var physics_crate: RigidBody2D
var ragdoll_mannequin: Node2D
var explosive_barrels: Array[CoreExplosiveBarrel] = []
var fuel_field: CoreFuelField
var hanging_loads: Array[CoreHangingLoad] = []
var hanging_target: CoreEnemyDummy
const BARREL_RAMP := [Vector2(-3320,610),Vector2(-3050,610),Vector2(-2690,760),Vector2(-2690,860),Vector2(-3320,860)]
# Continuous hills: ramp, flat crest, opposite ramp. Heights give 20° and 35°.
var slopes: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(3180,760),Vector2(3510,760-330*tan(deg_to_rad(20))),Vector2(3610,760-330*tan(deg_to_rad(20))),Vector2(3940,760),Vector2(3940,860),Vector2(3180,860)]),
	PackedVector2Array([Vector2(4060,760),Vector2(4320,760-260*tan(deg_to_rad(35))),Vector2(4420,760-260*tan(deg_to_rad(35))),Vector2(4680,760),Vector2(4680,860),Vector2(4060,860)])]

func _ready() -> void:
	if prologue_mode:
		floors.append(PROLOGUE_FLOOR)
		_solid(Rect2(11960,0,40,1200),false)
		_solid(Rect2(24000,0,40,1200),false)
	for rect in floors+obstacles: _solid(rect,false)
	for rect in platforms: _solid(rect,true)
	_solid(HANGING_BEAM,false)
	for points in slopes:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionPolygon2D.new()
		shape.polygon = points
		body.add_child(shape)
		add_child(body)
	_solid(Rect2(LEFT_BOUND-40,0,40,1200),false)
	_solid(Rect2(WIDTH,0,40,1200),false)
	var ramp := StaticBody2D.new()
	var ramp_shape := CollisionPolygon2D.new()
	ramp_shape.polygon = PackedVector2Array(BARREL_RAMP)
	ramp.add_child(ramp_shape)
	add_child(ramp)
	fuel_field = CoreFuelField.new()
	add_child(fuel_field)
	physics_crate = preload("res://scenes/core/physics_crate.tscn").instantiate()
	physics_crate.position = Vector2(-560,FLOOR-170)
	add_child(physics_crate)
	ragdoll_mannequin = preload("res://scenes/core/ragdoll_mannequin.tscn").instantiate()
	ragdoll_mannequin.position = Vector2(-350,FLOOR)
	add_child(ragdoll_mannequin)
	for x in [-1810.0,-1680.0]:
		var barrel: CoreExplosiveBarrel = load("res://scenes/core/explosive_barrel.tscn").instantiate()
		barrel.position = Vector2(x,FLOOR-28)
		add_child(barrel)
		explosive_barrels.append(barrel)
	for i in 3:
		var barrel: CoreExplosiveBarrel = load("res://scenes/core/fuel_barrel.tscn").instantiate()
		barrel.contents = i
		barrel.position = Vector2(-3260+i*75,582)
		add_child(barrel)
		explosive_barrels.append(barrel)
	for variant in [CoreExplosiveBarrel.Contents.EMPTY,CoreExplosiveBarrel.Contents.INERT]:
		var barrel: CoreExplosiveBarrel = load("res://scenes/core/explosive_barrel.tscn").instantiate()
		barrel.contents = variant
		barrel.position = Vector2(-1940-130*(variant-1),FLOOR-28)
		add_child(barrel)
		explosive_barrels.append(barrel)
	var fuel_barrel: CoreExplosiveBarrel = load("res://scenes/core/fuel_barrel.tscn").instantiate()
	fuel_barrel.position = Vector2(-2200,FLOOR-28)
	add_child(fuel_barrel)
	explosive_barrels.append(fuel_barrel)
	for index in 2:
		var load_fixture: CoreHangingLoad = load("res://scenes/core/hanging_load.tscn").instantiate()
		load_fixture.container = CoreHangingLoad.ContainerKind.CRATE if index == 0 else CoreHangingLoad.ContainerKind.NET
		load_fixture.contents = CoreHangingLoad.Contents.WOOD if index == 0 else CoreHangingLoad.Contents.RUBBLE
		load_fixture.base_dimensions = Vector2(96,84) if index == 0 else Vector2(140,110)
		load_fixture.position = Vector2(-4560+index*500,310)
		add_child(load_fixture)
		hanging_loads.append(load_fixture)
	for i in 3:
		var dummy := CoreEnemyDummy.new()
		dummy.position = Vector2(2460+i*230,FLOOR)
		dummy.body_size = [Vector2(32,64),Vector2(40,80),Vector2(28,56)][i]
		dummy.identifier = "%02d" % (i+1)
		add_child(dummy)
		enemies.append(dummy)
	zombie = load("res://scenes/core/zombie.tscn").instantiate()
	zombie.position = Vector2(5400,FLOOR)
	add_child(zombie)
	enemies.append(zombie)
	concept_zombie = load("res://scenes/core/concept_zombie.tscn").instantiate()
	concept_zombie.position = Vector2(-5820,FLOOR)
	add_child(concept_zombie)
	enemies.append(concept_zombie)
	hanging_target = CoreEnemyDummy.new()
	hanging_target.name = "HangingLoadTarget"
	hanging_target.identifier = "ПОД ГРУЗОМ"
	hanging_target.position = Vector2(hanging_loads[0].position.x,FLOOR)
	add_child(hanging_target)
	enemies.append(hanging_target)

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
	for x in range(int(LEFT_BOUND),int(WIDTH)+1,64): draw_line(Vector2(x,180),Vector2(x,900),Color("253039"),1)
	for y in range(192,901,64): draw_line(Vector2(LEFT_BOUND,y),Vector2(WIDTH,y),Color("253039"),1)
	for rect in floors+platforms+obstacles:
		draw_rect(rect,Color("43525b"))
		draw_line(rect.position,Vector2(rect.end.x,rect.position.y),Color("829398"),3)
	draw_rect(HANGING_BEAM,Color("495d66"))
	draw_line(HANGING_BEAM.position,HANGING_BEAM.position+Vector2(HANGING_BEAM.size.x,0),Color("8999a0"),3)
	draw_line(Vector2(HANGING_BEAM.position.x,HANGING_BEAM.end.y),HANGING_BEAM.end,Color("26333b"),3)
	draw_colored_polygon(PackedVector2Array(BARREL_RAMP),Color("43525b"))
	for i in 2: draw_line(BARREL_RAMP[i],BARREL_RAMP[i+1],Color("81c6a7"),3)
	for rect in ladders:
		var color := Color("b4af83")
		# Rails above the landing let a human-sized climber keep a handhold.
		draw_line(rect.position-Vector2(0,72),Vector2(rect.position.x,rect.end.y),color,3)
		draw_line(Vector2(rect.end.x,rect.position.y-72),rect.end,color,3)
		for y in range(int(rect.position.y)-60,int(rect.end.y),24):
			draw_line(Vector2(rect.position.x,y),Vector2(rect.end.x,y),color,2)
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(-6350,510),"11 · ЗОМБИ-СОЛДАТ · F10 — К ЗОНЕ",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("c2b579"))
	draw_string(font,Vector2(-6350,547),"Новая модель · 16 кадров в каждой анимации",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("a4b4ba"))
	draw_string(font,Vector2(-6350,579),"F1 — зоны попаданий · F6 — баланс · F7 — возрождение",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("a4b4ba"))
	draw_string(font,Vector2(-2200,555),"08 · БОЧКИ · ТОПЛИВО И ОГОНЬ",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("e6a267"))
	draw_string(font,Vector2(-2200,590),"Красная — взрывная · коричневая — топливо",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("a4b4ba"))
	draw_string(font,Vector2(-2200,620),"G — уложить и катить · выстрел в топливо — поджечь",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("a4b4ba"))
	draw_string(font,Vector2(-3320,470),"09 · БОЧКИ НА СКЛОНЕ",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("e6a267"))
	draw_string(font,Vector2(-4800,801),"10 · ПОДВЕСНЫЕ ГРУЗЫ",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("c8aa63"))
	draw_string(font,Vector2(-4800,833),"Попадите в трос или крепление · F8 — восстановить",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("a4b4ba"))
	draw_string(font,Vector2(-1080,555),"07 · ФИЗИКА · ЯЩИК И RAGDOLL",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("c19a63"))
	draw_string(font,Vector2(-1080,590),"G — взять / отпустить · A/D — толкать / тянуть",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("a4b4ba"))
	draw_string(font,Vector2(-1080,620),"Выстрел или захват — ragdoll · F8 — восстановить всё",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("a4b4ba"))
	for i in slopes.size():
		var points := slopes[i]
		draw_colored_polygon(points,Color("43525b"))
		for edge in 3: draw_line(points[edge],points[edge+1],Color("81c6a7"),3)
		draw_string(font,Vector2(points[0].x+80,803),"%d° · ПОДЪЁМ / СПУСК" % [20 if i == 0 else 35],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("81c6a7"))
	draw_string(font,Vector2(3230,480),"05 · НАКЛОННЫЕ ПОВЕРХНОСТИ",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("a4b4ba"))
	draw_string(font,Vector2(4980,570),"06 · ЗОМБИ · F9 — К ЗОНЕ",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("a0bb87"))
	if is_instance_valid(zombie):
		var home := to_local(zombie.home)+Vector2(0,10)
		draw_line(home-Vector2(zombie.tuning.patrol_radius,0),home+Vector2(zombie.tuning.patrol_radius,0),Color("a0bb87"),2)
	for item in [[Vector2(96,612),"01 · ХОДЬБА / СПРИНТ"],[Vector2(805,612),"02 · ПРЫЖОК / ДЭШ"],[Vector2(1360,284),"03 · ЛЕСТНИЦЫ"],[Vector2(2400,612),"04 · ЗАГЛУШКИ ВРАГОВ"]]:
		draw_string(font,item[0],item[1],HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("a4b4ba"))
	draw_line(SPAWN-Vector2(0,90),SPAWN,Color("81c6a7"),2)
	draw_string(font,SPAWN-Vector2(40,102),"СТАРТ",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("81c6a7"))
	draw_string(font,Vector2(975,803),"200 px",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("a4b4ba"))
