extends SceneTree

var lab: CoreMovementLab
var zombie: CoreZombie
var hero: CoreMovementPlayer
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for tick in count: await physics_frame
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)

func setup(side: float,waiting := false,prone := false,distance := 120.0) -> void:
	Input.action_release("core_fire")
	Input.action_release("core_aim")
	for bullet in get_nodes_in_group("core_projectiles"): bullet.queue_free()
	zombie.tuning.apply_values(lab.zombie_overlay.defaults.as_dictionary())
	zombie.tuning.hearing_range = 0
	zombie.tuning.detection_range = 32
	zombie.tuning.forget_range = 32
	zombie.reset_target()
	if prone: zombie.take_projectile_hit(50,"left_leg")
	zombie.facing = -side
	zombie.patrol_direction = -side
	zombie.state = CoreZombie.State.WAIT if waiting else CoreZombie.State.PATROL
	hero.reset_to(zombie.home+Vector2(side*distance,0))
	hero.weapon.tuning.fire_mode = CoreShootingSettings.FireMode.SINGLE
	hero.weapon.tuning.hip_spread = 0
	hero.weapon.tuning.hip_max_spread = 0
	hero.weapon.tuning.bullet_speed = 2400
	hero.weapon.aim_override = zombie.aim_point_for_part("torso")
	await frames(4)

func fire() -> void:
	Input.action_press("core_fire")
	await frames(2)
	Input.action_release("core_fire")

func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	zombie = lab.level.zombie
	await frames(8)
	for side in [1.0,-1.0]:
		for kind in ["patrol","idle","crawler"]:
			await setup(side,kind != "patrol",kind == "crawler")
			var before := zombie.health
			var origin := hero.weapon.pivot()
			check(not zombie.sees_player(360) and zombie.heard_noise_count == 0,"player behind "+kind+" is initially unnoticed")
			await fire()
			await frames(8)
			check(zombie.health < before and hero.weapon.hits == 1,"real player bullet damages "+kind+" from side %.0f" % side)
			check(zombie.state == CoreZombie.State.CHASE and zombie.facing == side and zombie.velocity.x*side > 0,"damage wakes and turns "+kind+" toward the attacker")
			check(zombie.last_seen_position.distance_to(origin) < .01 and zombie.heard_noise_count == 0,"damage reaction is independent of hearing and vision range")
		# The pivot-to-muzzle ray must alert the zombie just like a flying bullet.
		await setup(side,true,false,33)
		var before := zombie.health
		await fire()
		await frames(2)
		check(zombie.health < before and (zombie.state == CoreZombie.State.CHASE or (zombie.state == CoreZombie.State.WINDUP and zombie.attacks_started > 0)) and zombie.facing == side,"point-blank muzzle impact alerts the idle zombie, allowing an immediate committed melee windup")
	# Remember the shot's origin even if the player moves before impact.
	await setup(1,true)
	hero.weapon.tuning.bullet_speed = 200
	var origin := hero.weapon.pivot()
	await fire()
	check(zombie.health == 100 and zombie.state == CoreZombie.State.WAIT,"a silent shot alone does not alert a zombie before the bullet arrives")
	hero.reset_to(CoreMovementLevel.SPAWN)
	await frames(45)
	check(zombie.health < 100 and zombie.state == CoreZombie.State.CHASE and zombie.facing > 0,"a delayed hit still alerts the zombie after the shooter leaves")
	check(zombie.last_seen_position == origin,"a hit remembers the firing position rather than the hidden player's new position")
	await frames(110)
	check(zombie.state == CoreZombie.State.RETURN,"unseen damage-source memory expires using the normal target memory")
	# All six anatomical regions use the same reaction, including a falling leg.
	for part in CoreEnemyDummy.PARTS:
		await setup(1,true)
		origin = hero.weapon.pivot()
		zombie.take_projectile_hit(50 if part.ends_with("leg") else 10,part,Vector2.LEFT,origin)
		check(zombie.state == CoreZombie.State.CHASE and zombie.facing > 0 and zombie.last_seen_position == origin,"damage to "+part+" alerts immediately")
		if part.ends_with("leg"):
			await frames(4)
			check(zombie.is_prone() and zombie.state == CoreZombie.State.CHASE and zombie.velocity.x > 0,"severing "+part+" starts crawling toward the damage source")
	await setup(1,true)
	origin = hero.weapon.pivot()
	zombie.take_projectile_hit(0,"torso",Vector2.LEFT,origin)
	zombie.take_projectile_hit(-1,"torso",Vector2.LEFT,origin)
	zombie.take_projectile_hit(NAN,"torso",Vector2.LEFT,origin)
	zombie.take_projectile_hit(10,"unknown",Vector2.LEFT,origin)
	check(zombie.health == 100 and zombie.state == CoreZombie.State.WAIT,"rejected or zero-damage hits do not alert the zombie")
	zombie.take_projectile_hit(10,"torso",Vector2.LEFT,Vector2(NAN,0))
	check(zombie.state == CoreZombie.State.WAIT,"invalid attack coordinates cannot become a pursuit target")
	zombie.take_projectile_hit(200,"torso",Vector2.LEFT,origin)
	await frames(2)
	check(zombie.health == 0 and zombie.state == CoreZombie.State.DEAD,"a lethal hit kills instead of starting pursuit")
	zombie.take_projectile_hit(10,"torso",Vector2.LEFT,origin)
	check(zombie.state == CoreZombie.State.DEAD,"a dead zombie cannot be awakened by damage")
	await setup(1,true)
	zombie.state = CoreZombie.State.WINDUP
	zombie.state_left = .5
	zombie.take_projectile_hit(10,"torso",Vector2.LEFT,hero.weapon.pivot())
	check(zombie.state == CoreZombie.State.WINDUP and zombie.facing < 0 and zombie.state_left == .5,"damage preserves a committed melee windup and its facing")
	zombie.reset_target()
	check(zombie.state == CoreZombie.State.PATROL and zombie.last_seen_position == zombie.home,"respawn clears the damage source and restores patrol")
	Input.action_release("core_fire")
	hero.weapon.reset_state()
	for bullet in get_nodes_in_group("core_projectiles"): bullet.queue_free()
	await create_timer(.15).timeout
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
