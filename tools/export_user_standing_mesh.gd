extends SceneTree
## Offline promotion: the game loads a prebuilt scene, never the authoring JSON.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var folder := preload("res://tools/media_paths.gd").path("docs/mannequin_candidates/Основа_стойки_2026-11-06/Игровая_сборка_2026-11-07")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("runtime_mesh.json")))
	var model := Node2D.new()
	model.name = "UserStanding"
	root.add_child(model)
	var skeleton := Skeleton2D.new()
	skeleton.name = "Rig"
	model.add_child(skeleton)
	skeleton.owner = model
	var bones: Dictionary = {}
	for key in data.points:
		var bone := Bone2D.new()
		bone.name = key
		bone.set_autocalculate_length_and_angle(false)
		var parent_name = data.parents[key]
		var point := Vector2(data.points[key][0],data.points[key][1])
		var parent_point := Vector2.ZERO
		if parent_name != null:
			parent_point = Vector2(data.points[parent_name][0],data.points[parent_name][1])
			bones[parent_name].add_child(bone)
		else: skeleton.add_child(bone)
		bone.position = point-parent_point
		bone.rest = bone.transform
		bone.length = 1.0
		bone.owner = model
		bones[key] = bone
	for part in data.parts:
		var poly := Polygon2D.new()
		poly.name = part.name
		model.add_child(poly)
		poly.owner = model
		var vertices := PackedVector2Array()
		var uvs := PackedVector2Array()
		for v in part.vertices: vertices.append(Vector2(v[0],v[1]))
		for v in part.uv: uvs.append(Vector2(v[0],v[1]))
		poly.polygon = vertices
		poly.uv = uvs
		var faces: Array[PackedInt32Array] = []
		for face in part.triangles: faces.append(PackedInt32Array(face))
		poly.polygons = faces
		poly.texture = load("res://resources/core/user_standing/"+part.texture)
		assert(poly.texture != null)
		poly.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		poly.skeleton = NodePath("../Rig")
		for key in bones:
			var weights := PackedFloat32Array()
			var used := false
			for entry in part.weights:
				var value := float(entry.get(key,0.0))
				weights.append(value)
				used = used or value>0
			if used: poly.add_bone(skeleton.get_path_to(bones[key]),weights)
	var scene := PackedScene.new()
	assert(scene.pack(model)==OK)
	assert(ResourceSaver.save(scene,"res://resources/core/user_standing/Standing.scn",ResourceSaver.FLAG_COMPRESS)==OK)
	print("USER_STANDING_SCENE_EXPORTED bones=",bones.size())
	quit()
