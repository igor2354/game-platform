class_name CoreHybridBody
extends Node2D
## Whole-body baked pictures; the arms attach to each picture's shoulders.
const POSES = preload("res://resources/core/hybrid/poses.gd")
const TEXTURES = {
	"idle":preload("res://resources/core/hybrid/idle.png"),
	"run":preload("res://resources/core/hybrid/run.png"),
	"jump":preload("res://resources/core/hybrid/jump.png"),
	"dash":preload("res://resources/core/hybrid/dash.png"),
	"climb":preload("res://resources/core/hybrid/climb.png")
}
const RUN_STRIDE := 96.0
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
	player = get_parent() as CoreMovementPlayer
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.offset = Vector2(-192,-320)
	sprite.scale = Vector2.ONE*.25
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	far_arm = CoreHybridArm.new()
	far_arm.z_index = -1
	near_arm = CoreHybridArm.new()
	near_arm.z_index = 6
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
	facing = player.dash_direction if player.mode == "dash" else player.weapon.look_facing()
	if player.climbing: facing = 1
	landing_left = maxf(0,landing_left-delta)
	if previous_mode in ["jump","fall"] and player.mode in ["idle","run"]:
		landing_left = .075
	if player.mode == "climb":
		state = "climb"
		# World distance drives the cycle; stopping and reversing keep the pose.
		phase = fposmod(-(player.global_position.y-player.ladder.position.y-12)/48,1)
		frame = posmod(floori(phase*8),8)
	elif player.mode == "dash":
		state = "dash"
		frame = clampi(floori((1-player.dash_left/player.tuning.dash_duration)*8),0,7)
	elif player.mode in ["jump","fall"]:
		state = "jump"
		if player.velocity.y < 0:
			frame = clampi(floori((1+player.velocity.y/player.tuning.jump_speed)*4),0,3)
		else:
			frame = 4+clampi(floori(player.velocity.y/player.tuning.jump_speed*3),0,2)
	elif landing_left > 0:
		state = "jump"
		frame = 7
	elif player.mode == "run":
		state = "run"
		var travel := player.velocity.length()*signf(player.velocity.x)*facing
		phase = fposmod(phase+travel*delta/RUN_STRIDE,1)
		frame = floori(phase*8)
	else:
		state = "idle"
		frame = 0
	previous_mode = player.mode
	_show_frame()
	update_arms()

func _show_frame() -> void:
	sprite.texture = TEXTURES[state]
	sprite.hframes = 1 if state == "idle" else 8
	sprite.frame = frame
	scale.x = facing

func shoulder(side: String) -> Vector2:
	var values: Array = POSES.DATA[state][frame][side]
	return Vector2(float(values[0])*facing,float(values[1]))

func eye_anchor() -> Vector2:
	return shoulder("near")+Vector2(facing*3,-11)

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

