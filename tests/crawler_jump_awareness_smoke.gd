extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var zombie: CoreZombie
var checks := 0
var failures := 0
const ACTIONS := ["core_left","core_right","core_jump","core_fire","core_aim","core_dash"]
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
func setup(side: float,both_legs: bool,recovery: float,moving := false) -> void:
	release()
	zombie.tuning.apply_values(lab.zombie_overlay.defaults.as_dictionary())
	zombie.reset_target()
	zombie.tuning.apply_values({"hearing_enabled":false,"movement_enabled":moving,"shove_enabled":false,"combat_enabled":false,"attack_recovery":recovery})
	zombie.facing = side
	hero.reset_to(zombie.home+Vector2(side*35,0))
	hero.set_invulnerable(true)
	hero.tuning.air_acceleration = 4000
	hero.weapon.aim_override = zombie.home-Vector2(0,17)
	await frames(5)
	zombie.take_projectile_hit(50,"left_leg",Vector2(-side,0),hero.weapon.pivot())
	if both_legs: zombie.take_projectile_hit(50,"right_leg",Vector2(-side,0),hero.weapon.pivot())
	await frames(3)
	zombie.tuning.combat_enabled = true
	await frames(2)
func jump_over(side: float) -> bool:
	var phase_facing := zombie.facing
	var attack_count := zombie.attacks_started
	var locked := true
	Input.action_press("core_jump")
	Input.action_press("core_left" if side > 0 else "core_right")
	await frames(3)
	# Isolate ordinary target memory from any previous contact on takeoff.
	zombie.contact_memory_left = 0
	zombie.contact_followup = false
	for i in 45:
		await frames(1)
		if zombie.state in [CoreZombie.State.WINDUP,CoreZombie.State.RECOVERY] and zombie.attacks_started == attack_count:
			locked = locked and zombie.facing == phase_facing
		if (hero.global_position.x-zombie.global_position.x)*side <= -27: break
	Input.action_release("core_left")
	Input.action_release("core_right")
	await frames(25)
	Input.action_release("core_jump")
	await frames(12)
	return locked
func encounter(side: float,both_legs: bool,recovery: float,moving := false) -> void:
	await setup(side,both_legs,recovery,moving)
	var label := "side %.0f both legs %s recovery %.1f moving %s" % [side,both_legs,recovery,moving]
	check(zombie.is_prone() and zombie.state == CoreZombie.State.WINDUP,"actual leg severing establishes an engaged crawler: "+label)
	var facing := zombie.facing
	check(await jump_over(side),"the committed swing keeps its original facing during the jump: "+label)
	check(hero.is_on_floor() and (hero.global_position.x-zombie.global_position.x)*side < -25 and zombie.shoves_landed == 0,"a real jump lands beside the opposite side without requiring a shove: "+label)
	var landed_at := hero.global_position
	await frames(150)
	check(zombie.state in [CoreZombie.State.CHASE,CoreZombie.State.WINDUP,CoreZombie.State.RECOVERY] and zombie.facing == -facing,"the crawler retains and turns to the stationary close player after the jump: "+label)
	check(zombie.attacks_started > 1 and zombie.heard_noise_count == 0,"continued melee does not require steps, gunfire or a shove: "+label)
	check(hero.global_position.distance_to(landed_at) < .5,"no new player input is needed to sustain awareness")
	await jump_over(-side)
	await frames(100)
	check(zombie.state in [CoreZombie.State.CHASE,CoreZombie.State.WINDUP,CoreZombie.State.RECOVERY] and zombie.facing == facing,"a repeated jump back across the same crawler retains combat awareness: "+label)
	hero.set_invulnerable(false)
	await frames(100)
	check(zombie.attacks_landed > 0 and hero.health < hero.maximum_health(),"the reacquired close target can receive actual melee damage: "+label)
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	zombie = lab.level.zombie
	await frames(8)
	for side in [-1.0,1.0]:
		for both in [false,true]:
			for recovery in [.2,.8]: await encounter(side,both,recovery)
		for both in [false,true]: await encounter(side,both,.8,true)
	# Nearby retention requires real prior awareness, a clear path and memory.
	hero.set_physics_process(false)
	for side in [-1.0,1.0]:
		hero.reset_to(CoreMovementLevel.SPAWN)
		zombie.tuning.apply_values(lab.zombie_overlay.defaults.as_dictionary())
		zombie.reset_target()
		zombie.tuning.apply_values({"hearing_enabled":false,"movement_enabled":false,"shove_enabled":false})
		for part in ["left_leg","right_leg"]: zombie.take_projectile_hit(50,part)
		zombie.facing = side
		hero.reset_to(zombie.home-Vector2(side*35,0))
		await frames(20)
		check(zombie.state == CoreZombie.State.WAIT and not zombie.visual_target_known and not zombie.contact_followup,"a silent nearby rear approach cannot wake an unaware crawler")
		await setup(side,true,.2)
		zombie.contact_memory_left = 0
		zombie.contact_followup = false
		zombie.state = CoreZombie.State.CHASE
		hero.reset_to(zombie.home-Vector2(side*160,0))
		var remembered := zombie.last_seen_position
		await frames(120)
		check(zombie.state == CoreZombie.State.WAIT and not zombie.visual_target_known and zombie.last_seen_position == remembered,"leaving close range expires memory without tracking a silent hidden player")
		await setup(side,true,.2)
		zombie.contact_memory_left = 0
		zombie.contact_followup = false
		zombie.state = CoreZombie.State.CHASE
		hero.reset_to(zombie.home-Vector2(side*50,0))
		var wall := StaticBody2D.new()
		wall.collision_layer = 1
		wall.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(4,160)
		shape.shape = rectangle
		wall.add_child(shape)
		wall.position = zombie.home-Vector2(side*25,80)
		lab.level.add_child(wall)
		await frames(2)
		check(not zombie._sees_tracked_close_player(),"a wall blocks retention of a known nearby player")
		await frames(120)
		check(zombie.state == CoreZombie.State.WAIT and not zombie.visual_target_known,"a target hidden by a wall is forgotten normally")
		wall.queue_free()
		await frames(2)
	await setup(1,true,.2)
	zombie.contact_memory_left = 0
	zombie.contact_followup = false
	zombie.tuning.vision_enabled = false
	zombie.apply_tuning()
	await frames(8)
	check(not zombie.visual_target_known and not zombie._sees_tracked_close_player(),"disabling vision also disables nearby visual retention")
	await frames(50)
	check(zombie.state == CoreZombie.State.WAIT,"the committed phase finishes without resuming disabled visual tracking")
	await setup(1,true,.2)
	zombie.contact_memory_left = 0
	zombie.contact_followup = false
	zombie.state = CoreZombie.State.CHASE
	hero.reset_to(zombie.home-Vector2(160,0))
	await frames(5)
	paused = true
	var memory := zombie.unseen_left
	await frames(20)
	check(zombie.unseen_left == memory and zombie.visual_target_known,"pause freezes the new visual memory together with the world")
	paused = false
	zombie.reset_target()
	check(not zombie.visual_target_known and zombie.contact_memory_left == 0,"respawn clears prior visual and contact awareness")
	await setup(1,true,.2)
	hero.set_current_health(0)
	await frames(8)
	check(not zombie.visual_target_known and zombie.contact_memory_left == 0 and not zombie._has_target_memory(),"a defeated hero ends all crawler awareness")
	await frames(50)
	check(zombie.state == CoreZombie.State.WAIT,"after the committed phase a dead target cannot restart pursuit")
	release()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
