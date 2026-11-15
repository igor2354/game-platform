extends "res://scripts/core/mannequin_01_body.gd"
## User's own proportions and joint coordinates; only a uniform pixel/unit conversion.
const WALK = preload("res://resources/core/user_standing/walk_cycle.gd")
const RUN_ATLAS = preload("res://resources/core/user_standing/run_atlas.png")
const RUN_ATLAS_STRIDE := 256.0
const RUN_POSES = preload("res://resources/core/user_standing/run_poses.gd")
const DEPTH := {"FarArm":0,"FarLeg":1,"FarLegBacking":2,"Body":3,"HiddenTorso":4,"NearArm":5}
const PHYSICAL := {"HeadPivot":"head","Neck":"head","Spine":"torso","Pelvis":"pelvis",
	"NearShoulder":"right_upper_arm","NearElbow":"right_forearm","NearWrist":"right_forearm",
	"FarShoulder":"left_upper_arm","FarElbow":"left_forearm","FarWrist":"left_forearm",
	"NearHip":"right_thigh","NearKnee":"right_shin","NearAnkle":"right_foot",
	"FarHip":"left_thigh","FarKnee":"left_shin","FarAnkle":"left_foot"}
var mesh_pieces: Array[Polygon2D] = []
var skin_cache: Array[Dictionary] = []
var walk_blend := 0.0
var walk_cycle_active := false

func animation_stride() -> float:
	if state == "walk" or _aim_walk():
		return WALK.STRIDE
	if state == "run":
		return RUN_ATLAS_STRIDE
	return super.animation_stride()

func _aim_walk() -> bool:
	return state == "run" and _weapon_aiming()

func _weapon_aiming() -> bool:
	return player.weapon.aiming and player.weapon.tuning.weapon_enabled and not player.weapon.equipped_weapon_id.is_empty() and not player.grenades.busy()

func uses_run_atlas() -> bool:
	return state == "run" and player.health > 0 and (player.weapon.equipped_weapon_id.is_empty() or not player.weapon.tuning.weapon_enabled) and not player.grenades.busy()

func reset_visual() -> void:
	walk_blend=0
	walk_cycle_active = false
	super.reset_visual()

func advance(delta: float) -> void:
	var walking := (player.mode == "walk" or (player.mode == "run" and _weapon_aiming())) and landing_left <= delta
	if walking and not walk_cycle_active:
		phase = 0
	walk_cycle_active = walking
	walk_blend=move_toward(walk_blend,1.0 if walking else 0.0,delta/.14)
	super.advance(delta)

func _sample_walk() -> Dictionary:
	var p := fposmod(phase,1)*WALK.ANGLES.size()
	var index := floori(p)
	var next := (index+1)%WALK.ANGLES.size()
	return {"index":index,"next":next,"weight":p-index}

func _show_frame() -> void:
	# Other states must not inherit the walk's pelvis/head rotations.
	for bone: Bone2D in bones.values():bone.transform=bone.rest
	super._show_frame()
	if state == "run" and not _aim_walk() and not uses_run_atlas():
		_show_armed_run()
		return
	if walk_blend<=0:return
	var sample := _sample_walk()
	for i in WALK.NAMES.size():
		var bone: Bone2D=bones[WALK.NAMES[i]]
		var angle := lerp_angle(WALK.ANGLES[sample.index][i],WALK.ANGLES[sample.next][i],sample.weight)
		bone.rotation=lerp_angle(bone.rotation,angle,walk_blend)
	var a: Array=WALK.OFFSETS[sample.index]
	var b: Array=WALK.OFFSETS[sample.next]
	var offset := Vector2(a[0],a[1]).lerp(Vector2(b[0],b[1]),sample.weight)
	model.position=model.position.lerp(offset,walk_blend)
	bones.Neck.rotation+=deg_to_rad(12.0*float(head_aim_stage())/(ADS_STAGES-1))*walk_blend

func _show_armed_run() -> void:
	var sample := fposmod(phase, 1.0) * RUN_POSES.KEYS.size()
	var index := floori(sample)
	var a: Array = RUN_POSES.KEYS[index]
	var b: Array = RUN_POSES.KEYS[(index + 1) % RUN_POSES.KEYS.size()]
	var weight := sample - index
	bones.Spine.rotation_degrees = lerpf(a[6], b[6], weight)
	bones.Neck.rotation_degrees = -bones.Spine.rotation_degrees * .65 + 12.0 * float(head_aim_stage()) / (ADS_STAGES - 1)
	for side_index in 2:
		var side := "Near" if side_index == 0 else "Far"
		var offset := side_index * 3
		var hip := lerpf(a[offset], b[offset], weight)
		var knee := lerpf(a[offset + 1], b[offset + 1], weight)
		bones[side + "Hip"].rotation_degrees = hip
		bones[side + "Knee"].rotation_degrees = knee
		bones[side + "Ankle"].rotation_degrees = lerpf(a[offset + 2], b[offset + 2], weight) - hip - knee
	model.position = Vector2.ZERO
	var sole_y := -INF
	for sole in ground_soles():
		sole_y = maxf(sole_y, to_local(sole).y)
	model.position.y = -sole_y - lerpf(a[7], b[7], weight)

func _instantiate_model() -> Node2D:
	var result: Node2D = super._instantiate_model()
	for piece: Polygon2D in result.find_children("*","Polygon2D",true,false):
		mesh_pieces.append(piece)
	return result

func _ready() -> void:
	super._ready()
	sprite.texture = RUN_ATLAS
	sprite.hframes = 4
	sprite.vframes = 4
	sprite.offset = Vector2(-220, -496)
	sprite.scale = Vector2.ONE * (64.0 / 480.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_prepare_skin_cache()

func ground_soles() -> PackedVector2Array:
	return PackedVector2Array([bones.NearAnkle.to_global(Vector2(1.5,WALK.SOLE_Y)),bones.FarAnkle.to_global(Vector2(1.5,WALK.SOLE_Y))])

func eye_anchor() -> Vector2:
	return to_local(bones.HeadPivot.to_global(Vector2(2.4,.15))) * Vector2(facing,1)

func update_arms() -> void:
	super.update_arms()
	var atlas_active := uses_run_atlas()
	sprite.visible = atlas_active
	if atlas_active:
		sprite.frame = mini(15, floori(fposmod(phase, 1.0) * 16))
	for piece in mesh_pieces:
		piece.visible = not atlas_active
	if walk_blend>0 and player.weapon.equipped_weapon_id.is_empty() and not player.grenades.busy() and not player.climbing and not player.pushing:
		var sample := _sample_walk()
		for i in WALK.NAMES.size():
			var key: String=WALK.NAMES[i]
			if not (key.ends_with("Shoulder") or key.ends_with("Elbow") or key.ends_with("Wrist")):continue
			var bone: Bone2D=bones[key]
			bone.rotation=lerp_angle(bone.rotation,lerp_angle(WALK.ANGLES[sample.index][i],WALK.ANGLES[sample.next][i],sample.weight),walk_blend)
		for side in ["Near","Far"]:
			var arm := near_arm if side=="Near" else far_arm
			arm.shoulder=_point(side+"Shoulder")
			arm.elbow=_point(side+"Elbow")
			arm.hand=_point(side+"Wrist")
	if near_arm.get_parent()==null: return
	var skeleton: Skeleton2D = model.get_node("Rig")
	for poly in mesh_pieces:
		var layer: Node2D = model
		if poly.name=="NearArm": layer=near_arm
		elif poly.name=="FarArm": layer=far_arm
		if poly.get_parent()!=layer:
			poly.reparent(layer,false)
			poly.skeleton=poly.get_path_to(skeleton)
		poly.transform=layer.global_transform.affine_inverse()*model.global_transform
		poly.texture_filter=sprite.texture_filter

func _prepare_skin_cache() -> void:
	# Cache topology/bind matrices on creation, not on every shot or frame.
	var skeleton: Skeleton2D = model.get_node("Rig")
	for poly in mesh_pieces:
		var influences: Array[Dictionary] = []
		for i in poly.get_bone_count():
			var bone: Bone2D = skeleton.get_node(poly.get_bone_path(i))
			var local_bind: Transform2D = model.global_transform.affine_inverse()*bone.global_transform
			# Arms may already be aimed by _ready: derive bind from the saved rest chain.
			local_bind=Transform2D.IDENTITY
			var chain: Array[Bone2D] = []
			var cursor: Node = bone
			while cursor is Bone2D:
				chain.push_front(cursor)
				cursor=cursor.get_parent()
			for entry in chain: local_bind=local_bind*entry.rest
			influences.append({"bone":bone,"inverse":local_bind.affine_inverse(),"weights":poly.get_bone_weights(i),"part":PHYSICAL.get(str(bone.name),"torso")})
		var groups: Dictionary = {}
		for face in poly.polygons:
			var scores: Dictionary = {}
			for influence in influences:
				var score := 0.0
				for index in face: score+=influence.weights[index]
				scores[influence.part]=float(scores.get(influence.part,0.0))+score
			var winner := "torso"
			var best := -1.0
			for key in scores:
				if scores[key]>best: best=scores[key]; winner=key
			if not groups.has(winner): groups[winner]=PackedInt32Array()
			for index in face: groups[winner].append(index)
		skin_cache.append({"poly":poly,"influences":influences,"groups":groups})

func capture_skin() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in skin_cache:
		var poly: Polygon2D = entry.poly
		var positions := PackedVector2Array()
		positions.resize(poly.polygon.size())
		for influence in entry.influences:
			var transform: Transform2D = model.global_transform.affine_inverse()*influence.bone.global_transform*influence.inverse
			var weights: PackedFloat32Array = influence.weights
			for i in weights.size():
				if weights[i]>0: positions[i]+=transform*poly.polygon[i]*weights[i]
		var normalized_uv := PackedVector2Array()
		for uv in poly.uv: normalized_uv.append(uv/poly.texture.get_size())
		for key in entry.groups:
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=positions
			arrays[Mesh.ARRAY_TEX_UV]=normalized_uv
			arrays[Mesh.ARRAY_INDEX]=entry.groups[key]
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
			result.append({"texture":poly.texture,"mesh":mesh,"world":model.global_transform,"part":key,"depth":DEPTH[str(poly.name)]})
	return result
