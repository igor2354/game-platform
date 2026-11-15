extends Node3D
## Native static geometry for the migration. No 2D world is instantiated.
const SOURCE = preload("res://scripts/core/level.gd")
const SURFACES = preload("res://scripts/core/platform_surfaces.gd")
const U := 100.97598
var ladder_rects: Array[Rect2] = []
var surface_count := 0

func point(p: Vector2, depth := 0.0) -> Vector3:
	return Vector3(p.x / U, (760.0 - p.y) / U, depth)

func _ready() -> void:
	var source := SOURCE.new()
	ladder_rects.assign(source.ladders + source.side_ladders)
	for i in ladder_rects.size():
		ladder_rects[i].position.x -= (51.3 - ladder_rects[i].size.x) * .5
		ladder_rects[i].size.x = 51.3
	var floors: Array[Rect2] = source.floors.duplicate()
	floors[1].size.x = SOURCE.WIDTH - 1160
	for rect in floors: box(rect, 2.25, Color("526874"))
	for rect in [Rect2(560,630,110,130), Rect2(800,675,70,85)]:
		box(rect, 1.25, Color("96724c"))
	for rect in CoreIndoorLighting.SOLIDS: box(rect, 2.25, Color("526874"))
	for rect in source.platforms:
		for segment in SURFACES.split(rect, ladder_rects): box(segment, 1.65, Color("508e86"))
	box(SOURCE.HANGING_BEAM, 1.25, Color("526874"))
	for polygon in source.slopes: prism(polygon)
	prism(PackedVector2Array(SOURCE.BARREL_RAMP))
	box(Rect2(SOURCE.LEFT_BOUND-40,0,40,1200),2.25,Color("526874"))
	box(Rect2(SOURCE.WIDTH,0,40,1200),2.25,Color("526874"))
	for rect in ladder_rects:
		for x in [rect.position.x, rect.end.x]:
			box(Rect2(x-2,rect.position.y-72,4,rect.size.y+72),.08,Color("ab985f"),false,-.45)
		for y in preload("res://scripts/core/ladder_geometry.gd").rung_levels(rect):
			box(Rect2(rect.position.x,y,rect.size.x,2),.08,Color("ab985f"),false,-.45)
	source.free()

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = .95
	return result

func box(rect: Rect2, depth: float, color: Color, solid := true, z := 0.0, kind := 3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(rect.size.x/U,rect.size.y/U,depth)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material(color)
	visual.position = point(rect.get_center(),z)
	add_child(visual)
	if solid:
		var body := StaticBody3D.new()
		body.set_meta("terra_material",kind)
		body.position = visual.position
		var shape := CollisionShape3D.new()
		var geometry := BoxShape3D.new()
		geometry.size = mesh.size
		shape.shape = geometry
		body.add_child(shape)
		add_child(body)
		surface_count += 1

func prism(polygon: PackedVector2Array) -> void:
	var vertices := PackedVector3Array()
	var triangles := Geometry2D.triangulate_polygon(polygon)
	for side in [-1.125,1.125]:
		for i in range(0,triangles.size(),3):
			var order := [0,1,2] if side < 0 else [2,1,0]
			for j in order: vertices.append(point(polygon[triangles[i+j]],side))
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i+1)%polygon.size()]
		for p in [point(a,-1.125),point(a,1.125),point(b,1.125),point(a,-1.125),point(b,1.125),point(b,-1.125)]:
			vertices.append(p)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var mat := material(Color("637c63"))
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = mat
	add_child(visual)
	var body := StaticBody3D.new()
	body.set_meta("terra_material",3)
	var shape := CollisionShape3D.new()
	# These source ramps are convex solids. A hull avoids one-sided triangle
	# contacts at the bottom seam; visual winding must not define physics.
	var hull := ConvexPolygonShape3D.new()
	var hull_points := PackedVector3Array()
	for p in polygon:
		hull_points.append(point(p,-1.125))
		hull_points.append(point(p,1.125))
	hull.points = hull_points
	shape.shape = hull
	body.add_child(shape)
	add_child(body)
	surface_count += 1
