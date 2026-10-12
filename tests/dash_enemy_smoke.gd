extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var target: CoreEnemyDummy
var checks := 0
var failures := 0
const ACTIONS := ["core_left","core_right","core_jump","core_dash","core_fire","core_aim"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func release() -> void:
	for action in ACTIONS: Input.action_release(action)
func settle(point: Vector2) -> void:
	release()
	hero.reset_to(point)
	await frames(8)
func dash(direction: float) -> void:
	Input.action_press("core_right" if direction > 0 else "core_left")
	Input.action_press("core_dash")
	await frames(3)
	Input.action_release("core_dash")
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	target = lab.level.enemies[0]
	await settle(Vector2(2400,760))
	Input.action_press("core_right")
	await frames(25)
	check(hero.position.x <= 2431 and hero.get_collision_mask_value(3),"ordinary running is still blocked by live enemies")
	await dash(1)
	check(hero.dash_left > 0 and not hero.get_collision_mask_value(3) and target.collision_layer == 4,"dash phases only the player without disabling enemy hit collision")
	await frames(10)
	check(hero.position.x > 2490 and hero.get_collision_mask_value(3) and hero.dash_overlap_exceptions.is_empty() and target.position == Vector2(2460,760),"forward dash exits through the enemy and restores ordinary collision")
	await settle(Vector2(2520,760))
	await dash(-1)
	await frames(10)
	check(hero.position.x < 2430 and hero.get_collision_mask_value(3),"backward dash passes through an enemy too")
	await settle(Vector2(2420,725))
	await dash(1)
	check(not hero.is_on_floor() and not hero.get_collision_mask_value(3),"air dash also phases through enemy bodies")
	await frames(10)
	check(hero.position.x > 2490 and hero.get_collision_mask_value(3),"air dash restores enemy collision when it finishes")
	var extras: Array[CoreEnemyDummy] = []
	for x in [2476,2492]:
		var dummy := CoreEnemyDummy.new()
		dummy.position = Vector2(x,760)
		hero.get_parent().add_child(dummy)
		extras.append(dummy)
	await settle(Vector2(2420,760))
	await dash(1)
	await frames(10)
	check(hero.position.x > 2522 and hero.get_collision_mask_value(3),"a single dash crosses a compact group of overlapping enemies")
	for dummy in extras: dummy.queue_free()
	await frames(2)
	var default_duration := hero.tuning.dash_duration
	hero.tuning.dash_duration = .10
	await settle(Vector2(2390,760))
	await dash(1)
	release()
	await frames(9)
	check(hero.dash_left == 0 and hero.get_collision_mask_value(3) and target in hero.dash_overlap_exceptions,"ending inside an enemy grants only that body a temporary exit exception")
	check(lab.level.enemies[1] not in hero.get_collision_exceptions(),"unrelated enemies keep their normal blocking collision")
	Input.action_press("core_right")
	await frames(12)
	check(hero.position.x > 2490 and hero.dash_overlap_exceptions.is_empty() and target not in hero.get_collision_exceptions(),"walking out clears the exception without teleporting or getting stuck")
	Input.action_release("core_right")
	await frames(10)
	Input.action_press("core_left")
	await frames(25)
	check(hero.position.x >= 2489,"the same enemy blocks a normal return after exiting")
	hero.tuning.dash_duration = default_duration
	target.position = Vector2(610,760)
	await settle(Vector2(550,760))
	await dash(1)
	await frames(8)
	check(hero.position.x <= 627 and hero.dash_left == 0 and hero.get_collision_mask_value(1),"a wall still stops the dash even with an enemy in front of it")
	target.position = Vector2(2460,760)
	await settle(Vector2(2400,760))
	await dash(1)
	paused = true
	var held := [hero.position,hero.dash_left,hero.collision_mask]
	await frames(8)
	check(held == [hero.position,hero.dash_left,hero.collision_mask],"pause freezes the dash and its collision state")
	paused = false
	release()
	hero.reset_to(Vector2(2400,760))
	check(hero.collision_mask == CoreMovementPlayer.WORLD_MASK and hero.dash_overlap_exceptions.is_empty(),"reset during a dash restores the complete collision mask")
	hero.tuning.dash_duration = .10
	await settle(Vector2(2390,760))
	await dash(1)
	release()
	await frames(9)
	hero.reset_to(Vector2(2400,760))
	check(hero.dash_overlap_exceptions.is_empty() and target not in hero.get_collision_exceptions(),"reset inside an enemy removes temporary exceptions")
	await settle(Vector2(2390,760))
	await dash(1)
	release()
	await frames(9)
	target.take_damage(100)
	await frames(2)
	check(hero.dash_overlap_exceptions.is_empty(),"a defeated enemy's disabled collider clears its exit exception")
	target.reset_target()
	await settle(Vector2(2390,760))
	await dash(1)
	release()
	await frames(9)
	# Replace the first target temporarily to exercise actual body deletion.
	var disappearing := CoreEnemyDummy.new()
	disappearing.position = target.position
	hero.get_parent().add_child(disappearing)
	target.collision_layer = 0
	await settle(Vector2(2390,760))
	await dash(1)
	release()
	await frames(9)
	disappearing.queue_free()
	await frames(3)
	check(hero.dash_overlap_exceptions.is_empty(),"a freed enemy body does not leave an invalid exception")
	target.reset_target()
	hero.tuning.dash_duration = default_duration
	await settle(Vector2(2390,760))
	await dash(1)
	var bullet := CoreProjectile.new()
	bullet.direction = Vector2.RIGHT
	bullet.damage = 25
	bullet.shooter = hero.get_rid()
	bullet.position = Vector2(2400,728)
	hero.get_parent().add_child(bullet)
	await frames(2)
	check(hero.dash_left > 0 and target.health == 75,"projectiles still hit an enemy while the player is dashing through it")
	release()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
