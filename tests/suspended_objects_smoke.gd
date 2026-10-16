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
	lab.player.weapon.tuning.sound_enabled = false
	var crate := lab.level.hanging_loads[0]
	var bag := lab.level.hanging_loads[1]
	lab.level.enemies.erase(lab.level.hanging_target)
	lab.level.hanging_target.queue_free()
	await frames(15)
	var net = bag.physical_net
	check(lab.level.hanging_loads.size() == 2 and crate.container == CoreHangingLoad.ContainerKind.CRATE and bag.container == CoreHangingLoad.ContainerKind.NET,"arena has one suspended wooden crate and one real net")
	check(is_instance_valid(crate.joint) and is_instance_valid(bag.joint) and net.ready_for_load,"both specimens have a working ceiling suspension")
	check(bag.fragments.size() == 12 and net.knots.size() == 24 and net.strands.size() == 37,"the full cargo and physical weave exist before any shot or impact")
	check(bag.body.get_node("Shape").shape is CircleShape2D and bag.body.get_node("Shape").shape.radius == 5 and not is_instance_valid(bag.torn_net),"the net has only a small hook collider, with no solid bag or replacement mesh")
	check(net.links.all(func(link): return link.joints.size() == 2 and link.joints.all(func(pin): return pin is PinJoint2D)),"every rope length has real endpoint constraints")
	check(net.links.filter(func(link): return link.boundary).size() == 14 and net.strands.all(func(rod): return rod.get_child(0).shape is CapsuleShape2D),"side, hem and bottom ropes have real collision thickness to hold the stones")
	check(bag.fragments.all(func(piece): return piece.collision_mask & 32 and not piece.can_grab()),"cargo CCD includes the rope layer and G cannot pull stones from an intact suspension")
	await frames(600)
	check(net.broken_links == 0 and not bag.ruptured and bag.fragments.all(func(piece): return piece.global_position.y < 715 and piece.global_position.y > 450),"the physical net retains every stone for ten seconds without a hidden hull")
	var before: Transform2D = net.strands[27].global_transform
	net.strands[27].apply_central_impulse(Vector2(12,-3))
	await frames(20)
	check(not net.strands[27].global_transform.is_equal_approx(before) and net.broken_links == 0,"the weave bends and swings while still suspended")
	var poses: Array[Transform2D] = []
	for body in net.knots+net.strands+bag.fragments: poses.append(body.global_transform)
	lab.ragdoll_settings.hanging_enabled = false
	lab._ragdoll_settings_changed()
	await frames(20)
	var fixed := true
	var bodies: Array = net.knots+net.strands+bag.fragments
	for index in bodies.size(): fixed = fixed and bodies[index].global_transform.is_equal_approx(poses[index])
	check(fixed,"master OFF freezes every rope, node and stone")
	lab.ragdoll_settings.hanging_enabled = true
	lab._ragdoll_settings_changed()
	await frames(10)
	check(net.strands.all(func(rod): return not rod.freeze) and bag.fragments.all(func(piece): return not piece.freeze),"master ON resumes the same physical net")
	var ids := bag.fragments.map(func(piece): return piece.get_instance_id())
	var net_id: int = net.get_instance_id()
	var target := CoreEnemyDummy.new()
	target.body_size = Vector2(140,64)
	target.damage_tuning = lab.player.weapon.tuning
	target.position = Vector2(bag.position.x,760)
	lab.level.add_child(target)
	await frames(3)
	bag.release_load(lab.player)
	await frames(3)
	check(not is_instance_valid(bag.joint) and net.get_instance_id() == net_id and bag.fragments.map(func(piece): return piece.get_instance_id()) == ids,"cutting the cable releases the existing bodies without swapping or spawning a new net")
	await frames(100)
	check(net.broken_links > 0 and net.impact_breaks > 0 and bag.ruptured,"real contact loads tear individual rope joints on landing")
	check(net.links.any(func(link): return link.broken and not is_instance_valid(link.joints[link.free_end])) and net.strands.size() == 37,"broken strands retain their actual rope bodies and free ends")
	check(bag.fragments.all(func(piece): return piece.global_position.is_finite() and piece.global_position.y < 785),"released stones stay physical and settle above the floor")
	check(target.health < 100 and bag.impact_count > 0,"the real suspended contents still damage an enemy during the fall")
	target.queue_free()
	paused = true
	var held: Transform2D = net.strands[0].global_transform
	await frames(15)
	check(net.strands[0].global_transform.is_equal_approx(held),"pause freezes the deforming rope")
	paused = false
	lab._reset_hanging_loads()
	await frames(20)
	check(not is_instance_valid(net) and bag.physical_net.ready_for_load and bag.physical_net.broken_links == 0 and bag.fragments.size() == 12,"restore replaces every physical rope and recaptures all cargo")
	crate.body.take_damage(75)
	await frames(3)
	check(crate.crate_health == 25 and not crate.released,"the suspended crate has its own HP and remains attached until destroyed")
	crate.body.take_damage(25)
	await frames(6)
	check(crate.ruptured and crate.fragments.size() == 12 and not is_instance_valid(crate.torn_net),"destroying the crate releases wooden debris without drawing any net")
	lab._recover()
	await frames(20)
	crate.release_load(lab.player)
	await frames(70)
	check(crate.ruptured and crate.fragments.size() == 12,"a hard physical fall can also break the wooden crate")
	lab._recover()
	await frames(20)
	bag = lab.level.hanging_loads[1]
	net = bag.physical_net
	var intact_count: int = net.broken_links
	check(net.strands[0].take_projectile_damage(25,lab.player) and net.broken_links == intact_count+1,"a projectile can sever a visible physical thread before the cargo falls")
	lab._recover()
	await frames(20)
	bag = lab.level.hanging_loads[1]
	lab.ragdoll_settings.hanging_net_tear_enabled = false
	bag.release_load()
	await frames(130)
	check(bag.physical_net.broken_links == 0 and bag.fragments.size() == 12,"the rupture toggle keeps the fallen weave connected while physics continues")
	lab._recover()
	await frames(20)
	check(crate.crate_health == 100 and not crate.ruptured and is_instance_valid(crate.joint) and is_instance_valid(bag.joint),"F8 restores the wooden crate and net suspension together")
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
