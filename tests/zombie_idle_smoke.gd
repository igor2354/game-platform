extends SceneTree

var lab: CoreMovementLab
var zombie: CoreZombie
var hero: CoreMovementPlayer
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
	for tick in count: await physics_frame
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	zombie = lab.level.zombie
	await frames(8)
	for leg in ["left_leg","right_leg"]:
		hero.reset_to(CoreMovementLevel.SPAWN)
		zombie.reset_target()
		zombie.tuning.apply_values(lab.zombie_overlay.defaults.as_dictionary())
		lab.zombie_overlay._sync()
		await frames(6)
		zombie.take_projectile_hit(50,leg)
		await frames(4)
		check(zombie.is_prone() and zombie.state == CoreZombie.State.WAIT and zombie.velocity.x == 0,"loss of "+leg+" stops an unaware patrol and enters waiting")
		var anchor := zombie.global_position
		var facing := zombie.facing
		await frames(90)
		check(zombie.global_position.distance_to(anchor) < .2 and zombie.facing == facing,"a quiet crawler stays where it fell without patrolling or scanning")
		paused = true
		lab.zombie_overlay.rows.crawl_speed.number.value = 100
		lab.zombie_overlay.rows.patrol_radius.slider.value = 64
		paused = false
		await frames(20)
		check(zombie.state == CoreZombie.State.WAIT and zombie.global_position.distance_to(anchor) < .2,"editing crawl speed and patrol radius does not wake an unaware crawler")
		hero.reset_to(zombie.global_position+Vector2(100,0))
		await frames(20)
		check(zombie.state == CoreZombie.State.WAIT and zombie.global_position.distance_to(anchor) < .2,"a silent player behind its back does not make the crawler move")
		hero.reset_to(zombie.global_position+Vector2(-160,0))
		await frames(10)
		check(zombie.state == CoreZombie.State.CHASE and zombie.velocity.x < -90 and zombie.global_position.x < anchor.x-5,"seeing the player activates pursuit at the configured crawl speed")
		hero.reset_to(CoreMovementLevel.SPAWN)
		zombie.tuning.lose_sight_delay = .15
		zombie.apply_tuning()
		await frames(20)
		anchor = zombie.global_position
		check(zombie.state == CoreZombie.State.WAIT and zombie.velocity.x == 0 and absf(zombie.global_position.x-zombie.home.x) > 5,"forgetting the target stops the crawler away from home")
		await frames(60)
		check(zombie.global_position.distance_to(anchor) < .2,"a crawler does not return to its patrol after losing the player")
		zombie.tuning.apply_values({"detection_range":32,"forget_range":32,"noise_memory_time":.3})
		hero.reset_to(zombie.global_position+Vector2(80,0))
		hero.noise_emitted.emit(hero.global_position-Vector2(0,8),1.0,"step")
		await frames(8)
		check(zombie.state == CoreZombie.State.INVESTIGATE and zombie.global_position.x > anchor.x+5,"a player noise event wakes the waiting crawler and moves it toward the source")
		# Isolate expiry of the remembered sound from a new visual/contact melee
		# encounter when the crawler reaches the player who emitted that sound.
		hero.reset_to(CoreMovementLevel.SPAWN)
		await frames(24)
		anchor = zombie.global_position
		check(zombie.state == CoreZombie.State.WAIT and zombie.noise_memory_left == 0 and zombie.velocity.x == 0,"expired sound memory stops the crawler rather than returning home")
		await frames(40)
		check(zombie.global_position.distance_to(anchor) < .2,"the crawler remains at its search endpoint while the nearby player stays silent")
		zombie.tuning.apply_values({"detection_range":360,"forget_range":540})
		hero.reset_to(zombie.global_position+Vector2(zombie.facing*160,0))
		await frames(5)
		hero.health = 0
		await frames(4)
		check(zombie.state == CoreZombie.State.WAIT and zombie.velocity.x == 0 and not zombie.hear_noise(hero.global_position,1),"a defeated opponent ends crawl pursuit and cannot wake it with noise")
		hero.reset_to(CoreMovementLevel.SPAWN)
		zombie.noise_memory_left = 0
		zombie.state = CoreZombie.State.RECOVERY
		zombie.state_left = .01
		await frames(3)
		check(zombie.state == CoreZombie.State.WAIT,"attack recovery without a target returns a prone zombie to waiting")
		zombie.state = CoreZombie.State.RETURN
		await frames(4)
		check(zombie.state == CoreZombie.State.WAIT and zombie.velocity.x == 0,"an old return state cannot make a crawler head home")
		zombie.reset_target()
		await frames(8)
		check(not zombie.is_prone() and zombie.state == CoreZombie.State.PATROL and zombie.velocity.x != 0,"respawn restores normal standing patrol")
	# Waiting must retain ground support on an incline as well.
	zombie.tuning.apply_values(lab.zombie_overlay.defaults.as_dictionary())
	zombie.home = lab.level.slopes[1][0].lerp(lab.level.slopes[1][1],.5)-Vector2(0,12)
	zombie.reset_target()
	zombie.state = CoreZombie.State.RECOVERY
	zombie.state_left = 100
	await frames(20)
	zombie.state = CoreZombie.State.PATROL
	zombie.take_projectile_hit(50,"left_leg")
	await frames(20)
	var rest := zombie.global_position
	check(zombie.state == CoreZombie.State.WAIT and zombie.is_on_floor() and absf(zombie.rotation) > .5,"an unaware crawler waits grounded on the 35° incline")
	await frames(40)
	check(zombie.global_position.distance_to(rest) < .3,"waiting on a slope does not become downhill sliding")
	zombie.home = Vector2(5400,760)
	zombie.reset_target()
	for part in ["left_arm","right_arm"]: zombie.take_projectile_hit(50,part)
	await frames(8)
	check(not zombie.is_prone() and zombie.state == CoreZombie.State.PATROL and zombie.velocity.x != 0,"arm loss alone does not disable a standing zombie's patrol")
	lab.queue_free()
	await process_frame
	await create_timer(.12).timeout
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
