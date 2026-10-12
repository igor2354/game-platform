class_name CoreMovementPlayer
extends CharacterBody2D

signal fell
const HEIGHT := 64.0
const RADIUS := 14.0
const WORLD_MASK := 1 | 4 | 8
const ENEMY_MASK := 4
@export var tuning: CoreMovementSettings
var ladders: Array[Rect2] = []
var facing := 1.0
var mode := "idle"
var climbing := false
var ladder := Rect2()
var ladder_lock := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var dash_left := 0.0
var dash_cooldown := 0.0
var dash_direction := 1.0
var air_dash_used := false
var jumps := 0
var dashes := 0
var last_dash_distance := 0.0
var dash_origin := Vector2.ZERO
var debug_shape := false
var input_blocker: Callable
var ground_speed := 0.0
var weapon: CoreShootingController
var dash_held := false
var body: CoreHybridBody
var movement_shape: CollisionShape2D
var dash_overlap_exceptions: Array[PhysicsBody2D] = []

func _ready() -> void:
	if tuning == null: tuning = CoreMovementSettings.new()
	collision_layer = 2
	collision_mask = WORLD_MASK
	floor_snap_length = 24
	# Tangential velocity already sets surface speed; don't project it twice.
	floor_constant_speed = false
	floor_stop_on_slope = true
	var capsule := CapsuleShape2D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	var shape := CollisionShape2D.new()
	shape.shape = capsule
	shape.position.y = -HEIGHT/2
	movement_shape = shape
	add_child(shape)
	weapon = CoreShootingController.new()
	add_child(weapon)
	body = CoreHybridBody.new()
	add_child(body)
	add_child(body.far_arm)
	add_child(body.near_arm)

func reset_to(point: Vector2) -> void:
	_clear_dash_exceptions()
	global_position = point
	velocity = Vector2.ZERO
	ground_speed = 0
	collision_mask = WORLD_MASK
	climbing = false
	ladder = Rect2()
	ladder_lock = 0
	coyote = 0
	jump_buffer = 0
	dash_left = 0
	dash_cooldown = 0
	air_dash_used = false
	last_dash_distance = 0
	facing = 1
	mode = "idle"
	jumps = 0
	dashes = 0
	dash_held = Input.is_action_pressed("core_dash")
	if weapon: weapon.reset_state()
	if body: body.reset_visual()
	queue_redraw()

func dash_available() -> bool:
	return not climbing and dash_left <= 0 and dash_cooldown <= 0 and (is_on_floor() or not air_dash_used)

func _physics_process(delta: float) -> void:
	_refresh_dash_exceptions()
	var input_allowed := not input_blocker.is_valid() or not bool(input_blocker.call())
	var axis := Input.get_axis("core_left","core_right") if input_allowed else 0.0
	var vertical := Input.get_axis("core_up","core_down") if input_allowed else 0.0
	var jump_held := input_allowed and Input.is_action_pressed("core_jump")
	var dash_pressed := Input.is_action_pressed("core_dash")
	var dash_requested := input_allowed and dash_pressed and not dash_held
	dash_held = dash_pressed
	weapon.update_state(delta,input_allowed)
	ladder_lock = maxf(0,ladder_lock-delta)
	dash_cooldown = maxf(0,dash_cooldown-delta)
	coyote = maxf(0,coyote-delta)
	jump_buffer = maxf(0,jump_buffer-delta)
	if not input_allowed: jump_buffer = 0
	if is_on_floor() and not climbing and dash_left <= 0:
		coyote = tuning.coyote_time
		air_dash_used = false
	if input_allowed and Input.is_action_just_pressed("core_jump"): jump_buffer = maxf(tuning.jump_buffer_time,delta)
	if axis != 0 and dash_left <= 0: facing = signf(axis)
	if dash_left > 0:
		_tick_dash(delta)
	elif climbing:
		_tick_climb(axis,vertical,delta)
	else:
		var nearby := ladder_here(vertical)
		if absf(vertical) > 0 and nearby.has_area() and ladder_lock <= 0 and jump_buffer <= 0:
			_enter_ladder(nearby)
			_tick_climb(axis,vertical,delta)
		elif dash_requested and dash_available():
			_start_dash(axis)
			_tick_dash(delta)
		else:
			_tick_run(axis,delta,jump_held)
	if global_position.y > 1120: fell.emit()
	_update_mode()
	body.advance(delta)
	# Choose this tick's body anchors before computing the muzzle and firing.
	weapon.finish_tick()
	body.update_arms()
	queue_redraw()

func _tick_run(axis: float,delta: float,jump_held: bool) -> void:
	var grounded := is_on_floor()
	var rate := tuning.acceleration if axis != 0 else tuning.braking
	var run_speed := tuning.run_speed*weapon.movement_multiplier
	if grounded:
		var tangent := Vector2(-get_floor_normal().y,get_floor_normal().x)
		run_speed *= slope_speed_multiplier(axis)
		# Godot adjusts velocity after sliding. Keep acceleration along the floor
		# separately so that this adjustment does not slow every following frame.
		ground_speed = move_toward(ground_speed,axis*run_speed,rate*delta)
		velocity = tangent*ground_speed
	else:
		rate = tuning.air_acceleration
		velocity.x = move_toward(velocity.x,axis*run_speed,rate*delta)
		velocity.y = minf(velocity.y+tuning.gravity*delta,tuning.fall_speed)
		ground_speed = velocity.x
	if jump_buffer > 0 and (is_on_floor() or coyote > 0):
		velocity.y = -tuning.jump_speed
		jump_buffer = 0
		coyote = 0
		jumps += 1
		grounded = false
	# Holding Space gives a full jump; releasing it early gives a short jump.
	if not grounded and not jump_held and velocity.y < -tuning.jump_cut_speed:
		velocity.y = -tuning.jump_cut_speed
	move_and_slide()
	# Explicit snap follows downhill and convex crests; jumping never snaps back.
	if grounded: apply_floor_snap()

func slope_speed_multiplier(axis: float) -> float:
	if not is_on_floor() or is_zero_approx(axis): return 1.0
	var tangent := Vector2(-get_floor_normal().y,get_floor_normal().x)
	# Y points down: a negative signed rise means moving uphill. Use input
	# rather than facing, which can be changed independently by aiming.
	return tuning.slope_multiplier(rad_to_deg(get_floor_angle()),tangent.y*axis < 0)

func _start_dash(axis: float) -> void:
	dash_direction = signf(axis) if axis != 0 else facing
	facing = dash_direction
	dash_left = tuning.dash_duration
	dash_cooldown = tuning.dash_cooldown
	air_dash_used = true
	coyote = 0
	dash_origin = global_position
	dashes += 1
	set_collision_mask_value(3,false)

func _tick_dash(delta: float) -> void:
	# Enemy bodies are phased; swept movement still stops at world geometry.
	var active_fraction := minf(delta,dash_left)/delta
	var grounded := is_on_floor()
	var direction := Vector2(-get_floor_normal().y,get_floor_normal().x) if grounded else Vector2.RIGHT
	velocity = direction*dash_direction*tuning.dash_speed*active_fraction
	move_and_slide()
	if grounded: apply_floor_snap()
	dash_left = maxf(0,dash_left-delta)
	last_dash_distance = absf(global_position.x-dash_origin.x)
	if is_on_wall(): dash_left = 0
	if dash_left <= 0:
		_finish_dash_collision()
		ground_speed = dash_direction*tuning.run_speed
		velocity = direction*ground_speed if is_on_floor() else Vector2(ground_speed,0)

func _overlapping_enemies() -> Array[PhysicsBody2D]:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = movement_shape.shape
	query.transform = movement_shape.global_transform
	query.collision_mask = ENEMY_MASK
	query.exclude = [get_rid()]
	query.margin = .05
	var bodies: Array[PhysicsBody2D] = []
	for hit in get_world_2d().direct_space_state.intersect_shape(query,128):
		if hit.collider is PhysicsBody2D and hit.collider not in bodies: bodies.append(hit.collider)
	return bodies

func _finish_dash_collision() -> void:
	# Restore ordinary blocking immediately. Only enemies already intersecting
	# the player remain passable until the player leaves their body naturally.
	set_collision_mask_value(3,true)
	allow_exit_overlapping_enemies()

func allow_exit_overlapping_enemies() -> void:
	# Used after dashes and when a dead enemy is respawned around the player.
	for enemy in _overlapping_enemies():
		if enemy in get_collision_exceptions(): continue
		add_collision_exception_with(enemy)
		dash_overlap_exceptions.append(enemy)

func _refresh_dash_exceptions() -> void:
	if dash_overlap_exceptions.is_empty(): return
	var overlaps := _overlapping_enemies()
	for i in range(dash_overlap_exceptions.size()-1,-1,-1):
		var enemy := dash_overlap_exceptions[i]
		if not is_instance_valid(enemy):
			dash_overlap_exceptions.remove_at(i)
		elif enemy not in overlaps:
			remove_collision_exception_with(enemy)
			dash_overlap_exceptions.remove_at(i)

func _clear_dash_exceptions() -> void:
	for enemy in dash_overlap_exceptions:
		if is_instance_valid(enemy): remove_collision_exception_with(enemy)
	dash_overlap_exceptions.clear()

func ladder_here(vertical: float) -> Rect2:
	for candidate in ladders:
		if absf(global_position.x-candidate.get_center().x) > 28: continue
		if global_position.y < candidate.position.y-6 or global_position.y > candidate.end.y+6: continue
		if vertical < 0 and global_position.y <= candidate.position.y+4: continue
		if vertical > 0 and global_position.y >= candidate.end.y-4: continue
		return candidate
	return Rect2()

func _enter_ladder(candidate: Rect2) -> void:
	climbing = true
	ladder = candidate
	velocity = Vector2.ZERO
	ground_speed = 0
	coyote = 0
	# Only one-way platforms are ignored. Ground, walls and targets stay solid.
	set_collision_mask_value(4,false)

func _leave_ladder() -> void:
	climbing = false
	set_collision_mask_value(4,true)
	ladder_lock = tuning.ladder_regrab_delay

func _tick_climb(axis: float,vertical: float,delta: float) -> void:
	if jump_buffer > 0:
		_leave_ladder()
		velocity = Vector2(axis*tuning.run_speed,-tuning.jump_speed*.85)
		jump_buffer = 0
		jumps += 1
		move_and_slide()
		return
	velocity.x = clampf((ladder.get_center().x-global_position.x)/delta,-tuning.ladder_snap_speed,tuning.ladder_snap_speed)
	velocity.y = vertical*tuning.climb_speed
	move_and_slide()
	if vertical < 0 and global_position.y <= ladder.position.y:
		global_position.y = ladder.position.y
		velocity = Vector2.ZERO
		_leave_ladder()
	elif vertical > 0 and global_position.y >= ladder.end.y-1:
		global_position.y = ladder.end.y
		velocity = Vector2.ZERO
		_leave_ladder()

func _update_mode() -> void:
	if dash_left > 0: mode = "dash"
	elif climbing: mode = "climb"
	elif not is_on_floor(): mode = "jump" if velocity.y < 0 else "fall"
	elif absf(velocity.x) > 5: mode = "run"
	else: mode = "idle"

func _draw() -> void:
	if debug_shape:
		draw_rect(Rect2(-RADIUS,-HEIGHT,RADIUS*2,HEIGHT),Color("f4f4dc"),false,1)
