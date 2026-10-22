extends Node2D
const LADDER = preload("res://scripts/core/ladder_geometry.gd")
## Approved forest plan, drawn as geometry only. No external concept art at runtime.
## Heights are positive upwards; all measurements use the existing 64 px capsule.

const H := 64.0
const ORIGIN := Vector2(12000,760)
const WIDTH := 330.0*H
const BOUNDS := Rect2(12000,80,WIDTH,1000)
const SOIL_BOTTOM := 1280.0
const SECTIONS := [
	["01","Лес / заброшенная машина",24,[[0,0],[8,0],[12,.5],[18,.5],[24,0]]],
	["02","Овраг",28,[[0,0],[4,0],[10,-3],[17,-3],[24,0],[28,0]]],
	# Flatten the ground under the root: the schematic's rising floor closed its tunnel.
	["03","Корни / поваленное дерево",30,[[0,0],[8,0],[18,0],[24,1],[30,1]]],
	["04","Лесной мост",26,[[0,1],[5,1],[10,-2.5],[17,-2.5],[22,1],[26,1]]],
	["05","Лесозаготовка",32,[[0,1],[6,1],[10,4],[18,4],[24,1],[32,1]]],
	["06","Башня лесника",24,[[0,1],[24,1]]],
	["07","Каменный переход",28,[[0,1],[5,1],[10,-2],[18,-2],[23,1],[28,0]]],
	["08","Памятный знак / передышка",20,[[0,0],[7,.5],[13,.5],[20,0]]],
	["09","Избушка лесника",30,[[0,0],[4,0],[10,2],[22,2],[27,1],[30,1]]],
	["10","Лесные укрепления",28,[[0,1],[4,1],[9,-1.5],[18,-1.5],[24,1],[28,1]]],
	# A flat landing under the roof ladder keeps the capsule clear of the slope.
	["11","Бункер",28,[[0,1],[5,1],[10,3],[20.5,3],[24,1],[28,1]]],
	["12","Бревно / железная дорога",32,[[0,1],[5,1],[10,-2],[16,-2],[21,1],[25,4],[28,4],[32,2]]],
]

var sections: Array[Dictionary] = []
var surfaces: Array[PackedVector2Array] = []
var terrain: Array[PackedVector2Array] = []
var platforms: Array[Rect2] = []
var obstacles: Array[Rect2] = []
var ladders: Array[Rect2] = []
var features: Dictionary = {}
var guides: Array[Dictionary] = []

func _init() -> void:
	name = "ForestPrologue"
	var start := 0.0
	for definition in SECTIONS:
		var surface := PackedVector2Array()
		for p in definition[3]: surface.append(point(start+float(p[0]),float(p[1])))
		surfaces.append(surface)
		var polygon := surface.duplicate()
		polygon.append(Vector2(surface[-1].x,SOIL_BOTTOM))
		polygon.append(Vector2(surface[0].x,SOIL_BOTTOM))
		terrain.append(polygon)
		sections.append({"id":definition[0],"label":definition[1],"start_H":start,"width_H":float(definition[2]),"position":ground_point(start+float(definition[2])*.5),"kind":"zone"})
		start += float(definition[2])
	# Root has 57.6 px of headroom: crouch underneath or jump onto its 89.6 px top.
	_block("root",61,.9,8,.5)
	_deck("forest_bridge",87,104,1)
	_ladder("bridge_down",93,-2.5,1)
	_ladder("bridge_up",98,-2.5,1)
	_deck("tower_deck",147,156,8)
	_ladder("tower",149,1,8)
	_deck("stone_bridge",169,187,1)
	_ladder("stone_down",175,-2,1)
	_ladder("stone_up",181,-2,1)
	# The floor is part of the solid terrain, so the cabin cannot be bypassed below.
	_block("cabin_roof",222,6,12,.25)
	_block("cabin_left_lintel",222,3.7,.25,2.3)
	_block("cabin_right_lintel",233.75,3.7,.25,2.3)
	_block("trench_cover_a",253,-1.5,.65,.55)
	_block("trench_cover_b",261,ground_height(261),.65,.55)
	_deck("bunker_roof",281,290.5,6)
	_block("bunker_left_lintel",281,4.7,.25,1.3)
	_block("bunker_right_lintel",288.75,4.7,.25,1.3)
	_ladder("bunker",290,ground_height(290),6)
	_deck("tree_bridge",303,319,1)
	_block("wagon",324,ground_height(324),3,1.4)
	_guide(2,3.8,"ПРОЛОГ · ЛЕСНОЙ УЧАСТОК")
	_guide(2,3.2,"Двигайтесь вправо · M — карта · F8 — на старт")
	_guide(58,3.2,"C — пройти под стволом · Space — сверху")
	_guide(91,3,"W / S — нижний путь по лестницам")
	_guide(146,10.4,"Обзорная площадка · W / S — лестница")
	_guide(172,3,"Верхний переход / сухой нижний ход")
	_guide(219,7.3,"Избушка лесника · проход внутри")
	_guide(279,7.5,"Бункер · вход и лестница на крышу")
	_guide(321,7,"Space — на вагон и через него")
	_guide(326,5.1,"КОНЕЦ ЛЕСНОГО УЧАСТКА")
	_guide(326,4.5,"Продолжение пролога ещё не собрано")

static func point(x_H: float,height_H: float) -> Vector2:
	return ORIGIN+Vector2(x_H*H,-height_H*H)

func ground_point(x_H: float) -> Vector2:
	return point(x_H,ground_height(x_H))

func ground_height(x_H: float) -> float:
	var start := 0.0
	for definition in SECTIONS:
		var width := float(definition[2])
		if x_H >= start and x_H <= start+width:
			var profile: Array = definition[3]
			for index in range(1,profile.size()):
				var a: Array = profile[index-1]
				var b: Array = profile[index]
				if x_H <= start+float(b[0]):
					return lerpf(float(a[1]),float(b[1]),(x_H-start-float(a[0]))/(float(b[0])-float(a[0])))
		start += width
	return 2.0 if x_H > 330 else 0.0

func _block(id: String,x_H: float,bottom_H: float,width_H: float,height_H: float) -> void:
	var rect := Rect2(point(x_H,bottom_H+height_H),Vector2(width_H,height_H)*H)
	obstacles.append(rect)
	features[id] = rect

func _deck(id: String,x0: float,x1: float,height_H: float) -> void:
	var rect := Rect2(point(x0,height_H),Vector2((x1-x0)*H,14))
	platforms.append(rect)
	features[id] = rect

func _ladder(id: String,x_H: float,bottom_H: float,top_H: float) -> void:
	var rect := LADDER.make(point(x_H,top_H).x,point(x_H,top_H).y,(top_H-bottom_H)*H)
	ladders.append(rect)
	features[id+"_ladder"] = rect

func _guide(x_H: float,height_H: float,message: String) -> void:
	guides.append({"position":point(x_H,height_H),"text":message})

func map_landmarks() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"id":"S","label":"Старт пролога","position":point(6.25,0),"kind":"start"}]
	result.append_array(sections)
	result.append({"id":"E","label":"Конец лесного участка","position":point(329,2),"kind":"edge"})
	return result

func _draw() -> void:
	for x in range(int(ORIGIN.x),int(BOUNDS.end.x)+1,128):
		draw_line(Vector2(x,100),Vector2(x,1080),Color("253239"),1)
	for y in range(120,1081,128):
		draw_line(Vector2(ORIGIN.x,y),Vector2(BOUNDS.end.x,y),Color("253239"),1)
	for polygon in terrain: draw_colored_polygon(polygon,Color("3b4c52"))
	for surface in surfaces: draw_polyline(surface,Color("8fa7ac"),3,true)
	# Non-colliding supports sit behind the playable plane, not across its path.
	for x_H in [147.0,156.0]:
		draw_line(point(x_H,1),point(x_H,8),Color("61777e"),10)
		draw_line(point(x_H,2),point(303-x_H,7),Color("52686d"),6)
	_draw_frame(147,156,8,10)
	_draw_frame(222,234,2,6)
	_draw_frame(281,289,3,6)
	# A compact empty machine marks the start; it is not the later convoy encounter.
	var car := Rect2(point(7,1.8),Vector2(3.3*H,1.3*H))
	draw_rect(car,Color("52616a"),false,3)
	for x_H in [7.6,9.6]: draw_circle(point(x_H,.5),16,Color("63777d"),false,3)
	# Logging hoist is only a structural silhouette; there is no hanging-load puzzle yet.
	draw_line(point(120,4),point(120,7),Color("647d82"),7)
	draw_line(point(120,7),point(126,7),Color("647d82"),7)
	draw_line(point(125,7),point(125,5.2),Color("647d82"),2)
	var monument := Rect2(point(201,2.1),Vector2(H*.6,H*1.6))
	draw_rect(monument,Color("738184"))
	for rect in platforms:
		draw_rect(rect,Color("637c82"))
		draw_line(rect.position,Vector2(rect.end.x,rect.position.y),Color("a3bebd"),3)
	for rect in obstacles:
		draw_rect(rect,Color("667272"))
		draw_rect(rect,Color("a6b5b0"),false,2)
	for rect in ladders:
		LADDER.draw(self,rect,Color("c1b68a"))
	var font := ThemeDB.fallback_font
	for section in sections:
		var origin := ground_point(section.start_H+1.0)
		draw_string(font,origin+Vector2(0,-164),section.id+" · "+section.label,HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("b4c9cc"))
	for guide in guides:
		draw_string(font,guide.position,guide.text,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("d6cba3"))
	var end := point(329,2)
	draw_line(end-Vector2(0,170),end,Color("8dc7af"),4)
	draw_line(end-Vector2(0,170),end+Vector2(36,-145),Color("8dc7af"),4)

func _draw_frame(x0: float,x1: float,bottom: float,top: float) -> void:
	draw_line(point(x0,bottom),point(x0,top),Color("74868a"),5)
	draw_line(point(x1,bottom),point(x1,top),Color("74868a"),5)
	draw_line(point(x0,top),point(x1,top),Color("74868a"),6)
