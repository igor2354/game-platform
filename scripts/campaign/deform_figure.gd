extends Node2D
## One weighted 2D skeleton, used by animation and by the actual ragdoll.
const ATLAS = preload("res://resources/campaign/harry_deform_v2.png")
const ART = preload("res://scripts/campaign/art.gd")
static var painted_regions: Dictionary = {}
const ORDER = ["pelvis","torso","head","left_upper_arm","left_forearm","right_upper_arm","right_forearm","left_thigh","left_shin","left_foot","right_thigh","right_shin","right_foot"]
const PARENTS = {"torso":"pelvis","head":"torso","left_upper_arm":"torso","left_forearm":"left_upper_arm","right_upper_arm":"torso","right_forearm":"right_upper_arm","left_thigh":"pelvis","left_shin":"left_thigh","left_foot":"left_shin","right_thigh":"pelvis","right_shin":"right_thigh","right_foot":"right_shin"}
class MeshOverlay extends Node2D:
	var figure: Node2D
	func _draw() -> void:
		if is_instance_valid(figure): figure.draw_deform_overlay(self)
var player: CoreMovementPlayer
var skeleton: Skeleton2D
var bones: Dictionary = {}
var bind_poses: Dictionary = {}
var bind_lengths: Dictionary = {}
var meshes: Dictionary = {}
var geometry: Dictionary = {}
var active := false
var head_stage := 0
var facing := 1.0
var physical := false
var applied_pose: Dictionary = {}
var borrowed: Array[Polygon2D] = []
var mesh_overlay: Node2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	skeleton = Skeleton2D.new()
	skeleton.name = "PaintedSkeleton"
	add_child(skeleton)
	var origins := {"pelvis":Vector2(0,-32),"torso":Vector2(0,-52),"head":Vector2(0,-58),"left_upper_arm":Vector2(-3,-48),"left_forearm":Vector2(-3,-33),"right_upper_arm":Vector2(5,-48),"right_forearm":Vector2(5,-33),"left_thigh":Vector2(-2,-32),"left_shin":Vector2(-2,-16),"left_foot":Vector2(-.5,-2),"right_thigh":Vector2(2,-32),"right_shin":Vector2(2,-16),"right_foot":Vector2(3.5,-2)}
	for key in ORDER:
		var bone := Bone2D.new()
		bone.name = key
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(10)
		bone.set_bone_angle(PI/2)
		var bind := Transform2D(0,origins[key])
		bind_poses[key] = bind
		bind_lengths[key] = 20.0 if key == "torso" else 16.0 if key.ends_with("thigh") else 12.0 if key.ends_with("shin") else 15.0 if "arm" in key else 14.0 if key == "head" else 4.0 if key.ends_with("foot") else 5.0
		var parent: Node2D = bones[PARENTS[key]] if PARENTS.has(key) else skeleton
		parent.add_child(bone)
		bone.rest = (bind_poses[PARENTS[key]] as Transform2D).affine_inverse()*bind if PARENTS.has(key) else bind
		bone.transform = bone.rest
		bones[key] = bone
	for side in ["left","right"]:
		var x := -2.0 if side == "left" else 2.0
		_grid(side+"_leg",Rect2(x-4.6,-33,9.2,30),_region(2),[side+"_thigh",side+"_shin"],.57,14,4)
		_grid(side+"_foot",Rect2(x-3.5,-9,10,9.6),ART.part("harry","foot"),[side+"_foot"],0,3,3)
	# Coat remains continuous across the waist and overlaps the trouser roots.
	_grid("coat",Rect2(-12,-53,25,40),_region(0),["torso","pelvis"],.52,15,6)
	_grid("head",Rect2(-9,-68.5,19,22),_region(3+head_stage),["head"],0,4,4)
	for side in ["left","right"]:
		var x := -3.0 if side == "left" else 5.0
		_grid(side+"_arm",Rect2(x-4.2,-49,8.4,32),_region(1),[side+"_upper_arm",side+"_forearm"],.50,16,4)
	# The far sleeve is behind the coat; the near sleeve is above the gun.
	move_child(meshes.left_arm,0)
	mesh_overlay = MeshOverlay.new()
	mesh_overlay.name = "DeformMeshOverlay"
	mesh_overlay.figure = self
	add_child(mesh_overlay)
	if not physical: call_deferred("_attach_arms")

func _attach_arms() -> void:
	for side in ["left","right"]:
		var mesh: Polygon2D = meshes[side+"_arm"]
		var arm: CoreHybridArm = player.body.far_arm if side == "left" else player.body.near_arm
		mesh.reparent(arm,false)
		mesh.skeleton = mesh.get_path_to(skeleton)
		borrowed.append(mesh)
		arm.deform_owner = self
	# Draw the debug triangles after the coat, sleeves and gun, not beneath them.
	mesh_overlay.reparent(player.visuals,false)

func _region(index: int) -> Texture2D:
	if painted_regions.has(index): return painted_regions[index]
	# The generated layout has a tall upper row and three neck-aligned heads.
	var boxes := [Rect2(.10,0,.30,.665),Rect2(.44,.02,.19,.645),Rect2(.68,0,.23,.665),Rect2(.10,.665,.25,.335),Rect2(.40,.665,.23,.335),Rect2(.67,.665,.24,.335)]
	var box: Rect2 = boxes[index]
	var bounds := Rect2i(box.position*ATLAS.get_size(),box.size*ATLAS.get_size())
	# Ignore faint generated edge haze when finding the actual painted silhouette.
	# Only UV bounds change; the source PNG and its alpha remain untouched.
	var image := ATLAS.get_image()
	var minimum := bounds.end
	var maximum := bounds.position
	for y in range(bounds.position.y,bounds.end.y,2):
		for x in range(bounds.position.x,bounds.end.x,2):
			if image.get_pixel(x,y).a < .6: continue
			minimum = minimum.min(Vector2i(x,y))
			maximum = maximum.max(Vector2i(x+1,y+1))
	var region := Rect2i(minimum,maximum-minimum).grow(3).intersection(bounds)
	var texture := AtlasTexture.new()
	texture.atlas = ATLAS
	texture.region = region
	texture.filter_clip = true
	painted_regions[index] = texture
	return texture

func _grid(key: String,rect: Rect2,texture: Texture2D,influences: Array,joint: float,rows: int,columns: int) -> void:
	var mesh := Polygon2D.new()
	mesh.name = key
	var texture_rect := Rect2(Vector2.ZERO,texture.get_size())
	if texture is AtlasTexture:
		texture_rect = texture.region
		mesh.texture = texture.atlas
	else: mesh.texture = texture
	mesh.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	mesh.antialiased = true
	add_child(mesh)
	mesh.skeleton = mesh.get_path_to(skeleton)
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var weights: Array[PackedFloat32Array] = []
	for bone in influences: weights.append(PackedFloat32Array())
	for row in rows+1:
		var v := float(row)/rows
		var lower := smoothstep(joint-.10,joint+.10,v) if influences.size() == 2 else 0.0
		for column in columns+1:
			var u := float(column)/columns
			vertices.append(rect.position+rect.size*Vector2(u,v))
			uv.append(texture_rect.position+texture_rect.size*Vector2(u,v))
			weights[0].append(1-lower)
			if weights.size() > 1: weights[1].append(lower)
	var triangles: Array[PackedInt32Array] = []
	for row in rows:
		for column in columns:
			var a := row*(columns+1)+column
			var b := a+columns+1
			triangles.append(PackedInt32Array([a,b,a+1]))
			triangles.append(PackedInt32Array([a+1,b,b+1]))
	mesh.polygon = vertices
	mesh.uv = uv
	mesh.polygons = triangles
	for index in influences.size(): mesh.add_bone(skeleton.get_path_to(bones[influences[index]]),weights[index])
	mesh.color = Color(.68,.72,.68) if key.begins_with("left") else Color.WHITE
	meshes[key] = mesh
	geometry[key] = {"base":vertices,"rect":rect,"influences":influences,"weights":weights,"rows":rows,"columns":columns,"joint":joint}

func update_pose(pose: Dictionary) -> void:
	var was_active := active
	active = player.uses_deformed_skin()
	if active != was_active:
		for mesh in borrowed: mesh.get_parent().queue_redraw()
	for mesh in meshes.values(): mesh.visible = active
	mesh_overlay.queue_redraw()
	if not active: return
	facing = pose.facing
	applied_pose = pose
	for key in ORDER:
		var part: Dictionary = pose.parts[key]
		var target := Transform2D(part.rotation,part.position)
		if key not in ["pelvis","head"] and not key.ends_with("foot"):
			target.origin -= target.y*part.dimensions.y*.5
		target.x *= facing
		target.y *= part.dimensions.y/float(bind_lengths[key])
		(bones[key] as Bone2D).global_transform = global_transform*target
	if not physical:
		var next := 1 if player.weapon.ads_blend > .55 else 2 if player.weapon.aim_direction.y < -.55 else 0
		if next != head_stage:
			head_stage = next
			var mesh: Polygon2D = meshes.head
			var frame_texture := _region(3+head_stage) as AtlasTexture
			var uv := mesh.uv
			var rect: Rect2 = geometry.head.rect
			for i in uv.size(): uv[i] = frame_texture.region.position+(geometry.head.base[i]-rect.position)/rect.size*frame_texture.region.size
			mesh.uv = uv
	for key in ["left_arm","right_arm","left_leg","right_leg"]:
		_correct_joint(key)

func _correct_joint(key: String) -> void:
	var data: Dictionary = geometry[key]
	var a: Bone2D = bones[data.influences[0]]
	var b: Bone2D = bones[data.influences[1]]
	var bend := absf(a.global_transform.y.angle_to(b.global_transform.y))
	var amount := sin(bend*.5)*sin(bend*.5)*player.visuals.settings.deform_joint_volume
	var vertices: PackedVector2Array = data.base.duplicate()
	var rect: Rect2 = data.rect
	for index in vertices.size():
		var y: float = float(floori(float(index)/(int(data.columns)+1)))/data.rows
		var envelope := maxf(0,1-absf(y-data.joint)/.16)
		var x := vertices[index].x-rect.get_center().x
		vertices[index].x += x*amount*envelope
	meshes[key].polygon = vertices

func deformed_vertices(key: String) -> PackedVector2Array:
	var mesh: Polygon2D = meshes[key]
	var data: Dictionary = geometry[key]
	var result := PackedVector2Array()
	for index in mesh.polygon.size():
		var point := Vector2.ZERO
		for bone_index in data.influences.size():
			var name: String = data.influences[bone_index]
			var current := global_transform.affine_inverse()*(bones[name] as Bone2D).global_transform
			point += current*(bind_poses[name] as Transform2D).affine_inverse()*mesh.polygon[index]*data.weights[bone_index][index]
		result.append(point)
	return result

func draw_deform_overlay(canvas: Node2D) -> void:
	if not active or not player.visuals.settings.deform_mesh_debug: return
	canvas.draw_set_transform_matrix(canvas.global_transform.affine_inverse()*global_transform)
	for key in meshes:
		var vertices := deformed_vertices(key)
		for triangle in meshes[key].polygons:
			canvas.draw_polyline(PackedVector2Array([vertices[triangle[0]],vertices[triangle[1]],vertices[triangle[2]],vertices[triangle[0]]]),Color(0.2,1,.8,.45),.22,true)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func _exit_tree() -> void:
	for mesh in borrowed:
		if is_instance_valid(mesh): mesh.queue_free()
	if is_instance_valid(mesh_overlay) and mesh_overlay.get_parent() != self: mesh_overlay.queue_free()
