extends Sprite2D
## Genesis9 retains its rest lengths. The 2D controller supplies screen-space targets.
const ASSET = preload("res://resources/core/player_mannequin_3d/PlayerMannequin.glb")
const UNITS_PER_METER := 63.42 / 1.61
const VIEW_HEIGHT := 2.5
const CAMERA_HEIGHT := .85
const SIDES := {"Near": "r_", "Far": "l_"}
var rig: Skeleton3D
var model: Node3D
var camera: Camera3D
var viewport: SubViewport
var indices: Dictionary[String, int] = {}
var last_points: Dictionary = {}
var fall_view := Transform3D.IDENTITY

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(320, 384)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	model = ASSET.instantiate()
	stage.add_child(model)
	var mannequin_material := StandardMaterial3D.new()
	mannequin_material.albedo_color = Color("#8d8986")
	mannequin_material.roughness = .88
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = mannequin_material
		# Imported mesh bounds describe the unskinned coordinates of this GLB.
		mesh.custom_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	rig = model.find_children("*", "Skeleton3D", true, false)[0]
	# The source scene stores its character away from the scene origin.
	# Centre the complete imported rig before projecting bone-local points.
	model.position -= rig.global_position
	for bone in rig.get_bone_count():
		indices[rig.get_bone_name(bone)] = bone
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = VIEW_HEIGHT
	stage.add_child(camera)
	camera.position = Vector3(-4, CAMERA_HEIGHT, 0)
	camera.look_at(Vector3(0, CAMERA_HEIGHT, 0))
	camera.current = true
	var light := DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees = Vector3(-28, -55, 0)
	light.light_energy = .9
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .65
	stage.add_child(environment)
	texture = viewport.get_texture()
	_frame(Vector2.ZERO, Vector2(0, CAMERA_HEIGHT), VIEW_HEIGHT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _joint(name: String) -> Vector3:
	return rig.get_bone_global_pose(indices[name]).origin

func _aim(bone: String, next: String, direction: Vector3) -> void:
	var index := indices[bone]
	var pose := rig.get_bone_global_pose(index)
	var current := _joint(next) - pose.origin
	if current.length_squared() < .000001 or direction.length_squared() < .000001:
		return
	var turn := Quaternion(current.normalized(), direction.normalized())
	pose.basis = Basis(turn) * pose.basis
	rig.set_bone_global_pose(index, pose)

func _target(point: Vector2, depth: float) -> Vector3:
	return Vector3(depth, -point.y / UNITS_PER_METER, point.x / UNITS_PER_METER)

func _limb(upper: String, lower: String, end: String, bend: Vector3, target: Vector3) -> void:
	var start := _joint(upper)
	var middle := _joint(lower)
	var finish := _joint(end)
	var first := middle.distance_to(start)
	var second := finish.distance_to(middle)
	var delta := target - start
	var axis := delta.normalized() if delta.length_squared() > .000001 else Vector3.DOWN
	var distance := clampf(delta.length(), absf(first - second) + .0001, first + second - .0001)
	var along := (first * first - second * second + distance * distance) / (2 * distance)
	var height := sqrt(maxf(0, first * first - along * along))
	var offset := bend - start
	var pole := offset - axis * offset.dot(axis)
	if pole.length_squared() < .000001:
		pole = Vector3.RIGHT
	var elbow := start + axis * along + pole.normalized() * height
	_aim(upper, lower, elbow - start)
	_aim(lower, end, start + axis * distance - _joint(lower))

func _point(body: Node2D, key: String) -> Vector2:
	var bone: Bone2D = body.get("bones")[key]
	return body.to_local(bone.global_position)

func apply_pose(body: Node2D) -> void:
	var points := {}
	for key: String in ["Pelvis", "Neck", "NearElbow", "FarElbow", "NearWrist", "FarWrist",
		"NearKnee", "FarKnee", "NearAnkle", "FarAnkle"]:
		points[key] = _point(body, key)
	for side: String in SIDES:
		var sole: Bone2D = body.get("bones")[side + "Ankle"]
		points[side + "FootAxis"] = body.to_local(sole.to_global(Vector2.RIGHT)) - body.to_local(sole.global_position)
	var state: String = body.get("state")
	if state in ["idle", "walk", "run", "sprint"]:
		_grounded_pose(points, state, float(body.get("phase")), bool(body.call("_aim_walk")))
	apply_points(points)

func _grounded_pose(points: Dictionary, state: String, phase: float, aiming_walk: bool) -> void:
	var pelvis_rest := rig.get_bone_global_rest(indices.pelvis).origin
	var ankle_rest := rig.get_bone_global_rest(indices.r_foot).origin
	var neck_rest := rig.get_bone_global_rest(indices.neck1).origin
	var height := (pelvis_rest.y - ankle_rest.y) * UNITS_PER_METER
	var ankle_y := -ankle_rest.y * UNITS_PER_METER
	var running := state in ["run", "sprint"] and not aiming_walk
	var stride := 0.0 if state == "idle" else height * (.27 if running else .17)
	var lift := 0.0 if state == "idle" else height * (.22 if running else .09)
	var swing := phase * TAU
	var bob := 0.0 if state == "idle" else (1 - cos(swing * 2)) * (.42 if running else .25)
	var pelvis := Vector2(pelvis_rest.z * UNITS_PER_METER, ankle_y - height + .8 + bob)
	points.Pelvis = pelvis
	points.Neck = pelvis + Vector2((neck_rest.z - pelvis_rest.z) * UNITS_PER_METER + (3.8 if running else 0),
		-(neck_rest.y - pelvis_rest.y) * UNITS_PER_METER)
	for side: String in SIDES:
		var cycle := swing + (0.0 if side == "Near" else PI)
		var offset := 1.6 if side == "Near" else -1.6
		var ankle := Vector2(ankle_rest.z * UNITS_PER_METER + offset + cos(cycle) * stride, ankle_y - maxf(0, sin(cycle)) * lift)
		points[side + "Ankle"] = ankle
		points[side + "Knee"] = (pelvis + ankle) * .5 + Vector2(6, 0)
		points[side + "FootAxis"] = Vector2.RIGHT.rotated(maxf(0, sin(cycle)) * .28 if state != "idle" else 0.0)

func _frame(origin: Vector2, center: Vector2, height: float) -> void:
	var profile_camera := Transform3D(Basis.looking_at(Vector3.RIGHT), Vector3(-4, center.y, center.x))
	camera.transform = fall_view.affine_inverse() * profile_camera
	camera.size = height
	position = origin + Vector2(center.x, -center.y) * UNITS_PER_METER
	scale = Vector2.ONE * (height * UNITS_PER_METER / viewport.size.y)

func frame_fall(origin: Vector2) -> void:
	var lower := Vector2(INF, INF)
	var upper := Vector2(-INF, -INF)
	for key: String in ["head", "neck1", "pelvis", "l_upperarm", "r_upperarm", "l_forearm", "r_forearm",
		"l_hand", "r_hand", "l_mid3", "r_mid3", "l_thigh", "r_thigh", "l_shin", "r_shin",
		"l_foot", "r_foot", "l_toes", "r_toes"]:
		var point := fall_view * _joint(key)
		lower = lower.min(Vector2(point.z, point.y))
		upper = upper.max(Vector2(point.z, point.y))
	var bounds := upper - lower + Vector2.ONE * .54
	var height := maxf(VIEW_HEIGHT, maxf(bounds.y, bounds.x * viewport.size.y / viewport.size.x))
	_frame(origin, (lower + upper) * .5, height)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func restore_profile_frame() -> void:
	_frame(Vector2.ZERO, Vector2(0, CAMERA_HEIGHT), VIEW_HEIGHT)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func set_fall_turn(yaw: float, roll: float) -> void:
	if not is_instance_valid(rig): return
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, roll)
	var pivot := _joint("pelvis")
	var turned := Transform3D(basis, pivot - basis * pivot)
	if fall_view.is_equal_approx(turned): return
	fall_view = turned
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func apply_points(points: Dictionary) -> void:
	if not is_instance_valid(rig) or points == last_points: return
	last_points = points
	rig.reset_bone_poses()
	var hip := rig.get_bone_global_pose(indices.hip)
	var pelvis := _target(points.Pelvis, 0)
	hip.origin += pelvis - _joint("pelvis")
	rig.set_bone_global_pose(indices.hip, hip)
	var neck := _target(points.Neck, 0)
	_aim("spine1", "neck1", neck - _joint("spine1"))
	for side: String in SIDES:
		var prefix: String = SIDES[side]
		var upper := prefix + "upperarm"
		var thigh := prefix + "thigh"
		var arm_depth := _joint(upper).x
		var leg_depth := _joint(thigh).x
		var elbow_target := _target(points[side + "Elbow"], arm_depth)
		var grip_target := _target(points[side + "Wrist"], arm_depth)
		var palm_direction := (grip_target - elbow_target).normalized()
		var wrist := grip_target - palm_direction * .063
		_limb(upper, prefix + "forearm", prefix + "hand", elbow_target, wrist)
		_aim(prefix + "hand", prefix + "hand_anchor", grip_target - _joint(prefix + "hand"))
		_limb(thigh, prefix + "shin", prefix + "foot",
			_target(points[side + "Knee"], leg_depth),
			_target(points[side + "Ankle"], leg_depth))
		var foot_axis: Vector2 = points[side + "FootAxis"]
		var foot_rest := rig.get_bone_global_rest(indices[prefix + "foot"]).origin
		var toe_rest := rig.get_bone_global_rest(indices[prefix + "toes"]).origin
		_aim(prefix + "foot", prefix + "toes", (toe_rest - foot_rest).rotated(Vector3.RIGHT, foot_axis.angle()))
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
