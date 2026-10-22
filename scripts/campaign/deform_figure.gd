extends Node2D
## One weighted 2D skeleton, used by animation and by the actual ragdoll.
const ATLAS = preload("res://resources/campaign/harry_deform_v2.png")
const ART = preload("res://scripts/campaign/art.gd")
const ANATOMY = preload("res://scripts/campaign/harry_anatomy.gd")
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
var far_forearm_surface: Polygon2D
var _harry_rest_vertices: Dictionary = {}
var _harry_skin_keys: Dictionary = {}
var _forearm_split := false
var _forearm_skin_key := 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	skeleton = Skeleton2D.new()
	skeleton.name = "PaintedSkeleton"
	add_child(skeleton)
	var rest := ANATOMY.pose({})
	for key in ORDER:
		var bone := Bone2D.new()
		bone.name = key
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(10)
		bone.set_bone_angle(PI/2)
		var bind := Transform2D(rest.parts[key].rotation,rest.parts[key].position)
		bind_poses[key] = bind
		bind_lengths[key] = rest.parts[key].dimensions.y
		var parent: Node2D = bones[PARENTS[key]] if PARENTS.has(key) else skeleton
		parent.add_child(bone)
		bone.rest = (bind_poses[PARENTS[key]] as Transform2D).affine_inverse()*bind if PARENTS.has(key) else bind
		bone.transform = bone.rest
		bones[key] = bone
	for side in ["left","right"]:
		var hip: Vector2 = rest.joints[side+"_hip"]
		var leg_height := ANATOMY.THIGH+ANATOMY.SHIN+3
		var leg_size := proportional_size(_region(2),leg_height)
		_grid(side+"_leg",Rect2(hip-Vector2(leg_size.x*.5,2.5),leg_size),_region(2),[side+"_thigh",side+"_shin"],(2.5+ANATOMY.THIGH)/leg_height,18,5)
		var boot := _boot_region()
		var foot_size := proportional_size(boot,ANATOMY.BOOT_ART_HEIGHT)
		var ankle: Vector2 = rest.joints[side+"_ankle"]
		# The ankle is inside the boot, not at its top rim. The shaft belongs to
		# the shin; the toe/sole belong to the foot. Keep the same art scale.
		var boot_ankle := Vector2(1604,360)
		var boot_scale := ANATOMY.BOOT_ART_HEIGHT/boot.get_height()
		var boot_rect := Rect2(ankle-(boot_ankle-boot.region.position)*boot_scale,foot_size)
		var ankle_row := (boot_ankle.y-boot.region.position.y)/boot.get_height()
		_grid(side+"_foot",boot_rect,boot,[side+"_shin",side+"_foot"],ankle_row,16,8)
		geometry[side+"_foot"].volume_center = ankle.x
	# Coat remains continuous across the waist and overlaps the trouser roots.
	var coat_size := proportional_size(_region(0),ANATOMY.COAT_ART_HEIGHT)
	var coat_rect := Rect2(rest.joints.neck-Vector2(coat_size.x*.57,2),coat_size)
	_grid("coat",coat_rect,_region(0),["torso","pelvis"],(rest.joints.waist.y-coat_rect.position.y)/coat_size.y,20,8)
	_grid("head",_head_rect(head_stage),_region(3+head_stage),["head"],0,4,4)
	for side in ["left","right"]:
		var shoulder: Vector2 = rest.joints[side+"_shoulder"]
		var sleeve_height := ANATOMY.UPPER_ARM+ANATOMY.FOREARM+1.5
		var sleeve_size := proportional_size(_region(1),sleeve_height)
		var sleeve := _region(1) as AtlasTexture
		# Measured palm on the unmodified atlas; put the painted glove on the IK hand.
		var palm_pixel := Vector2(854,610)
		var palm := shoulder+Vector2(0,ANATOMY.UPPER_ARM+ANATOMY.FOREARM)
		var sleeve_rect := Rect2(palm-(palm_pixel-sleeve.region.position)*(sleeve_height/sleeve.get_height()),sleeve_size)
		var joint := (shoulder.y+ANATOMY.UPPER_ARM-sleeve_rect.position.y)/sleeve_height
		_grid(side+"_arm",sleeve_rect,sleeve,[side+"_upper_arm",side+"_forearm"],joint,18,5)
	# The far sleeve is behind the coat; the near sleeve is above the gun.
	move_child(meshes.left_arm,0)
	far_forearm_surface = Polygon2D.new()
	far_forearm_surface.name = "FarForearmSurface"
	far_forearm_surface.texture = meshes.left_arm.texture
	far_forearm_surface.uv = meshes.left_arm.uv
	far_forearm_surface.antialiased = true
	far_forearm_surface.color = meshes.left_arm.color
	far_forearm_surface.hide()
	add_child(far_forearm_surface)
	mesh_overlay = MeshOverlay.new()
	mesh_overlay.name = "DeformMeshOverlay"
	mesh_overlay.figure = self
	add_child(mesh_overlay)
	if not physical: call_deferred("_attach_arms")

func proportional_size(texture: Texture2D,height: float) -> Vector2:
	return texture.get_size()*(height/texture.get_height())

func _boot_region() -> AtlasTexture:
	if painted_regions.has(6): return painted_regions[6]
	var original := ART.part("harry","foot") as AtlasTexture
	var image := original.atlas.get_image()
	var bounds := Rect2i(original.region)
	var low := bounds.end
	var high := bounds.position
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			if image.get_pixel(x,y).a < .6: continue
			low = low.min(Vector2i(x,y))
			high = high.max(Vector2i(x+1,y+1))
	var result := AtlasTexture.new()
	result.atlas = original.atlas
	result.region = Rect2(Rect2i(low,high-low).grow(2).intersection(bounds))
	result.filter_clip = true
	painted_regions[6] = result
	return result

func _head_rect(stage: int) -> Rect2:
	var size := proportional_size(_region(3+stage),ANATOMY.HEAD_ART_HEIGHT)
	var neck: Vector2 = ANATOMY.pose({}).joints.neck
	return Rect2(neck-Vector2(size.x*.45,size.y*.84),size)

func _attach_arms() -> void:
	for side in ["left","right"]:
		var mesh: Polygon2D = meshes[side+"_arm"]
		var arm: CoreHybridArm = player.body.far_arm if side == "left" else player.body.near_arm
		mesh.reparent(arm,false)
		mesh.skeleton = NodePath() if player.character_id == "harry" else mesh.get_path_to(skeleton)
		borrowed.append(mesh)
		arm.deform_owner = self
	if player.character_id == "harry":
		far_forearm_surface.reparent(player.visuals,false)
		player.body.far_arm.occlusion_forearm = far_forearm_surface
		borrowed.append(far_forearm_surface)
		player.visuals.layers_arranged = false
		player.visuals.arrange_layers()
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
	if player.character_id == "harry": mesh.skeleton = NodePath()
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
	if player.character_id == "harry":
		_harry_rest_vertices[key] = vertices
		geometry[key].triangles = triangles

func update_pose(pose: Dictionary) -> void:
	var was_active := active
	active = player.uses_deformed_skin()
	if active != was_active:
		for mesh in borrowed: mesh.get_parent().queue_redraw()
	for mesh in meshes.values(): mesh.visible = active
	if is_instance_valid(far_forearm_surface): far_forearm_surface.hide()
	mesh_overlay.queue_redraw()
	if not active: return
	facing = pose.facing
	applied_pose = pose
	for key in ORDER:
		var part: Dictionary = pose.parts[key]
		var target := Transform2D(part.rotation,part.position)
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
			var next_rect := _head_rect(head_stage)
			var vertices: PackedVector2Array = geometry.head.base
			for i in uv.size():
				var coordinate: Vector2 = (vertices[i]-rect.position)/rect.size
				uv[i] = frame_texture.region.position+coordinate*frame_texture.region.size
				vertices[i] = next_rect.position+coordinate*next_rect.size
			geometry.head.rect = next_rect
			geometry.head.base = vertices
			_harry_rest_vertices.head = vertices
			mesh.polygon = vertices
			mesh.uv = uv
	for key in ["left_arm","right_arm","left_leg","right_leg","left_foot","right_foot"]:
		_correct_joint(key)
	_skin_harry()
	_update_forearm_surface()

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
		var x: float = vertices[index].x-data.get("volume_center",rect.get_center().x)
		vertices[index].x += x*amount*envelope
	_harry_rest_vertices[key] = vertices

func _skin_harry() -> void:
	# Use the same computed vertices for native rendering, debug and geometry
	# checks. Reparented sleeves must not receive renderer-side skinning twice.
	for key in meshes:
		var mesh: Polygon2D = meshes[key]
		var conversion := mesh.global_transform.affine_inverse()*global_transform
		var inputs: Array = [conversion,head_stage,player.visuals.settings.deform_joint_volume]
		for name in geometry[key].influences: inputs.append(bones[name].global_transform)
		var skin_key := hash(inputs)
		if _harry_skin_keys.get(key) == skin_key: continue
		_harry_skin_keys[key] = skin_key
		var vertices := deformed_vertices(key)
		for i in vertices.size(): vertices[i] = conversion*vertices[i]
		mesh.polygon = vertices

func _update_forearm_surface() -> void:
	if not is_instance_valid(far_forearm_surface): return
	var split := not physical and player.body.uses_down_aim_pose()
	var data: Dictionary = geometry.left_arm
	far_forearm_surface.visible = split
	if split != _forearm_split:
		if split and not data.has("upper_triangles"):
			var upper: Array[PackedInt32Array] = []
			var lower: Array[PackedInt32Array] = []
			for triangle in data.triangles:
				var amount := 0.0
				for index in triangle: amount += data.weights[1][index]
				if amount >= 1.5: lower.append(triangle)
				else: upper.append(triangle)
			data.upper_triangles = upper
			data.lower_triangles = lower
		meshes.left_arm.polygons = data.upper_triangles if split else data.triangles
		if split: far_forearm_surface.polygons = data.lower_triangles
		_forearm_split = split
	if not split: return
	var conversion: Transform2D = far_forearm_surface.global_transform.affine_inverse()*meshes.left_arm.global_transform
	var skin_key := hash([_harry_skin_keys.left_arm,conversion])
	if skin_key == _forearm_skin_key: return
	_forearm_skin_key = skin_key
	var vertices: PackedVector2Array = meshes.left_arm.polygon
	for i in vertices.size(): vertices[i] = conversion*vertices[i]
	far_forearm_surface.polygon = vertices

func deformed_vertices(key: String) -> PackedVector2Array:
	var mesh: Polygon2D = meshes[key]
	var data: Dictionary = geometry[key]
	var source: PackedVector2Array = _harry_rest_vertices.get(key,mesh.polygon)
	var transforms: Array[Transform2D] = []
	var inverse := global_transform.affine_inverse()
	for name in data.influences:
		transforms.append(inverse*(bones[name] as Bone2D).global_transform*(bind_poses[name] as Transform2D).affine_inverse())
	var result := PackedVector2Array()
	for index in source.size():
		var point := Vector2.ZERO
		for bone_index in data.influences.size():
			point += transforms[bone_index]*source[index]*data.weights[bone_index][index]
		result.append(point)
	return result

func draw_deform_overlay(canvas: Node2D) -> void:
	if not active or not player.visuals.settings.deform_mesh_debug: return
	canvas.draw_set_transform_matrix(canvas.global_transform.affine_inverse()*global_transform)
	for key in meshes:
		var vertices := deformed_vertices(key)
		for triangle in geometry[key].get("triangles",meshes[key].polygons):
			canvas.draw_polyline(PackedVector2Array([vertices[triangle[0]],vertices[triangle[1]],vertices[triangle[2]],vertices[triangle[0]]]),Color(0.2,1,.8,.45),.22,true)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func _exit_tree() -> void:
	for mesh in borrowed:
		if is_instance_valid(mesh): mesh.queue_free()
	if is_instance_valid(mesh_overlay) and mesh_overlay.get_parent() != self: mesh_overlay.queue_free()
