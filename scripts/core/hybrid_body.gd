class_name CoreHybridBody
extends Node2D
## Whole-body baked pictures; the arms attach to each picture's shoulders.
const POSES = preload("res://resources/core/hybrid/poses.gd")
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
	"slide":preload("res://resources/core/hybrid/slide.png")
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
var far_arm: CoreHybridArm
var near_arm: CoreHybridArm

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
	reset_visual()

func reset_visual() -> void:
	phase = 0
	previous_mode = "idle"
	landing_left = 0
	state = "idle"
	frame = 0
	facing = 1
	_show_frame()
	update_arms()

func advance(delta: float) -> void:
	facing = player.weapon.look_facing()
	if player.sprint_pose_active():
		facing = signf(player.velocity.x) if absf(player.velocity.x) > 5 else signf(player.movement_axis)
	if player.sprint_dash_pose_active(): facing = player.dash_direction
	if player.mode == "slide": facing = player.slide_direction
	if player.climbing: facing = 1
	landing_left = maxf(0,landing_left-delta)
	if previous_mode in ["jump","fall"] and player.mode in ["idle","walk","run","sprint"]:
		landing_left = .075
	if player.mode == "climb":
		state = "climb"
		# World distance drives the cycle; stopping and reversing keep the pose.
		phase = fposmod(-(player.global_position.y-player.ladder.position.y-12)/48,1)
		frame = posmod(floori(phase*8),8)
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
		phase = fposmod(phase+travel*delta/(128.0 if state == "sprint" else 64.0 if state == "walk" else RUN_STRIDE),1)
		frame = floori(phase*8)
	else:
		state = "idle"
		frame = 0
	previous_mode = player.mode
	_show_frame()
	update_arms()

func _show_frame() -> void:
	var ads_stage := head_aim_stage()
	sprite.texture = ADS_TEXTURES[state] if ads_stage > 0 else TEXTURES[state]
	sprite.hframes = 1 if state in ["idle","crouch"] else 8
	sprite.vframes = ADS_STAGES if ads_stage > 0 else 1
	sprite.scale.y = .25*_pose_height_scale()
	sprite.frame_coords = Vector2i(frame,ads_stage)
	scale.x = facing

func head_aim_stage() -> int:
	if not player.weapon or not ADS_TEXTURES.has(state): return 0
	return roundi(smoothstep(0,1,player.weapon.ads_blend)*(ADS_STAGES-1))

func _pose_height_scale() -> float:
	return player.collision_height()/(32.0 if state == "slide" else 42.0 if state in ["crouch","crouch_walk"] else CoreMovementPlayer.HEIGHT)

func shoulder(side: String) -> Vector2:
	var values: Array = POSES.DATA[state][frame][side]
	return Vector2(float(values[0])*facing,float(values[1])*_pose_height_scale())

func eye_anchor() -> Vector2:
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
	if state == "climb":
		for side in ["far","near"]:
			var arm := far_arm if side == "far" else near_arm
			var desired_height := 33.0 if side == "far" else 45.0
			var rungs_start := player.ladder.position.y+12
			var cell := (player.global_position.y-desired_height-rungs_start)/24
			var fraction := fposmod(cell,1)
			var rung := rungs_start+floorf(cell)*24
			# Move one hand to the next rung while the other supports the body.
			rung -= (1-smoothstep(0,.30,fraction))*24
			var last_rung := rungs_start+floorf((player.ladder.end.y-1-rungs_start)/24)*24
			rung = clampf(rung,rungs_start-72,last_rung)
			var hand := Vector2(-14 if side == "far" else 14,rung-player.global_position.y)
			arm.pose(shoulder(side),hand,-1 if side == "far" else 1,side == "far")
	else:
		var gun_pose := player.weapon.visual_pose()
		far_arm.pose(shoulder("far"),gun_pose.front_grip,facing,true)
		near_arm.pose(shoulder("near"),gun_pose.rear_grip,facing,false)

