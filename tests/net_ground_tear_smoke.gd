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
	var trap := lab.level.hanging_loads[0]
	await frames(12)
	trap.release_load(lab.player)
	await frames(10)
	check(not trap.ruptured and not is_instance_valid(trap.torn_net),"the ground-tear effect does not start when the cable is cut in midair")
	for step in 100:
		if trap.ruptured: break
		await frames(1)
	var net = trap.torn_net
	check(trap.ruptured and is_instance_valid(net) and net.ground_tear,"actual floor impact starts the fabric-tearing effect")
	check(net.links.any(func(link): return link.get("ground_cut",false)) and not net.tear_queue.is_empty(),"the contact starts a progressive crack instead of deleting the whole sheet")
	check(not net.fibres.is_empty(),"loose fibres appear at the contact and newly snapped strands")
	var age: float = net.tear_age
	var fibre_life: float = net.fibres[0].life
	lab.ragdoll_settings.hanging_enabled = false
	lab._ragdoll_settings_changed()
	await frames(15)
	check(net.tear_age == age and net.fibres[0].life == fibre_life,"master OFF freezes both crack progression and the fibre effect")
	lab.ragdoll_settings.hanging_enabled = true
	lab._ragdoll_settings_changed()
	await frames(9)
	var seam: Array = net.links.filter(func(link): return link.get("ground_cut",false))
	check(seam.size() == 4 and net.tear_queue.is_empty() and seam.all(func(link): return link.broken and not is_instance_valid(link.joint)),"the ground crack physically disconnects the complete four-row seam")
	# This grid has only horizontal and vertical edges. Cutting the central
	# horizontal links must leave no surviving edge connecting the two flaps.
	check(net.links.all(func(link): return link.broken or (link.a%5 < 2) == (link.b%5 < 2)),"the two fabric flaps have no remaining joint across the opening")
	check(net.tethers.all(func(tether): return tether.knot%5 not in [1,2] or not is_instance_valid(tether.joint)),"attachments along the cut release while outer fabric remains free to drape")
	check(seam.all(func(link): return link.has("axis") and link.age > 0),"snapped ends retain their own direction and recoil age")
	paused = true
	age = net.tear_age
	var fibre_count: int = net.fibres.size()
	await frames(15)
	check(net.tear_age == age and net.fibres.size() == fibre_count,"pause freezes the visual tear with the physical net")
	paused = false
	await frames(80)
	check(net.fibres.is_empty() and is_instance_valid(net) and trap.fragments.size() == 12,"short-lived fibres fade while the torn sheet and cargo persist")
	check(net.links.filter(func(link): return link.get("ground_cut",false)).size() == 4,"resting contact never restarts the ground burst")
	lab._recover()
	await frames(10)
	check(not trap.ruptured and not is_instance_valid(trap.torn_net) and trap.fragments.is_empty(),"F8 clears the tear animation and restores the intact net")
	# A net released above ground can reach the floor after hitting a person.
	# Exercise that second contact using actual net-body collision manifolds.
	var air: CoreHangingLoad = load("res://scenes/core/hanging_load.tscn").instantiate()
	air.tuning = lab.ragdoll_settings.duplicate()
	air.position = Vector2(-1250,120)
	lab.level.add_child(air)
	await frames(10)
	air.release_load()
	await frames(2)
	air.queue_net_impact({"speed":500.0,"normal":Vector2.UP,"point":air.body.global_position,"velocity":Vector2.DOWN*500,"spin":0.0,"ground":false})
	air.rupture_net()
	check(not air.torn_net.ground_tear,"a non-ground rupture alone does not play the ground-contact burst")
	await frames(5)
	check(not air.torn_net.ground_tear,"the effect waits for collision rather than proximity or a timer")
	for step in 100:
		if air.torn_net.ground_tear: break
		await frames(1)
	check(air.torn_net.ground_tear,"a later real net-floor contact triggers the same opening effect")
	air.queue_free()
	lab.ragdoll_settings.hanging_net_tear_enabled = false
	trap.release_load()
	await frames(100)
	check(not trap.ruptured and not is_instance_valid(trap.torn_net),"the existing rupture toggle disables both tearing and its effect")
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
