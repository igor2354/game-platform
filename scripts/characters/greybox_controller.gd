class_name GreyboxController
extends CharacterBody2D
# Minimal controller for the greybox rig: walk, run, roll and ladders.
# Intent fields come from the keyboard unless `scripted` is set (tests).

const WALK := 180.0
const RUN := 420.0
const ROLL_SPEED := 460.0
const CLIMB_SPEED := 128.0
const GRAVITY := 2600.0
const STAND_HEIGHT := 210.0
const ROLL_HEIGHT := 96.0
const RADIUS := 24.0
# Invulnerability window inside the roll, seconds from its start.
const IFRAME_START := 0.05
const IFRAME_END := 0.35
# The body stands this far from the ladder's centre line, facing it.
const LADDER_OFFSET := 18.0

var rig: HumanoidRig
var ladders: Array[Rect2] = []
var scripted := false
var move_x := 0.0
var running := false
var roll_pressed := false
var climb_axis := 0.0
var preview := ""
var facing := 1.0
var rolling := 0.0
var climbing := false
var ladder := Rect2()
var capsule: CapsuleShape2D
var shape: CollisionShape2D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 10
	capsule = CapsuleShape2D.new()
	capsule.radius = RADIUS
	shape = CollisionShape2D.new()
	shape.shape = capsule
	add_child(shape)
	_set_height(STAND_HEIGHT)
	rig = load("res://scenes/characters/humanoid_greybox.tscn").instantiate()
	add_child(rig)

func invulnerable() -> bool:
	var elapsed := HumanoidRig.ROLL_TIME-rolling
	return rolling > 0 and elapsed >= IFRAME_START and elapsed <= IFRAME_END

func _unhandled_key_input(event: InputEvent) -> void:
	if not scripted and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		roll_pressed = true

func _physics_process(delta: float) -> void:
	if preview != "":
		_preview(delta)
		return
	if not scripted:
		move_x = float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A))
		running = Input.is_physical_key_pressed(KEY_SHIFT)
		climb_axis = float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))
	if climbing: _climb()
	elif rolling > 0: _roll(delta)
	else: _ground(delta)
	roll_pressed = false
	var anim := "idle"
	if climbing: anim = "climb"
	elif rolling > 0: anim = "roll"
	elif absf(velocity.x) > 300: anim = "run"
	elif absf(velocity.x) > 10: anim = "walk"
	rig.face(facing)
	if anim != "roll" or rig.state != "roll": rig.drive(anim,velocity)
	rig.modulate = Color(1.45,1.0,0.7) if invulnerable() else Color.WHITE

func _ground(delta: float) -> void:
	velocity.x = move_toward(velocity.x,move_x*(RUN if running else WALK),2400*delta)
	velocity.y = minf(velocity.y+GRAVITY*delta,1600)
	if move_x != 0: facing = signf(move_x)
	var near := _ladder_here()
	if near.has_area() and climb_axis != 0:
		var at_top := global_position.y <= near.position.y+4
		# Up from anywhere below the top; down only from the top landing.
		if (climb_axis < 0 and not at_top) or (climb_axis > 0 and at_top):
			_start_climb(near)
			return
	if roll_pressed and is_on_floor():
		_start_roll()
		return
	move_and_slide()

func _start_roll() -> void:
	rolling = HumanoidRig.ROLL_TIME
	_set_height(ROLL_HEIGHT)
	rig.drive("roll",velocity)

func _roll(delta: float) -> void:
	var progress := 1.0-rolling/HumanoidRig.ROLL_TIME
	# Full speed through the tumble, then ease off into the stand-up.
	velocity.x = facing*ROLL_SPEED*(1.0 if progress < 0.75 else lerpf(1.0,0.35,(progress-0.75)/0.25))
	velocity.y = minf(velocity.y+GRAVITY*delta,1600)
	move_and_slide()
	rolling -= delta
	if rolling > 0: return
	if _can_stand():
		rolling = 0
		_set_height(STAND_HEIGHT)
	else:
		# Still under a low ceiling: keep rolling instead of standing into it.
		rolling = HumanoidRig.ROLL_TIME
		rig.restart("roll")

func _start_climb(near: Rect2) -> void:
	climbing = true
	ladder = near
	velocity = Vector2.ZERO
	facing = 1.0 if global_position.x <= near.get_center().x else -1.0
	set_collision_mask_value(1,false)

func _climb() -> void:
	var target_x := ladder.get_center().x-facing*LADDER_OFFSET
	global_position.x = move_toward(global_position.x,target_x,6)
	velocity = Vector2(0,climb_axis*CLIMB_SPEED)
	move_and_slide()
	if climb_axis < 0 and global_position.y <= ladder.position.y:
		_end_climb(ladder.position.y)
	elif climb_axis > 0 and global_position.y >= ladder.end.y:
		_end_climb(ladder.end.y)

func _end_climb(feet_y: float) -> void:
	global_position.y = feet_y
	velocity = Vector2.ZERO
	climbing = false
	set_collision_mask_value(1,true)

func _ladder_here() -> Rect2:
	for rect in ladders:
		if absf(global_position.x-rect.get_center().x) < 34 and global_position.y >= rect.position.y-6 and global_position.y <= rect.end.y+6:
			return rect
	return Rect2()

func _set_height(height: float) -> void:
	capsule.height = height
	shape.position.y = -height*0.5

func _can_stand() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var standing := CapsuleShape2D.new()
	standing.radius = RADIUS-2
	standing.height = STAND_HEIGHT-4
	query.shape = standing
	query.transform = Transform2D(0,global_position+Vector2(0,-STAND_HEIGHT*0.5-2))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

# Play one animation in place at its authored speed, for checking poses.
func _preview(delta: float) -> void:
	velocity = Vector2.ZERO
	var design := {"walk":Vector2(HumanoidRig.WALK_SPEED,0),"run":Vector2(HumanoidRig.RUN_SPEED,0),"climb":Vector2(0,-HumanoidRig.CLIMB_CYCLE)}
	if preview == "roll":
		rolling -= delta
		if rig.state != "roll" or rolling <= -0.4:
			rolling = HumanoidRig.ROLL_TIME
			rig.restart("roll")
		return
	rig.drive(preview,design.get(preview,Vector2.ZERO))
