extends SceneTree
## Rest must come from stable constraints and native physics sleeping, while
## leaving the same bodies responsive to impacts and suspension release.
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
func bodies(bag: CoreHangingLoad) -> Array:
	return bag.physical_net.knots+bag.physical_net.strands+bag.fragments+[bag.body]
func snapshot(bag: CoreHangingLoad) -> Array:
	return bodies(bag).map(func(body): return body.global_transform)
func maximum_change(bag: CoreHangingLoad,poses: Array) -> float:
	var change := 0.0
	var physical := bodies(bag)
	for index in physical.size():
		var pose: Transform2D = physical[index].global_transform
		change = maxf(change,pose.origin.distance_to(poses[index].origin))
		change = maxf(change,absf(angle_difference(pose.get_rotation(),poses[index].get_rotation()))*100)
	return change
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.weapon.tuning.sound_enabled = false
	lab.level.enemies.erase(lab.level.hanging_target)
	lab.level.hanging_target.queue_free()
	var bag := lab.level.hanging_loads[1]
	await frames(600)
	check(bodies(bag).all(func(body): return body.sleeping and not body.freeze),"the entire loaded net reaches native sleep without freezing the simulation")
	check(bag.fragments.all(func(piece): return piece.global_position.y < 715) and bag.physical_net.broken_links == 0,"settling retains all twelve stones on the intact suspension")
	var poses := snapshot(bag)
	var jitter := 0.0
	for frame in 180:
		await frames(1)
		jitter = maxf(jitter,maximum_change(bag,poses))
	check(jitter < .001,"knots, strands, stones and hook stay motionless for three seconds (%.6f)" % jitter)
	bag.physical_net.strands[27].apply_central_impulse(Vector2(12,-3))
	await frames(10)
	check(maximum_change(bag,poses) > .1 and bodies(bag).any(func(body): return not body.sleeping),"a direct physical impulse wakes and deforms the sleeping weave")
	await frames(600)
	check(bodies(bag).all(func(body): return body.sleeping) and bag.physical_net.broken_links == 0,"the disturbed weave returns to rest without tearing")
	poses = snapshot(bag)
	bag.fragments[5].receive_projectile_impulse(Vector2.RIGHT,bag.fragments[5].global_position,15)
	await frames(10)
	check(maximum_change(bag,poses) > .1,"shooting a stone also wakes the suspended physical net")
	await frames(600)
	check(bodies(bag).all(func(body): return body.sleeping),"cargo impacts settle again instead of leaving persistent jitter")
	var ids := bodies(bag).map(func(body): return body.get_instance_id())
	var height: float = bag.body.global_position.y
	bag.release_load(lab.player)
	await frames(12)
	check(bag.body.global_position.y > height+5 and not bag.body.sleeping,"cutting the cable wakes the resting load and starts a real fall")
	check(bodies(bag).map(func(body): return body.get_instance_id()) == ids,"release keeps the original rope and cargo bodies")
	await frames(100)
	check(bag.physical_net.impact_breaks > 0 and bag.ruptured,"the stabilized net still tears physically on ground impact")
	lab._reset_hanging_loads()
	await frames(600)
	check(bodies(bag).all(func(body): return body.sleeping) and bag.physical_net.broken_links == 0,"F8 restoration settles the new weave without residual oscillation")
	poses = snapshot(bag)
	bag.physical_net.strands[0].receive_projectile_impulse(Vector2.LEFT,bag.physical_net.strands[0].global_position,10)
	bag.physical_net.strands[0].take_projectile_damage(25,lab.player)
	await frames(12)
	check(bag.physical_net.broken_links > 0 and maximum_change(bag,poses) > .1,"a shot wakes sleeping ropes and can sever their physical attachment")
	for configuration in [[100.0,3.0,1.0],[5.0,.1,.5],[35.0,1.0,2.0]]:
		lab.ragdoll_settings.hanging_base_mass = configuration[0]
		lab.ragdoll_settings.hanging_net_strength = configuration[1]
		lab.ragdoll_settings.hanging_scale = configuration[2]
		lab._reset_hanging_loads()
		await frames(1200)
		check(bodies(bag).all(func(body): return body.sleeping and not body.freeze),"custom mass/strength/size also settle: %s" % [configuration])
		poses = snapshot(bag)
		jitter = 0.0
		for frame in 60:
			await frames(1)
			jitter = maxf(jitter,maximum_change(bag,poses))
		check(jitter < .001 and bag.physical_net.broken_links == 0,"custom loaded weave stays still and intact: %s" % [configuration])
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
