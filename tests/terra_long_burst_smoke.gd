extends SceneTree
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame;await process_frame
func run() -> void:
	print("USER DATA ",OS.get_user_data_dir())
	var app=preload("res://scripts/campaign/frontend.gd").new();app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("terra-long-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app);app.selected_level="terra";app.launch(true);await frames(15)
	var lab=app.game;var g=lab.level.ground
	lab.player.reset_to(g.global_position+Vector2(4300,0));lab.player.invulnerable=true
	if "--actual" in OS.get_cmdline_user_args():
		var weapon=lab.player.weapon;weapon.tuning.magazine_enabled=false
		Input.action_press("core_aim");Input.action_press("core_fire")
		for frame in 5000:
			# Native focus events can release synthetic actions; keep the test hold explicit.
			Input.action_press("core_aim");Input.action_press("core_fire")
			# Hold the shooter over the wood test area while its floor is excavated.
			if frame%60==0:lab.player.global_position=g.global_position+Vector2(4300,-40);lab.player.velocity=Vector2.ZERO
			weapon.aim_override=g.global_position+Vector2(4300,800)
			await frames(1)
			if frame%600==0:print("ACTUAL BURST frame=",frame," shots=",weapon.shots_fired)
			if weapon.shots_fired>=600:break
		Input.action_release("core_fire");Input.action_release("core_aim")
		await frames(240) # Finish projectiles and delayed shot effects before scene teardown.
		var invalid:=false;var bodies:=0;var baked:=0;var recoveries:=0
		for body in g.get_children():
			if body.is_in_group("terra_deposits"):
				baked+=1
				if not is_finite(body.mass) or not body.global_position.is_finite():invalid=true
			if body is RigidBody2D:
				bodies+=1;recoveries+=body.recovered_states
				if not body.global_position.is_finite() or not body.linear_velocity.is_finite() or not is_finite(body.angular_velocity):invalid=true
		print("ACTUAL BURST shots=",weapon.shots_fired," fragments=",bodies," baked=",baked," invalid=",invalid," recoveries=",recoveries)
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			var folder:=preload("res://tools/media_paths.gd").path("docs/core/terra_hang_fix_20261102")
			root.get_texture().get_image().save_png(folder.path_join("actual_600_shots.png"))
		var passed: bool=weapon.shots_fired>=600 and bodies+baked>0 and not invalid and recoveries==0
		print("PASS actual six hundred ADS shots" if passed else "FAIL actual burst")
		app.queue_free();await frames(4);quit(0 if passed else 1);return
	for i in 600:
		var from: Vector2=g.global_position+Vector2(4300,-60)
		var query:=PhysicsRayQueryParameters2D.create(from,from+Vector2(0,1400),1|8)
		var hit: Dictionary=lab.get_world_2d().direct_space_state.intersect_ray(query)
		if i%10==0:print("SHOT BEGIN ",i," bodies=",g.get_children().filter(func(n):return n is RigidBody2D).size()," phase=",g.support_solver.phase if g.support_solver else -1)
		if not hit.is_empty():
			if hit.collider.has_method("receive_projectile_impulse"):hit.collider.receive_projectile_impulse(Vector2.DOWN,hit.position,35)
			else:g.bullet_hit(hit.position,Vector2.DOWN,35,preload("res://scripts/campaign/catalog.gd").terrain_ballistics("stg44"))
		await frames(3)
		for body in g.get_children():
			if body is RigidBody2D and (not body.global_position.is_finite() or not body.linear_velocity.is_finite() or not is_finite(body.angular_velocity)):
				print("FAIL nonfinite body at shot ",i);quit(1);return
	print("LONG BURST COMPLETE")
	app.queue_free();await frames(4);quit()
