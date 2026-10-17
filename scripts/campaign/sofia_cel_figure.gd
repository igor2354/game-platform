extends "res://scripts/campaign/deform_figure.gd"
## Reuses skeleton/layer/debug utilities; Harry's artwork and renderer stay unchanged.
## Every cel has its own bind pose, so its painted silhouette is exact at rest.
const CEL_POSES = preload("res://scripts/campaign/sofia_cel_poses.gd")
const LEG_ATLAS = preload("res://resources/campaign/sofia_leg_cels.png")
const BODY_ATLAS = preload("res://resources/campaign/sofia_body_cels_v2.png")
const ARM_ATLAS = preload("res://resources/campaign/sofia_arm_cels.png")
static var body_regions: Dictionary = {}
var source_pose: Dictionary = {}
var bind_sizes: Dictionary = {}
var frame_key := 0
var configured := false
var frame_meta: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	skeleton = Skeleton2D.new()
	skeleton.name = "CelSkeleton"
	add_child(skeleton)
	for key in ORDER:
		var bone := Bone2D.new()
		bone.name = key
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(10)
		bone.set_bone_angle(PI/2)
		var parent: Node2D = bones[PARENTS[key]] if PARENTS.has(key) else skeleton
		parent.add_child(bone)
		bones[key] = bone
	for key in ["left_leg","right_leg","coat","head","left_arm","right_arm"]:
		var mesh := Polygon2D.new()
		mesh.name = key
		mesh.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		mesh.antialiased = true
		mesh.color = Color(.69,.72,.71) if key.begins_with("left") else Color.WHITE
		add_child(mesh)
		mesh.skeleton = mesh.get_path_to(skeleton)
		meshes[key] = mesh
	move_child(meshes.left_arm,0)
	mesh_overlay = MeshOverlay.new()
	mesh_overlay.name = "CelMeshOverlay"
	mesh_overlay.figure = self
	add_child(mesh_overlay)
	_configure(source_pose if physical and source_pose.has("cel_indices") else CEL_POSES.selection(player))
	if not physical: call_deferred("_attach_arms")

func _body_region(index: int) -> Rect2:
	if body_regions.has(index): return body_regions[index]
	var cell_size := Vector2i(BODY_ATLAS.get_size())/Vector2i(4,2)
	var cell := Rect2i(Vector2i(index%4,index/4)*cell_size,cell_size)
	var image := BODY_ATLAS.get_image()
	var minimum := cell.end
	var maximum := cell.position
	for y in range(cell.position.y,cell.end.y,2):
		for x in range(cell.position.x,cell.end.x,2):
			if image.get_pixel(x,y).a < .6: continue
			minimum = minimum.min(Vector2i(x,y))
			maximum = maximum.max(Vector2i(x+1,y+1))
	var region := Rect2(Rect2i(minimum,maximum-minimum).grow(2).intersection(cell))
	body_regions[index] = region
	return region

func _configure(meta: Dictionary) -> void:
	var next := hash([meta.cel_indices,meta.get("arm_cels",[0,0]),meta.body_cel,meta.head_cel,meta.cel_y_scale,meta.cel_bob,meta.cel_stride])
	if configured and next == frame_key: return
	configured = true
	frame_key = next
	frame_meta = meta.duplicate(true)
	var rest := CEL_POSES.baseline(meta)
	for key in ORDER:
		var part: Dictionary = rest.parts[key]
		bind_poses[key] = Transform2D(part.rotation,part.position)
		bind_sizes[key] = part.dimensions
		var bone: Bone2D = bones[key]
		bone.rest = (bind_poses[PARENTS[key]] as Transform2D).affine_inverse()*bind_poses[key] if PARENTS.has(key) else bind_poses[key]
		bone.transform = bone.rest
	for side in ["left","right"]:
		var index: int = meta.cel_indices[0 if side == "left" else 1]
		var cel: Dictionary = CEL_POSES.LEGS[index]
		var outline := PackedVector2Array()
		var scale := Vector2(CEL_POSES.LEG_SCALE*float(meta.cel_stride),CEL_POSES.LEG_SCALE*float(meta.cel_y_scale))
		var origin: Vector2 = rest.joints[side+"_hip"]
		for pixel in cel.outline: outline.append(origin+(pixel-cel.hip)*scale)
		var vertices := _filled_outline(outline,1.6)
		var uv := PackedVector2Array()
		for point in vertices: uv.append(cel.hip+(point-origin)/scale)
		_assign(side+"_leg",vertices,uv,outline,LEG_ATLAS,[side+"_thigh",side+"_shin",side+"_foot"],rest.segments)
	var stretch := Vector2(1,float(meta.cel_y_scale))
	var bob := Vector2(0,float(meta.cel_bob)*stretch.y)
	_rect_mesh("coat",Rect2(Vector2(-12,-54)*stretch+bob,Vector2(24,27)*stretch),BODY_ATLAS,_body_region(meta.body_cel),["torso","pelvis"],rest.segments)
	_rect_mesh("head",Rect2(Vector2(-8,-72)*stretch+bob,Vector2(18,25)*stretch),BODY_ATLAS,_body_region(4+int(meta.head_cel)),["head"],rest.segments)
	for side in ["left","right"]:
		var shoulder: Vector2 = rest.joints[side+"_shoulder"]
		var art: Dictionary = CEL_POSES.ARMS[meta.get("arm_cels",[0,0])[0 if side == "left" else 1]]
		var upper: Vector2 = art.elbow-art.shoulder
		var angle := upper.angle_to(Vector2.DOWN)
		var scale := 14.0/upper.length()
		var box: Rect2 = art.box
		var outline := PackedVector2Array()
		for point in [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]:
			outline.append(shoulder+(point-art.shoulder).rotated(angle)*scale*stretch)
		var vertices := _filled_outline(outline,1.5)
		var uv := PackedVector2Array()
		for point in vertices: uv.append(art.shoulder+((point-shoulder)/stretch/scale).rotated(-angle))
		_assign(side+"_arm",vertices,uv,outline,ARM_ATLAS,[side+"_upper_arm",side+"_forearm"],rest.segments)

func _filled_outline(outline: PackedVector2Array,step: float) -> PackedVector2Array:
	var result := outline.duplicate()
	var bounds := Rect2(outline[0],Vector2.ZERO)
	for point in outline: bounds = bounds.expand(point)
	var y := bounds.position.y+step*.5
	while y < bounds.end.y:
		var x := bounds.position.x+step*.5
		while x < bounds.end.x:
			var point := Vector2(x,y)
			if Geometry2D.is_point_in_polygon(point,outline): result.append(point)
			x += step
		y += step
	return result

func _rect_mesh(key: String,rect: Rect2,texture: Texture2D,region: Rect2,influences: Array,segments: Dictionary) -> void:
	var outline := PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	var vertices := _filled_outline(outline,2)
	var uv := PackedVector2Array()
	for point in vertices: uv.append(region.position+(point-rect.position)/rect.size*region.size)
	_assign(key,vertices,uv,outline,texture,influences,segments)

func _assign(key: String,vertices: PackedVector2Array,uv: PackedVector2Array,outline: PackedVector2Array,texture: Texture2D,influences: Array,segments: Dictionary) -> void:
	var mesh: Polygon2D = meshes[key]
	mesh.clear_bones()
	mesh.texture = texture
	mesh.polygon = vertices
	mesh.uv = uv
	var indices := Geometry2D.triangulate_delaunay(vertices)
	var triangles: Array[PackedInt32Array] = []
	for i in range(0,indices.size(),3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i+1]]
		var c := vertices[indices[i+2]]
		var center := (a+b+c)/3
		if not Geometry2D.is_point_in_polygon(center,outline): continue
		if not Geometry2D.is_point_in_polygon(((a+b)*.5).lerp(center,.001),outline): continue
		if not Geometry2D.is_point_in_polygon(((a+c)*.5).lerp(center,.001),outline): continue
		if not Geometry2D.is_point_in_polygon(((b+c)*.5).lerp(center,.001),outline): continue
		triangles.append(PackedInt32Array([indices[i],indices[i+1],indices[i+2]]))
	mesh.polygons = triangles
	var weights: Array[PackedFloat32Array] = []
	for key_name in influences: weights.append(PackedFloat32Array())
	for point in vertices:
		var values: Array[float] = []
		var total := 0.0
		for key_name in influences:
			var distance: float
			if segments.has(key_name):
				var span: Array = segments[key_name]
				distance = point.distance_to(Geometry2D.get_closest_point_to_segment(point,span[0],span[1]))
			else: distance = point.distance_to((bind_poses[key_name] as Transform2D).origin)
			var strength := 1.0/pow(maxf(.7,distance),4)
			values.append(strength)
			total += strength
		for i in influences.size(): weights[i].append(values[i]/total)
	for i in influences.size(): mesh.add_bone(skeleton.get_path_to(bones[influences[i]]),weights[i])
	geometry[key] = {"influences":influences,"weights":weights}

func update_pose(pose: Dictionary) -> void:
	var was_active := active
	active = player.uses_painted_cels()
	if active != was_active:
		for mesh in borrowed: mesh.get_parent().queue_redraw()
	for mesh in meshes.values(): mesh.visible = active
	mesh_overlay.queue_redraw()
	if not active: return
	if not physical: _configure(pose)
	facing = pose.facing
	applied_pose = pose
	for key in ORDER:
		var part: Dictionary = pose.parts[key]
		var target := Transform2D(part.rotation,part.position)
		target.x *= facing
		target.y *= part.dimensions.y/(bind_sizes[key] as Vector2).y
		(bones[key] as Bone2D).global_transform = global_transform*target
