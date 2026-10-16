extends SceneTree

var lab: CoreMovementLab
var hero: CoreMovementPlayer
var checks := 0
var failures := 0
var pieces: Array[CoreCrateDebris] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame
func release() -> void:
	for action in ["core_left","core_right","core_walk","core_sprint","core_dash","core_crouch","core_jump"]: Input.action_release(action)
func clear_pieces() -> void:
	for piece in pieces:
		if is_instance_valid(piece): piece.queue_free()
	pieces.clear()
	await frames(2)
func prepare(side: float,with_pieces: bool) -> void:
	release()
	await clear_pieces()
	hero.reset_to(Vector2(0,760))
	hero.weapon.aim_override = Vector2(side*1200,710)
	if with_pieces:
		for i in 6:
			var piece := CoreCrateDebris.new()
			piece.position = Vector2(side*(60+i*14),757.5)
			lab.add_child(piece)
			pieces.append(piece)
	await frames(16)
func trajectory(gait: String,side: float) -> Array[Vector2]:
	Input.action_press("core_right" if side > 0 else "core_left")
	if gait == "walk": Input.action_press("core_walk")
	if gait in ["sprint","slide"]: Input.action_press("core_sprint")
	if gait == "crouch": Input.action_press("core_crouch")
	if gait == "dash": Input.action_press("core_dash")
	var points: Array[Vector2] = []
	for i in 45:
		if gait == "slide" and i == 10: Input.action_press("core_crouch")
		await frames(1)
		points.append(hero.global_position)
	release()
	return points
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	var crate: RigidBody2D = lab.level.physics_crate
	hero.reset_to(Vector2(0,760))
	await frames(12)
	crate.take_damage(100)
	await frames(2)
	check(crate.debris.size() == 24,"destruction now creates 24 small chips")
	var small := true
	var passable := true
	var world_collision := true
	for piece in crate.debris:
		small = small and piece.dimensions.x <= 10 and piece.dimensions.y <= 7 and piece.mass < .1
		passable = passable and (piece.collision_layer & hero.collision_mask) == 0 and (piece.collision_mask & hero.collision_layer) == 0
		world_collision = world_collision and (piece.collision_mask & 1) != 0 and (piece.collision_mask & CoreCrateDebris.COLLISION_LAYER) != 0
	check(small,"all fragments are smaller and lighter than the previous chunks")
	check(passable,"debris cannot block the player from either side of collision filtering")
	check(world_collision,"debris still collides with the floor, walls and other fragments")
	crate.reset_crate()
	await frames(4)
	for side in [-1.0,1.0]:
		for gait in ["walk","run","sprint","crouch","dash","slide"]:
			await prepare(side,false)
			var empty := await trajectory(gait,side)
			await prepare(side,true)
			var starts := []
			for piece in pieces: starts.append(piece.position)
			var debris_run := await trajectory(gait,side)
			var identical := true
			for i in empty.size(): identical = identical and empty[i].distance_to(debris_run[i]) < .05
			check(identical,"debris preserves every movement frame: "+gait+" side "+str(side))
			var scattered := false
			for i in pieces.size(): scattered = scattered or (pieces[i].position.x-starts[i].x)*side > 5
			check(scattered,"physical contact scatters resting debris: "+gait+" side "+str(side))
	await prepare(1,false)
	# A very short, fast dash crosses a chip between physics frames. Neither
	# endpoint overlaps it, so endpoint-only overlap detection would miss it.
	var chip := CoreCrateDebris.new()
	chip.position = Vector2(40,735)
	chip.gravity_scale = 0
	lab.add_child(chip)
	pieces.append(chip)
	await frames(2)
	hero.tuning.dash_speed = 6000
	hero.tuning.dash_duration = hero.get_physics_process_delta_time()
	Input.action_press("core_right")
	Input.action_press("core_dash")
	# The contact is found in the dash tick; Godot integrates the queued
	# rigid-body impulse in the following physics step.
	await frames(2)
	check(hero.position.x > 70 and chip.linear_velocity.x > 20,"swept contact catches a chip crossed entirely by a fast dash")
	release()
	hero.tuning.dash_speed = lab.movement_overlay.defaults.dash_speed
	hero.tuning.dash_duration = lab.movement_overlay.defaults.dash_duration
	await prepare(1,false)
	chip = CoreCrateDebris.new()
	chip.position = Vector2(80,720)
	chip.gravity_scale = 0
	lab.add_child(chip)
	pieces.append(chip)
	await frames(2)
	var query := PhysicsRayQueryParameters2D.create(Vector2(30,720),Vector2(100,720),CoreProjectile.BULLET_MASK,[hero.get_rid()])
	var hit := hero.get_world_2d().direct_space_state.intersect_ray(query)
	check(hit.get("collider") == chip,"bullets still detect the dedicated debris layer")
	CoreProjectile.resolve_impact(hit,25,Vector2.RIGHT,Callable())
	await frames(1)
	check(chip.linear_velocity.x > 50 and chip.linear_velocity.x < 400,"bullets move light chips with a bounded physical impulse")
	chip.gravity_scale = 1
	await frames(900)
	check(is_instance_valid(chip) and chip.visible and chip.position.y < 780,"small chips remain permanently and settle on the floor")
	await clear_pieces()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
