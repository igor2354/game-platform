extends SceneTree
var lab: CoreMovementLab
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
	for frame in count:
		await physics_frame
		await process_frame
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	load("res://tests/hanging_legacy_fixtures.gd").install(lab)
	lab.player.weapon.tuning.sound_enabled = false
	lab.level.enemies.erase(lab.level.hanging_target)
	lab.level.hanging_target.queue_free()
	var loads := lab.level.hanging_loads
	var profile := lab.ragdoll_settings
	await frames(15)
	check(profile.hanging_net_tear_enabled and loads.all(func(item): return not item.ruptured and item.fragments.is_empty()),"nets remain intact under suspended weight with tearing enabled by default")
	for item in loads: item.release_load(lab.player)
	await frames(10)
	check(loads.all(func(item): return not item.ruptured),"cutting a cable starts a fall without prematurely spilling its contents")
	for step in 150:
		if loads.all(func(item): return item.ruptured): break
		await frames(1)
	check(loads.all(func(item): return item.ruptured and item.fragments.size() == item.body.chunks.size()),"real floor impacts rupture rubble, wood and metal loads and release every drawn item")
	check(loads.all(func(item): return not item.body.visible and item.body.freeze and item.body.collision_layer == 0 and item.body.get_node("Shape").disabled and not item.body.can_grab()),"the old bag has no visible or invisible physical shell after rupture")
	for item in loads:
		var total := 0.0
		for piece in item.fragments: total += piece.mass
		check(is_equal_approx(total,item.body.mass) and item.fragments.all(func(piece): return piece is RigidBody2D and piece.get_child(0) is CollisionShape2D),"all released contents have individual colliders and conserve cargo mass: "+item.content_name())
	var trap := loads[0]
	var net = trap.torn_net
	check(net.knots.size() == 20 and net.links.size() == 31 and net.broken_links > 0 and net.broken_links < net.links.size(),"impact opens a seam while the rest of the net retains real spring connections")
	var captured: Array[Transform2D] = []
	for piece in trap.fragments: captured.append(piece.global_transform)
	var net_captured: Array[Transform2D] = []
	for knot in net.knots: net_captured.append(knot.global_transform)
	profile.hanging_enabled = false
	lab._ragdoll_settings_changed()
	await frames(15)
	var fixed := true
	for index in trap.fragments.size(): fixed = fixed and trap.fragments[index].freeze and trap.fragments[index].global_transform.is_equal_approx(captured[index])
	for index in net.knots.size(): fixed = fixed and net.knots[index].freeze and net.knots[index].global_transform.is_equal_approx(net_captured[index])
	check(fixed,"master OFF freezes both the scattered contents and every physical net knot")
	profile.hanging_enabled = true
	lab._ragdoll_settings_changed()
	await frames(12)
	check(trap.fragments.any(func(piece): return not piece.freeze and piece.linear_velocity.length() > 5),"master ON resumes fragment momentum without rebuilding the load")
	var intact: Dictionary = net.links.filter(func(link): return not link.broken)[0]
	var knot: RigidBody2D = net.knots[intact.a]
	var away: Vector2 = (knot.global_position-net.knots[intact.b].global_position).normalized()
	var strain_before: int = net.strain_breaks
	knot.apply_central_impulse(away*85)
	knot.sleeping = false
	await frames(12)
	check(net.strain_breaks > strain_before,"an actual physical impulse stretches and tears remaining net links")
	await frames(180)
	var left := INF
	var right := -INF
	var contained := true
	for item in loads:
		for piece in item.fragments:
			contained = contained and piece.global_position.is_finite() and piece.global_position.y < 785 and piece.global_position.y > 400 and piece.linear_velocity.length() < 300
	for piece in trap.fragments:
		left = minf(left,piece.global_position.x)
		right = maxf(right,piece.global_position.x)
	check(right-left > trap.body.dimensions.x+20,"impact spreads the rubble outside the former bag instead of leaving a solid pile (%0.f px)" % (right-left))
	check(contained,"all material types settle on real floor without tunnelling or explosive overlapping colliders")
	check(trap.fragments.size() == 12 and is_instance_valid(trap.torn_net),"scattered cargo and net remnants persist after settling")
	var poses: Array[Transform2D] = []
	for piece in trap.fragments: poses.append(piece.global_transform)
	paused = true
	await frames(15)
	var pause_fixed := true
	for index in trap.fragments.size(): pause_fixed = pause_fixed and trap.fragments[index].global_transform.is_equal_approx(poses[index])
	check(pause_fixed,"pause stops every released physical piece")
	paused = false
	lab._respawn_enemies()
	check(trap.ruptured and trap.fragments.size() == 12,"F7 leaves physical wreckage in the arena")
	lab._reset_hanging_loads()
	await frames(12)
	check(get_nodes_in_group("hanging_fragments").is_empty() and loads.all(func(item): return item.fragments.is_empty() and not is_instance_valid(item.torn_net)),"restoring removes all contents, net knots and their spring joints")
	check(loads.all(func(item): return not item.ruptured and item.body.visible and not item.body.get_node("Shape").disabled and is_instance_valid(item.joint)),"restore recreates the stable intact suspension and its collision hull")
	profile.hanging_net_tear_enabled = false
	trap.release_load()
	await frames(100)
	check(not trap.ruptured and trap.fragments.is_empty() and trap.body.can_grab(),"tear OFF preserves the fallen load as a single grabbable physical object")
	profile.hanging_net_tear_enabled = true
	trap.reset_load()
	await frames(8)
	profile.hanging_net_tear_speed = 1200
	trap.release_load()
	await frames(100)
	check(not trap.ruptured,"a high configured rupture threshold withstands the same actual fall")
	profile.hanging_net_tear_speed = 220
	trap.reset_load()
	var soft: CoreHangingLoad = load("res://scenes/core/hanging_load.tscn").instantiate()
	soft.tuning = profile
	soft.position = Vector2(-4450,481.5)
	lab.level.add_child(soft)
	await frames(8)
	soft.release_load()
	await frames(100)
	check(not soft.ruptured,"a gentle five-pixel drop does not tear the net")
	soft.queue_free()
	trap.reset_load()
	await frames(8)
	profile.hanging_impact_enabled = false
	trap.release_load()
	await frames(70)
	check(trap.ruptured and trap.fragments.size() == 12 and trap.impact_count == 0,"disabling damage leaves physical rupture and spill active")
	# Reset invalidates queued impacts, even in the same frame.
	trap.reset_load()
	trap.release_load()
	trap.queue_net_impact({"speed":900.0,"normal":Vector2.UP,"point":trap.body.global_position,"velocity":Vector2.DOWN*900,"spin":0.0})
	trap.reset_load()
	trap.rupture_net()
	await frames(12)
	check(not trap.ruptured and trap.fragments.is_empty() and is_instance_valid(trap.joint),"a stale queued rupture cannot destroy a restored suspension")
	profile.hanging_impact_enabled = true
	var target := CoreEnemyDummy.new()
	target.damage_tuning = lab.player.weapon.tuning
	target.position = Vector2(trap.position.x,760)
	lab.level.add_child(target)
	await frames(8)
	trap.release_load(lab.player)
	await frames(50)
	check(trap.ruptured and target.health < 100 and trap.impact_count == 1,"the initial real enemy impact deals damage once before releasing individual pieces")
	# Isolate one released piece above a second actual target. The shared hit
	# path must use only its mass share, not the original whole load's energy.
	var fragment: RigidBody2D = trap.fragments[0]
	var second := CoreEnemyDummy.new()
	second.position = Vector2(-4750,760)
	second.damage_tuning = lab.player.weapon.tuning
	lab.level.add_child(second)
	fragment.set_simulation_enabled(false)
	fragment.held_transform = Transform2D(0,Vector2(-4750,600))
	await frames(3)
	fragment.set_simulation_enabled(true)
	fragment.linear_velocity = Vector2.DOWN*400
	fragment.previous_velocity = Vector2.DOWN*400
	fragment.sleeping = false
	await frames(25)
	check(second.health < 100 and second.health > 70,"a real released fragment can hit another enemy with damage proportional to its own mass")
	target.queue_free()
	second.queue_free()
	lab._recover()
	await frames(12)
	check(get_nodes_in_group("hanging_fragments").is_empty() and loads.all(func(item): return not item.ruptured and is_instance_valid(item.joint)),"F8 restores all torn loads with no lingering fragment bodies")
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
