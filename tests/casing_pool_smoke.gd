extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func run() -> void:
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("case-pool-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app); app.launch(false); await frames(15)
	var lab = app.game
	var weapon = lab.player.weapon
	var floor := StaticBody2D.new()
	floor.position = Vector2(100000,1000)
	floor.set_meta("terra_material",3)
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new(); shape.shape.size = Vector2(1000,20)
	floor.add_child(shape); lab.add_child(floor)
	lab.player.reset_to(Vector2(99800,990)); lab.player.invulnerable = true
	await frames(4)
	weapon.effects.clear()
	weapon.cosmetic_rng.seed = 1743
	weapon.casing_motion.visual_rng.seed = 851
	var reference: Array[Dictionary] = []
	var variants := {}
	var angles := {}
	for i in 24:
		var effect: Dictionary = weapon.casing_motion.spawn(Vector2(100000+i*5,950),Vector2.RIGHT,Vector2(3,1),["stg44","mp40","svt","m1911"][i%4],weapon.cosmetic_rng)
		weapon.effects.append(effect)
		reference.append(effect.duplicate(true))
		variants[effect.rest_variant] = true
		angles[effect.rotation] = true
	var reference_rng := RandomNumberGenerator.new(); reference_rng.state = weapon.cosmetic_rng.state
	var same := true
	for step in 240:
		await frames(1)
		for i in reference.size():
			weapon.casing_motion.tick(weapon,reference[i],1.0/60.0,reference_rng)
			var current: Dictionary = weapon.effects[i]
			same = same and (current.point as Vector2).is_equal_approx(reference[i].point) and (current.velocity as Vector2).is_equal_approx(reference[i].velocity) and is_equal_approx(current.rotation,reference[i].rotation) and current.state == reference[i].state
	check(same,"240 steps preserve the old trajectory, bounce, rotation and rest solver exactly")
	check(weapon.cosmetic_rng.state == reference_rng.state,"sleep and batch rendering do not consume or reorder physics random numbers")
	check(variants.size()==4 and angles.size()==24,"spawn retains all rest variants and individual random angles")
	# Isolate the sleep fixture from still-airborne cases in the legacy solver.
	var rest_hit: Dictionary = lab.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(100000,960),Vector2(100000,1020),1))
	weapon.effects = weapon.effects.duplicate(true)
	for i in weapon.effects.size():
		weapon.effects[i].point = Vector2(100000+i*3,989.4)
		weapon.casing_motion._settle(weapon.effects[i],rest_hit)
		weapon.effects[i].smoke_age = 10.0
	await frames(3)
	check(weapon.casing_pool.active.is_empty() and weapon.casing_pool.supports.size()==1,"static cases sleep as one support group")
	await frames(60)
	check(weapon.casing_pool.simulated_last_tick==0 and weapon.effects.size()==24,"sleep skips per-case simulation without deleting cases")
	var replacement := StaticBody2D.new(); replacement.position = floor.position
	var replacement_shape := CollisionShape2D.new(); replacement_shape.shape = shape.shape
	replacement.add_child(replacement_shape); lab.add_child(replacement)
	weapon.on_terrain_collision_replaced([floor],[replacement],weapon.get_world_2d())
	floor.queue_free(); floor = replacement; shape = replacement_shape
	await frames(3)
	check(weapon.casing_pool.simulated_last_tick==0 and weapon.effects.all(func(e):return e.state=="rest"),"equivalent collision replacement preserves sleep instead of waking the entire pile")
	shape.disabled = true; await frames(3)
	check(weapon.effects.all(func(e):return e.state=="air" and e.velocity.y>0),"disabled support wakes every affected case")
	shape.disabled = false; await frames(240)
	check(weapon.effects.all(func(e):return is_inf(e.life)),"cases survive a second landing")
	var released_page: WeakRef = weakref(weapon.casing_pool.batch.pages[0])
	var released_buffer: WeakRef = weakref(weapon.casing_pool.batch.pages[0].multimesh)
	weapon.effects.clear(); weapon.casing_pool.sync(weapon.effects)
	check(weapon.casing_pool.records.is_empty() and weapon.casing_pool.batch.pages.is_empty(),"explicit clear releases tracking and GPU pages")
	await frames(3)
	check(released_page.get_ref()==null and released_buffer.get_ref()==null,"deferred deletion releases page and MultiMesh resources")
	var hit: Dictionary = lab.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(100000,960),Vector2(100000,1020),1))
	for x in [-20,20,300]:
		var effect: Dictionary = weapon.casing_motion.spawn(Vector2(100000+x,989.4),Vector2.RIGHT,Vector2(3,1),"stg44",weapon.cosmetic_rng)
		weapon.casing_motion._settle(effect,hit); effect.smoke_age = 10.0
		weapon.effects.append(effect)
	await frames(3)
	var blast_profile := CoreExplosionSettings.new()
	blast_profile.explosion_audio_enabled=false; blast_profile.explosion_radius=80; blast_profile.explosion_impulse=800
	CoreExplosion.spawn(lab,Vector2(100000,990),blast_profile)
	await frames(2)
	check(weapon.effects[0].velocity.x<0 and weapon.effects[1].velocity.x>0,"explosion kicks sleeping cases away from its center")
	check(weapon.effects[2].state=="rest","distant sleeping case is unaffected by the local explosion")
	# Use a moving surface without changing the old resting-contact algorithm.
	weapon.effects.clear(); weapon.casing_pool.sync(weapon.effects)
	var platform := AnimatableBody2D.new(); platform.sync_to_physics = false
	platform.position = Vector2(100000,900)
	var platform_shape := CollisionShape2D.new(); platform_shape.shape=RectangleShape2D.new(); platform_shape.shape.size=Vector2(100,10)
	platform.add_child(platform_shape); lab.add_child(platform); await frames(2)
	hit=lab.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(100000,880),Vector2(100000,920),1))
	var moving: Dictionary = weapon.casing_motion.spawn(Vector2(100000,894.4),Vector2.RIGHT,Vector2(3,1),"mp40",weapon.cosmetic_rng)
	weapon.casing_motion._settle(moving,hit); moving.smoke_age=10.0
	weapon.effects.append(moving); await frames(2)
	platform.position.x += 30; await frames(2)
	check(is_equal_approx(moving.point.x,100030) and weapon.casing_pool.active.size()==1,"moving support continues carrying the case")
	platform.queue_free(); await frames(3)
	check(moving.state=="air","removing a moving support restores falling")
	weapon.effects.clear(); weapon.casing_pool.sync(weapon.effects)
	floor.queue_free()
	var grid = preload("res://scripts/core/terra_grid.gd").new()
	grid.W=64; grid.H=12; grid.CHUNK=4; grid.local_collision_mode=true; grid.material_override=1
	grid.position=Vector2(99700,990); grid.tuning=lab.player.tuning
	grid.tuning.terra_enabled=true; grid.tuning.terra_bake_enabled=true; grid.tuning.terra_collapse_enabled=false
	lab.add_child(grid); await frames(3)
	grid.dirty_at(Vector2i(6,0)); await frames(3)
	hit=lab.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(99800,970),Vector2(99800,1010),1))
	var grounded: Dictionary=weapon.casing_motion.spawn(Vector2(99800,989.4),Vector2.RIGHT,Vector2(3,1),"svt",weapon.cosmetic_rng)
	weapon.casing_motion._settle(grounded,hit); grounded.smoke_age=10.0
	weapon.effects.append(grounded); await frames(120)
	check(grid.static_bake.bakes>0 and grounded.state=="rest" and weapon.casing_pool.simulated_last_tick==0,"real terrain baking transfers sleeping case support")
	grid.bullet_hit(grid.global_position+Vector2(130,.2),Vector2.DOWN,25)
	await frames(120)
	check(grounded.state=="rest" and absf(grounded.point.y-989.4)<1.0 and weapon.effects.size()==1,"terrain unbaking and rebaking preserve the case on unchanged nearby ground")
	app.queue_free(); await frames(4)
	print("CASING POOL ",checks-failures,"/",checks)
	quit(1 if failures else 0)
