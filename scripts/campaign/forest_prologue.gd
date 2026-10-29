extends Node2D
## P1-R1: blueprint meters, full solid ceilings and independent gameplay art.
signal lethal_fall
const DATA = preload("res://scripts/campaign/forest_prologue_r1_data.gd")
const LADDER = preload("res://scripts/core/ladder_geometry.gd")
const UPM: float = DATA.PLAN.units_per_m
const ORIGIN := Vector2(12000,760)
const WIDTH := 246.0*UPM
const BOUNDS := Rect2(12000,760-9*UPM,WIDTH,16*UPM)
const SOIL_BOTTOM := 760+7*UPM
const PANORAMA_SIZE := Vector2(24600,1600)
const PANORAMA_ORIGIN := ORIGIN-Vector2(0,9*UPM)
const PANORAMA_STRIDE := 2048
const PANORAMA_GUTTER := 2
const PANORAMA_TEXTURES := [
 preload("res://resources/campaign/forest_panorama/strip_00.png"),
 preload("res://resources/campaign/forest_panorama/strip_01.png"),
 preload("res://resources/campaign/forest_panorama/strip_02.png"),
 preload("res://resources/campaign/forest_panorama/strip_03.png"),
 preload("res://resources/campaign/forest_panorama/strip_04.png"),
 preload("res://resources/campaign/forest_panorama/strip_05.png"),
 preload("res://resources/campaign/forest_panorama/strip_06.png"),
 preload("res://resources/campaign/forest_panorama/strip_07.png"),
 preload("res://resources/campaign/forest_panorama/strip_08.png"),
 preload("res://resources/campaign/forest_panorama/strip_09.png"),
 preload("res://resources/campaign/forest_panorama/strip_10.png"),
 preload("res://resources/campaign/forest_panorama/strip_11.png"),
 preload("res://resources/campaign/forest_panorama/strip_12.png")]
var actor
var backdrop: Node2D
var background_plane: Node2D
var foreground_plane: Node2D
var panorama_strips: Array[Sprite2D] = []
var debug_geometry := false
var sections: Array[Dictionary] = []
var surfaces: Array[PackedVector2Array] = []
var terrain: Array[PackedVector2Array] = []
var platforms: Array[Rect2] = []
var obstacles: Array[Rect2] = []
var ladders: Array[Rect2] = []
var features: Dictionary = {}
var lethal_rect := Rect2(point(233,-2),Vector2(1.4*UPM,5*UPM))

static func point(x_m: float,height_m: float) -> Vector2:
 return ORIGIN+Vector2(x_m,-height_m)*UPM

func _init() -> void:
 name = "ForestPrologue"
 for n in DATA.PLAN.nodes:
  _terrain(n.start_m,n.ground)
  for i in n.decks.size():
   var edge: Array = n.decks[i]
   if n.id == "03" and i == 0:
    # Root terrace has a solid core; recovery ledges remain to its right.
    _terrain(n.start_m,edge)
   elif n.id != "09" and n.id != "11":
    # The 1.3 m sketch slot traps a standing mantle under the trunk.
    # Shorten its left end by 1 m; preserve the three recovery ledges and hero.
    var clearance := 1.0 if n.id == "03" and i == 1 else 0.0
    _deck(n.id+"_deck_"+str(i),n.start_m+float(edge[0][0])+clearance,n.start_m+float(edge[-1][0]),float(edge[0][1]))
  for i in n.blocks.size():
   var b: Array = n.blocks[i]
   _block(n.id+"_block_"+str(i),n.start_m+float(b[0]),b[1],b[2],b[3])
  for i in n.ladders.size():
   var l: Array = n.ladders[i]
   # Blueprint top includes .7 m handrails, not an elevated landing.
   _ladder(n.id+"_"+str(i),n.start_m+float(l[0]),l[1],float(l[2])-.7)
  sections.append({"id":n.id,"label":n.title,"start_m":n.start_m,"width_m":n.length_m,"position":ground_point(n.start_m+n.length_m*.5),"kind":"zone"})
 # Sawmill approach and departure steps drawn in the generated gameplay plane.
 _terrain(72,[[1,1],[2,1.7],[3,1.7],[4,2.4],[4,0]])
 _terrain(72,[[24,0],[24,2.4],[25,1.7],[26,1.7],[27,1]])
 # Outside steps to the post; external ladder occupies the 1.3 m opening.
 for row in [[157,0,1.4,.8],[158.4,.8,1.4,.8],[159.8,1.6,1.4,1.0]]:
  _block("house_step_"+str(row[0]),row[0],row[1],row[2],row[3])
 _block("house_floor",162.5,2.4,6.5,.2)
 _block("house_roof",162.5,5,6.5,.2)
 for x in [162.5,168.8]:
  _block("house_door_lintel_"+str(x),x,2.15,.2,.25)
 _block("house_left_upper",162.5,4.75,.2,.25)
 _block("house_window_sill",168.8,2.6,.2,.25)
 _block("house_right_upper",168.8,5,.2,.2)
 _block("house_balcony",169,2.65,1,.2)
 _block("house_exit_rock",171.3,0,1.7,2.85)
 # Concrete roof has a real hatch. No one-way ceiling or sealed ladder exit.
 _block("bunker_roof_left",209,2.8,4,.2)
 _block("bunker_roof_right",214.3,2.8,.7,.2)
 for x in [209.0,214.8]: _block("bunker_lintel_"+str(x),x,2.55,.2,.25)
 # Open wreck ends are deliberate; roof has full collision on both faces.
 _block("wagon_roof",239,4.6,5,.16)
 # Floor follows the blueprint slope; the wreck floor is set above it.
 _block("wagon_floor",239,1.8,5,.2)

func _ready() -> void:
 z_index = 1
 background_plane = Node2D.new();background_plane.name="BackgroundPlanes";background_plane.z_index=-2;add_child(background_plane)
 backdrop = Node2D.new();backdrop.name="GameplayPlane";backdrop.position=PANORAMA_ORIGIN;backdrop.scale=Vector2.ONE*(UPM/100.0);backdrop.z_index=-1;add_child(backdrop)
 for i in PANORAMA_TEXTURES.size():
  var width := mini(PANORAMA_STRIDE,int(PANORAMA_SIZE.x)-i*PANORAMA_STRIDE)
  var region := AtlasTexture.new();region.atlas=PANORAMA_TEXTURES[i];region.region=Rect2(2,0,width,1600);region.filter_clip=false
  var strip := Sprite2D.new();strip.name="Strip%02d" % i;strip.texture=region;strip.centered=false;strip.position=Vector2(i*PANORAMA_STRIDE,0);strip.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
  backdrop.add_child(strip);panorama_strips.append(strip)
 foreground_plane=Node2D.new();foreground_plane.name="ForegroundOccluders";foreground_plane.z_index=2;add_child(foreground_plane)

func _physics_process(_delta: float) -> void:
 if is_instance_valid(actor) and actor.health > 0 and lethal_rect.has_point(actor.global_position): lethal_fall.emit()

func _polygon(start: float,profile: Array) -> void:
 var poly := PackedVector2Array()
 for p in profile: poly.append(point(start+float(p[0]),float(p[1])))
 terrain.append(poly)

func _terrain(start: float,profile: Array) -> void:
 var edge := PackedVector2Array()
 for p in profile: edge.append(point(start+float(p[0]),float(p[1])))
 surfaces.append(edge)
 var poly := edge.duplicate();poly.append(Vector2(edge[-1].x,SOIL_BOTTOM));poly.append(Vector2(edge[0].x,SOIL_BOTTOM));terrain.append(poly)

func _block(id: String,x: float,bottom: float,w: float,h: float) -> void:
 var rect := Rect2(point(x,bottom+h),Vector2(w,h)*UPM)
 obstacles.append(rect);features[id]=rect

func _deck(id: String,x0: float,x1: float,top: float) -> void:
 var rect := Rect2(point(x0,top),Vector2(x1-x0,.2)*UPM)
 platforms.append(rect);features[id]=rect

func _ladder(id: String,x: float,bottom: float,top: float) -> void:
 var rect := LADDER.make(point(x,top).x,point(x,top).y,(top-bottom)*UPM,51.3)
 ladders.append(rect);features[id+"_ladder"]=rect

func ground_point(x: float) -> Vector2:
 return point(x,ground_height(x))

func ground_height(x: float) -> float:
 for n in DATA.PLAN.nodes:
  if x < n.start_m or x > n.start_m+n.length_m: continue
  var local := x-float(n.start_m)
  for i in range(1,n.ground.size()):
   var a: Array=n.ground[i-1];var b: Array=n.ground[i]
   if float(b[0]) > float(a[0]) and local <= float(b[0]): return lerpf(a[1],b[1],(local-float(a[0]))/(float(b[0])-float(a[0])))
 return 1.0 if x > 246 else 0.0

func map_landmarks() -> Array[Dictionary]:
 var result: Array[Dictionary]=[{"id":"S","label":"Старт P1-R1","position":point(2,0),"kind":"start"}]
 result.append_array(sections);result.append({"id":"E","label":"Выход к деревне","position":point(245,1),"kind":"edge"});return result

func set_debug_geometry(enabled: bool) -> void:
 debug_geometry=enabled;queue_redraw()
 if is_instance_valid(get_parent()):get_parent().queue_redraw()

func _draw() -> void:
 if not debug_geometry:return
 for poly in terrain:draw_colored_polygon(poly,Color(.23,.3,.32,.5))
 for edge in surfaces:draw_polyline(edge,Color("61edf0"),2,true)
 for rect in platforms+obstacles:draw_rect(rect,Color(.6,.8,.8,.35));draw_rect(rect,Color("61edf0"),false,2)
 for rect in ladders:LADDER.draw(self,rect,Color("c1b68a"))
 draw_rect(lethal_rect,Color(.7,.12,.09,.5))
