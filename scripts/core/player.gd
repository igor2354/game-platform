class_name CoreMovementPlayer
extends CharacterBody2D

signal fell
signal noise_emitted(point: Vector2,loudness: float,kind: String)
const MAX_HEALTH := 100.0
var health := MAX_HEALTH
var invulnerable := false
var hurt_left := 0.0
var hurt_flash := 0.0
const HEIGHT := 64.0
const RADIUS := 14.0
const WORLD_MASK := 1 | 4 | 8
const ENEMY_MASK := 4
@export var tuning: CoreMovementSettings
@export var character_id := "" # Empty preserves the original polygon hero.
@export var sofia_cel_variant := false # Selected Sofia uses the same painted skin in both modes.

func uses_deformed_skin() -> bool:
	return character_id == "harry" and is_instance_valid(visuals) and visuals.settings.deform_skin_enabled

func ragdoll_recovery_pose(_prone := false) -> Dictionary:
	return body.ragdoll_pose(true)

func uses_painted_cels() -> bool:
	return sofia_cel_variant and character_id == "sofia" and is_instance_valid(visuals) and visuals.settings.sofia_cels_enabled

func uses_smooth_recovery() -> bool:
	return uses_deformed_skin() or uses_painted_cels()

func constrain_recovery_points(points: Dictionary,_feet: Vector2) -> void:
	if uses_deformed_skin():
		preload("res://scripts/campaign/harry_anatomy.gd").constrain_recovery(points,body.facing)
		return
	if not uses_painted_cels(): return
	for side in ["left","right"]:
		var shoulder: Vector2 = points[side+"_shoulder"]
		var direction: Vector2 = points[side+"_hand"]-shoulder
		var distance := clampf(direction.length(),.61,20.99)
		direction = direction.normalized() if direction.length_squared() > .001 else Vector2(body.facing,0)
		var along := (10.8*10.8-10.2*10.2+distance*distance)/(2*distance)
		var height := sqrt(maxf(0,10.8*10.8-along*along))
		points[side+"_hand"] = shoulder+direction*distance
		points[side+"_elbow"] = shoulder+direction*along+Vector2(-direction.y,direction.x)*height*body.facing
var parkour: RefCounted

func parkour_active() -> bool:
	return parkour != null and parkour.active

var ladders: Array[Rect2] = []
var side_ladders: Array[Rect2] = []
var ladder_side_view := false
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
var dash_from_sprint := false
var air_dash_used := false
var jumps := 0
var dashes := 0
var last_dash_distance := 0.0
var dash_origin := Vector2.ZERO
var debug_shape := false
var input_blocker: Callable
var ground_speed := 0.0
var ground_acceleration := 0.0
var grenades: CoreGrenadeController
var blast_ragdoll: CoreCharacterRagdoll
var weapon: CoreShootingController
var dash_held := false
var visuals: CorePlayerVisuals
var body: CoreHybridBody
var movement_shape: CollisionShape2D
var dash_overlap_exceptions: Array[PhysicsBody2D] = []
var dash_stunned_enemies: Dictionary = {}
var pushing := false
var push_target: RigidBody2D
var push_direction := 1.0
var push_contact_time := 0.0
var grab_held := false
var queued_grab_press := false
var push_anchor_local := Vector2.ZERO
var push_anchor_offset := Vector2.ZERO
var step_noise_distance := 0.0
var ladder_noise_distance := 0.0
var movement_noise_suppressed := 0.0
var shove_left := 0.0
var barrel_knockdown_left := 0.0
var crouching := false
var standing_capsule: CapsuleShape2D
var crouching_capsule: CapsuleShape2D
var sprinting := false
var sprint_requested := false
var walking := false
var walk_requested := false
var movement_axis := 0.0
var air_move_speed := 320.0
# A fraction keeps live duration edits from refilling an already spent reserve.
var sprint_reserve := 1.0
var sprint_exhausted := false
var slide_left := 0.0
var slide_duration_active := .65
var slide_cooldown_left := 0.0
var slide_direction := 1.0
var slide_speed := 0.0
var slides := 0
var slide_hits := 0
var crouch_held := false
var slide_hit_enemies := {}
var slide_rng := RandomNumberGenerator.new()

func _ready() -> void:
	parkour = preload("res://scripts/core/parkour.gd").new(self)
	slide_rng.randomize()
	if tuning == null: tuning = CoreMovementSettings.new()
	air_move_speed = tuning.run_speed
	collision_layer = 2
	collision_mask = WORLD_MASK
	floor_snap_length = 24
	# Tangential velocity already sets surface speed; don't project it twice.
	floor_constant_speed = false
	floor_stop_on_slope = true
	var capsule := CapsuleShape2D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	standing_capsule = capsule
	crouching_capsule = CapsuleShape2D.new()
	crouching_capsule.radius = RADIUS
	crouching_capsule.height = tuning.crouch_height
	var shape := CollisionShape2D.new()
	shape.shape = capsule
	shape.position.y = -HEIGHT/2
	movement_shape = shape
	add_child(shape)
	weapon = CoreShootingController.new()
	add_child(weapon)
	visuals = CorePlayerVisuals.new()
	visuals.player = self
	add_child(visuals)
	body = CoreHybridBody.new()
	body.player = self
	visuals.add_child(body)
	visuals.add_child(body.far_arm)
	visuals.add_child(body.near_arm)
	visuals.arrange_layers()
	visuals.update_effect()
	grenades = CoreGrenadeController.new()
	grenades.player = self
	add_child(grenades)
	blast_ragdoll = CoreCharacterRagdoll.new()
	blast_ragdoll.actor = self
	add_child(blast_ragdoll)

func reset_to(point: Vector2) -> void:
	if parkour: parkour.cancel(false)
	collision_layer = 2
	if blast_ragdoll: blast_ragdoll.cancel()
	if grenades: grenades.reset_state()
	stop_pushing()
	grab_held = Input.is_action_pressed("core_grab")
	queued_grab_press = false
	dash_stunned_enemies.clear()
	slide_left = 0
	slide_cooldown_left = 0
	slide_speed = 0
	slides = 0
	slide_hits = 0
	slide_hit_enemies.clear()
	crouch_held = Input.is_action_pressed("core_crouch")
	sprint_reserve = 1
	sprint_exhausted = false
	sprinting = false
	sprint_requested = false
	walking = false
	walk_requested = false
	movement_axis = 0
	air_move_speed = tuning.run_speed
	crouching = false
	if movement_shape:
		movement_shape.shape = standing_capsule
		movement_shape.position.y = -HEIGHT*.5
	_clear_dash_exceptions()
	step_noise_distance = 0
	ladder_noise_distance = 0
	movement_noise_suppressed = .08
	health = maximum_health()
	hurt_left = 0
	hurt_flash = 0
	shove_left = 0
	barrel_knockdown_left = 0
	if body: body.modulate = Color.WHITE
	global_position = point
	velocity = Vector2.ZERO
	ground_acceleration = 0
	ground_speed = 0
	collision_mask = WORLD_MASK
	climbing = false
	ladder = Rect2()
	ladder_side_view = false
	ladder_lock = 0
	coyote = 0
	jump_buffer = 0
	dash_left = 0
	dash_from_sprint = false
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
	return not parkour_active() and not grenades.busy() and tuning.dash_enabled and barrel_knockdown_left <= 0 and not pushing and health > 0 and not climbing and slide_left <= 0 and dash_left <= 0 and dash_cooldown <= 0 and (is_on_floor() or (tuning.air_dash_enabled and not air_dash_used))

func transition_to(point: Vector2) -> void:
	if parkour: parkour.cancel(false)
	stop_pushing()
	_clear_dash_exceptions()
	global_position = point
	velocity = Vector2.ZERO
	ground_acceleration = 0
	ground_speed = 0
	movement_axis = 0
	sprinting = false
	sprint_requested = false
	walking = false
	walk_requested = false
	crouching = false
	crouch_held = Input.is_action_pressed("core_crouch")
	if movement_shape:
		movement_shape.shape = standing_capsule
		movement_shape.position.y = -HEIGHT*.5
	climbing = false
	ladder = Rect2()
	ladder_side_view = false
	ladder_lock = 0
	coyote = 0
	jump_buffer = 0
	dash_left = 0
	dash_from_sprint = false
	dash_held = Input.is_action_pressed("core_dash")
	slide_left = 0
	slide_speed = 0
	collision_layer = 2
	collision_mask = WORLD_MASK
	mode = "idle"
	queue_redraw()

func collision_height() -> float:
	return (movement_shape.shape as CapsuleShape2D).height if movement_shape else HEIGHT

func _fits_height(height: float) -> bool:
	var capsule := CapsuleShape2D.new()
	capsule.radius = RADIUS
	capsule.height = height
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = capsule
	# Ignore the tiny floor-contact overlap retained by CharacterBody2D. Moving
	# the probe up by the skin width keeps the headroom check conservative.
	query.transform = Transform2D(0,global_position-Vector2(0,height*.5+safe_margin+.02))
	# One-way platforms are passable from below. Feet stay in the same place.
	query.collision_mask = collision_mask & ~8
	var excluded: Array[RID] = [get_rid()]
	for exception in get_collision_exceptions(): excluded.append(exception.get_rid())
	query.exclude = excluded
	query.margin = .01
	return get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func _try_stand() -> bool:
	if not crouching: return true
	if not _fits_height(HEIGHT): return false
	crouching = false
	movement_shape.shape = standing_capsule
	movement_shape.position.y = -HEIGHT*.5
	return true

func _update_crouch(requested: bool) -> void:
	if weapon.requires_standing_for_down_aim(): requested = false
	var can_crouch := tuning.crouch_enabled and requested and not climbing and dash_left <= 0 and (is_on_floor() or crouching)
	if not can_crouch and _try_stand(): return
	# A forced crouch under a ceiling also accepts safe live height edits.
	var height := tuning.crouch_height
	if height <= collision_height() or _fits_height(height):
		crouching = true
		crouching_capsule.height = height
		movement_shape.shape = crouching_capsule
		movement_shape.position.y = -height*.5

func maximum_health() -> float:
	return clampf(tuning.max_health,1,1000) if tuning and is_finite(tuning.max_health) else MAX_HEALTH

func apply_health_limit() -> void:
	health = clampf(health,0,maximum_health())

func apply_feature_settings() -> void:
	if not tuning.parkour_enabled and parkour_active(): parkour.cancel()
	if not tuning.push_enabled: stop_pushing()
	if not tuning.dash_enabled and dash_left > 0:
		dash_left = 0
		dash_from_sprint = false
		ground_speed = 0
		velocity.x = 0
		_finish_dash_collision()
	if not tuning.slide_enabled and slide_left > 0: _finish_slide()
	if not tuning.ladder_enabled and climbing: _leave_ladder()
	if not tuning.crouch_enabled and crouching and slide_left <= 0: _try_stand()
	if not tuning.jump_enabled: jump_buffer = 0
	if not tuning.sprint_enabled: sprinting = false
	if not tuning.walk_enabled: walking = false
	if not tuning.health_enabled:
		hurt_left = 0
		hurt_flash = 0

func set_current_health(value: float) -> void:
	if not is_finite(value): return
	if value > 0 and health <= 0 and blast_ragdoll: blast_ragdoll.cancel()
	health = clampf(value,0,maximum_health())
	if health <= 0 and weapon: weapon.cancel_reload()
	hurt_left = 0
	hurt_flash = 0
	jump_buffer = 0
	dash_held = Input.is_action_pressed("core_dash")
	if weapon: weapon.queued_single_press = false
	if body: body.modulate = Color("6c737a") if health <= 0 else Color.WHITE
	queue_redraw()

func set_invulnerable(value: bool) -> void:
	invulnerable = value
	if value:
		hurt_left = 0
		hurt_flash = 0
		if health <= 0: set_current_health(maximum_health())
		elif body: body.modulate = Color.WHITE

func take_damage(amount: float) -> bool:
	if not tuning.health_enabled or invulnerable or health <= 0 or dash_left > 0 or hurt_left > 0 or not is_finite(amount) or amount <= 0: return false
	health = maxf(0,health-amount)
	if health <= 0 and weapon: weapon.cancel_reload()
	hurt_left = .65
	hurt_flash = .16
	return true

func receive_shove(impulse: Vector2) -> bool:
	if health <= 0 or dash_left > 0 or get_tree().paused or not is_finite(impulse.x) or not is_finite(impulse.y): return false
	stop_pushing()
	if parkour_active(): parkour.cancel()
	if climbing: _leave_ladder()
	if slide_left > 0: _finish_slide()
	velocity = impulse
	ground_acceleration = 0
	ground_speed = 0
	coyote = 0
	jump_buffer = 0
	shove_left = .2
	return true

func receive_explosion(amount: float,impulse: Vector2,_stun: float,_origin: Vector2) -> void:
	if amount > 0: take_damage(amount)
	if impulse.length_squared() > 0: receive_shove(impulse+Vector2(0,-absf(impulse.x)*.35))

func receive_barrel_hit(amount: float,impulse: Vector2,duration: float) -> void:
	receive_prop_hit(amount,impulse,duration)

func receive_prop_hit(amount: float,impulse: Vector2,duration: float) -> void:
	if health <= 0 or dash_left > 0 or get_tree().paused: return
	take_damage(amount)
	if duration <= 0: return
	if not receive_shove(impulse): return
	weapon.cancel_reload()
	barrel_knockdown_left = maxf(barrel_knockdown_left,duration)
	facing = signf(impulse.x) if absf(impulse.x) > 1 else facing
	crouching = true
	crouching_capsule.height = 32
	movement_shape.shape = crouching_capsule
	movement_shape.position.y = -16

func _tick_barrel_knockdown(delta: float) -> void:
	barrel_knockdown_left = maxf(0,barrel_knockdown_left-delta)
	shove_left = maxf(0,shove_left-delta)
	weapon.update_state(delta,false)
	velocity.x = move_toward(velocity.x,0,(400 if is_on_floor() else 30)*delta)
	velocity.y = minf(velocity.y+tuning.gravity*delta,tuning.fall_speed)
	move_and_slide()
	if is_on_floor(): apply_floor_snap()
	mode = "knocked_down"
	body.advance(delta)
	if barrel_knockdown_left <= 0: _try_stand()
	if global_position.y > CoreMovementLevel.FALL_LIMIT: fell.emit()

func _physics_process(delta: float) -> void:
	if blast_ragdoll and blast_ragdoll.active:
		mode = "ragdoll"
		blast_ragdoll.tick(delta)
		hurt_left = maxf(0,hurt_left-delta)
		weapon.update_state(delta,false)
		return
	apply_feature_settings()
	parkour.cooldown = maxf(0,parkour.cooldown-delta)
	_refresh_dash_exceptions()
	movement_noise_suppressed = maxf(0,movement_noise_suppressed-delta)
	var previous_position := global_position
	var was_grounded := is_on_floor()
	var previous_fall_speed := velocity.y
	var was_dashing := dash_left > 0
	var was_sliding := slide_left > 0
	hurt_left = maxf(0,hurt_left-delta)
	hurt_flash = maxf(0,hurt_flash-delta)
	body.modulate = Color("6c737a") if health <= 0 else Color("ff8f80") if hurt_flash > 0 else Color.WHITE
	if health <= 0:
		if parkour_active(): parkour.cancel()
		stop_pushing()
		if slide_left > 0: _finish_slide()
		weapon.update_state(delta,false)
		body._show_frame()
		body.update_arms()
		if shove_left > 0: shove_left = maxf(0,shove_left-delta)
		else: velocity.x = 0
		velocity.y = minf(velocity.y+tuning.gravity*delta,tuning.fall_speed)
		move_and_slide()
		if global_position.y > CoreMovementLevel.FALL_LIMIT: fell.emit()
		return
	var input_allowed := not input_blocker.is_valid() or not bool(input_blocker.call())
	if barrel_knockdown_left > 0:
		_tick_barrel_knockdown(delta)
		return
	var axis := Input.get_axis("core_left","core_right") if input_allowed else 0.0
	movement_axis = axis
	walk_requested = tuning.walk_enabled and input_allowed and Input.is_action_pressed("core_walk")
	sprint_requested = tuning.sprint_enabled and input_allowed and Input.is_action_pressed("core_sprint")
	var vertical := Input.get_axis("core_up","core_down") if input_allowed else 0.0
	var jump_held := input_allowed and Input.is_action_pressed("core_jump")
	if parkour_active():
		dash_held = Input.is_action_pressed("core_dash")
		crouch_held = Input.is_action_pressed("core_crouch")
		queued_grab_press = false
		parkour.tick(delta,jump_held,input_allowed)
		weapon.update_state(delta,false)
		_update_mode()
		body.advance(delta)
		queue_redraw()
		return
	var dash_pressed := Input.is_action_pressed("core_dash")
	var dash_requested := input_allowed and dash_pressed and not dash_held
	dash_held = dash_pressed
	_update_push_contact(axis,delta,input_allowed)
	weapon.update_state(delta,input_allowed)
	var crouch_pressed := Input.is_action_pressed("core_crouch")
	var slide_requested := input_allowed and crouch_pressed and not crouch_held and slide_available(axis)
	crouch_held = crouch_pressed
	if not pushing and slide_left <= 0 and not slide_requested: _update_crouch(crouch_pressed if input_allowed else crouching)
	ladder_lock = maxf(0,ladder_lock-delta)
	dash_cooldown = maxf(0,dash_cooldown-delta)
	slide_cooldown_left = maxf(0,slide_cooldown_left-delta)
	coyote = maxf(0,coyote-delta)
	jump_buffer = maxf(0,jump_buffer-delta)
	if not input_allowed or pushing: jump_buffer = 0
	if is_on_floor() and not climbing and dash_left <= 0 and slide_left <= 0:
		coyote = tuning.coyote_time
		air_dash_used = false
	if not pushing and tuning.jump_enabled and input_allowed and Input.is_action_just_pressed("core_jump"): jump_buffer = maxf(tuning.jump_buffer_time,delta)
	if axis != 0 and dash_left <= 0 and slide_left <= 0: facing = signf(axis)
	if pushing:
		_tick_grab(axis,delta)
	elif shove_left > 0:
		# Preserve the impulse briefly so ordinary braking cannot erase the shove.
		if dash_requested and dash_available():
			shove_left = 0
			_start_dash(axis)
			_tick_dash(delta)
		else:
			shove_left = maxf(0,shove_left-delta)
			velocity.y = minf(velocity.y+tuning.gravity*delta,tuning.fall_speed)
			move_and_slide()
	elif dash_left > 0:
		_tick_dash(delta)
	elif slide_left > 0:
		if jump_buffer > 0 or not is_on_floor():
			_finish_slide()
			_tick_run(axis,delta,jump_held)
		else: _tick_slide(delta)
	elif climbing:
		_tick_climb(axis,vertical,delta)
	else:
		var nearby := ladder_here(vertical)
		if slide_requested:
			_start_slide()
			_tick_slide(delta)
		elif not grenades.busy() and absf(vertical) > 0 and nearby.has_area() and ladder_lock <= 0 and jump_buffer <= 0 and _try_stand():
			_enter_ladder(nearby)
			_tick_climb(axis,vertical,delta)
		elif dash_requested and dash_available():
			_start_dash(axis)
			_tick_dash(delta)
		elif parkour.try_start(axis,jump_held):
			pass
		else:
			_tick_run(axis,delta,jump_held)
	if pushing: _move_grabbed_body(delta,axis,(global_position.x-previous_position.x)/delta)
	_scatter_debris(previous_position,delta)
	if global_position.y > CoreMovementLevel.FALL_LIMIT: fell.emit()
	_tick_sprint_reserve(delta,was_dashing,was_sliding)
	_update_mode()
	if dash_left > 0 or slide_left > 0 or climbing: weapon.cancel_reload()
	body.advance(delta)
	# Choose this tick's body anchors before computing the muzzle and firing.
	weapon.finish_tick()
	body.update_arms()
	_emit_movement_noise(previous_position,was_grounded,previous_fall_speed,was_dashing or was_sliding or slide_left > 0)
	queue_redraw()

func _scatter_debris(from: Vector2,delta: float) -> void:
	if not get_tree().has_group("crate_debris"): return
	# Query the swept body bounds: fast dashes should also scatter small chips,
	# even when neither the previous nor current capsule overlaps their centre.
	var size := Vector2(RADIUS*2,collision_height())
	var offset := Vector2(RADIUS,collision_height())
	var bounds := Rect2(from-offset,size).merge(Rect2(global_position-offset,size))
	var shape := RectangleShape2D.new()
	shape.size = bounds.size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0,bounds.get_center())
	query.collision_mask = CoreCrateDebris.COLLISION_LAYER
	var speed := (global_position.x-from.x)/delta
	for hit in get_world_2d().direct_space_state.intersect_shape(query,128):
		if hit.collider is CoreCrateDebris:
			hit.collider.scatter_from_player(global_position-Vector2(0,collision_height()*.5),speed)

func stop_pushing() -> void:
	if is_instance_valid(push_target) and push_target.has_method("end_grab"): push_target.call("end_grab")
	pushing = false
	push_target = null
	push_contact_time = 0

func _can_grab(prop) -> bool:
	if not is_instance_valid(prop) or prop.is_queued_for_deletion(): return false
	if prop.has_method("can_grab"): return bool(prop.call("can_grab"))
	return not prop.freeze

func _update_push_contact(axis: float,delta: float,input_allowed: bool) -> void:
	var pressed := Input.is_action_pressed("core_grab")
	var toggle := input_allowed and (queued_grab_press or (pressed and not grab_held))
	grab_held = pressed
	queued_grab_press = false
	if pushing and (not tuning.push_enabled or health <= 0 or not _can_grab(push_target) or not is_on_floor() or shove_left > 0):
		stop_pushing()
	if toggle:
		if pushing:
			stop_pushing()
			return
		if not tuning.push_enabled or health <= 0 or not is_on_floor() or crouching or climbing or parkour_active() or dash_left > 0 or slide_left > 0 or shove_left > 0 or weapon.reloading or grenades.busy(): return
		# Prefer the side being approached; a stationary hero uses the body gaze.
		var preferred := signf(axis) if axis != 0 else body.facing
		for direction in [preferred,-preferred]:
			for height in [HEIGHT*.5,tuning.push_hand_height,HEIGHT*.75,20.0,12.0]:
				var origin := global_position-Vector2(0,height)
				var query := PhysicsRayQueryParameters2D.create(origin,origin+Vector2(direction*(RADIUS+tuning.push_contact_distance+2),0),1,[get_rid()])
				var hit := get_world_2d().direct_space_state.intersect_ray(query)
				var prop := hit.get("collider") as RigidBody2D
				if not _can_grab(prop): continue
				if prop.has_method("begin_grab"): prop.call("begin_grab")
				if prop.has_method("begin_barrel_grab"): prop.call("begin_barrel_grab",self,direction)
				if prop.freeze: continue
				push_target = prop
				push_direction = direction
				pushing = true
				push_contact_time = 0
				var anchor := (push_hand_point("near")+push_hand_point("far"))*.5
				push_anchor_local = prop.to_local(anchor)
				push_anchor_offset = anchor-global_position
				ground_speed = 0
				ground_acceleration = 0
				velocity.x = 0
				break
			if pushing: break
	if not pushing: return
	push_contact_time += delta
	sprinting = false
	walking = false
	jump_buffer = 0
	# Broken contact (falling object, reset, explosion) cannot stretch the arms
	# across the arena. Normal pauses and direction changes keep the grip.
	var anchor := push_hand_point("near") if push_target.has_method("move_grabbed") else push_target.to_global(push_anchor_local)
	if anchor.distance_to(global_position+push_anchor_offset) > 54:
		stop_pushing()

func _tick_grab(axis: float,delta: float) -> void:
	var target_speed := axis*tuning.push_speed
	if push_target.has_method("move_grabbed"):
		target_speed = axis*push_target.tuning.barrel_roll_speed
		if push_target.is_tipping(): target_speed = 0
	if push_contact_time < tuning.push_activation_delay: target_speed = 0
	ground_acceleration = 0
	ground_speed = move_toward(ground_speed,target_speed,tuning.acceleration*delta)
	var tangent := Vector2(-get_floor_normal().y,get_floor_normal().x)
	velocity = tangent*ground_speed
	if axis*push_direction < 0:
		# A heavy or obstructed object holds the player back. Never stretch a
		# pulling constraint, teleport the prop, or pull it through the player.
		var anchor := push_hand_point("near") if push_target.has_method("move_grabbed") else push_target.to_global(push_anchor_local)
		var separation := (anchor.x-global_position.x)*push_direction
		var slack := maxf(1,tuning.push_contact_distance)+push_anchor_offset.x*push_direction-separation
		velocity.x = push_direction*-minf(absf(velocity.x),maxf(0,slack)/delta)
	move_and_slide()
	apply_floor_snap()

func _move_grabbed_body(delta: float,axis: float,actual_speed: float) -> void:
	if not _can_grab(push_target):
		stop_pushing()
		return
	if push_contact_time < tuning.push_activation_delay: return
	if push_target.has_method("move_grabbed"):
		push_target.move_grabbed(delta,axis,global_position,push_direction,tuning.push_force,tuning.push_response)
		return
	var anchor := push_target.to_global(push_anchor_local)
	var error := global_position.x+push_anchor_offset.x-anchor.x
	var desired_speed := (actual_speed if axis != 0 else 0.0)+error*12
	# While pushing, the body blocks the capsule until the applied force moves
	# it. Supply the commanded speed only for that specific collision.
	if axis*push_direction > 0:
		for index in get_slide_collision_count():
			if get_slide_collision(index).get_collider() == push_target:
				desired_speed = ground_speed+error*12
				break
	# Point velocity includes rotation, so a tilted crate or ragdoll is held
	# at the grip rather than driven as though its centre were the hands.
	var radius := anchor-push_target.global_position
	var point_speed := push_target.linear_velocity.x-push_target.angular_velocity*radius.y
	# Limit the servo gain by the effective mass at the grip. The same gain
	# that is stable for an 8 kg crate would oscillate on a light ragdoll limb.
	var inverse_mass := 1.0/push_target.mass
	var state := PhysicsServer2D.body_get_direct_state(push_target.get_rid())
	if state: inverse_mass += radius.y*radius.y*state.inverse_inertia
	var response := minf(tuning.push_response,.65/(inverse_mass*delta))
	var force := clampf((desired_speed-point_speed)*response,-tuning.push_force,tuning.push_force)
	push_target.apply_impulse(Vector2(force*delta,0),radius)

func push_hand_point(side: String) -> Vector2:
	if not is_instance_valid(push_target): return global_position+Vector2(push_direction*RADIUS,-tuning.push_hand_height)
	if push_target.has_method("grab_hand_point"): return push_target.grab_hand_point(side,global_position,push_direction)
	# Discover the collider instead of depending on a scene-specific child name;
	# dynamically generated ragdoll limbs use the same interaction contract.
	var shape: CollisionShape2D
	for child in push_target.get_children():
		if child is CollisionShape2D and child.shape and not child.disabled:
			shape = child
			break
	if not shape: return push_target.global_position
	var rect := shape.shape.get_rect()
	var corners: Array[Vector2] = []
	if shape.shape is CircleShape2D:
		for i in 32: corners.append(shape.global_transform*(Vector2.from_angle(i*TAU/32)*shape.shape.radius))
	else:
		for point in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
			corners.append(shape.global_transform*point)
	var top := INF
	var bottom := -INF
	for point in corners:
		top = minf(top,point.y)
		bottom = maxf(bottom,point.y)
	var height := tuning.push_hand_height+(tuning.push_hand_spacing*.5 if side == "far" else -tuning.push_hand_spacing*.5)
	var inset := minf(4,(bottom-top)*.25)
	var y := clampf(global_position.y-height,top+inset,bottom-inset)
	var start := Vector2(global_position.x,y)
	var end := Vector2(push_target.global_position.x+push_direction*1000,y)
	var nearest := push_target.global_position
	var distance := INF
	for i in corners.size():
		var hit = Geometry2D.segment_intersects_segment(start,end,corners[i],corners[(i+1)%corners.size()])
		if hit != null and start.distance_squared_to(hit) < distance:
			nearest = hit
			distance = start.distance_squared_to(hit)
	return nearest

func _emit_movement_noise(previous_position: Vector2,was_grounded: bool,fall_speed: float,was_dashing: bool) -> void:
	if movement_noise_suppressed > 0: return
	var travel := global_position.distance_to(previous_position)
	if climbing:
		step_noise_distance = 0
		ladder_noise_distance += travel
		if ladder_noise_distance >= 48:
			ladder_noise_distance = fmod(ladder_noise_distance,48)
			noise_emitted.emit(global_position-Vector2(0,HEIGHT*.5),.7,"ladder")
		return
	ladder_noise_distance = 0
	if dash_left > 0 or was_dashing: return
	if is_on_floor():
		if not was_grounded and fall_speed > 180:
			noise_emitted.emit(global_position-Vector2(0,8),1.5,"land")
		step_noise_distance += travel
		if step_noise_distance >= 64:
			step_noise_distance = fmod(step_noise_distance,64)
			var loudness := tuning.crouch_noise_multiplier if crouching else tuning.sprint_noise_multiplier if sprinting else tuning.slow_walk_noise_multiplier if walking else 1.0
			noise_emitted.emit(global_position-Vector2(0,8),loudness,"step")
	else: step_noise_distance = 0

func _can_sprint(axis: float) -> bool:
	return tuning.sprint_enabled and not pushing and sprint_requested and not walk_requested and sprint_reserve > 0 and not sprint_exhausted and not is_zero_approx(axis) and not crouching and not weapon.reloading and not weapon.aiming and not weapon.firing and not weapon.trigger_held

func sprint_seconds_left() -> float:
	return sprint_reserve*tuning.sprint_duration

func sprint_recovery_left() -> float:
	return (1-sprint_reserve)*tuning.sprint_recovery_time

func _tick_sprint_reserve(delta: float,was_dashing: bool,was_sliding := false) -> void:
	var spending := sprinting and absf(velocity.x) > 5 and not climbing and not crouching and not weapon.reloading and not weapon.aiming and not weapon.firing and not weapon.trigger_held and not was_dashing and dash_left <= 0 and shove_left <= 0
	if spending:
		sprint_reserve = maxf(0,sprint_reserve-delta/tuning.sprint_duration)
		if sprint_reserve <= .00001:
			sprint_reserve = 0
			sprint_exhausted = true
			sprinting = false
	elif (is_on_floor() or climbing) and not was_dashing and dash_left <= 0 and slide_left <= 0 and not was_sliding:
		sprint_reserve = minf(1,sprint_reserve+delta/tuning.sprint_recovery_time)
		if sprint_reserve >= .99999:
			sprint_reserve = 1
			sprint_exhausted = false

func slide_available(axis: float) -> bool:
	if grenades.busy(): return false
	return tuning.slide_enabled and health > 0 and is_on_floor() and sprinting and _can_sprint(axis) and slide_left <= 0 and slide_cooldown_left <= 0 and dash_left <= 0 and not climbing and shove_left <= 0 and velocity.length() >= tuning.slide_min_speed

func _slide_posture() -> void:
	var height := tuning.slide_height
	if height > collision_height() and not _fits_height(height): height = collision_height()
	crouching = true
	crouching_capsule.height = height
	movement_shape.shape = crouching_capsule
	movement_shape.position.y = -height*.5

func _start_slide() -> void:
	ground_acceleration = 0
	slide_direction = signf(ground_speed)
	facing = slide_direction
	slide_speed = absf(ground_speed)*tuning.slide_speed_multiplier
	slide_duration_active = tuning.slide_duration
	slide_left = slide_duration_active
	slide_cooldown_left = tuning.slide_cooldown
	slide_hit_enemies.clear()
	slides += 1
	sprinting = false
	coyote = 0
	jump_buffer = 0
	_slide_posture()
	noise_emitted.emit(global_position-Vector2(0,8),1.5,"slide")

func _finish_slide() -> void:
	slide_left = 0
	air_move_speed = maxf(tuning.run_speed,absf(velocity.x)) if not is_on_floor() else tuning.run_speed
	ground_speed = slide_direction*slide_speed
	_update_crouch(Input.is_action_pressed("core_crouch"))

func _tick_slide(delta: float) -> void:
	_slide_posture()
	var tick_time := minf(delta,slide_left)
	var next_speed := maxf(0,slide_speed-tuning.slide_braking*tick_time)
	var tangent := Vector2(-get_floor_normal().y,get_floor_normal().x)
	velocity = tangent*slide_direction*(slide_speed+next_speed)*.5*(tick_time/delta)
	var ordinary_snap := floor_snap_length
	floor_snap_length = maxf(ordinary_snap,velocity.length()*delta+safe_margin)
	move_and_slide()
	apply_floor_snap()
	floor_snap_length = ordinary_snap
	var blocked := false
	for index in get_slide_collision_count():
		var contact := get_slide_collision(index)
		var enemy := contact.get_collider() as CoreEnemyDummy
		if enemy:
			_slide_impact(enemy,slide_speed)
			if enemy.health <= 0 or enemy.is_prone():
				if enemy not in get_collision_exceptions():
					add_collision_exception_with(enemy)
					dash_overlap_exceptions.append(enemy)
					var cleanup := _enemy_exiting.bind(enemy)
					if not enemy.tree_exiting.is_connected(cleanup): enemy.tree_exiting.connect(cleanup)
			else: blocked = true
		elif absf(contact.get_normal().x) > .7 and contact.get_normal().dot(Vector2.UP) < .5:
			blocked = true
	slide_speed = next_speed
	ground_speed = slide_direction*slide_speed
	slide_left = maxf(0,slide_left-tick_time)
	if blocked:
		slide_speed = 0
		velocity = Vector2.ZERO
	if blocked or slide_left <= 0 or slide_speed <= 5 or not is_on_floor(): _finish_slide()

func _slide_impact(enemy: CoreEnemyDummy,impact_speed: float) -> void:
	if enemy.health <= 0 or slide_hit_enemies.has(enemy.get_instance_id()): return
	slide_hit_enemies[enemy.get_instance_id()] = true
	slide_hits += 1
	var direction := Vector2(slide_direction,0)
	var damage := tuning.slide_damage if impact_speed >= tuning.slide_damage_min_speed else 0.0
	var killed := enemy.take_slide_hit(damage,direction,global_position)
	if not killed and tuning.slide_knockdown_enabled and impact_speed >= tuning.slide_knockdown_min_speed and (tuning.slide_knockdown_chance >= 1 or slide_rng.randf() < tuning.slide_knockdown_chance):
		var duration := tuning.slide_zombie_knockdown_duration if enemy is CoreZombie else tuning.slide_knockdown_duration
		enemy.knock_down(duration,direction*tuning.slide_knockback_speed)
	if damage > 0 or enemy.is_knocked_down(): weapon._on_impact(enemy.global_position-Vector2(0,12),true,killed,direction)

func sprint_pose_active() -> bool:
	return sprinting and sprint_requested and not walk_requested and not crouching and not climbing and dash_left <= 0 and slide_left <= 0 and shove_left <= 0 and not weapon.reloading and not weapon.aiming and not weapon.trigger_held and not is_zero_approx(movement_axis)

func sprint_dash_pose_active() -> bool:
	return dash_left > 0 and dash_from_sprint

func backward_speed_multiplier(axis: float) -> float:
	if not tuning.backward_enabled: return 1.0
	if sprinting or axis*weapon.look_facing() >= 0: return 1.0
	if crouching: return tuning.crouch_backward_multiplier
	return tuning.slow_walk_backward_multiplier if walking else tuning.run_backward_multiplier

func _capture_ground_gait(axis: float) -> void:
	# Ground contact captures the gait for both jumps and walking off ledges.
	# Crouching keeps its own speed; Ctrl never scales the crouch speed again.
	walking = walk_requested and not crouching and not pushing
	sprinting = _can_sprint(axis)
	air_move_speed = tuning.push_speed if pushing else (tuning.sprint_speed if sprinting else tuning.slow_walk_speed if walking else tuning.run_speed)*backward_speed_multiplier(axis)

func _tick_run(axis: float,delta: float,jump_held: bool) -> void:
	var grounded := is_on_floor()
	if grounded:
		_capture_ground_gait(axis)
	if not tuning.run_enabled and not walking and not sprinting and not crouching and not pushing: axis = 0
	var rate := (tuning.slow_walk_acceleration if axis != 0 else tuning.slow_walk_braking) if walking else (tuning.acceleration if axis != 0 else tuning.braking)
	var run_speed := air_move_speed*weapon.movement_multiplier
	if crouching: run_speed *= tuning.crouch_speed_multiplier
	if grounded:
		var tangent := Vector2(-get_floor_normal().y,get_floor_normal().x)
		run_speed *= slope_speed_multiplier(axis)
		# Godot adjusts velocity after sliding. Keep acceleration along the floor
		# separately so that this adjustment does not slow every following frame.
		if is_zero_approx(axis):
			ground_acceleration = 0
			ground_speed = move_toward(ground_speed,0,rate*delta)
		else:
			var accelerated := tuning.acceleration_step(ground_speed,axis*run_speed,ground_acceleration,rate,delta)
			ground_speed = accelerated.x
			ground_acceleration = accelerated.y
		velocity = tangent*ground_speed
	else:
		ground_acceleration = 0
		rate = tuning.slow_walk_air_acceleration if walking else tuning.air_acceleration
		velocity.x = move_toward(velocity.x,axis*run_speed,rate*delta)
		velocity.y = minf(velocity.y+tuning.gravity*delta,tuning.fall_speed)
		ground_speed = velocity.x
	if tuning.jump_enabled and jump_buffer > 0 and (is_on_floor() or coyote > 0):
		_try_stand()
		var jump_multiplier := tuning.sprint_jump_multiplier if sprinting else tuning.slow_walk_jump_multiplier if walking else tuning.walk_jump_multiplier
		velocity.x *= jump_multiplier
		air_move_speed *= jump_multiplier
		ground_acceleration = 0
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
	dash_stunned_enemies.clear()
	# Capture the outgoing gait before dash disables the live sprint pose.
	dash_from_sprint = sprint_pose_active()
	ground_acceleration = 0
	_try_stand()
	dash_direction = signf(axis) if axis != 0 else facing
	facing = dash_direction
	dash_left = tuning.dash_duration
	dash_cooldown = tuning.dash_cooldown
	air_dash_used = true
	coyote = 0
	dash_origin = global_position
	dashes += 1
	set_collision_mask_value(3,false)
	noise_emitted.emit(global_position-Vector2(0,HEIGHT*.5),2.0,"dash")

func _tick_dash(delta: float) -> void:
	# Enemy bodies are phased; swept movement still stops at world geometry.
	var active_fraction := minf(delta,dash_left)/delta
	var grounded := is_on_floor()
	var direction := Vector2(-get_floor_normal().y,get_floor_normal().x) if grounded else Vector2.RIGHT
	var multiplier := tuning.dash_slope_multiplier(rad_to_deg(get_floor_angle()),direction.y*dash_direction < 0) if grounded else 1.0
	velocity = direction*dash_direction*tuning.dash_speed*multiplier*active_fraction
	# Fast custom dashes can cross more than the usual snap distance in one
	# tick at a crest. Follow the next surface only when starting grounded.
	var ordinary_snap := floor_snap_length
	if grounded: floor_snap_length = maxf(ordinary_snap,velocity.length()*delta+safe_margin)
	var previous_position := global_position
	move_and_slide()
	if grounded: apply_floor_snap()
	floor_snap_length = ordinary_snap
	_stun_dash_crossings(previous_position)
	dash_left = maxf(0,dash_left-delta)
	last_dash_distance = absf(global_position.x-dash_origin.x)
	if is_on_wall(): dash_left = 0
	if dash_left <= 0:
		# The stop is audible at the actual endpoint, including wall-shortened
		# dashes. Otherwise an enemy keeps investigating the starting position
		# after the player phases behind it and stands still.
		noise_emitted.emit(global_position-Vector2(0,HEIGHT*.5),2.0,"dash")
		dash_from_sprint = false
		_finish_dash_collision()
		if is_on_floor():
			_capture_ground_gait(movement_axis)
		ground_speed = dash_direction*air_move_speed
		velocity = direction*ground_speed if is_on_floor() else Vector2(ground_speed,0)

func _stun_dash_crossings(from: Vector2) -> void:
	var travel := global_position-from
	if is_zero_approx(travel.x): return
	# Test the actual capsule at the crossing, rather than only the endpoint.
	# This also catches a complete pass through a body within one physics tick.
	for candidate in get_tree().get_nodes_in_group("dash_stunnable"):
		var enemy := candidate as PhysicsBody2D
		if not enemy: continue
		if dash_stunned_enemies.has(enemy.get_instance_id()): continue
		var weight := (enemy.global_position.x-from.x)/travel.x
		if weight < 0 or weight > 1: continue
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = movement_shape.shape
		query.transform = movement_shape.global_transform
		query.transform.origin += from.lerp(global_position,weight)-global_position
		query.collision_mask = ENEMY_MASK
		query.exclude = [get_rid()]
		for hit in get_world_2d().direct_space_state.intersect_shape(query,128):
			if hit.collider != enemy: continue
			dash_stunned_enemies[enemy.get_instance_id()] = true
			enemy.call("apply_dash_stun")
			break

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
		# Falling one target must not also phase a still-standing neighbour in
		# a dense group: that neighbour should receive its own slide collision.
		if slide_left > 0 and enemy is CoreEnemyDummy and enemy.health > 0 and not enemy.is_prone(): continue
		if enemy in get_collision_exceptions(): continue
		add_collision_exception_with(enemy)
		dash_overlap_exceptions.append(enemy)
		var cleanup := _enemy_exiting.bind(enemy)
		if not enemy.tree_exiting.is_connected(cleanup): enemy.tree_exiting.connect(cleanup)

func _enemy_exiting(enemy: PhysicsBody2D) -> void:
	# Remove the RID while it still exists; querying a freed exception is an
	# engine error even after our local list has discarded the dead Node.
	if enemy in dash_overlap_exceptions:
		remove_collision_exception_with(enemy)
		dash_overlap_exceptions.erase(enemy)

func _refresh_dash_exceptions() -> void:
	if dash_overlap_exceptions.is_empty(): return
	var overlaps := _overlapping_enemies()
	for i in range(dash_overlap_exceptions.size()-1,-1,-1):
		var enemy := dash_overlap_exceptions[i]
		if not is_instance_valid(enemy):
			dash_overlap_exceptions.remove_at(i)
		elif enemy not in overlaps:
			if slide_left > 0 and slide_hit_enemies.has(enemy.get_instance_id()) and enemy is CoreEnemyDummy and (enemy.health <= 0 or enemy.is_prone()): continue
			remove_collision_exception_with(enemy)
			dash_overlap_exceptions.remove_at(i)

func _clear_dash_exceptions() -> void:
	for enemy in dash_overlap_exceptions:
		if is_instance_valid(enemy): remove_collision_exception_with(enemy)
	dash_overlap_exceptions.clear()

func ladder_here(vertical: float) -> Rect2:
	if not tuning.ladder_enabled: return Rect2()
	for candidate in ladders:
		if absf(global_position.x-candidate.get_center().x) > 28: continue
		if global_position.y < candidate.position.y-6 or global_position.y > candidate.end.y+6: continue
		if vertical < 0 and global_position.y <= candidate.position.y+4: continue
		if vertical > 0 and global_position.y >= candidate.end.y-4: continue
		return candidate
	return Rect2()

func _enter_ladder(candidate: Rect2) -> void:
	walking = false
	sprinting = false
	air_move_speed = tuning.run_speed
	climbing = true
	ladder = candidate
	ladder_side_view = candidate in side_ladders
	velocity = Vector2.ZERO
	ground_acceleration = 0
	ground_speed = 0
	coyote = 0
	# Only one-way platforms are ignored. Ground, walls and targets stay solid.
	set_collision_mask_value(4,false)

func _leave_ladder() -> void:
	climbing = false
	ladder_side_view = false
	set_collision_mask_value(4,true)
	ladder_lock = tuning.ladder_regrab_delay

func _tick_climb(axis: float,vertical: float,delta: float) -> void:
	if jump_buffer > 0:
		_leave_ladder()
		air_move_speed = tuning.run_speed*tuning.walk_jump_multiplier
		velocity = Vector2(axis*air_move_speed,-tuning.jump_speed*.85)
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
	if parkour_active(): mode = parkour.stage
	elif dash_left > 0: mode = "dash"
	elif slide_left > 0: mode = "slide"
	elif climbing: mode = "climb"
	elif not is_on_floor(): mode = "jump" if velocity.y < 0 else "fall"
	elif crouching: mode = "crouch_walk" if absf(velocity.x) > 5 else "crouch"
	elif pushing: mode = "push"
	elif absf(velocity.x) > 5: mode = "sprint" if sprinting else "walk" if walking else "run"
	else: mode = "idle"

func _draw() -> void:
	if debug_shape:
		draw_rect(Rect2(-RADIUS,-collision_height(),RADIUS*2,collision_height()),Color("f4f4dc"),false,1)
