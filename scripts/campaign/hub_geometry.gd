extends Node2D
signal lethal_fall
const DATA = preload("res://scripts/campaign/hub_data.gd")
const UPM := 100.97598
const ORIGIN := Vector2(12000,760)
const BOUNDS := Rect2(12000,760-19*UPM,80*UPM,23*UPM)
var actor
var visual_art: Node2D
var debug_geometry := true
var floor_rects: Array[Rect2] = []
var wall_rects: Array[Rect2] = []
var platforms: Array[Rect2] = []
var obstacles: Array[Rect2] = []
var ladders: Array[Rect2] = [] # Deliberately not registered with the player.
var terrain: Array[PackedVector2Array] = []
var features: Dictionary = {}
var stair_flights: Array[PackedVector2Array] = []
var room_boxes: Array[Dictionary] = []
var sections: Array[Dictionary] = []

static func point(x: float,h: float) -> Vector2:
	return ORIGIN + Vector2(x,-h)*UPM

static func box(x: float,h: float,w: float,t: float) -> Rect2:
	return Rect2(point(x,h),Vector2(w,t)*UPM)

func _init() -> void:
	name = "HubBlocking07"
	z_index = -1
	floor_rects.append(box(0,0,80,.5))
	for row in [[24.0,72.0,4.4],[24.0,72.0,7.8],[48.0,72.0,11.2],[24.0,28.0,11.2],[68.0,72.0,14.6]]:
		# Stairs occupy a deliberate backplane. Ordinary corridor traversal has
		# continuous support; stair_motion alone grants passage through landings.
		floor_rects.append(box(row[0],row[2],row[1]-row[0],.25))
	# Building envelopes. Ground doors have 2.2m headroom; upper bounds are solid.
	for row in [[24.0,14.25],[72.0,17.65]]:
		wall_rects.append(box(row[0]-.125,row[1],.25,row[1]-2.2))
	for row in [[28.0,48.0,10.8],[48.0,68.0,14.6],[24.0,28.0,14.25],[68.0,72.0,17.65]]:
		var roof := box(row[0],row[2],row[1]-row[0],.25)
		wall_rects.append(roof); features["roof_"+str(row[0])] = roof
	for x in [28.0,48.0,68.0]:
		for h in [0.0,4.4,7.8]:
			wall_rects.append(box(x-.125,h+2.75,.25,.55))
	# Safe exterior limits, not random holes beyond the edge.
	wall_rects.append(box(-.3,20,.3,25)); wall_rects.append(box(80,20,.3,25))
	for core in [[24.0,[0.0,4.4,7.8,11.2]],[68.0,[0.0,4.4,7.8,11.2,14.6]]]:
		for i in core[1].size()-1:
			var bottom: float = core[1][i]
			var top: float = core[1][i+1]
			var middle := (bottom+top)*.5
			for flight in [[core[0]+.6,bottom,core[0]+3.4,middle],[core[0]+3.4,middle,core[0]+.6,top]]:
				stair_flights.append(PackedVector2Array([point(flight[0],flight[1]),point(flight[2],flight[3])]))
	for room in DATA.PLAN.rooms:
		var height := 3.15 if room.height_m > 0 else 3.8
		if room.id == "R01": height = 3.3
		if room.height_m == 7.8 and room.x_m[1] <= 48: height = 2.75
		room_boxes.append({"id":room.id,"label":room.name,"locked":room.state == "locked","rect":box(room.x_m[0],room.height_m+height,room.x_m[1]-room.x_m[0],height)})
		sections.append({"id":room.id,"label":room.name,"position":point((room.x_m[0]+room.x_m[1])*.5,room.height_m),"kind":"zone"})

func map_landmarks() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"id":"hub_entry","label":"Хаб · вход","position":point(49,0),"kind":"start"}]
	result.append_array(sections)
	return result

func set_debug_geometry(enabled: bool) -> void:
	debug_geometry = enabled
	queue_redraw()

func _draw() -> void:
	if is_instance_valid(visual_art): return
	var font := ThemeDB.fallback_font
	for room in room_boxes:
		var color := Color("544b34") if room.locked else Color("233b42")
		draw_rect(room.rect,color)
		draw_rect(room.rect,Color("9badac"),false,2)
		draw_string(font,room.rect.position+Vector2(12,35),room.id+" · "+room.label,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("d9d0b0"))
		if room.locked: draw_string(font,room.rect.position+Vector2(12,68),"РЕЗЕРВ · ЗАКРЫТО",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("d5b777"))
	for rect in floor_rects + wall_rects:
		draw_rect(rect,Color("596f77")); draw_rect(rect,Color("a0b2b5"),false,2)
	for flight in stair_flights:
		draw_line(flight[0],flight[1],Color("bd9862"),7)
		for i in 18:
			var p: Vector2 = flight[0].lerp(flight[1],float(i)/17)
			draw_line(p,p+Vector2(18,0),Color("e0c595"),3)
	for core in [26.0,70.0]:
		draw_string(font,point(core-1.8,2.5),"ЛЕСТНИЦА · A/D + W/S",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("e0c595"))
	for item in DATA.PLAN.services:
		var p := point(item[2],0)
		draw_rect(Rect2(p-Vector2(65,105),Vector2(130,105)),Color("75603d"))
		draw_string(font,p+Vector2(-110,-125),item[0]+" · "+item[1],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("ead3a0"))
	for x in [1.5,22.5,73.5,78.5]:
		draw_rect(box(x,2.7,.2,2.7),Color("806d52"))
	draw_string(font,point(48,2.5),"ХАБ · ВХОД / ВОЗВРАТ",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("f2dda6"))
