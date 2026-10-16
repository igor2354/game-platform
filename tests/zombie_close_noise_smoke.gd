extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var zombie: CoreZombie
var checks := 0
var failures := 0
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
	for action in ["core_left","core_right","core_dash"]: Input.action_release(action)
func setup(side: float) -> void:
	release()
	zombie.tuning.apply_values(lab.zombie_overlay.defaults.as_dictionary())
	zombie.reset_target()
	zombie.tuning.apply_values({"vision_angle":60,"movement_enabled":false,"shove_enabled":false,"stun_enabled":false})
	zombie.facing = -side
	hero.reset_to(zombie.home+Vector2(side*40,0))
	hero.set_invulnerable(true)
	hero.weapon.aim_override = zombie.home+Vector2(side*300,-36)
	await frames(4)
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	zombie = lab.level.zombie
	await frames(8)
	# The final footstep can be inside the eight-pixel arrival tolerance while
	# the capsule settles beside the zombie. Neither player movement nor a
	# second noise should be required to escape this state.
	for side in [-1.0,1.0]:
		for offset in [-3.0,0.0,3.0]:
			await setup(side)
			var source := zombie.global_position+Vector2(offset,-8)
			check(zombie.hear_noise(source,1,"step"),"near-centre sound accepted: "+str(side)+" / "+str(offset))
			var heard := zombie.heard_noise_count
			await frames(45)
			check(zombie.attacks_started > 0 and zombie.facing == side,"reached noise does not strand a close stationary player behind the zombie")
			await frames(100)
			check(zombie.attacks_started > 1 and zombie.facing == side,"melee engagement continues after the initial close-noise attack")
			check(zombie.last_heard_position == source and zombie.heard_noise_count == heard,"reacquiring a close player does not invent new noise or move its source")
			hero.set_invulnerable(false)
			await frames(80)
			check(zombie.attacks_landed > 0 and hero.health < 100,"the stationary player can receive actual melee damage")
	for side in [-1.0,1.0]:
		await setup(side)
		hero.tuning.apply_values({"dash_speed":600,"dash_duration":.16,"dash_cooldown":.16})
		hero.reset_to(zombie.home-Vector2(side*50,0))
		hero.set_invulnerable(true)
		await frames(6)
		var crossed := true
		for pass_index in 8:
			var direction: float = side if pass_index%2 == 0 else -side
			Input.action_press("core_right" if direction > 0 else "core_left")
			Input.action_press("core_dash")
			await frames(1)
			for tick in 30:
				if hero.dash_left <= 0: break
				await frames(1)
			crossed = crossed and (hero.global_position.x-zombie.global_position.x)*direction > 0
			release()
			await frames(2)
		check(crossed and hero.dashes == 8,"eight real alternating dashes cross the zombie in both directions")
		# Let ordinary braking finish before checking a stationary target.
		await frames(25)
		var standing_at := hero.global_position
		var heard := zombie.heard_noise_count
		var attacks := zombie.attacks_started
		await frames(150)
		check(zombie.attacks_started > attacks and zombie.facing == signf(hero.position.x-zombie.position.x),"after dash spam the zombie turns to and keeps attacking a stationary hero")
		check(hero.global_position.distance_to(standing_at) < .5 and zombie.heard_noise_count == heard,"continued engagement requires neither movement nor additional sounds")
	# A local sound is a reason to inspect, not knowledge of a distant target.
	for side in [-1.0,1.0]:
		await setup(side)
		zombie.tuning.vision_enabled = false
		hero.reset_to(zombie.home+Vector2(side*200,0))
		var source := zombie.global_position+Vector2(0,-8)
		zombie.hear_noise(source,1,"step")
		await frames(60)
		check(zombie.state == CoreZombie.State.INVESTIGATE and zombie.attacks_started == 0 and zombie.last_heard_position == source and not zombie.contact_followup,"searching a reached sound does not reveal a silent distant player")
		paused = true
		var timer := zombie.noise_search_left
		var facing := zombie.facing
		await frames(20)
		check(zombie.noise_search_left == timer and zombie.facing == facing,"pause freezes noise inspection and facing")
		paused = false
		zombie.tuning.hearing_enabled = false
		zombie.apply_tuning()
		check(zombie.noise_memory_left == 0 and not zombie.noise_search_started and zombie.noise_search_left == 0,"disabling hearing also cancels reached-source inspection")
		await setup(side)
		var wall := StaticBody2D.new()
		wall.collision_layer = 1
		wall.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(4,150)
		shape.shape = rectangle
		wall.add_child(shape)
		wall.position = zombie.home+Vector2(side*20,-75)
		lab.level.add_child(wall)
		await frames(2)
		zombie.hear_noise(zombie.global_position+Vector2(0,-8),1,"step")
		await frames(100)
		check(zombie.attacks_started == 0 and not zombie.contact_followup,"a wall blocks close-noise melee reacquisition")
		wall.queue_free()
		await frames(2)
		zombie.reset_target()
		check(not zombie.noise_search_started and zombie.noise_search_left == 0,"respawn clears reached-source inspection")
	release()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
