extends SceneTree

var lab: CoreMovementLab
var hero: CoreMovementPlayer
var zombie: CoreZombie
var noises: Array[Dictionary] = []
var checks := 0
var failures := 0
const ACTIONS := ["core_left","core_right","core_dash","core_jump","core_fire","core_aim"]

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func release() -> void:
	for action in ACTIONS: Input.action_release(action)
func reset_case(side: float) -> void:
	release()
	zombie.tuning.apply_values(lab.zombie_overlay.defaults.as_dictionary())
	zombie.reset_target()
	zombie.tuning.apply_values({"vision_angle":60,"patrol_speed":0,"movement_enabled":false,"combat_enabled":false,"stun_enabled":false})
	zombie.facing = -side
	zombie._sync_zones()
	hero.reset_to(zombie.home-Vector2(side*65,0))
	hero.weapon.aim_override = zombie.home-Vector2(0,38)
	noises.clear()
func start_dash(side: float) -> void:
	Input.action_press("core_right" if side > 0 else "core_left")
	Input.action_press("core_dash")
	await frames(3)
	release()
func finish_dash() -> Vector2:
	for i in 80:
		await frames(1)
		if hero.dash_left <= 0: return hero.global_position-Vector2(0,CoreMovementPlayer.HEIGHT*.5)
	push_error("Dash did not finish")
	return Vector2.INF
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	zombie = lab.level.zombie
	hero.noise_emitted.connect(func(point: Vector2,loudness: float,kind: String): noises.append({"point":point,"loudness":loudness,"kind":kind}))
	await frames(8)
	for side in [-1.0,1.0]:
		reset_case(side)
		await frames(8)
		check(zombie.state == CoreZombie.State.CHASE,"the zombie sees the player before the dash, side %.0f" % side)
		await start_dash(side)
		var endpoint := await finish_dash()
		check(noises.size() == 2 and noises.all(func(n: Dictionary): return n.kind == "dash") and noises[-1].point.is_equal_approx(endpoint),"dash start and finish use actual player positions, side %.0f" % side)
		await frames(25)
		check((hero.global_position.x-zombie.global_position.x)*side > 0 and absf(hero.velocity.x) < .1,"the player crosses the zombie and stops with no further input, side %.0f" % side)
		check(zombie.facing == side and zombie.state == CoreZombie.State.CHASE and zombie.sees_player(360),"the zombie turns and reacquires the stationary player after crossing, side %.0f" % side)
		check(zombie.last_heard_position.is_equal_approx(endpoint) and zombie.heard_noise_count == 2,"remembered dash noise points to the endpoint rather than the start, side %.0f" % side)
		var heard := zombie.heard_noise_count
		await frames(15)
		check(zombie.heard_noise_count == heard,"standing still after a dash does not generate continuous noise")
		# A committed swing must still miss a dash to the opposite side.
		reset_case(side)
		zombie.tuning.combat_enabled = true
		zombie.tuning.movement_enabled = true
		hero.reset_to(zombie.home-Vector2(side*48,0))
		await frames(4)
		check(zombie.state == CoreZombie.State.WINDUP,"the close encounter starts a committed swing")
		var facing := zombie.facing
		await start_dash(side)
		await finish_dash()
		check(zombie.state == CoreZombie.State.WINDUP and zombie.facing == facing,"end-of-dash noise cannot rotate a committed swing")
		await frames(20)
		check(zombie.attacks_landed == 0 and hero.health == 100,"crossing behind the attacker still dodges the original strike")
		await frames(160)
		check(zombie.attacks_landed > 0 and hero.health < 100,"after recovery the zombie finds and attacks the stationary player")
	# Isolated hearing settings must apply to both ends of a dash.
	for mode in ["switch","radius","multiplier"]:
		reset_case(1)
		if mode == "switch": zombie.tuning.hearing_enabled = false
		elif mode == "radius": zombie.tuning.hearing_range = 0
		else: zombie.tuning.movement_noise_multiplier = 0
		await frames(8)
		await start_dash(1)
		await finish_dash()
		await frames(25)
		check(zombie.heard_noise_count == 0 and zombie.facing == -1 and not zombie.sees_player(360),"a dash cannot bypass disabled hearing: "+mode)
	reset_case(1)
	zombie.tuning.vision_enabled = false
	await frames(8)
	await start_dash(1)
	var endpoint := await finish_dash()
	await frames(20)
	check(zombie.facing == 1 and zombie.state == CoreZombie.State.INVESTIGATE and zombie.last_heard_position.is_equal_approx(endpoint),"isolated hearing turns towards the dash endpoint with vision disabled")
	var remembered := zombie.last_heard_position
	hero.reset_to(zombie.home+Vector2(-200,0))
	await frames(8)
	check(zombie.last_heard_position == remembered,"silent reset cannot update the heard endpoint or grant continuous tracking")
	# Pausing and cancelling do not invent a destination sound.
	reset_case(1)
	await frames(8)
	await start_dash(1)
	paused = true
	var position := hero.global_position
	await frames(15)
	check(noises.size() == 1 and hero.global_position == position,"pausing mid-dash freezes movement without an endpoint event")
	paused = false
	await finish_dash()
	check(noises.size() == 2,"resuming a paused dash emits its endpoint exactly once")
	reset_case(1)
	await frames(8)
	await start_dash(1)
	hero.reset_to(zombie.home+Vector2(200,0))
	await frames(20)
	check(noises.size() == 1,"resetting during a dash cancels it without a sound at the teleport destination")
	# Collision termination must report the wall, not the nominal full distance.
	reset_case(1)
	hero.reset_to(Vector2(590,760))
	await frames(8)
	noises.clear()
	await start_dash(1)
	await finish_dash()
	check(noises.size() == 2 and noises[-1].point.x < 630 and noises[-1].point.distance_to(noises[0].point) < 45,"a wall-shortened dash reports the actual stopped position")
	reset_case(1)
	hero.reset_to(zombie.home+Vector2(-65,-100))
	await frames(2)
	noises.clear()
	await start_dash(1)
	endpoint = await finish_dash()
	check(not hero.is_on_floor() and noises.size() == 2 and noises[-1].point.is_equal_approx(endpoint),"air dash uses its actual endpoint without inventing a ground landing")
	reset_case(1)
	hero.tuning.air_dash_enabled = false
	hero.reset_to(zombie.home+Vector2(-65,-100))
	await frames(2)
	noises.clear()
	await start_dash(1)
	check(hero.dashes == 0 and noises.is_empty(),"a rejected air dash emits neither start nor finish noise")
	hero.tuning.air_dash_enabled = true
	reset_case(1)
	zombie.tuning.vision_enabled = false
	zombie.tuning.hearing_range = 35
	zombie.tuning.noise_occlusion_multiplier = 1
	hero.tuning.dash_duration = .32
	hero.reset_to(zombie.home+Vector2(-40,0))
	await frames(8)
	noises.clear()
	await start_dash(1)
	endpoint = await finish_dash()
	await frames(15)
	check(noises.size() == 2 and zombie.heard_noise_count == 1 and zombie.last_heard_position.is_equal_approx(noises[0].point) and not zombie.last_heard_position.is_equal_approx(endpoint),"an endpoint outside hearing range does not grant knowledge of the dash destination")
	release()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
