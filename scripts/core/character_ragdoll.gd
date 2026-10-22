class_name CoreCharacterRagdoll
extends Node2D
## Combat actor stays authoritative for HP; an articulated physical proxy moves it.
const LAYER := 128
const PLAYER_SKIN = preload("res://scripts/core/player_ragdoll_skin.gd")
const ZOMBIE_SKIN = preload("res://scripts/core/zombie_ragdoll_skin.gd")
var actor: Node2D
var rig: Node2D
var active := false
var left := 0.0
var height := 64.0
var original_layer := 0
var original_mask := 0
var hidden_nodes: Array[CanvasItem] = []
var frozen := false
var player_skin: Node2D
var pelvis_offset := 0.0
var zombie_skin: Node2D
var recovering := false
var recovery_finished := false
var recovery_elapsed := 0.0
var recovery_duration := .65
var recovery_feet := Vector2.ZERO
var recovery_source: Dictionary = {}
var recovery_target: Dictionary = {}
var recovery_points: Dictionary = {}
var joint_anchors: Dictionary = {}
func capture_pose() -> Dictionary:
	if actor.has_method("ragdoll_pose"): return actor.call("ragdoll_pose")
	if actor is CoreMovementPlayer: return actor.body.ragdoll_pose()
	if actor is CoreZombie: return ZOMBIE_SKIN.capture_pose(actor)
	return {}
func start(impulse: Vector2,duration: float,tension: float,initial_pose: Dictionary = {}) -> void:
	left = maxf(left,duration)
	if active:
		if recovering or recovery_finished: _interrupt_recovery()
		for part in rig.parts.values(): part.linear_velocity += impulse
		return
	var pose: Dictionary = capture_pose() if initial_pose.is_empty() else initial_pose
	if actor is CoreMovementPlayer and not actor.character_id.is_empty() and not actor.weapon.equipped_weapon_id.is_empty():
		pose.weapon_pose = actor.weapon.visual_pose().duplicate(true)
	recovering = false
	recovery_finished = false
	active = true
	original_layer = actor.collision_layer
	original_mask = actor.collision_mask
	if actor is CoreEnemyDummy and actor.knockdown_left > 0:
		original_mask = actor.knockdown_saved_mask
		actor.knockdown_left = 0
		actor.knockdown_saved_mask = 0
	actor.collision_layer = 0
	actor.collision_mask = 0
	actor.velocity = Vector2.ZERO
	actor.rotation = 0
	height = actor.collision_height() if actor is CoreMovementPlayer else actor.body_size.y
	if actor is CoreMovementPlayer:
		if actor.parkour_active(): actor.parkour.cancel()
		actor.stop_pushing()
		if actor.climbing: actor._leave_ladder()
		if actor.slide_left > 0: actor._finish_slide()
		actor.dash_left = 0
		actor._clear_dash_exceptions()
		actor.weapon.cancel_reload()
		actor.weapon.firing = false
		actor.weapon.aiming = false
		if actor.grenades.preparing(): actor.grenades.throw_held(true)
		hidden_nodes = [actor.visuals]
	else:
		actor._sync_zones()
		hidden_nodes = []
	actor.collision_layer = 0
	actor.collision_mask = 0
	for node in hidden_nodes: node.hide()
	rig = load("res://scripts/core/ragdoll_mannequin.gd").new()
	rig.name = "BlastBody"
	rig.position = actor.global_position
	rig.body_scale = height/94.0
	pelvis_offset = height*44/94
	if actor is CoreMovementPlayer:
		rig.body_scale = CoreMovementPlayer.HEIGHT/94.0
	if not pose.is_empty():
		rig.initial_parts = pose.parts.duplicate(true)
		rig.initial_joints = pose.joints.duplicate(true)
		rig.anatomical_limits = pose.get("anatomical_limits",{})
		pelvis_offset = pose.pelvis_offset
	rig.display_label = false
	rig.muscle_tension = tension
	rig.muscle_damping = 3
	actor.get_parent().add_child(rig)
	if actor is CoreMovementPlayer:
		player_skin = PLAYER_SKIN.new()
		player_skin.name = "PlayerSkin"
		player_skin.rig = rig
		player_skin.player = actor
		player_skin.facing = pose.facing
		player_skin.painted_head_stage = pose.get("painted_head_stage",0)
		# Keep the exact painted phase as the physical mesh's bind pose.
		player_skin.painted_cel_pose = pose.duplicate(true)
		rig.add_child(player_skin)
	elif actor is CoreZombie:
		zombie_skin = actor.call("create_ragdoll_skin") if actor.has_method("create_ragdoll_skin") else ZOMBIE_SKIN.new()
		zombie_skin.name = "ZombieSkin"
		zombie_skin.rig = rig
		zombie_skin.zombie = actor
		zombie_skin.pose = pose
		rig.add_child(zombie_skin)
	joint_anchors.clear()
	for index in rig.joints.size():
		var definition: Array = rig.JOINTS[index]
		joint_anchors[definition[0]] = rig.parts[definition[1]].to_local(rig.joints[index].global_position)
	for key in rig.parts:
		var part: RigidBody2D = rig.parts[key]
		part.collision_layer = LAYER
		part.collision_mask = 1|8|LAYER
		part.set_meta("combat_owner",actor)
		var anatomical := anatomy(key)
		part.set_meta("body_part",anatomical)
		part.skin_rendered = actor is CoreMovementPlayer or actor is CoreZombie
		part.tint = Color("829fae") if actor is CoreMovementPlayer else Color("809769") if actor is CoreZombie else Color("7d8b76")
		if anatomical == "head": part.tint = Color("b4b39b")
		part.add_collision_exception_with(actor)
		if actor is CoreEnemyDummy and not actor.has_part(anatomical):
			part.hide()
			part.collision_layer = 0
			part.collision_mask = 0
	rig.activate()
	for part in rig.parts.values():
		part.linear_velocity = impulse
		part.angular_velocity = clampf(impulse.x/100,-5,5)
	if pose.has("weapon_pose"):
		var held_weapon := preload("res://scripts/campaign/ragdoll_weapon.gd").new()
		held_weapon.name = "HeldWeapon"
		held_weapon.player = actor
		held_weapon.rig = rig
		held_weapon.source = pose.weapon_pose
		rig.add_child(held_weapon)
	queue_redraw()
func anatomy(key: String) -> String:
	if "arm" in key or "forearm" in key: return "left_arm" if key.begins_with("left") else "right_arm"
	if "thigh" in key or "shin" in key or "foot" in key: return "left_leg" if key.begins_with("left") else "right_leg"
	return "head" if key == "head" else "torso"
func tick(delta: float) -> void:
	if not active or not is_instance_valid(rig): return
	var stopped: bool = actor is CoreEnemyDummy and actor.test_frozen
	if stopped != frozen:
		frozen = stopped
		rig.set_simulation_enabled(not stopped and not recovering and not recovery_finished)
	if stopped: return
	if actor is CoreEnemyDummy:
		for key in rig.parts:
			var part: RigidBody2D = rig.parts[key]
			if not actor.has_part(anatomy(key)):
				part.hide()
				part.collision_layer = 0
				part.collision_mask = 0
	if (recovering or recovery_finished) and (actor.health <= 0 or (actor is CoreEnemyDummy and not recovery_target.get("prone",false) and (not actor.has_part("left_leg") or not actor.has_part("right_leg")))):
		_interrupt_recovery()
		# Let gravity resolve the changed support before starting a new crawl
		# recovery; never re-enter the old standing transition in this tick.
		left = maxf(left,.15)
	if recovering:
		_tick_recovery(delta)
		queue_redraw()
		return
	left = maxf(0,left-delta)
	var pelvis: RigidBody2D = rig.parts.pelvis
	actor.global_position = pelvis.global_position+Vector2(0,pelvis_offset)
	actor.velocity = pelvis.linear_velocity
	if actor.global_position.y > CoreMovementLevel.FALL_LIMIT:
		if actor is CoreMovementPlayer: actor.fell.emit()
		else:
			actor.take_damage(actor.health)
			for part in rig.parts.values(): part.freeze = true
		return
	if left <= 0 and actor.health > 0 and pelvis.linear_velocity.length() < 130:
		_try_recover()
	queue_redraw()
func _try_recover() -> void:
	var pelvis: RigidBody2D = rig.parts.pelvis
	var excluded: Array[RID] = [actor.get_rid()]
	for part in rig.parts.values(): excluded.append(part.get_rid())
	# Start beside the fallen body, below any low roof. Starting a full body
	# height above it can mistake an overhead platform for the recovery floor.
	var from := pelvis.global_position-Vector2(0,2)
	var ray := PhysicsRayQueryParameters2D.create(from,pelvis.global_position+Vector2(0,height),1|8,excluded)
	var ground := get_world_2d().direct_space_state.intersect_ray(ray)
	if ground.is_empty(): return
	var size: Vector2 = Vector2(28,height) if actor is CoreMovementPlayer else actor.body_size
	# Harry's target is a full standing pose, even if the hit began crouched.
	if actor is CoreMovementPlayer and actor.uses_smooth_recovery(): size.y = CoreMovementPlayer.HEIGHT
	if actor is CoreEnemyDummy:
		var legless: bool = not actor.has_part("left_leg") and not actor.has_part("right_leg")
		if actor is CoreZombie: legless = not actor.has_part("left_leg") or not actor.has_part("right_leg")
		if legless: size = Vector2(24,24)
	var shape := CapsuleShape2D.new()
	shape.radius = minf(12,size.x*.4)
	shape.height = maxf(size.y,shape.radius*2)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = original_mask & ~8
	query.exclude = excluded
	# Try nearby feet positions; never stand inside a ceiling, prop or wall.
	for offset in [0.0,-20.0,20.0,-40.0,40.0]:
		var feet: Vector2 = ground.position+Vector2(offset,-.5)
		query.transform = Transform2D(0,feet-Vector2(0,shape.height*.5))
		if get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():
			if (actor is CoreZombie or (actor is CoreMovementPlayer and actor.uses_smooth_recovery())) and not recovery_finished:
				_begin_recovery(feet)
				return
			actor.global_position = feet
			cancel()
			actor.velocity = Vector2.ZERO
			if actor is CoreMovementPlayer:
				actor.barrel_knockdown_left = 0
				actor.shove_left = 0
				actor._try_stand()
				actor.mode = "idle"
				if actor.uses_smooth_recovery():
					var direction: float = actor.body.facing
					actor.body.reset_visual()
					actor.body.facing = direction
					actor.body._show_frame()
					actor.body.update_arms()
			else:
				actor.knockdown_left = 0
				actor._update_body_shape()
				actor._sync_zones()
				actor._on_knockdown_ended()
			return

func _begin_recovery(feet: Vector2) -> void:
	recovering = true
	recovery_elapsed = 0
	recovery_feet = feet
	var legless: bool = actor is CoreEnemyDummy and (not actor.has_part("left_leg") or not actor.has_part("right_leg"))
	recovery_duration = .35 if legless else .65
	if actor is CoreEnemyDummy: actor.reaction_offset = Vector2.ZERO
	var rects := {}
	if actor is CoreEnemyDummy:
		for anatomy_key in CoreEnemyDummy.PARTS: rects[anatomy_key] = actor.animated_part_rect(anatomy_key,legless,false)
	recovery_target = actor.call("ragdoll_recovery_pose",legless) if actor.has_method("ragdoll_recovery_pose") else ZOMBIE_SKIN.capture_pose(actor,rects)
	recovery_source = {"parts":{},"points":{},"offset":pelvis_offset}
	for key in rig.parts:
		var part: RigidBody2D = rig.parts[key]
		recovery_source.parts[key] = {"pose":part.global_transform,"dimensions":part.dimensions}
	for definition in rig.JOINTS:
		recovery_source.points[definition[0]] = rig.parts[definition[1]].to_global(joint_anchors[definition[0]])
	for side in ["left","right"]:
		for entry in [["hand","_forearm"],["tip","_foot"]]:
			var part: RigidBody2D = rig.parts[side+entry[1]]
			recovery_source.points[side+"_"+entry[0]] = part.to_global(Vector2(0,part.dimensions.y*.5))
	rig.set_simulation_enabled(false)

func _tick_recovery(delta: float) -> void:
	recovery_elapsed += delta
	var phase := clampf(recovery_elapsed/recovery_duration,0,1)
	if actor.has_method("ragdoll_recovery_phase"): phase = actor.call("ragdoll_recovery_phase",phase)
	var blend := smoothstep(0,1,phase)
	recovery_points.clear()
	for key in recovery_source.points:
		var target_point: Vector2
		if recovery_target.joints.has(key): target_point = recovery_target.joints[key]
		else:
			var body_key: String = key.replace("_hand","_forearm").replace("_tip","_foot")
			var definition: Dictionary = recovery_target.parts[body_key]
			target_point = Transform2D(definition.rotation,definition.position)*Vector2(0,definition.dimensions.y*.5)
		# Palms brace the ground before lifting; knees unfold after the torso.
		var amount := smoothstep(.3,1,phase) if key.ends_with("hand") else blend
		recovery_points[key] = (recovery_source.points[key] as Vector2).lerp(recovery_feet+target_point,amount)
	if actor.has_method("constrain_recovery_points"):
		actor.call("constrain_recovery_points",recovery_points,recovery_feet)
	var endpoints := {"torso":["neck","waist"]}
	for side in ["left","right"]:
		endpoints[side+"_upper_arm"] = [side+"_shoulder",side+"_elbow"]
		endpoints[side+"_forearm"] = [side+"_elbow",side+"_hand"]
		endpoints[side+"_thigh"] = [side+"_hip",side+"_knee"]
		endpoints[side+"_shin"] = [side+"_knee",side+"_ankle"]
		endpoints[side+"_foot"] = [side+"_ankle",side+"_tip"]
	for key in rig.parts:
		var part: RigidBody2D = rig.parts[key]
		var from: Dictionary = recovery_source.parts[key]
		var to: Dictionary = recovery_target.parts[key]
		var target_pose := Transform2D(to.rotation,recovery_feet+to.position)
		var pose: Transform2D = from.pose.interpolate_with(target_pose,blend)
		var dimensions: Vector2 = from.dimensions.lerp(to.dimensions,blend)
		if key == "head" and (recovery_target.get("concept",false) or recovery_target.get("harry_anatomy",false)):
			# Use the same neck pivot as the physical joint, not an unrelated
			# interpolation of the head's centre through the lifting torso.
			var neck_anchor: Vector2 = Transform2D(to.rotation,to.position).affine_inverse()*recovery_target.joints.neck
			pose.origin = recovery_points.neck-pose.basis_xform(neck_anchor*dimensions/to.dimensions)
		if endpoints.has(key):
			var a: Vector2 = recovery_points[endpoints[key][0]]
			var b: Vector2 = recovery_points[endpoints[key][1]]
			pose = Transform2D(Vector2.DOWN.angle_to(b-a),(a+b)*.5)
			dimensions.y = maxf(2,a.distance_to(b))
		part.dimensions = dimensions
		part.inertia = part.mass*dimensions.length_squared()/12.0
		var shape = part.get_child(0).shape
		if shape is RectangleShape2D: shape.size = dimensions
		part.suspended_transform = pose
		part.global_transform = pose
		part.linear_velocity = Vector2.ZERO
		part.angular_velocity = 0
	pelvis_offset = lerpf(recovery_source.offset,recovery_target.pelvis_offset,blend)
	actor.global_position = rig.parts.pelvis.global_position+Vector2(0,pelvis_offset)
	actor.velocity = Vector2.ZERO
	if phase >= 1:
		recovering = false
		recovery_finished = true
		_try_recover()

func _interrupt_recovery() -> void:
	recovering = false
	recovery_finished = false
	rig.set_simulation_enabled(true)
	for key in rig.parts: rig.initial_parts[key].rotation = rig.parts[key].rotation
	for index in rig.joints.size():
		var definition: Array = rig.JOINTS[index]
		var key: String = definition[0]
		var joint: PinJoint2D = rig.joints[index]
		var brace: PinJoint2D = rig.muscle_braces[index]
		joint.node_a = NodePath()
		joint.node_b = NodePath()
		brace.node_a = NodePath()
		brace.node_b = NodePath()
		joint.global_position = recovery_points[key]
		brace.global_position = joint.global_position+rig.parts[definition[1]].global_transform.x*12*rig.body_scale
		joint_anchors[key] = rig.parts[definition[1]].to_local(joint.global_position)
		brace.set_meta("anchor_a",rig.parts[definition[1]].to_local(brace.global_position))
		for pin in [joint,brace]:
			if pin == brace and rig.muscle_tension <= 0: continue
			pin.node_a = pin.get_path_to(rig.parts[definition[1]])
			pin.node_b = pin.get_path_to(rig.parts[definition[2]])

func cancel() -> void:
	if not active: return
	active = false
	recovering = false
	recovery_finished = false
	actor.collision_layer = original_layer if actor is CoreMovementPlayer or actor.health > 0 else 0
	actor.collision_mask = original_mask
	for node in hidden_nodes:
		if is_instance_valid(node): node.show()
	if is_instance_valid(rig):
		rig.set_physics_process(false)
		for part in rig.parts.values():
			part.collision_layer = 0
			part.collision_mask = 0
			rig.set_simulation_enabled(false)
		rig.queue_free()
	rig = null
	player_skin = null
	zombie_skin = null
	queue_redraw()
func _exit_tree() -> void:
	if is_instance_valid(rig) and not rig.is_queued_for_deletion(): rig.queue_free()
func _draw() -> void:
	if not active or not is_instance_valid(rig) or actor is CoreMovementPlayer: return
	var point := to_local(rig.parts.head.global_position)+Vector2(-35,-20)
	if actor is CoreZombie:
		var status := "МЁРТВ" if actor.health <= 0 else "ОПИРАЕТСЯ НА РУКИ" if recovering and recovery_target.prone else "ПОДНИМАЕТСЯ" if recovering else "СБИТ С НОГ"
		draw_string(ThemeDB.fallback_font,point+Vector2(-10,-16),"ЗОМБИ · "+status,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("a0bb87"))
	draw_string(ThemeDB.fallback_font,point,"%s · %.0f HP" % [actor.identifier,actor.health],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("d0c9b5"))
