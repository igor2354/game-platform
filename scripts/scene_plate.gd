class_name StationScenePlate
extends MeshInstance2D

const WORLD_SIZE := Vector2(1280,1504)
var design_rows := PackedFloat32Array([0,520,820,1120,1504])
var painted_rows := PackedFloat32Array([0,520,820,1120,1504])
var horizontal_anchors: Array[Vector2] = [Vector2(0,0),Vector2(1280,1280)]
var row_anchors: Array = []
var blend_left := false
var plate_material: ShaderMaterial

func build(asset_path: String, origin: float) -> void:
	texture = load(asset_path)
	position.x = origin
	var positions: Array[float] = []
	for x in range(0,1281,64): positions.append(x)
	for anchors in row_anchors:
		for anchor in anchors:
			if not positions.has(anchor.x): positions.append(anchor.x)
	positions.sort()
	var columns := PackedFloat32Array(positions)
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in design_rows.size():
		for x in columns:
			vertices.append(Vector3(x,design_rows[row],0))
			uv.append(Vector2(source_x(x,row)/WORLD_SIZE.x,painted_rows[row]/WORLD_SIZE.y))
	for row in range(design_rows.size()-1):
		for col in range(columns.size()-1):
			var a := row*columns.size()+col
			var b := a+1
			var c := a+columns.size()
			var d := c+1
			indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var geometry := ArrayMesh.new()
	geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh = geometry
	plate_material = ShaderMaterial.new()
	plate_material.shader = load("res://shaders/scene_plate.gdshader")
	plate_material.set_shader_parameter("blend_left",blend_left)
	material = plate_material
	show_behind_parent = true

func source_x(x: float, row: int) -> float:
	var anchors: Array = row_anchors[row] if not row_anchors.is_empty() else horizontal_anchors
	for i in range(anchors.size()-1):
		if x <= anchors[i+1].x:
			return lerpf(anchors[i].y,anchors[i+1].y,inverse_lerp(anchors[i].x,anchors[i+1].x,x))
	return anchors.back().y
