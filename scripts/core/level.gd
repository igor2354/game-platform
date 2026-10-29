class_name CoreMovementLevel
extends Node2D

@export var prologue_mode := false
@export var prologue_version := 1
const FOREST = preload("res://scripts/campaign/forest_prologue.gd")
const FOREST_V2 = preload("res://scripts/campaign/forest_prologue_v2.gd")
const LADDER = preload("res://scripts/core/ladder_geometry.gd")
const PROLOGUE_START := FOREST.ORIGIN+Vector2(2*FOREST.UPM,0)
var forest: Node2D
var atmosphere_opacity := 0.0

func player_spawn() -> Vector2:
	if prologue_mode and prologue_version == 2: return FOREST_V2.point(2,0)
	return PROLOGUE_START if prologue_mode else SPAWN

func right_bound() -> float:
	if prologue_mode and prologue_version == 2: return FOREST_V2.BOUNDS.end.x
	return FOREST.BOUNDS.end.x if prologue_mode else WIDTH

func campaign_bounds() -> Rect2:
	return FOREST_V2.BOUNDS if prologue_version == 2 else FOREST.BOUNDS

func map_landmarks() -> Array[Dictionary]:
	if prologue_mode:
		return forest.map_landmarks() if forest else []
	return [
		{"id":"S","label":"Старт","position":SPAWN,"kind":"start"},
		{"id":"12","label":"Освещение","position":CoreIndoorLighting.TEST_SPAWN,"kind":"zone"},
		{"id":"11","label":"Зомби-солдат","position":Vector2(-6350,FLOOR),"kind":"zone"},
		{"id":"10","label":"Подвесные грузы","position":Vector2(-4800,FLOOR),"kind":"zone"},
		{"id":"09","label":"Бочки на склоне","position":Vector2(-3320,FLOOR),"kind":"zone"},
		{"id":"08","label":"Бочки и топливо","position":Vector2(-2200,FLOOR),"kind":"zone"},
		{"id":"07","label":"Ящик и ragdoll","position":Vector2(-1080,FLOOR),"kind":"zone"},
		{"id":"01","label":"Ходьба и спринт","position":Vector2(96,FLOOR),"kind":"zone"},
		{"id":"02","label":"Прыжок и дэш","position":Vector2(805,FLOOR),"kind":"zone"},
		{"id":"03","label":"Лестницы","position":Vector2(1360,540),"kind":"zone"},
		{"id":"04","label":"Заглушки врагов","position":Vector2(2400,FLOOR),"kind":"zone"},
		{"id":"05","label":"Наклонные поверхности","position":Vector2(3230,FLOOR),"kind":"zone"},
		{"id":"06","label":"Зомби","position":Vector2(4980,FLOOR),"kind":"zone"}
	]

const BASE_WIDTH := 5900.0
const WIDTH := 7100.0
const LEFT_BOUND := -6500.0
const CONCEPT_ZOMBIE_TEST_SPAWN := Vector2(-6240,760)
const EXPLOSION_TEST_SPAWN := Vector2(-1420,760)
const BARREL_RAMP_SPAWN := Vector2(-3300,610)
const HANGING_TEST_SPAWN := Vector2(-4800,760)
const HANGING_BEAM := Rect2(-4870,270,1260,18)
const FLOOR := 760.0
const FALL_LIMIT := 1120.0
const SPAWN := Vector2(160,760)
const SPAWN_LEFT_DOOR := Vector2(-80,FLOOR)
const SPAWN_RIGHT_DOOR := Vector2(400,FLOOR)
const FAR_LEFT_DOOR := Vector2(LEFT_BOUND+180,FLOOR)
const FAR_RIGHT_DOOR := Vector2(BASE_WIDTH-180,FLOOR)
const ZOMBIE_TEST_SPAWN := Vector2(4980,760)
var floors: Array[Rect2] = [Rect2(LEFT_BOUND,760,960-LEFT_BOUND,100),Rect2(1160,760,BASE_WIDTH-1160,100)]
var solid_platforms: Array[Rect2] = []
var platforms: Array[Rect2] = [Rect2(1340,540,420,20),Rect2(1780,540,460,20),Rect2(1780,350,460,20)]
var obstacles: Array[Rect2] = [Rect2(640,690,90,70),Rect2(800,712,56,48)]
var ladders: Array[Rect2] = [LADDER.make(1446,540,220),LADDER.make(2018,350,410)]
var side_ladders: Array[Rect2] = [LADDER.make(1668,540,220),LADDER.make(2198,350,410)]
var enemies: Array[CoreEnemyDummy] = []
var campaign_enemies: Array[CoreZombie] = []
var zombie: CoreZombie
var concept_zombie: CoreConceptZombie
var indoor_zombie: CoreZombie
var indoor_lighting: CoreIndoorLighting
var physics_crate: RigidBody2D
var ragdoll_mannequin: Node2D
var explosive_barrels: Array[CoreExplosiveBarrel] = []
var fuel_field: CoreFuelField
var hanging_loads: Array[CoreHangingLoad] = []
var hanging_target: CoreEnemyDummy
var transition_doors: Array[CoreTransitionDoor] = []
const BARREL_RAMP := [Vector2(-3320,610),Vector2(-3050,610),Vector2(-2690,760),Vector2(-2690,860),Vector2(-3320,860)]
# Continuous hills: ramp, flat crest, opposite ramp. Heights give 20° and 35°.
var slopes: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(3180,760),Vector2(3510,760-330*tan(deg_to_rad(20))),Vector2(3610,760-330*tan(deg_to_rad(20))),Vector2(3940,760),Vector2(3940,860),Vector2(3180,860)]),
	PackedVector2Array([Vector2(4060,760),Vector2(4320,760-260*tan(deg_to_rad(35))),Vector2(4420,760-260*tan(deg_to_rad(35))),Vector2(4680,760),Vector2(4680,860),Vector2(4060,860)])]

func _ready() -> void:
	# Keep the original two entries and their landings; add profile ladders nearby.
	if not prologue_mode:
		floors[1].size.x = WIDTH-1160
		ladders.append_array(side_ladders)
		obstacles.append_array(CoreIndoorLighting.SOLIDS)
	if prologue_mode:
		forest = FOREST_V2.new() if prologue_version == 2 else FOREST.new()
		add_child(forest)
		platforms.append_array(forest.platforms)
		obstacles.append_array(forest.obstacles)
		ladders.append_array(forest.ladders)
		slopes.append_array(forest.terrain)
		if prologue_version == 2:
			var bounds := campaign_bounds()
			_solid(Rect2(bounds.position.x-40,bounds.position.y,40,bounds.size.y),false)
			_solid(Rect2(bounds.end.x,bounds.position.y,40,bounds.size.y),false)
		else:
			_solid(Rect2(FOREST.ORIGIN.x-40,-1500,40,3000),false)
			_solid(Rect2(FOREST.BOUNDS.end.x,-1500,40,3000),false)
	for rect in floors+obstacles: _solid(rect,false)
	for rect in platforms:
		solid_platforms.append_array(preload("res://scripts/core/platform_surfaces.gd").split(rect,ladders))
	for rect in solid_platforms: _solid(rect,false)
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
	_solid(Rect2(BASE_WIDTH if prologue_mode else WIDTH,0,40,1200),false)
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
	if not prologue_mode:
		indoor_lighting = CoreIndoorLighting.new()
		indoor_lighting.name = "IndoorLightingTest"
		add_child(indoor_lighting)
		indoor_zombie = load("res://scenes/core/zombie.tscn").instantiate()
		indoor_zombie.identifier = "Z03"
		indoor_zombie.position = CoreIndoorLighting.ENEMY_HOME
		add_child(indoor_zombie)
		enemies.append(indoor_zombie)
		_add_transition_door("SpawnLeftDoor",SPAWN_LEFT_DOOR,FAR_LEFT_DOOR,"К ЛЕВОМУ КРАЮ")
		_add_transition_door("SpawnRightDoor",SPAWN_RIGHT_DOOR,FAR_RIGHT_DOOR,"К ПРАВОМУ КРАЮ")
		_add_transition_door("FarLeftReturnDoor",FAR_LEFT_DOOR,SPAWN_LEFT_DOOR,"К СТАРТУ")
		_add_transition_door("FarRightReturnDoor",FAR_RIGHT_DOOR,SPAWN_RIGHT_DOOR,"К СТАРТУ")
	if prologue_mode and prologue_version == 2:
		campaign_enemies = preload("res://scripts/campaign/prologue_v2_encounters.gd").populate(self)
	elif prologue_mode:
		campaign_enemies = preload("res://scripts/campaign/prologue1_r1_encounters.gd").populate(self)

func _add_transition_door(door_name: String,point: Vector2,destination: Vector2,label: String) -> void:
	var door := CoreTransitionDoor.new()
	door.name = door_name
	door.position = point
	door.destination_position = destination
	door.destination_label = label
	add_child(door)
	transition_doors.append(door)

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
	# Prologue 1 now has transparent art. Its own debug overlay draws these
	# supports; the old lab drawing must not leak through the empty backdrop.
	if prologue_mode and prologue_version == 1 and is_instance_valid(forest) and not forest.debug_geometry:
		return
	var grid_color := Color(Color("253039"),1.0-atmosphere_opacity*.95)
	var test_right := BASE_WIDTH if prologue_mode else WIDTH
	for x in range(int(LEFT_BOUND),int(test_right)+1,64): draw_line(Vector2(x,180),Vector2(x,900),grid_color,1)
	for y in range(192,901,64): draw_line(Vector2(LEFT_BOUND,y),Vector2(test_right,y),grid_color,1)
	for rect in floors+solid_platforms+obstacles:
		draw_rect(rect,Color("43525b"))
		draw_line(rect.position,Vector2(rect.end.x,rect.position.y),Color("829398"),3)
	draw_rect(HANGING_BEAM,Color("495d66"))
	draw_line(HANGING_BEAM.position,HANGING_BEAM.position+Vector2(HANGING_BEAM.size.x,0),Color("8999a0"),3)
	draw_line(Vector2(HANGING_BEAM.position.x,HANGING_BEAM.end.y),HANGING_BEAM.end,Color("26333b"),3)
	draw_colored_polygon(PackedVector2Array(BARREL_RAMP),Color("43525b"))
	for i in 2: draw_line(BARREL_RAMP[i],BARREL_RAMP[i+1],Color("81c6a7"),3)
	for rect in ladders:
		var profile := rect in side_ladders
		LADDER.draw(self,rect,Color("88aeb9") if profile else Color("b4af83"),profile)
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(630,657),"ПАРКУР · удерживайте Space у края",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("81c6a7"))
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
		# Forest draws its own terrain; avoid an opaque duplicate over the approved backdrop.
		if prologue_mode and i >= slopes.size()-forest.terrain.size(): continue
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
	draw_string(font,Vector2(975,803),CoreWorldUnits.distance(200),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("a4b4ba"))
