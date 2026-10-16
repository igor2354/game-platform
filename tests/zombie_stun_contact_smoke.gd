extends SceneTree

var lab: CoreMovementLab
var hero: CoreMovementPlayer
var zombie: CoreZombie
var checks := 0
var failures := 0
var original_home := Vector2.ZERO
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
	for action in ["core_left","core_right","core_dash","core_crouch"]: Input.action_release(action)
func setup(side: float,vision := true) -> void:
	release()
	hero.reset_to(Vector2(160,760))
	zombie.home = original_home
	zombie.tuning.apply_values(lab.zombie_overlay.defaults.as_dictionary())
	zombie.tuning.apply_values({"vision_enabled":vision,"vision_angle":60,"hearing_enabled":false,"damage_reaction_enabled":false,"lose_sight_delay":.15,"dash_stun_duration":1.5,"patrol_speed":0,"chase_speed":30,"attack_windup":.15,"attack_recovery":.2})
	zombie.reset_target()
	zombie.global_position = original_home-Vector2(side*120,0)
	zombie.facing = -side
	zombie.patrol_direction = -side
	zombie._sync_zones()
	hero.tuning.apply_values(lab.movement_overlay.defaults.as_dictionary())
	hero.tuning.apply_values({"dash_speed":600,"dash_duration":.16,"crouch_speed_multiplier":.45})
	hero.reset_to(zombie.global_position-Vector2(side*50,0))
	hero.set_invulnerable(true)
	hero.weapon.aim_override = zombie.global_position-Vector2(side*300,36)
	await frames(5)
func dash_and_approach(side: float) -> void:
	Input.action_press("core_right" if side > 0 else "core_left")
	Input.action_press("core_dash")
	await frames(1)
	for tick in 30:
		if hero.dash_left <= 0: break
		await frames(1)
	release()
	Input.action_press("core_crouch")
	Input.action_press("core_left" if side > 0 else "core_right")
	await frames(40)
	Input.action_release("core_left")
	Input.action_release("core_right")
func wall_at(point: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2,120)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = point-Vector2(0,60)
	lab.level.add_child(wall)
	return wall
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	zombie = lab.level.zombie
	original_home = zombie.home
	await frames(8)
	for side in [-1.0,1.0]:
		for vision in [true,false]:
			await setup(side,vision)
			await dash_and_approach(side)
			check(hero.dashes == 1 and zombie.stuns_received == 1 and zombie.is_stunned() and hero.crouching,"real dash stuns and a silent crouched approach reaches its rear: %s / vision %s" % [side,vision])
			check(zombie._player_touching_body(),"crouched approach reaches actual solid-body contact rather than merely melee range")
			var facing := zombie.facing
			var attacks := zombie.attacks_started
			await frames(8)
			check(zombie.is_stunned() and zombie.facing == facing and zombie.attacks_started == attacks,"touching during stun cannot turn or prematurely wake the zombie")
			await frames(85)
			check(zombie.attacks_started > attacks and zombie.facing == side,"after stun, a silent crouched contact is detected even outside the cone or without sight")
			check(zombie.contact_memory_left > 0 and zombie.heard_noise_count == 0,"body contact establishes independent awareness without inventing noise")
			hero.set_invulnerable(false)
			await frames(35)
			check(hero.health < 100 and zombie.attacks_landed > 0,"a crouched stationary hero receives actual melee damage after recovery")
			var count := zombie.attacks_started
			Input.action_release("core_crouch")
			await frames(35)
			check(not hero.crouching and zombie.attacks_started > count,"standing back up does not strand the zombie in return-to-patrol")
	# Return can be physically blocked by a crouched capsule, even where the
	# drawn shins/hands do not overlap that capsule. The solid body still feels it.
	for side in [-1.0,1.0]:
		await setup(side,false)
		zombie.tuning.patrol_speed = 60
		zombie.state = CoreZombie.State.RETURN
		zombie.visual_target_known = false
		zombie.unseen_left = 0
		zombie.contact_memory_left = 0
		zombie.contact_followup = false
		zombie.facing = -side
		hero.reset_to(zombie.global_position+Vector2(side*32,0))
		Input.action_press("core_crouch")
		Input.action_press("core_left" if side > 0 else "core_right")
		await frames(10)
		Input.action_release("core_left")
		Input.action_release("core_right")
		await frames(50)
		check(zombie.attacks_started > 0 and zombie.contact_followup,"physical contact interrupts RETURN even with no prior chase or auditory memory")
		zombie.tuning.combat_enabled = false
		zombie.apply_tuning()
		var count := zombie.attacks_started
		await frames(30)
		check(zombie.contact_memory_left == 0 and zombie.attacks_started == count,"combat switch also disables the new contact recovery")
		zombie.tuning.combat_enabled = true
		zombie.apply_tuning()
		await frames(40)
		check(zombie.attacks_started > count,"re-enabling combat discovers the still touching player without new input")
	# Silence behind the back remains useful until there is actual contact.
	for side in [-1.0,1.0]:
		await setup(side,false)
		zombie.tuning.movement_enabled = false
		hero.reset_to(zombie.global_position+Vector2(side*36,0))
		Input.action_press("core_crouch")
		await frames(80)
		check(zombie.attacks_started == 0 and not zombie.contact_followup and zombie.contact_memory_left == 0,"a nearby silent player without contact remains hidden")
		hero.reset_to(zombie.global_position+Vector2(side*30.3,0))
		Input.action_press("core_crouch")
		var wall := wall_at(zombie.global_position+Vector2(side*16.15,0))
		await frames(50)
		check(not zombie._player_touching_body() and zombie.attacks_started == 0,"a thin intervening wall blocks contact awareness")
		wall.queue_free()
		await frames(2)
		zombie.reset_target()
		check(zombie.contact_memory_left == 0 and not zombie.contact_followup,"respawn clears contact engagement")
	# Contact supplies a target for the next attack, not a backwards hit or a
	# mid-swing rotation. Only stun itself may interrupt a committed attack.
	for side in [-1.0,1.0]:
		await setup(side,false)
		zombie.tuning.movement_enabled = false
		hero.reset_to(zombie.global_position+Vector2(side*30.1,0))
		Input.action_press("core_crouch")
		zombie.state = CoreZombie.State.WINDUP
		zombie.state_left = .2
		zombie.windup_duration = .2
		await frames(6)
		check(zombie.facing == -side and zombie.state == CoreZombie.State.WINDUP and zombie.attacks_landed == 0,"contact behind a committed swing cannot turn that swing around")
		await frames(60)
		check(zombie.facing == side and zombie.attacks_started > 0,"the next attack turns towards the touching player after recovery")
	release()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
