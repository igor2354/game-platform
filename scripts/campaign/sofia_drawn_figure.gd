extends "res://scripts/campaign/sofia_cel_figure.gd"
## The unmodified whole-body cel is the normal pose; skinning takes over on impact.
const DRAWN = preload("res://scripts/campaign/sofia_drawn_data.gd")
const HIDDEN_LEGS = preload("res://resources/campaign/sofia_hidden_legs_v3.png")
const LEG_ANCHORS = [[232,45,259,315,261,573,381,621],[721,84,880,298,711,540,812,612],[1194,205,1425,254,1277,473,1312,569],[1725,159,1943,280,1732,390,1740,461]]
static var cached_meshes: Dictionary = {}
var atlas_pose: Dictionary = {}
var rest_vertices: Dictionary = {}
var _skin_keys: Dictionary = {}

func _attach_arms() -> void:
	super._attach_arms()
	for mesh in meshes.values(): mesh.skeleton = NodePath()

func deformed_vertices(key: String) -> PackedVector2Array:
	var data: Dictionary = geometry[key]
	var vertices: PackedVector2Array = rest_vertices[key]
	var transforms: Array[Transform2D] = []
	var inverse := global_transform.affine_inverse()
	for name in data.influences:
		transforms.append(inverse*(bones[name] as Bone2D).global_transform*(bind_poses[name] as Transform2D).affine_inverse())
	var result := PackedVector2Array()
	result.resize(vertices.size())
	for index in vertices.size():
		var point := Vector2.ZERO
		for i in transforms.size():
			var weight: float = data.weights[i][index]
			if weight != 0: point += (transforms[i]*vertices[index])*weight
		result[index] = point
	return result

func _assign(key: String,vertices: PackedVector2Array,uv: PackedVector2Array,outline: PackedVector2Array,texture: Texture2D,influences: Array,segments: Dictionary) -> void:
	_skin_keys.erase(key)
	rest_vertices[key] = vertices
	meshes[key].skeleton = NodePath()
	var cache_key := hash([key,vertices,uv,texture.resource_path,influences])
	if cached_meshes.has(cache_key):
		var data: Dictionary = cached_meshes[cache_key]
		var mesh: Polygon2D = meshes[key]
		mesh.clear_bones()
		mesh.texture = texture
		mesh.polygon = vertices
		mesh.uv = uv
		mesh.polygons = data.triangles
		geometry[key] = data.geometry
		for i in influences.size(): mesh.add_bone(skeleton.get_path_to(bones[influences[i]]),data.geometry.weights[i])
		return
	super._assign(key,vertices,uv,outline,texture,influences,segments)
	cached_meshes[cache_key] = {"triangles":meshes[key].polygons,"geometry":geometry[key]}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	skeleton = Skeleton2D.new()
	skeleton.name = "AnatomicalSkeleton"
	add_child(skeleton)
	for key in ORDER:
		var bone := Bone2D.new()
		bone.name = key
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(10)
		bone.set_bone_angle(PI/2)
		(bones[PARENTS[key]] if PARENTS.has(key) else skeleton).add_child(bone)
		bones[key] = bone
	for key in ["body","left_arm","right_arm"]:
		var mesh := Polygon2D.new()
		mesh.name = key
		mesh.antialiased = true
		mesh.color = Color(.83,.85,.84) if key == "left_arm" else Color.WHITE
		add_child(mesh)
		mesh.skeleton = mesh.get_path_to(skeleton)
		meshes[key] = mesh
	move_child(meshes.left_arm,0)
	mesh_overlay = MeshOverlay.new()
	mesh_overlay.figure = self
	add_child(mesh_overlay)
	_configure(source_pose if physical and source_pose.has("drawn_clip") else DRAWN.selection(player))
	if physical:
		for side in ["left","right"]: _make_hidden_leg(side)
	if not physical: call_deferred("_attach_arms")

func _make_hidden_leg(side: String) -> void:
	# The whole cel cannot contain the rear leg's occluded cloth. Supply that
	# surface below the cel, masked to its original coverage to avoid extra limbs.
	var thigh: Dictionary = atlas_pose.parts[side+"_thigh"]
	var shin: Dictionary = atlas_pose.parts[side+"_shin"]
	var bend := absf(angle_difference(thigh.rotation,shin.rotation))
	var index := 0 if bend < .35 else 1 if bend < 1.1 else 2 if bend < 1.9 else 3
	var raw: Array = LEG_ANCHORS[index]
	var ratio := HIDDEN_LEGS.get_size()/Vector2(2048,683)
	var anchors: Array[Vector2] = []
	for i in 4: anchors.append(Vector2(raw[i*2],raw[i*2+1])*ratio)
	var influences := [side+"_thigh",side+"_shin",side+"_foot"]
	var transforms: Array[Transform2D] = []
	for i in 3:
		var a := anchors[i]
		var b := anchors[i+1]
		var art_pose := Transform2D(Vector2.DOWN.angle_to(b-a),(a+b)*.5)
		var target: Transform2D = bind_poses[influences[i]]
		target.y *= (bind_sizes[influences[i]] as Vector2).y/a.distance_to(b)
		target.x *= .052
		transforms.append(target*art_pose.affine_inverse())
	var mesh := Polygon2D.new()
	var key := side+"_hidden_leg"
	mesh.name = key
	mesh.texture = HIDDEN_LEGS
	mesh.antialiased = true
	add_child(mesh)
	move_child(mesh,0)
	meshes[key] = mesh
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var weights: Array[PackedFloat32Array] = [PackedFloat32Array(),PackedFloat32Array(),PackedFloat32Array()]
	var src := DRAWN.source(frame_meta)
	var image := DRAWN.texture(frame_meta).get_image()
	var cell := HIDDEN_LEGS.get_size()/Vector2(4,1)
	for y in 29:
		for x in 17:
			var pixel := Vector2(index*cell.x+cell.x*x/16,cell.y*y/28)
			var values: Array[float] = []
			var total := 0.0
			for i in 3:
				var distance := pixel.distance_to(Geometry2D.get_closest_point_to_segment(pixel,anchors[i],anchors[i+1]))
				var value := 1.0/pow(maxf(8,distance),4)
				values.append(value)
				total += value
			var point := Vector2.ZERO
			for i in 3:
				var weight := values[i]/total
				weights[i].append(weight)
				point += (transforms[i]*pixel)*weight
			vertices.append(point)
			uv.append(pixel)
			var sample: Vector2 = src.root+point/float(src.scale)
			var visible_pixel := Rect2(Vector2.ZERO,image.get_size()).has_point(sample) and image.get_pixelv(Vector2i(sample)).a > .4
			colors.append(Color(1,1,1,1 if visible_pixel else 0))
	var triangles: Array[PackedInt32Array] = []
	for y in 28:
		for x in 16:
			var start := y*17+x
			triangles.append(PackedInt32Array([start,start+1,start+17]))
			triangles.append(PackedInt32Array([start+1,start+18,start+17]))
	mesh.polygon = vertices
	mesh.uv = uv
	mesh.vertex_colors = colors
	mesh.polygons = triangles
	rest_vertices[key] = vertices
	geometry[key] = {"influences":influences,"weights":weights}

func _configure(meta: Dictionary) -> void:
	var next := hash([meta.drawn_clip,meta.drawn_frame])
	if configured and next == frame_key: return
	configured = true
	frame_key = next
	frame_meta = meta.duplicate(true)
	atlas_pose = DRAWN.baseline(meta)
	for key in ORDER:
		var part: Dictionary = atlas_pose.parts[key]
		bind_poses[key] = Transform2D(part.rotation,part.position)
		bind_sizes[key] = part.dimensions
		var bone: Bone2D = bones[key]
		bone.rest = (bind_poses[PARENTS[key]] as Transform2D).affine_inverse()*bind_poses[key] if PARENTS.has(key) else bind_poses[key]
		bone.transform = bone.rest
	var src := DRAWN.source(meta)
	var box: Rect2 = src.box
	var rect := Rect2((box.position-src.root)*float(src.scale),box.size*float(src.scale))
	var body_bones: Array = ORDER.filter(func(key): return not "arm" in key)
	_rect_mesh("body",rect,DRAWN.texture(meta),box,body_bones,atlas_pose.segments)

func _arm_mesh(side: String,pose: Dictionary) -> void:
	var upper: Dictionary = pose.parts[side+"_upper_arm"]
	var lower: Dictionary = pose.parts[side+"_forearm"]
	var bend := absf(angle_difference(upper.rotation,lower.rotation))
	var best := 0
	var difference := INF
	for index in DRAWN.ARM_POINTS.size():
		var points: Array = DRAWN.ARM_POINTS[index]
		var u := Vector2(points[2]-points[0],points[3]-points[1])
		var v := Vector2(points[4]-points[2],points[5]-points[3])
		var error := absf(absf(u.angle_to(v))-bend)
		if error < difference: difference = error; best = index
	var key := side+"_arm"
	var cache_key := str(best)+side+str(frame_key)
	if meshes[key].get_meta("cel","") == cache_key: return
	meshes[key].set_meta("cel",cache_key)
	meshes[key].set_meta("cel_index",best)
	var points: Array = DRAWN.ARM_POINTS[best]
	var ratio := DRAWN.ARMS.get_size()/Vector2(1773,882)
	var shoulder_pixel := Vector2(points[0],points[1])*ratio
	var elbow_pixel := Vector2(points[2],points[3])*ratio
	var hand_pixel := Vector2(points[4],points[5])*ratio
	var upper_pixel := elbow_pixel-shoulder_pixel
	var art_scale := DRAWN.UPPER_ARM/upper_pixel.length()
	var angle := upper_pixel.angle_to(Vector2.DOWN)
	var shoulder: Vector2 = atlas_pose.joints[side+"_shoulder"]
	var elbow := shoulder+Vector2(0,DRAWN.UPPER_ARM)
	var hand := elbow+(hand_pixel-elbow_pixel).rotated(angle)*art_scale
	var segments := {}
	for entry in [["_upper_arm",shoulder,elbow],["_forearm",elbow,hand]]:
		var a: Vector2 = entry[1]
		var b: Vector2 = entry[2]
		var name: String = side+entry[0]
		bind_poses[name] = Transform2D(Vector2.DOWN.angle_to(b-a),(a+b)*.5)
		bind_sizes[name] = Vector2(4,a.distance_to(b))
		segments[name] = [a,b]
	var art_box: Rect2 = DRAWN.ARM_BOXES[best]
	var box_ratio := DRAWN.ARMS.get_size()/Vector2(1774,887)
	var box := Rect2(art_box.position*box_ratio,art_box.size*box_ratio)
	var outline := PackedVector2Array()
	for pixel in [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]:
		outline.append(shoulder+(pixel-shoulder_pixel).rotated(angle)*art_scale)
	var vertices := _filled_outline(outline,1.3)
	var uv := PackedVector2Array()
	for point in vertices: uv.append(shoulder_pixel+((point-shoulder)/art_scale).rotated(-angle))
	_assign(key,vertices,uv,outline,DRAWN.ARMS,[side+"_upper_arm",side+"_forearm"],segments)
	for name in [side+"_upper_arm",side+"_forearm"]:
		(bones[name] as Bone2D).rest = (bind_poses[PARENTS[name]] as Transform2D).affine_inverse()*bind_poses[name]

func update_pose(pose: Dictionary) -> void:
	var was_active := active
	active = player.uses_painted_cels()
	if was_active != active:
		for mesh in borrowed: mesh.get_parent().queue_redraw()
	for mesh in meshes.values(): mesh.visible = active
	mesh_overlay.queue_redraw()
	if not active: return
	if not physical: _configure(pose)
	for side in ["left","right"]: _arm_mesh(side,pose)
	facing = pose.facing
	applied_pose = pose
	for key in ORDER:
		var part: Dictionary = pose.parts[key]
		var target := Transform2D(part.rotation,part.position)
		target.x *= facing
		# Limbs keep their anatomical length; only small art proportion correction.
		target.y *= part.dimensions.y/(bind_sizes[key] as Vector2).y
		(bones[key] as Bone2D).global_transform = global_transform*target
	# Explicit skinning keeps the rendered mesh and the verified anatomy identical
	# when a cel changes its bind pose; no stale renderer-side rest transform.
	for key in meshes:
		var mesh: Polygon2D = meshes[key]
		var conversion := mesh.global_transform.affine_inverse()*global_transform
		var inputs: Array = [conversion,facing]
		for name in geometry[key].influences: inputs.append([pose.parts[name],bind_poses[name]])
		var skin_key := hash(inputs)
		if _skin_keys.get(key) == skin_key: continue
		_skin_keys[key] = skin_key
		var vertices := deformed_vertices(key)
		for i in vertices.size(): vertices[i] = conversion*vertices[i]
		mesh.polygon = vertices
