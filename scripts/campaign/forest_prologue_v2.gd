extends Node2D
## Dry geometry of the separate prologue ver2. Source: the approved V4 blueprint.
signal lethal_fall
const DATA = preload("res://scripts/campaign/forest_prologue_v2_data.gd")
const LADDER = preload("res://scripts/core/ladder_geometry.gd")
const UPM: float = DATA.PLAN.units_per_meter
const LADDER_WIDTH := LADDER.WIDTH*2.85
const ORIGIN := Vector2(12000,760)
const WIDTH := 484.0*UPM
const BOUNDS := Rect2(12000,760-15*UPM,WIDTH,27*UPM)
var actor
var debug_geometry := false
var sections: Array[Dictionary] = []
var surfaces: Array[PackedVector2Array] = []
var terrain: Array[PackedVector2Array] = []
var platforms: Array[Rect2] = []
var obstacles: Array[Rect2] = []
var ladders: Array[Rect2] = []
var features: Dictionary = {}
var jump_catalog: Array = DATA.PLAN.nodes.reduce(func(all,n): return all+n.jumps,[])
var lethal_rect := Rect2(point(244,-8),Vector2(1.8*UPM,5*UPM))

static func point(x_m: float,height_m: float) -> Vector2:
	return ORIGIN+Vector2(x_m,-height_m)*UPM

func _init() -> void:
	name = "ForestPrologueVer2"
	for n in DATA.PLAN.nodes:
		for profile in n.ground: _terrain(n.start_m,_recovery_profile(n.id,profile))
		for index in n.ledges.size():
			var ledge: Array = n.ledges[index]
			if n.id == "02":
				var island := ledge.duplicate()
				# A thin rock bridge, with a genuine passage beneath the upper route.
				for i in range(ledge.size()-1,-1,-1):
					island.append([ledge[i][0],float(ledge[i][1])-.15])
				_polygon(n.start_m,island)
				var edge := PackedVector2Array()
				for p in ledge: edge.append(point(n.start_m+float(p[0]),float(p[1])))
				surfaces.append(edge)
			elif n.id == "03":
				_block("root",n.start_m+14.8,2.75,4.2,.5)
			elif n.id == "12" and index == 2:
				_block("wagon_floor",n.start_m+40,5.95,8.5,.2)
			else:
				_deck(n.id+"_"+str(index),n.start_m+float(ledge[0][0]),n.start_m+float(ledge[-1][0]),float(ledge[0][1]))
		var middle: Array = n.route[n.route.size()/2]
		sections.append({"id":n.id,"label":n.title,"start_m":n.start_m,"width_m":n.length_m,"position":point(n.start_m+float(middle[0]),float(middle[1])),"kind":"zone"})
	# Positions and heights are in the blueprint's project meters, never legacy H=64.
	_ladder("ravine_return",24+10,-5.05,-1.7)
	_ladder("ravine_forward",24+22.1,-5.05,-2.2)
	_deck("ravine_forward_landing",24+21.4,24+22.8,-2.2)
	_ladder("wood_down",96+11,-1.2,2.4);_ladder("wood_up",96+33,-1.2,2.4)
	_ladder("work_up",142+14,1.2,5.8);_ladder("work_down",142+32,1.2,5.8)
	_ladder("tower",188+14,3,9)
	_ladder("house_inner",296+12,.6,3.8);_ladder("house_outside",296+32,0,3.1)
	# Keep the full reference capsule clear of the terrain step beside this ladder.
	_ladder("flank_up",338+10.6,-2,.8);_ladder("flank_down",338+22,-2,.8)
	_ladder("basement_down",386+14,-2.8,.3);_ladder("basement_up",386+23,-2.8,.3)
	_ladder("bunker_roof",386+12,.3,3.3);_ladder("bunker_rocks",386+33,0,1.9)
	_ladder("log_down",430+13,0,3);_ladder("log_up",430+25,0,3)
	_block("work_barrier",142+28,1.2,.7,.9)
	_ramp(142,[[28.7,1.2],[28.7,2.1],[30,1.2]])
	_block("cover_a",338+25,-2,1.5,1.4);_ramp(338,[[26.5,-2],[26.5,-.6],[28,-2]])
	_block("cover_b",338+34,-2,1.5,.75);_ramp(338,[[35.5,-2],[35.5,-1.25],[37,-2]])
	_block("tower_roof",188+13,11.4,6,.18)
	# Solid ceilings with physical ladder openings; one-way decks cap those openings.
	_segmented_floor("house_floor",296,10,26,3.8,.2,[12.0])
	_block("house_roof",296+10,6.5,16,.18)
	for x in [10.0,25.82]:
		_block("house_door_"+str(x),296+x,2.9,.18,.7)
	_segmented_floor("bunker_floor",386,11,25,.3,.4,[14.0,23.0])
	_segmented_floor("bunker_roof_solid",386,11,25,3.3,.3,[12.0])
	for x in [11.0,24.82]: _block("bunker_door_"+str(x),386+x,2.6,.18,.7)
	_ramp(430,[[38,5],[40,6.15],[40,5]])
	_ramp(430,[[48.5,5],[48.5,6.15],[51.5,5]])
	_block("wagon_roof",430+40,8.5,8.5,.16)

func _ready() -> void:
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(actor) or actor.health <= 0: return
	if lethal_rect.has_point(actor.global_position): lethal_fall.emit()

func set_debug_geometry(enabled: bool) -> void:
	debug_geometry = enabled
	queue_redraw()

func _recovery_profile(section: String,profile: Array) -> Array:
	# Local corrections after reported traps; keep the source V4 blueprint intact.
	var result := profile.duplicate(true)
	if section == "02":
		for p in result:
			if is_equal_approx(float(p[1]),-4.8):
				p[1] = -5.05
				if is_equal_approx(float(p[0]),21.4): p[0] = 22.8
			elif is_equal_approx(float(p[0]),21.4) and is_equal_approx(float(p[1]),-2.2):
				p[0] = 22.8
	elif section == "03":
		for p in result:
			if is_equal_approx(float(p[1]),-1.5): p[1] = 0.0
	return result

func _terrain(start: float,profile: Array) -> void:
	var points: Array = profile.duplicate()
	points.append([profile[-1][0],-10.0]);points.append([profile[0][0],-10.0])
	_polygon(start,points)
	var edge := PackedVector2Array()
	for p in profile: edge.append(point(start+float(p[0]),float(p[1])))
	surfaces.append(edge)

func _polygon(start: float,profile: Array) -> void:
	var result := PackedVector2Array()
	for p in profile:
		var value := point(start+float(p[0]),float(p[1]))
		if result.is_empty() or not result[-1].is_equal_approx(value): result.append(value)
	# Zero-width up/down spikes in the sketch are not physical landings.
	var changed := true
	while changed:
		changed = false
		for i in range(1,result.size()-1):
			if is_equal_approx(result[i-1].x,result[i].x) and is_equal_approx(result[i].x,result[i+1].x):
				result.remove_at(i);changed = true;break
	terrain.append(result)

func _ramp(start: float,profile: Array) -> void:
	_polygon(start,profile)

func _block(id: String,x: float,bottom: float,width: float,height: float) -> void:
	var rect := Rect2(point(x,bottom+height),Vector2(width,height)*UPM)
	obstacles.append(rect);features[id]=rect

func _deck(id: String,x0: float,x1: float,h: float) -> void:
	var rect := Rect2(point(x0,h),Vector2((x1-x0)*UPM,.16*UPM))
	platforms.append(rect);features[id]=rect

func _segmented_floor(id: String,start: float,x0: float,x1: float,top: float,thickness: float,openings: Array) -> void:
	var cursor := x0
	for x in openings:
		_block(id+str(cursor),start+cursor,top-thickness,float(x)-.65-cursor,thickness)
		cursor = float(x)+.65
	_block(id+str(cursor),start+cursor,top-thickness,x1-cursor,thickness)

func _ladder(id: String,x: float,bottom: float,top: float) -> void:
	var rect := LADDER.make(point(x,top).x,point(x,top).y,(top-bottom)*UPM,LADDER_WIDTH)
	ladders.append(rect);features[id+"_ladder"]=rect

func map_landmarks() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"id":"S","label":"Старт ver2","position":point(2,0),"kind":"start"}]
	result.append_array(sections)
	result.append({"id":"E","label":"Конец пролога ver2","position":point(483,5),"kind":"edge"})
	return result

func _draw() -> void:
	for polygon in terrain: draw_colored_polygon(polygon,Color("3b4c52"))
	for edge in surfaces: draw_polyline(edge,Color("8fa7ac"),3,true)
	for r in platforms:
		draw_rect(r,Color("627b82"));draw_line(r.position,Vector2(r.end.x,r.position.y),Color("b2c9c8"),3)
	for r in obstacles:
		draw_rect(r,Color("596a6d"));draw_rect(r,Color("9eafaf"),false,2)
	for r in ladders: LADDER.draw(self,r,Color("c1b68a"))
	var frame := Color("63787c")
	for record in [[188+13,188+19,3,11.4],[296+10,296+26,.6,6.5],[386+11,386+25,-2.8,3.3]]:
		draw_line(point(record[0],record[2]),point(record[0],record[3]),frame,4)
		draw_line(point(record[1],record[2]),point(record[1],record[3]),frame,4)
	# Plain structural silhouettes only; no image textures or interactive decorations.
	draw_rect(Rect2(point(15,1.45),Vector2(3.9,1.45)*UPM),frame,false,3)
	for x in [15.7,18.1]: draw_circle(point(x,.28),.28*UPM,frame,false,3)
	draw_rect(Rect2(point(270+10,2.8),Vector2(.65,1.5)*UPM),frame,false,3)
	draw_line(point(142+16,5.8),point(142+16,9.5),frame,4)
	draw_line(point(142+16,9.5),point(142+20,9.5),frame,4)
	draw_rect(Rect2(point(142+19.6,8.9),Vector2(1,.8)*UPM),frame,false,2)
	for x in [430+41.5,430+47]: draw_circle(point(x,5.5),.45*UPM,frame,false,3)
	draw_rect(lethal_rect,Color(.7,.12,.09,.55))
	var font := ThemeDB.fallback_font
	for n in DATA.PLAN.nodes:
		var anchor: Array = n.route[0]
		draw_string(font,point(n.start_m+1,float(anchor[1])+3.5),n.id+" · "+n.title,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("bccfd0"))
	draw_string(font,point(238,6),"ОБРЫВ · ПАДЕНИЕ СМЕРТЕЛЬНО · Space с разбега",HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("eea497"))
	draw_string(font,point(3,2.7),"ПРОЛОГ ver2 · W/S — лестница · C — присед · F8 — на старт",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("d0c5a4"))
	draw_string(font,point(475,8),"КОНЕЦ ПРОЛОГА ver2",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("91c7ad"))
	if debug_geometry:
		for n in DATA.PLAN.nodes:
			for j in n.jumps:
				var a := point(n.start_m+float(j.a[0]),float(j.a[1]))
				var b := point(n.start_m+float(j.b[0]),float(j.b[1]))
				draw_dashed_line(a-Vector2(0,10),b-Vector2(0,10),Color("dca253"),2,8)
				draw_string(font,a-Vector2(0,28),j.id,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("e8b267"))
