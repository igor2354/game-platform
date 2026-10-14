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
	for i in count:
		await physics_frame
		await process_frame
func reset_case(side: float,vision: bool,one_arm := false) -> void:
	for action in ["core_left","core_right","core_jump","core_dash","core_fire","core_aim"]: Input.action_release(action)
	zombie.tuning.apply_values(lab.zombie_overlay.defaults.as_dictionary())
	zombie.reset_target()
	for part in ["left_leg","right_leg"]: zombie.take_projectile_hit(50,part)
	if one_arm: zombie.take_projectile_hit(50,"left_arm")
	zombie.tuning.apply_values({"vision_angle":60,"vision_enabled":vision,"hearing_enabled":false,"damage_reaction_enabled":false,"movement_enabled":false,"crawl_enabled":false,"shove_delay":.15,"shove_speed":100,"shove_lift":80,"shove_cooldown":3})
	zombie.facing = side
	zombie._sync_zones()
	hero.reset_to(zombie.home+Vector2(side*4,-80))
func wait_shove() -> bool:
	for i in 150:
		await frames(1)
		if zombie.shoves_landed > 0: return true
	return false
func encounter(side: float,vision: bool,one_arm := false) -> void:
	reset_case(side,vision,one_arm)
	var label := "side %.0f vision %s one arm %s" % [side,vision,one_arm]
	check(await wait_shove(),"a real unsupported player is shoved off the crawler: "+label)
	var shove_hp := hero.health
	var attack := false
	for i in 160:
		await frames(1)
		if zombie.attacks_landed > 0:
			attack = true
			break
	check(attack and hero.health < shove_hp and hero.is_on_floor(),"without any player input, contact leads to melee damage after landing: "+label)
	check(not zombie.sees_player(360) and zombie.heard_noise_count == 0 and not zombie.damage_pursuit,"melee does not depend on the cone, movement noise or a received bullet: "+label)
	check(zombie.contact_memory_left > 0 and zombie.shoves_landed == 1,"physical contact refreshes awareness without another shove: "+label)
	if not one_arm:
		var hits := zombie.attacks_landed
		await frames(80)
		check(zombie.attacks_landed > hits,"continued stationary contact allows subsequent full attack cycles: "+label)
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	zombie = lab.level.zombie
	await frames(8)
	for side in [1.0,-1.0]:
		for vision in [true,false]: await encounter(side,vision)
		await encounter(side,false,true)
	reset_case(1,false)
	await wait_shove()
	zombie.tuning.combat_enabled = false
	zombie.apply_tuning()
	await frames(120)
	check(zombie.attacks_landed == 0 and zombie.contact_memory_left == 0 and hero.health == 90,"combat switch cancels contact awareness and prevents follow-up strikes")
	reset_case(1,false)
	await wait_shove()
	hero.reset_to(zombie.home+Vector2(180,0))
	zombie.tuning.lose_sight_delay = .2
	zombie.apply_tuning()
	await frames(25)
	check(zombie.contact_memory_left == 0 and zombie.state == CoreZombie.State.WAIT and zombie.attacks_landed == 0,"leaving contact outside reach expires awareness instead of tracking a silent player")
	reset_case(1,false)
	await wait_shove()
	paused = true
	var memory := zombie.contact_memory_left
	await frames(8)
	check(zombie.contact_memory_left == memory,"pause freezes contact memory")
	paused = false
	zombie.reset_target()
	check(zombie.contact_memory_left == 0,"respawn clears previous physical contact")
	# A silent nearby player who never touched the body is still hidden.
	for part in ["left_leg","right_leg"]: zombie.take_projectile_hit(50,part)
	hero.reset_to(zombie.home+Vector2(100,0))
	zombie.facing = -1
	await frames(25)
	check(zombie.state == CoreZombie.State.WAIT and zombie.contact_memory_left == 0,"contact awareness does not become circular proximity detection")
	# Physical contact behind a wall cannot grant a strike through geometry.
	zombie.reset_target()
	for part in ["left_leg","right_leg"]: zombie.take_projectile_hit(50,part)
	zombie.facing = 1
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4,100)
	collision.shape = rectangle
	wall.add_child(collision)
	wall.position = zombie.home+Vector2(20,-50)
	lab.level.add_child(wall)
	hero.set_physics_process(false)
	hero.reset_to(zombie.home+Vector2(30,0))
	await frames(8)
	check(not zombie._player_touching_body() and not zombie.within_melee_reach() and zombie.attacks_landed == 0,"a wall blocks both contact awareness and melee")
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
