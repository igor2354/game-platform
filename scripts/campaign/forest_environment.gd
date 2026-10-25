extends Node2D
const HUMAN_SCALE = preload("res://scripts/campaign/environment_scale.gd")
## Main road is preserved; buildings use the human-scale physical geometry.
## Full panels use 1672x941 landmarks; cutouts have their own measured UV rows.
const DISTANT = preload("res://resources/campaign/forest_route/00_distant_forest.png")
const PAINTINGS = [
	preload("res://resources/campaign/forest_route/01_safe_start.png"),
	preload("res://resources/campaign/forest_route/02_ravine.png"),
	preload("res://resources/campaign/forest_route/03_roots.png"),
	preload("res://resources/campaign/forest_route/04_timber_bridge.png"),
	preload("res://resources/campaign/forest_route/05_logging.png"),
	preload("res://resources/campaign/forest_route/06_watchtower_background.png"),
	preload("res://resources/campaign/forest_route/07_stone_crossing.png"),
	preload("res://resources/campaign/forest_route/08_memorial.png"),
	preload("res://resources/campaign/forest_route/09_ranger_lodge_background.png"),
	preload("res://resources/campaign/forest_route/10_earthworks.png"),
	preload("res://resources/campaign/forest_route/11_bunker_background.png"),
	preload("res://resources/campaign/forest_route/12_railway.png"),
]
const ROAD = [
	[[0,655],[557,655],[835,618],[1254,618],[1672,655]],
	[[0,602],[240,602],[600,788],[1020,788],[1433,602],[1672,602]],
	[[0,640],[430,640],[1050,640],[1340,568],[1672,568]],
	[[0,548],[320,548],[645,813],[1093,813],[1415,548],[1672,548]],
	[[0,655],[330,655],[550,482],[1110,482],[1350,655],[1672,655]],
	[[0,752],[1672,752]],
	[[0,566],[296,566],[600,768],[1080,768],[1380,566],[1672,610]],
	[[0,594],[580,552],[1090,552],[1672,594]],
	[[0,691],[223,691],[557,576],[1226,576],[1505,638],[1672,638]],
	[[0,613],[239,613],[538,768],[1075,768],[1433,613],[1672,613]],
	[[0,637],[298,637],[597,507],[1224,507],[1433,637],[1672,637]],
	[[0,610],[260,610],[523,814],[836,814],[1097,610],[1306,455],[1463,455],[1672,559]],
]
# [source y, existing feature, blend range in source x]; no collision data is copied.
const FEATURES = {
	2: [[539,"root",450,1080],[605,"root_clearance",450,1080]],
	3: [[508,"forest_bridge_rail",260,1420],[548,"forest_bridge",0,1672]],
	5: [[226,"tower_rail",0,1672],[276,"tower_deck",0,1672]],
	6: [[520,"stone_bridge_rail",260,1420],[566,"stone_bridge",0,1672]],
	11: [[333,"wagon",1320,1560],[610,"tree_bridge",0,1220]],
}
const X_ANCHORS = {
	3: [[700,11],[1027,16]],
	5: [[470,7],[628,9],[1140,16]],
	6: [[660,11],[1012,17]],
}
const SOURCE := Vector2(1672,941)
const OVERLAP := 96.0
var forest: Node2D
var panels: Array[MeshInstance2D] = []
var buildings: Array[MeshInstance2D] = []
const HUT = preload("res://resources/campaign/forest_route/lookout_hut.png")
const CABIN = preload("res://resources/campaign/forest_route/ranger_lodge.png")
const BUNKER = preload("res://resources/campaign/forest_route/bunker.png")

func _building(texture: Texture2D, left: float, width: float, source_x: Vector2, rows: Array, id: String) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in rows:
		for side in 2:
			vertices.append(Vector3(left+width*side,float(row[1]),0))
			uvs.append(Vector2(source_x[side],float(row[0]))/texture.get_size())
	for r in range(rows.size()-1):
		var a := r*2
		indices.append_array(PackedInt32Array([a,a+1,a+2,a+1,a+3,a+2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node := MeshInstance2D.new()
	node.name = id
	node.texture = texture
	node.mesh = mesh
	node.z_index = 1
	buildings.append(node)
	add_child(node)

func landmark_y(id: String) -> float:
	match id:
		"root_clearance": return forest.features.root.end.y
		"forest_bridge_rail": return forest.features.forest_bridge.position.y-HUMAN_SCALE.units(HUMAN_SCALE.RAIL_HEIGHT_M)
		"stone_bridge_rail": return forest.features.stone_bridge.position.y-HUMAN_SCALE.units(HUMAN_SCALE.RAIL_HEIGHT_M)
		"tower_hut_top": return forest.features.tower_deck.position.y-HUMAN_SCALE.units(HUMAN_SCALE.TOWER_HUT_HEIGHT_M)
		"tower_door": return forest.features.tower_deck.position.y-HUMAN_SCALE.units(HUMAN_SCALE.DOOR_HEIGHT_M)
		"tower_rail": return forest.features.tower_deck.position.y-HUMAN_SCALE.units(HUMAN_SCALE.RAIL_HEIGHT_M)
		"cabin_rail": return forest.features.cabin_roof.position.y-HUMAN_SCALE.units(HUMAN_SCALE.RAIL_HEIGHT_M)
		"bunker_rail": return forest.features.bunker_roof.position.y-HUMAN_SCALE.units(HUMAN_SCALE.RAIL_HEIGHT_M)
		"cabin_door": return forest.features.cabin_left_lintel.end.y
		"bunker_door": return forest.features.bunker_left_lintel.end.y
		"cabin_table": return forest.ground_point(225).y-HUMAN_SCALE.units(HUMAN_SCALE.TABLE_HEIGHT_M)
		"cabin_seat": return forest.ground_point(225).y-HUMAN_SCALE.units(HUMAN_SCALE.CHAIR_SEAT_M)
		"bunker_table": return forest.ground_point(285).y-HUMAN_SCALE.units(HUMAN_SCALE.TABLE_HEIGHT_M)
	return forest.features[id].position.y

func configure(route: Node2D) -> void:
	forest = route
	name = "ForestEnvironment"
	z_index = -2
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# A fixed world-space distant layer also covers the top of the camera at the tower.
	var distant := Sprite2D.new()
	distant.name = "DistantForest"
	distant.texture = DISTANT
	distant.centered = false
	distant.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	distant.region_enabled = true
	distant.position = Vector2(forest.ORIGIN.x - 1800, -512)
	distant.scale = Vector2.ONE * 2.0
	distant.region_rect = Rect2(0,0,(forest.WIDTH + 3600) / 2.0,1600)
	add_child(distant)
	for i in PAINTINGS.size():
		var panel := MeshInstance2D.new()
		panel.name = "Section_%02d" % (i+1)
		panel.texture = PAINTINGS[i]
		panel.mesh = _mesh(i)
		panels.append(panel)
		add_child(panel)
	# The spawn camera sees beyond the closed left boundary. Continue the scenery
	# there instead of exposing a rectangular cliff edge; this has no collision.
	var border := MeshInstance2D.new()
	border.name = "LeftCameraMargin"
	border.mesh = panels[0].mesh
	border.texture = PAINTINGS[0]
	border.scale.x = -1
	border.position.x = forest.ORIGIN.x*2
	add_child(border)
	# Separate cutouts keep calibration out of the trees/sky/ground image.
	var hut_floor: float = forest.features.tower_deck.position.y
	var hut_height: float = HUMAN_SCALE.TOWER_HUT_HEIGHT_M
	_building(HUT,forest.features.tower_deck.position.x+HUMAN_SCALE.units(.2),HUMAN_SCALE.units(2.8),Vector2(0,HUT.get_width()),[
		[0,hut_floor-HUMAN_SCALE.units(hut_height+.08)],[49,landmark_y("tower_hut_top")],[500,landmark_y("tower_door")],[1125,hut_floor],[HUT.get_height(),hut_floor+HUMAN_SCALE.units(.08)]],"LookoutHut")
	var cabin_floor: float = forest.ground_point(228).y
	var cabin: Rect2 = forest.features.cabin_roof
	_building(CABIN,cabin.position.x,cabin.size.x,Vector2(0,CABIN.get_width()),[
		[0,landmark_y("cabin_rail")-HUMAN_SCALE.units(.08)],[71,landmark_y("cabin_rail")],[240,cabin.position.y],[330,cabin.end.y],[420,landmark_y("cabin_door")],[660,landmark_y("cabin_table")],[710,landmark_y("cabin_seat")],[800,cabin_floor],[CABIN.get_height(),cabin_floor+HUMAN_SCALE.units(.08)]],"RangerLodge")
	var bunker_floor: float = forest.ground_point(285.5).y
	var bunker: Rect2 = forest.features.bunker_roof
	var body_width: float = forest.features.bunker_right_lintel.end.x-bunker.position.x
	_building(BUNKER,bunker.position.x,body_width,Vector2(0,BUNKER.get_width()),[
		[0,landmark_y("bunker_rail")-HUMAN_SCALE.units(.08)],[122,landmark_y("bunker_rail")],[310,bunker.position.y],[390,bunker.end.y],[480,landmark_y("bunker_door")],[690,landmark_y("bunker_table")],[825,bunker_floor],[BUNKER.get_height(),bunker_floor+HUMAN_SCALE.units(.08)]],"ConcreteBunker")

func _sample(points: Array, x: float) -> float:
	for j in range(1,points.size()):
		var a: Array = points[j-1]
		var b: Array = points[j]
		if x <= float(b[0]):
			return lerpf(float(a[1]),float(b[1]),inverse_lerp(float(a[0]),float(b[0]),x))
	return float(points[-1][1])

func horizontal_anchors(index: int) -> Array:
	var profile: Array = forest.SECTIONS[index][3]
	var result: Array = []
	for j in ROAD[index].size():
		result.append([float(ROAD[index][j][0]), float(profile[j][0])*forest.H])
	for extra in X_ANCHORS.get(index,[]):
		result.append([float(extra[0]),float(extra[1])*forest.H])
	result.sort_custom(func(a,b): return a[0] < b[0])
	# Extend only the leading edge; the next painting fades over this one's tail.
	result[0][1] = -OVERLAP if index > 0 else 0.0
	return result

func column_anchors(index: int, source_x: float, world_x: float) -> Array:
	var road_y := _sample(ROAD[index],source_x)
	var ground: float = forest.ground_point((world_x-forest.ORIGIN.x)/forest.H).y
	var top_H: float = forest.sections[index].width_H*9.0/16.0-(1.5 if index == 5 else 4.0)
	var image_top: float = forest.ORIGIN.y-top_H*forest.H
	var anchors: Array = [[0.0,image_top]]
	var top := float(anchors[0][1])
	for marker in FEATURES.get(index,[]):
		var source_y := minf(float(marker[0]),road_y-1.0)
		var target := landmark_y(marker[1])
		var weight := smoothstep(float(marker[2])-50,float(marker[2]),source_x) * (1.0-smoothstep(float(marker[3]),float(marker[3])+50,source_x))
		var baseline := lerpf(image_top,ground,source_y/road_y)
		target = clampf(lerpf(baseline,target,weight),top+1,ground-1)
		anchors.append([source_y,target])
		top = target
	anchors.append([road_y,ground])
	anchors.append([SOURCE.y,forest.SOIL_BOTTOM])
	return anchors

func _mesh(index: int) -> ArrayMesh:
	var section: Dictionary = forest.sections[index]
	var x0: float = forest.ORIGIN.x+section.start_H*forest.H
	var horizontal := horizontal_anchors(index)
	var columns: Array[float] = []
	for x in range(0,1673,24): columns.append(float(x))
	columns.append(SOURCE.x)
	for p in horizontal:
		if float(p[0]) not in columns: columns.append(float(p[0]))
	columns.sort()
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var rows := 0
	for source_x in columns:
		var local_x := _sample(horizontal,source_x)
		var world_x := x0+local_x
		var anchors := column_anchors(index,source_x,world_x)
		rows = (anchors.size()-1)*8+1
		for row in rows:
			var segment := mini(row/8,anchors.size()-2)
			var t := float(row-segment*8)/8.0
			var source_y := lerpf(anchors[segment][0],anchors[segment+1][0],t)
			var y := lerpf(anchors[segment][1],anchors[segment+1][1],t)
			vertices.append(Vector3(world_x,y,0))
			uv.append(Vector2(source_x,source_y)/SOURCE)
			var fade_x := smoothstep(-OVERLAP,0,local_x) if index > 0 else 1.0
			colors.append(Color(1,1,1,fade_x*smoothstep(0,36,source_y)))
	for col in range(columns.size()-1):
		for row in range(rows-1):
			var a := col*rows+row
			indices.append_array(PackedInt32Array([a,a+rows,a+1,a+1,a+rows,a+rows+1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
