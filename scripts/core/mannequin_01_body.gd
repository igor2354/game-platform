extends CoreHybridBody
## Shared gameplay adapter; artwork supplies its own bind pose and bone lengths.
const MODEL = preload("res://resources/core/user_standing/Standing.scn")
const PARTS := {
	"NearShoulder": "right_upper_arm", "NearElbow": "right_forearm", "NearWrist": "right_forearm",
	"FarShoulder": "left_upper_arm", "FarElbow": "left_forearm", "FarWrist": "left_forearm",
	"NearHip": "right_thigh", "NearKnee": "right_shin", "NearAnkle": "right_foot",
	"FarHip": "left_thigh", "FarKnee": "left_shin", "FarAnkle": "left_foot",
	"Spine": "torso", "Neck": "head",
}
var model: Node2D
var bones: Dictionary[String, Bone2D] = {}
var bind_points: Dictionary[String, Vector2] = {}
var skin_pieces: Array[Dictionary] = []

func _instantiate_model() -> Node2D:
	return MODEL.instantiate()

func _ready() -> void:
	model = _instantiate_model()
	add_child(model)
	for bone: Bone2D in model.find_children("*", "Bone2D", true, false):
		bones[bone.name] = bone
		bind_points[bone.name] = model.to_local(bone.global_position)
	for piece: Sprite2D in model.find_children("*", "Sprite2D", true, false):
		var bone := piece.get_parent() as Bone2D
		var entry := {"sprite": piece, "bone": bone, "offset": piece.transform, "part": PARTS[bone.name], "depth": piece.z_index}
		skin_pieces.append(entry)
	skin_pieces.sort_custom(func(a, b): return a.depth < b.depth)
	super._ready()
	far_arm.draw_placeholder = false
	near_arm.draw_placeholder = false

func _draw() -> void:
	pass

func _show_frame() -> void:
	sprite.hide()
	scale.x = facing
	model.position = Vector2.ZERO
	var low := state in ["crouch", "crouch_walk", "slide"]
	var airborne := state == "jump" and frame != 7
	var stepping := state in ["walk", "run", "sprint", "crouch_walk", "climb"]
	var burst := state in ["dash", "dash_back"]
	var lean := 20.0 if low else 9.0 if stepping else 4.0 if airborne else 0.0
	if state in ["push", "pull", "barrel_roll", "barrel_tip"] or burst:
		lean = 20.0 * (-1.0 if state in ["pull", "dash_back"] else 1.0)
	bones.Spine.rotation_degrees = lean
	bones.Neck.rotation_degrees = -lean * .65 + 12.0 * float(head_aim_stage()) / (ADS_STAGES - 1)
	for side in ["Near", "Far"]:
		var offset := 0.0 if side == "Near" else PI
		var swing := sin(phase * TAU + offset) if stepping else 0.0
		var lift := maxf(0, cos(phase * TAU + offset)) if stepping else 0.0
		var stride := 30.0 if state == "sprint" else 23.0 if state == "run" else 16.0
		var hip := -43.0 if low else -22.0 if airborne else 0.0
		var knee := 83.0 if low else 38.0 if airborne else 0.0
		if state == "slide":
			hip = -62.0
			knee = 27.0 if side == "Near" else 54.0
		bones[side + "Hip"].rotation_degrees = hip + swing * stride
		bones[side + "Knee"].rotation_degrees = knee + lift * (31.0 if stepping else 0.0)
		bones[side + "Ankle"].rotation_degrees = -hip - swing * stride - bones[side + "Knee"].rotation_degrees
	var sole_y := -INF
	for sole in ground_soles():
		sole_y = maxf(sole_y, to_local(sole).y)
	model.position.y = -sole_y

func ground_soles() -> PackedVector2Array:
	return PackedVector2Array([
		bones.NearAnkle.to_global(Vector2(2, 5.08)),
		bones.FarAnkle.to_global(Vector2(2, 5.2)),
	])

func _configure_arm_lengths() -> void:
	for side in ["Near", "Far"]:
		var arm := near_arm if side == "Near" else far_arm
		arm.upper_length = bones[side + "Elbow"].position.length()
		arm.lower_length = bones[side + "Wrist"].position.length()
		arm.minimum_reach = 0

func arm_reach(side: String) -> float:
	var prefix := side.capitalize()
	return bones[prefix + "Elbow"].position.length() + bones[prefix + "Wrist"].position.length() - .15

func shoulder(side: String) -> Vector2:
	return _point(side.capitalize() + "Shoulder")

func _point(key: String, standing := false) -> Vector2:
	var point := bind_points[key] if standing else to_local(bones[key].global_position)
	return point * Vector2(facing, 1)

func eye_anchor() -> Vector2:
	return to_local(bones.Neck.to_global(Vector2(3.1, -4.8))) * Vector2(facing, 1)

func weapon_mount_points() -> Array:
	return [eye_anchor(), _point("Neck"), _point("Pelvis")]

func update_arms() -> void:
	super.update_arms()
	for side in ["Near", "Far"]:
		var arm := near_arm if side == "Near" else far_arm
		_orient(bones[side + "Shoulder"], bones[side + "Elbow"].position, arm.elbow - arm.shoulder)
		_orient(bones[side + "Elbow"], bones[side + "Wrist"].position, arm.hand - arm.elbow)
		bones[side + "Wrist"].rotation = 0.0
	if near_arm.get_parent() == null: return
	for entry in skin_pieces:
		var piece: Sprite2D = entry.sprite
		var layer: Node2D = model
		if piece.name.contains("arm") or piece.name.ends_with("_hand"):
			layer = far_arm if piece.name.begins_with("far") else near_arm
		if piece.get_parent() != layer:
			piece.reparent(layer, false)
			piece.z_index = 0
		var bone: Bone2D = entry.bone
		piece.transform = layer.global_transform.affine_inverse() * bone.global_transform * entry.offset
		piece.texture_filter = sprite.texture_filter

func _orient(bone: Bone2D, rest_axis: Vector2, target: Vector2) -> void:
	if target.length_squared() < .0001: return
	var parent := bone.get_parent() as Bone2D
	var world_axis := global_transform.basis_xform(target * Vector2(facing, 1))
	bone.rotation = rest_axis.angle_to(parent.global_transform.basis_xform_inv(world_axis))

func ragdoll_pose(standing := false) -> Dictionary:
	var pelvis := _point("Pelvis", standing)
	var neck := _point("Neck", standing)
	var head := neck + Vector2(facing, -5.0) if standing else eye_anchor() - Vector2(1.5 * facing, 1)
	var parts := {
		"pelvis": {"position": pelvis, "rotation": 0.0, "dimensions": Vector2(8, 5)},
		"head": {"position": head, "rotation": 0.0 if standing else bones.Neck.rotation * facing, "dimensions": Vector2(6.9, 8)},
	}
	var joints := {"neck": neck, "waist": pelvis}
	_pose_segment(parts, "torso", neck, pelvis, 9)
	for side in ["Near", "Far"]:
		var key := "right" if side == "Near" else "left"
		var origin := _point(side + "Shoulder", standing)
		var elbow := _point(side + "Elbow", standing)
		var wrist := _point(side + "Wrist", standing)
		var hip := _point(side + "Hip", standing)
		var knee := _point(side + "Knee", standing)
		var ankle := _point(side + "Ankle", standing)
		_pose_segment(parts, key + "_upper_arm", origin, elbow, 4.6)
		_pose_segment(parts, key + "_forearm", elbow, wrist, 3.6)
		_pose_segment(parts, key + "_thigh", hip, knee, 7)
		_pose_segment(parts, key + "_shin", knee, ankle, 5)
		parts[key + "_foot"] = {"position": ankle + Vector2(3.4 * facing, 2.8), "rotation": 0.0, "dimensions": Vector2(9, 4.5)}
		joints[key + "_shoulder"] = origin
		joints[key + "_elbow"] = elbow
		joints[key + "_hip"] = hip
		joints[key + "_knee"] = knee
		joints[key + "_ankle"] = ankle
	return {"parts": parts, "joints": joints, "facing": facing, "pelvis_offset": -pelvis.y}

func capture_skin() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in skin_pieces:
		var piece: Sprite2D = entry.sprite
		result.append({"texture": piece.texture, "world": piece.global_transform, "part": entry.part, "depth": entry.depth})
	return result
