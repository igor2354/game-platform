class_name CoreHybridBody
extends Node2D
## Whole-body baked pictures; the arms attach to each picture's shoulders.
const POSES = preload("res://resources/core/hybrid/poses.gd")
const HARRY = preload("res://scripts/campaign/harry_anatomy.gd")
const HARRY_MOTION = preload("res://scripts/campaign/harry_motion.gd")
const TEXTURES = {
	"idle":preload("res://resources/core/hybrid/idle.png"),
	"walk":preload("res://resources/core/hybrid/walk.png"),
	"run":preload("res://resources/core/hybrid/run.png"),
	"jump":preload("res://resources/core/hybrid/jump.png"),
	"dash":preload("res://resources/core/hybrid/dash.png"),
	"dash_back":preload("res://resources/core/hybrid/dash_back.png"),
	"climb":preload("res://resources/core/hybrid/climb.png"),
	"crouch":preload("res://resources/core/hybrid/crouch.png"),
	"crouch_walk":preload("res://resources/core/hybrid/crouch_walk.png"),
	"sprint":preload("res://resources/core/hybrid/sprint.png"),
	"slide":preload("res://resources/core/hybrid/slide.png"),
	"push":preload("res://resources/core/hybrid/push.png"),
	"pull":preload("res://resources/core/hybrid/pull.png")
	,"barrel_tip":preload("res://resources/core/hybrid/barrel_tip.png")
	,"barrel_roll":preload("res://resources/core/hybrid/barrel_roll.png")
}
const RUN_STRIDE := 96.0
const ADS_STAGES := 5
const ADS_TEXTURES = {
	"idle":preload("res://resources/core/hybrid/idle_ads.png"),
	"walk":preload("res://resources/core/hybrid/walk_ads.png"),
	"run":preload("res://resources/core/hybrid/run_ads.png"),
	"jump":preload("res://resources/core/hybrid/jump_ads.png"),
	"crouch":preload("res://resources/core/hybrid/crouch_ads.png"),
	"crouch_walk":preload("res://resources/core/hybrid/crouch_walk_ads.png")
}
var player: CoreMovementPlayer
var sprite: Sprite2D
var state := "idle"
var frame := 0
var phase := 0.0
var facing := 1.0
var previous_mode := "idle"
var landing_left := 0.0
var push_last_position := Vector2.ZERO
var far_arm: CoreHybridArm
var near_arm: CoreHybridArm
var deform_frame_data: Dictionary = {}
var harry_channels: Dictionary = {}
var _harry_pose_key := 0
var _harry_pose: Dictionary = {}
var down_aim_blend := 0.0

func down_aim_wanted() -> bool:
	if not player.uses_painted_cels() or not state in ["idle","crouch"]: return false
	if player.crouching and player.weapon.requires_standing_for_down_aim(): return false
	if player.weapon.reloading or player.climbing or player.pushing or player.slide_left > 0 or player.dash_left > 0: return false
	if player.grenades and player.grenades.busy(): return false
	return player.weapon.aim_direction.y > (.78 if down_aim_blend > 0 else .86)

func uses_down_aim_pose() -> bool:
	if player.crouching and player.weapon.requires_standing_for_down_aim(): return false
	return player.uses_painted_cels() and state in ["idle","crouch"] and down_aim_blend > 0

func _ready() -> void:
	if not player: player = get_parent() as CoreMovementPlayer
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.offset = Vector2(-192,-320)
	sprite.scale = Vector2.ONE*.25
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	far_arm = CoreHybridArm.new()
	near_arm = CoreHybridArm.new()
	if not player.character_id.is_empty():
		var skin := preload("res://scripts/campaign/player_skin.gd").new()
		skin.player = player
		add_child(skin)
		far_arm.character_id = player.character_id
		near_arm.character_id = player.character_id
	reset_visual()

func reset_visual() -> void:
	down_aim_blend = 0
	phase = 0
	previous_mode = "idle"
	landing_left = 0
	state = "idle"
	frame = 0
	facing = 1
	_update_deform_pose(0,true)
	_show_frame()
	update_arms()

func advance(delta: float) -> void:
	facing = player.weapon.look_facing()
	if player.weapon.reloading: facing = player.weapon.reload_facing
	if player.sprint_pose_active():
		facing = signf(player.velocity.x) if absf(player.velocity.x) > 5 else signf(player.movement_axis)
	if player.sprint_dash_pose_active(): facing = player.dash_direction
	if player.mode == "slide": facing = player.slide_direction
	if player.grenades and player.grenades.busy(): facing = player.weapon.look_facing()
	if player.climbing: facing = 1
	if player.pushing: facing = player.push_direction
	landing_left = maxf(0,landing_left-delta)
	if previous_mode in ["jump","fall"] and player.mode in ["idle","walk","run","sprint"]:
		landing_left = .075
	if player.barrel_knockdown_left > 0 or player.mode == "knocked_down":
		state = "slide"
		facing = player.facing
		frame = 3
	elif player.mode == "climb":
		state = "climb"
		# World distance drives the cycle; stopping and reversing keep the pose.
		phase = fposmod(-(player.global_position.y-player.ladder.position.y-12)/48,1)
		frame = posmod(floori(phase*8),8)
	elif player.mode == "push":
		state = "pull" if player.movement_axis*player.push_direction < 0 else "push"
		if previous_mode != "push":
			phase = 0
			push_last_position = player.global_position
		# Slow weight shifts remain readable when a heavy box hardly moves.
		# Sliding collisions can report zero commanded velocity even while the
		# moving rigid body carries the character; measure actual displacement.
		var travel := absf(player.global_position.x-push_last_position.x)
		var effort := delta*.35 if player.movement_axis != 0 else 0.0
		if player.movement_axis != 0:
			phase = fposmod(phase+(effort+travel/110)*player.tuning.push_animation_rate,1)
		push_last_position = player.global_position
		frame = floori(phase*8) if player.movement_axis != 0 else 0
		if is_instance_valid(player.push_target) and player.push_target.has_method("grab_pose"):
			state = player.push_target.grab_pose()
			if state == "barrel_tip": frame = clampi(floori(player.push_target.tip_progress()*8),0,7)
	elif player.mode == "dash":
		state = "dash_back" if player.dash_direction*facing < 0 else "dash"
		frame = clampi(floori((1-player.dash_left/player.tuning.dash_duration)*8),0,7)
	elif player.mode == "slide":
		state = "slide"
		frame = clampi(floori((1-player.slide_left/player.slide_duration_active)*8),0,7)
	elif player.mode in ["jump","fall"]:
		state = "jump"
		if player.velocity.y < 0:
			frame = clampi(floori((1+player.velocity.y/player.tuning.jump_speed)*4),0,3)
		else:
			frame = 4+clampi(floori(player.velocity.y/player.tuning.jump_speed*3),0,2)
	elif player.mode in ["crouch","crouch_walk"]:
		state = player.mode
		if state == "crouch_walk":
			var travel := player.velocity.length()*signf(player.velocity.x)*facing
			phase = fposmod(phase+travel*delta/64.0,1)
			frame = floori(phase*8)
		else: frame = 0
	elif landing_left > 0:
		state = "jump"
		frame = 7
	elif player.mode in ["walk","run","sprint"]:
		state = player.mode
		var travel := player.velocity.length()*signf(player.velocity.x)*facing
		var stride := (200.0 if state == "sprint" else 80.0 if state == "walk" else 160.0) if player.uses_painted_cels() else (128.0 if state == "sprint" else 64.0 if state == "walk" else RUN_STRIDE)
		phase = fposmod(phase+travel*delta/stride,1)
		frame = floori(phase*8)
	else:
		state = "idle"
		frame = 0
	previous_mode = player.mode
	down_aim_blend = move_toward(down_aim_blend,1.0 if down_aim_wanted() else 0.0,delta/.16)
	_update_deform_pose(delta)
	_show_frame()
	update_arms()

func _show_frame() -> void:
	sprite.visible = player.character_id.is_empty()
	var ads_stage := head_aim_stage()
	sprite.texture = ADS_TEXTURES[state] if ads_stage > 0 else TEXTURES[state]
	sprite.hframes = 1 if state in ["idle","crouch"] else 8
	sprite.vframes = ADS_STAGES if ads_stage > 0 else 1
	sprite.scale.y = .25*_pose_height_scale()
	sprite.frame_coords = Vector2i(frame,ads_stage)
	scale.x = facing

func head_aim_stage() -> int:
	if not player.weapon or not ADS_TEXTURES.has(state): return 0
	var blend := smoothstep(0,1,player.weapon.ads_blend)
	if player.weapon.reloading:
		var progress := player.weapon.reload_progress()
		blend = maxf(blend,smoothstep(.03,.20,progress)*(1-smoothstep(.85,1,progress)))
	return roundi(blend*(ADS_STAGES-1))

func _pose_height_scale() -> float:
	return player.collision_height()/(32.0 if state == "slide" else 42.0 if state in ["crouch","crouch_walk"] else CoreMovementPlayer.HEIGHT)

func _blend_data(a: Variant,b: Variant,amount: float) -> Variant:
	if a is Vector2: return (a as Vector2).lerp(b,amount)
	if a is Dictionary:
		var result := {}
		for key in a: result[key] = _blend_data(a[key],b[key],amount)
		return result
	if a is Array:
		var result: Array = []
		for index in a.size(): result.append(_blend_data(a[index],b[index],amount))
		return result
	return lerpf(float(a),float(b),amount)

func _update_deform_pose(delta: float,snap := false) -> void:
	if not player.uses_deformed_skin():
		deform_frame_data.clear()
		return
	var target: Dictionary = HARRY_MOTION.channels(state,phase,frame)
	var duration := player.visuals.settings.deform_pose_smoothing
	if snap or harry_channels.is_empty() or duration <= 0: harry_channels = target.duplicate(true)
	else: harry_channels = _blend_data(harry_channels,target,1-exp(-delta/duration))
	deform_frame_data.clear()

func harry_pose(standing := false) -> Dictionary:
	if standing: return HARRY.pose({},facing)
	var key := hash([harry_channels,facing])
	if key != _harry_pose_key or _harry_pose.is_empty():
		_harry_pose_key = key
		_harry_pose = HARRY.pose(harry_channels,facing)
	return _harry_pose

func shoulder(side: String) -> Vector2:
	if player.uses_painted_cels(): return preload("res://scripts/campaign/sofia_drawn_data.gd").shoulder(player,side)
	if player.uses_deformed_skin(): return harry_pose().joints[("left" if side == "far" else "right")+"_shoulder"]
	var values: Array = (deform_frame_data if not deform_frame_data.is_empty() and player.uses_deformed_skin() else POSES.DATA[state][frame])[side]
	var point := Vector2(float(values[0]),float(values[1]))
	if player.uses_deformed_skin(): point += Vector2(-2,0) if side == "near" else Vector2(-2,1)
	return point*Vector2(facing,_pose_height_scale())

func eye_anchor() -> Vector2:
	if player.uses_deformed_skin(): return harry_pose().parts.head.position+Vector2(3*facing,-1)
	# The painted eye starts at (+2,-11) relative to the near shoulder.
	# Match the bake's neck pivot, translation and rotation for each head stage.
	var blend := float(head_aim_stage())/(ADS_STAGES-1)
	var eye := Vector2(-1,-4)+(Vector2(3,-7)+Vector2(2,4)*blend).rotated(blend*PI/15)
	return shoulder("near")+Vector2(eye.x*facing,eye.y*_pose_height_scale())

func ads_anchor() -> Vector2:
	# Eleven pixels of stock end at the shoulder for horizontal aiming.
	return shoulder("near")+Vector2(facing*11,0)

func update_arms() -> void:
	if not near_arm: return
	for arm in [far_arm,near_arm]:
		arm.upper_length = 10.8 if player.uses_painted_cels() else 14.5 if not player.character_id.is_empty() else 0.0
		arm.lower_length = 10.2 if player.uses_painted_cels() else 13.5 if not player.character_id.is_empty() else 0.0
		if player.uses_deformed_skin():
			arm.upper_length = HARRY.UPPER_ARM
			arm.lower_length = HARRY.FOREARM
		# At most 112 degrees of flexion: the elbow never folds back on itself.
		arm.minimum_reach = 11.75 if uses_down_aim_pose() else 0.0
	if far_arm.get_parent() == player.visuals: player.visuals.arrange_layers()
	if player.grenades and player.grenades.busy():
		far_arm.pose(shoulder("far"),player.grenades.hand_point("far"),facing,true)
		near_arm.pose(shoulder("near"),player.grenades.hand_point("near"),facing,false)
	elif state in ["push","pull","barrel_tip","barrel_roll"]:
		far_arm.pose(shoulder("far"),player.push_hand_point("far")-player.global_position,facing,true)
		near_arm.pose(shoulder("near"),player.push_hand_point("near")-player.global_position,facing,false)
	elif state == "climb":
		for side in ["far","near"]:
			var arm := far_arm if side == "far" else near_arm
			var desired_height := 33.0 if side == "far" else 45.0
			if (player.uses_painted_cels() and not player.ladder_side_view) or player.uses_deformed_skin():
				desired_height = -shoulder(side).y+(-12 if side == "far" else 12)
			var rungs_start := player.ladder.position.y+12
			var cell := (player.global_position.y-desired_height-rungs_start)/24
			var fraction := fposmod(cell,1)
			var rung := rungs_start+floorf(cell)*24
			# Move one hand to the next rung while the other supports the body.
			rung -= (1-smoothstep(0,.30,fraction))*24
			var last_rung := rungs_start+floorf((player.ladder.end.y-1-rungs_start)/24)*24
			rung = clampf(rung,rungs_start-72,last_rung)
			var hand := Vector2(-14 if side == "far" else 14,rung-player.global_position.y)
			if player.ladder_side_view: hand.x = 14
			if (player.uses_painted_cels() and not player.ladder_side_view) or player.uses_deformed_skin():
				# Choose a reachable rung before IK. Clamping the arm alone leaves
				# its painted glove floating between the character and the ladder.
				var socket := shoulder(side)
				var reach_y := sqrt(maxf(0,pow(arm.upper_length+arm.lower_length-.05,2)-pow(hand.x-socket.x,2)))
				var low := rungs_start+ceilf((player.global_position.y+socket.y-reach_y-rungs_start)/24)*24
				var high := rungs_start+floorf((player.global_position.y+socket.y+reach_y-rungs_start)/24)*24
				hand.y = clampf(rung,low,high)-player.global_position.y
			arm.pose(shoulder(side),hand,-1 if side == "far" else 1,side == "far")
	else:
		var gun_pose := player.weapon.visual_pose()
		var far_shoulder := shoulder("far")
		var near_shoulder := shoulder("near")
		var far_bend := facing
		var near_bend := facing
		if uses_down_aim_pose():
			# Separate shoulder sockets and outward elbows in the three-quarter view.
			far_bend = -facing
			near_bend = facing
		far_arm.pose(far_shoulder,gun_pose.front_grip,far_bend,true)
		near_arm.pose(near_shoulder,gun_pose.rear_grip,near_bend,false)

func weapon_mount_points() -> Array:
	if player.uses_deformed_skin():
		var pose := harry_pose()
		return [pose.parts.head.position,pose.joints.neck,pose.joints.waist]
	# The mount needs three torso anchors, not thirteen ragdoll parts and all joints.
	if player.uses_painted_cels():
		var drawn = preload("res://scripts/campaign/sofia_drawn_data.gd")
		var pose: Dictionary = drawn._baseline_readonly(drawn.selection(player))
		var mirror := Vector2(facing,1)
		return [pose.parts.head.position*mirror,pose.joints.neck*mirror,pose.joints.waist*mirror]
	var data: Dictionary = deform_frame_data if not deform_frame_data.is_empty() and player.uses_deformed_skin() else POSES.DATA[state][frame]
	var skeleton: Dictionary = data.skeleton
	var mirror := Vector2(facing,_pose_height_scale())
	var neck := Vector2(skeleton.neck[0],skeleton.neck[1])
	var head := Vector2(skeleton.head[0],skeleton.head[1])
	var blend := float(head_aim_stage())/(ADS_STAGES-1)
	head = neck+(head-neck).rotated(blend*PI/15)+Vector2(2,4)*blend
	return [head*mirror,neck*mirror,Vector2(data.hip[0],data.hip[1])*mirror]

func ragdoll_pose(standing := false) -> Dictionary:
	if player.uses_deformed_skin(): return HARRY.capture(self,standing)
	if player.uses_painted_cels(): return preload("res://scripts/campaign/sofia_drawn_data.gd").capture(player,standing)
	# Use the exact baked frame and articulated arms at the instant of impact.
	# A sprint, crouch or airborne hit must not reset the body to a T-pose.
	var data: Dictionary = POSES.DATA.idle[0] if standing else deform_frame_data if not deform_frame_data.is_empty() and player.uses_deformed_skin() else POSES.DATA[state][frame]
	var skeleton: Dictionary = data.skeleton
	var y_scale := 1.0 if standing else _pose_height_scale()
	var mirror := Vector2(facing,y_scale)
	var hip := Vector2(data.hip[0],data.hip[1])*mirror
	var neck := Vector2(skeleton.neck[0],skeleton.neck[1])
	var head := Vector2(skeleton.head[0],skeleton.head[1])
	var blend := 0.0 if standing else float(head_aim_stage())/(ADS_STAGES-1)
	head = neck+(head-neck).rotated(blend*PI/15)+Vector2(2,4)*blend
	head *= mirror
	neck *= mirror
	var parts := {
		"pelvis":{"position":hip,"rotation":0.0,"dimensions":Vector2(13,5*y_scale)},
		"head":{"position":head,"rotation":blend*PI/15*facing,"dimensions":Vector2(12,14*y_scale)}
	}
	var joints := {"neck":neck,"waist":hip}
	_pose_segment(parts,"torso",neck,hip,13)
	for entry in [["left",far_arm],["right",near_arm]]:
		var side: String = entry[0]
		var arm: CoreHybridArm = entry[1]
		var shoulder_point := Vector2(data["far" if side == "left" else "near"][0],data["far" if side == "left" else "near"][1])*mirror if standing else arm.shoulder
		if standing and player.uses_deformed_skin(): shoulder_point += (Vector2(-2,1) if side == "left" else Vector2(-2,0))*mirror
		var elbow_point := shoulder_point+Vector2(-3,15)*mirror if standing else arm.elbow
		var hand_point := shoulder_point+Vector2(15,10)*mirror if standing else arm.hand
		_pose_segment(parts,side+"_upper_arm",shoulder_point,elbow_point,6.8)
		_pose_segment(parts,side+"_forearm",elbow_point,hand_point,5.2)
		joints[side+"_shoulder"] = shoulder_point
		joints[side+"_elbow"] = elbow_point
		var leg: Dictionary = skeleton.legs["far" if side == "left" else "near"]
		var h := Vector2(leg.hip[0],leg.hip[1])*mirror
		var knee := Vector2(leg.knee[0],leg.knee[1])*mirror
		var ankle := Vector2(leg.ankle[0],leg.ankle[1])*mirror
		var foot := Vector2(leg.foot[0],leg.foot[1])*mirror
		_pose_segment(parts,side+"_thigh",h,knee,8)
		_pose_segment(parts,side+"_shin",knee,ankle,6)
		parts[side+"_foot"] = {"position":foot+Vector2(facing*1.5,-2*y_scale),"rotation":0.0,"dimensions":Vector2(9,4*y_scale)}
		joints[side+"_hip"] = h
		joints[side+"_knee"] = knee
		joints[side+"_ankle"] = ankle
	var painted_head := 0 if standing else 1 if player.weapon.ads_blend > .55 else 2 if player.weapon.aim_direction.y < -.55 else 0
	return {"parts":parts,"joints":joints,"facing":facing,"pelvis_offset":-hip.y,"painted_head_stage":painted_head}

func _pose_segment(parts: Dictionary,key: String,a: Vector2,b: Vector2,width: float) -> void:
	parts[key] = {"position":(a+b)*.5,"rotation":Vector2.DOWN.angle_to(b-a),"dimensions":Vector2(width,maxf(2,a.distance_to(b)))}

