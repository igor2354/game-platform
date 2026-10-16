extends SceneTree

var checks := 0
var failures := 0
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var crate: RigidBody2D

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func release_inputs() -> void:
	for action in ["core_grab","core_left","core_right","core_jump","core_dash","core_fire","core_aim"]: Input.action_release(action)
func dispatch(action: String) -> void:
	# Dispatch from the ordinary frame/input phase, not between the physics
	# query flush and step (Godot 4.4 engine issue #122378).
	await process_frame
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
func reset_box() -> void:
	release_inputs()
	hero.reset_to(CoreMovementLevel.SPAWN)
	crate.reset_crate()
	await frames(120)
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	crate = lab.level.physics_crate
	hero.weapon.aim_override = Vector2(3000,700)
	check(crate is RigidBody2D and not crate.freeze and not crate.lock_rotation,"crate is a movable and rotating rigid body")
	check(crate.mass == 8 and crate.physics_material_override.friction > 0,"crate has mass and friction")
	var initial := crate.global_position
	await frames(15)
	check(crate.global_position.y > initial.y+15 and crate.linear_velocity.y > 0,"Godot gravity drops the crate onto the extended arena")
	await frames(110)
	check(absf(crate.global_position.y-(CoreMovementLevel.FLOOR-32)) < 2 and crate.linear_velocity.length() < 1,"crate settles on the solid floor")
	check(crate.global_position.x < 0 and CoreMovementLevel.LEFT_BOUND < -1000,"physics area is to the left of the original start")
	hero.reset_to(Vector2(-100,760))
	hero.weapon.aim_override = Vector2(-2000,700)
	Input.action_press("core_left")
	await frames(45)
	check(hero.global_position.x < -220 and hero.is_on_floor(),"hero crosses the old left wall into the extension")
	await reset_box()
	hero.reset_to(Vector2(crate.global_position.x+100,760))
	hero.weapon.aim_override = Vector2(-2000,700)
	await frames(6)
	var start := crate.global_position.x
	Input.action_press("core_left")
	await frames(35)
	Input.action_press("core_grab")
	await frames(1)
	Input.action_release("core_grab")
	await frames(90)
	check(crate.global_position.x < start-60,"grabbing from the right physically pushes the crate left")
	check(hero.global_position.x > crate.global_position.x,"hero is blocked by the crate rather than passing through it")
	Input.action_release("core_left")
	await frames(150)
	check(crate.linear_velocity.length() < 2,"friction brakes the crate after pushing stops")
	await reset_box()
	hero.reset_to(Vector2(crate.global_position.x-100,760))
	hero.weapon.aim_override = Vector2(2000,700)
	await frames(6)
	start = crate.global_position.x
	Input.action_press("core_right")
	await frames(35)
	Input.action_press("core_grab")
	await frames(1)
	Input.action_release("core_grab")
	await frames(90)
	check(crate.global_position.x > start+60,"grabbing from the left physically pushes the crate right")
	await reset_box()
	hero.reset_to(Vector2(crate.global_position.x,600))
	await frames(60)
	check(hero.is_on_floor() and hero.global_position.y < 710 and absf(hero.global_position.x-crate.global_position.x) < 20,"hero lands on the crate and can stand on it")
	check(crate.linear_velocity.length() < 2,"standing on the crate does not apply a horizontal pushing force")
	Input.action_press("core_jump")
	await frames(5)
	check(hero.velocity.y < -100 and not hero.is_on_floor(),"hero can jump from the crate")
	await reset_box()
	hero.reset_to(Vector2(crate.global_position.x-110,760))
	hero.weapon.aim_override = crate.global_position
	await frames(4)
	var ammunition := hero.weapon.magazine_ammo
	start = crate.global_position.x
	hero.weapon._fire()
	await frames(12)
	check(crate.global_position.x > start+.2 and hero.weapon.magazine_ammo == ammunition-1,"a real projectile stops on the crate and supplies an impulse")
	check(hero.weapon.hits == 0,"crate impacts are not counted as enemy hits")
	crate.apply_impulse(Vector2(1000,-1800),Vector2(0,-25))
	await frames(4)
	check(crate.linear_velocity.y < 0 and absf(crate.angular_velocity) > .1,"off-centre impulses launch and rotate the crate")
	await dispatch("core_pause")
	var paused_transform := crate.global_transform
	await frames(12)
	check(paused and crate.global_transform.is_equal_approx(paused_transform),"Escape stops the crate's physical simulation")
	await dispatch("core_pause")
	await frames(5)
	check(not paused and not crate.global_transform.is_equal_approx(paused_transform),"Escape resumes crate movement")
	await dispatch("core_reset")
	await frames(2)
	check(absf(crate.global_position.x-initial.x) < 1 and absf(crate.rotation) < .01 and absf(crate.linear_velocity.x) < 1,"level reset restores crate position, rotation and horizontal velocity")
	check(hero.global_position.distance_to(CoreMovementLevel.SPAWN) < 2,"level reset restores the original hero start")
	await frames(100)
	lab.camera_settings.limit_to_level = true
	lab.camera_settings.zoom = 2
	lab.camera_settings.offset_x = 0
	lab.camera_settings.look_ahead = 0
	hero.reset_to(Vector2(CoreMovementLevel.LEFT_BOUND+40,760))
	lab._update_camera(true)
	var half_width := lab.get_viewport_rect().size.x*.5/lab.camera_settings.zoom
	check(absf(lab.camera.position.x-(CoreMovementLevel.LEFT_BOUND+half_width)) < .1,"camera bounds include the extended left area")
	hero.reset_to(Vector2(CoreMovementLevel.LEFT_BOUND+40,760))
	hero.weapon.aim_override = Vector2(-2000,700)
	Input.action_press("core_left")
	await frames(25)
	check(hero.global_position.x >= CoreMovementLevel.LEFT_BOUND+CoreMovementPlayer.RADIUS-1,"new outer wall blocks the hero at the left boundary")
	release_inputs()
	lab.queue_free()
	await process_frame
	await create_timer(.12).timeout
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
