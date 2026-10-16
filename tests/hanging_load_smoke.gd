extends SceneTree
var lab: CoreMovementLab
var checks := 0
var failures := 0
var fixtures: Array[Node] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame
func shoot(point: Vector2) -> void:
	lab.player.weapon.aim_override = point
	lab.player.weapon._update_aim()
	lab.player.weapon._fire()
	await frames(22)
func reset_area() -> void:
	lab.player.reset_to(CoreMovementLevel.HANGING_TEST_SPAWN)
	lab._reset_hanging_loads()
	for node in fixtures:
		if is_instance_valid(node): node.queue_free()
	fixtures.clear()
	for bullet in get_nodes_in_group("core_projectiles"): bullet.queue_free()
	await frames(8)
func dummy_at(point: Vector2) -> CoreEnemyDummy:
	var target := CoreEnemyDummy.new()
	target.position = point
	target.damage_tuning = lab.player.weapon.tuning
	lab.level.add_child(target)
	fixtures.append(target)
	return target
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	load("res://tests/hanging_legacy_fixtures.gd").install(lab)
	# This suite isolates the intact load's contact damage; rupture has its own suite.
	lab.ragdoll_settings.hanging_net_tear_enabled = false
	# Isolate the temporary impact fixtures from the arena's permanent target.
	lab.level.enemies.erase(lab.level.hanging_target)
	lab.level.hanging_target.queue_free()
	var hero := lab.player
	var gun := hero.weapon
	gun.tuning.apply_values({"sound_enabled":false,"hip_spread":0,"hip_max_spread":0,"recoil_enabled":false,"magazine_enabled":false})
	var loads := lab.level.hanging_loads
	await frames(12)
	check(loads.size() == 3 and loads.all(func(item): return item.body is RigidBody2D and is_instance_valid(item.joint)),"three distinct materials are held by real rigid-body joints")
	var initial: Vector2 = loads[0].body.global_position
	await frames(180)
	check(loads[0].body.global_position.distance_to(initial) < 3,"the intact suspension supports gravity without slowly falling")
	check(loads.all(func(item): return not item.released and not item.body.can_grab()),"an attached cargo cannot be pulled free using G")
	await reset_area()
	var trap := loads[0]
	var target := dummy_at(Vector2(trap.position.x,760))
	await frames(4)
	var resting := trap.body.global_position
	await shoot(trap.rope.global_position)
	check(trap.released and trap.release_reason == "трос" and trap.instigator == hero,"a real bullet severs the cable and remembers its shooter")
	check(not is_instance_valid(trap.joint) and trap.rope.collision_layer == 0 and trap.mount.collision_layer == 0,"cutting removes the physical joint and stale hit targets")
	await frames(30)
	check(trap.body.global_position.y > resting.y+25 and trap.body.can_grab(),"the released load falls through real gravity and becomes a free prop")
	check(target.health < 100 and target.received_hits == 1 and trap.impact_count == 1,"an actual falling-body contact damages the enemy once")
	check(trap.last_impact_speed > 300 and trap.last_damage > 0 and gun.hits > 0,"incoming impact speed drives damage and the shooter's hit feedback")
	check(target.is_knocked_down() or target.health <= 0,"a fast load impact knocks down surviving enemies")
	await frames(200)
	var health := target.health
	await frames(180)
	check(target.health == health and trap.body.global_position.y < 780,"resting cargo remains physical without continuous contact damage")
	await reset_area()
	trap = loads[0]
	await shoot(trap.mount.global_position)
	check(trap.released and trap.release_reason == "крепление","a separate real shot can destroy the suspension mechanism")
	await reset_area()
	trap = loads[0]
	await shoot(trap.body.global_position)
	check(not trap.released and is_instance_valid(trap.joint) and trap.rope.health == lab.ragdoll_settings.hanging_rope_health,"a bullet hitting the netted cargo cannot bypass the suspension targets")
	await reset_area()
	trap = loads[0]
	lab.ragdoll_settings.hanging_rope_health = 50
	trap.reset_load()
	await frames(4)
	await shoot(trap.rope.global_position)
	check(not trap.released and trap.rope.health == 25 and trap.rope.hits == 1,"cable strength supports multiple accepted bullet hits")
	await shoot(trap.rope.global_position)
	check(trap.released,"the second shot cuts the reinforced cable at zero HP")
	lab.ragdoll_settings.hanging_rope_health = 15
	await reset_area()
	trap = loads[0]
	gun.tuning.damage_enabled = false
	await shoot(trap.rope.global_position)
	check(not trap.released and trap.rope.hits == 0,"the weapon damage switch also protects the suspension")
	gun.tuning.damage_enabled = true
	var reference_damage := trap.damage_for_speed(500)
	check(trap.damage_for_speed(1000) > reference_damage*3.99,"doubling closing speed quadruples uncapped impact energy")
	check(loads[2].damage_for_speed(500) > reference_damage and loads[1].damage_for_speed(500) < reference_damage,"different mass, size and contents produce materially different damage")
	check(trap.damage_for_speed(0) == 0 and trap.damage_for_speed(NAN) == 0,"slow, resting or non-finite contacts cannot deal damage")
	var old_mass := trap.body.mass
	lab.ragdoll_settings.hanging_base_mass *= 2
	lab._ragdoll_settings_changed()
	check(is_equal_approx(trap.body.mass,old_mass*2) and trap.damage_for_speed(500) > reference_damage*1.99,"live mass changes affect real physics and impact damage together")
	lab.ragdoll_settings.hanging_base_mass /= 2
	lab._ragdoll_settings_changed()
	await reset_area()
	trap = loads[0]
	trap.release_load(hero)
	await frames(8)
	lab.ragdoll_settings.hanging_enabled = false
	lab._ragdoll_settings_changed()
	var frozen: Transform2D = trap.body.global_transform
	await frames(50)
	check(trap.body.freeze and trap.body.global_transform.is_equal_approx(frozen),"the master switch freezes only the load's current physical state (delta %s)" % trap.body.global_position.distance_to(frozen.origin))
	lab.ragdoll_settings.hanging_enabled = true
	lab._ragdoll_settings_changed()
	await frames(30)
	check(not trap.body.freeze and trap.body.global_position.y > frozen.origin.y+20,"reenabling resumes the released load instead of reattaching it")
	await reset_area()
	trap = loads[0]
	lab.ragdoll_settings.hanging_impact_enabled = false
	target = dummy_at(Vector2(trap.position.x,760))
	await shoot(trap.rope.global_position)
	await frames(60)
	check(trap.released and target.health == 100 and target.received_hits == 0,"the impact switch preserves falling physics while disabling damage and knockdown")
	lab.ragdoll_settings.hanging_impact_enabled = true
	await reset_area()
	trap = loads[0]
	hero.reset_to(Vector2(trap.position.x,760))
	hero.set_invulnerable(false)
	trap.release_load()
	await frames(45)
	check(hero.health < 100 and trap.impact_count > 0,"a real falling load also damages the player")
	check(hero.barrel_knockdown_left > 0 or hero.health <= 0,"player impact reuses the shared physical knockdown instead of leaving normal controls active")
	await reset_area()
	trap = loads[0]
	hero.reset_to(Vector2(trap.position.x,760))
	hero.set_invulnerable(true)
	trap.release_load()
	await frames(45)
	check(hero.health == 100 and trap.impact_count > 0,"player immortality preserves HP under a real load impact (HP %s hits %s hero %s load %s)" % [hero.health,trap.impact_count,hero.position,trap.body.global_position])
	hero.set_invulnerable(false)
	await reset_area()
	trap = loads[0]
	trap.release_load(hero)
	trap.reset_load()
	await frames(15)
	check(not trap.released and is_instance_valid(trap.joint) and trap.rope.collision_layer == CoreHangingSupport.HIT_LAYER,"a queued detach cannot undo an immediate restore")
	trap.release_load(hero)
	await frames(10)
	paused = true
	frozen = trap.body.global_transform
	await frames(20)
	check(trap.body.global_transform.is_equal_approx(frozen),"pause freezes falling cargo")
	paused = false
	lab.developer_mode.debug_toggle.button_pressed = true
	check(loads.all(func(item): return item.debug_shapes),"F1 debug covers cable, attachment and load hull")
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.set_enabled(false)
	check(loads.all(func(item): return item.debug_shapes),"debug targets survive closing developer mode")
	lab._recover()
	await frames(8)
	check(loads.all(func(item): return not item.released and is_instance_valid(item.joint) and item.impact_count == 0 and item.rope.health == lab.ragdoll_settings.hanging_rope_health),"F8 restores every suspension, health, physical pose and hit bookkeeping")
	for bullet in get_nodes_in_group("core_projectiles"): bullet.queue_free()
	for node in fixtures:
		if is_instance_valid(node): node.queue_free()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
