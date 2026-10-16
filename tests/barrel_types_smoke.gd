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
	var profile := lab.ragdoll_settings
	profile.explosion_audio_enabled = false
	profile.explosion_camera_enabled = false
	profile.explosion_player_damage_enabled = false
	profile.explosion_visuals_enabled = false
	await frames(8)
	var kinds := {}
	for barrel in lab.level.explosive_barrels: kinds[barrel.contents] = true
	check(kinds.size() == 4 and lab.level.explosive_barrels.size() == 8,"the arena contains explosive, fuel, empty and inert barrels")
	check(lab.level.explosive_barrels[0].contents == CoreExplosiveBarrel.Contents.EXPLOSIVE and lab.level.explosive_barrels[1].contents == CoreExplosiveBarrel.Contents.EXPLOSIVE,"the original pair of explosive barrels is restored")
	var explosive: CoreExplosiveBarrel = load("res://scenes/core/explosive_barrel.tscn").instantiate()
	var fuel: CoreExplosiveBarrel = load("res://scenes/core/fuel_barrel.tscn").instantiate()
	explosive.position = Vector2(-1100,732)
	fuel.position = Vector2(-750,732)
	for barrel in [explosive,fuel]:
		barrel.tuning = profile
		lab.level.add_child(barrel)
	await frames(6)
	check(explosive.contents == CoreExplosiveBarrel.Contents.EXPLOSIVE and fuel.contents == CoreExplosiveBarrel.Contents.FUEL,"separate scene files instantiate the correct barrel behaviour")
	check(explosive.shell_color() != fuel.shell_color() and explosive.content_name() != fuel.content_name(),"explosive and fuel barrels are visually distinguishable")
	check(explosive.mass == fuel.mass and explosive.shape_node.shape.get_rect() == fuel.shape_node.shape.get_rect() and explosive.can_grab() and fuel.can_grab(),"both types preserve matching physics and G interaction")
	check(explosive.fuel_left == 0 and is_inf(fuel.fuel_left),"only the fuel barrel contains a leaking fuel supply")
	profile.barrel_leak_hits = 2
	fuel.take_projectile_damage(25,lab.player)
	explosive.take_projectile_damage(25,lab.player)
	check(not fuel.leaking and not fuel.armed and not explosive.leaking and not explosive.armed,"the first hit respects leak threshold and explosive shell HP independently")
	fuel.take_projectile_damage(25,lab.player)
	explosive.take_projectile_damage(25,lab.player)
	check(fuel.leaking and not fuel.armed and not fuel.destroyed and fuel.health == 0,"an exhausted fuel shell continues leaking instead of exploding from bullets")
	check(explosive.armed and not explosive.leaking and not explosive.can_grab(),"an exhausted explosive shell starts its fuse and releases interaction")
	await frames(30)
	check(explosive.destroyed and explosive.debris.size() == 12 and explosive.instigator == lab.player,"the explosive barrel detonates and credits its attacker")
	check(not fuel.destroyed and not fuel.armed and fuel.leaking and lab.level.fuel_field.cells.size() > 0,"the fuel barrel remains a leaking tank after the same number of shots")
	check(fuel.ignite_from_fire(lab.player),"the separate fuel tank can still be detonated by fire")
	await frames(20)
	check(fuel.destroyed and fuel.instigator == lab.player,"ignited fuel uses the shared explosion and attacker attribution")
	for barrel in [explosive,fuel]: barrel.reset_barrel()
	await frames(6)
	check(explosive.contents == CoreExplosiveBarrel.Contents.EXPLOSIVE and fuel.contents == CoreExplosiveBarrel.Contents.FUEL and not explosive.leaking and not fuel.leaking,"reset restores each barrel without changing its type")
	profile.fuel_leak_enabled = false
	profile.fuel_fire_enabled = false
	explosive.take_projectile_damage(100,lab.player)
	check(explosive.armed,"disabling fuel features does not disable explosive barrel shot detonation")
	await frames(20)
	check(explosive.destroyed and not fuel.destroyed,"independent explosive behaviour remains active")
	lab._reset_explosives()
	check(lab.level.explosive_barrels.all(func(b): return not b.destroyed and b.health == profile.barrel_health) and lab.level.fuel_field.cells.is_empty(),"arena reset restores every type and clears fuel")
	for barrel in [explosive,fuel]:
		for piece in barrel.debris:
			if is_instance_valid(piece): piece.queue_free()
		barrel.queue_free()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
