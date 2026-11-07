extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func run() -> void:
	var actual := "--actual" in OS.get_cmdline_user_args()
	var maps := ["prologue", "prologue_v2"] if actual or "--prologues" in OS.get_cmdline_user_args() else ["prologue", "prologue_v2", "polygon", "hub", "terra"]
	for id in maps:
		var app = preload("res://scripts/campaign/frontend.gd").new()
		app.load_user_settings = false
		app.test_settings_directory = OS.get_environment("TEMP").path_join("bake-stress-%d-%s" % [OS.get_process_id(),id])
		DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
		root.add_child(app); app.selected_level = id; app.launch(id != "polygon")
		await frames(20)
		var lab = app.game
		lab.player.invulnerable = true
		lab.blocking_overlay.set_debug_enabled(true)
		var spawn: Vector2 = lab.player.global_position
		var hits := 0
		var total_shots := [0]
		lab.player.weapon.shot_fired.connect(func(_a,_b,_c,_d): total_shots[0] += 1)
		var weapon = lab.player.weapon
		weapon.tuning.magazine_enabled = false
		for round_index in 4:
			if actual:
				weapon.aim_override = spawn + Vector2(150,220)
				for i in 1200:
					Input.action_press("core_aim"); Input.action_press("core_fire")
					if i % 120 == 0: lab.player.reset_to(spawn)
					await frames(1)
				Input.action_release("core_fire"); Input.action_release("core_aim")
			for i in (0 if actual else 60):
				var point := spawn+Vector2(80+(i%20)*5,0)
				var query := PhysicsRayQueryParameters2D.create(point-Vector2(0,250),point+Vector2(0,600),1)
				var hit: Dictionary = lab.get_world_2d().direct_space_state.intersect_ray(query)
				if not hit.is_empty():
					var owner = hit.collider.get_meta("terra_owner",null)
					if is_instance_valid(owner) and owner.has_method("bullet_hit"):
						owner.bullet_hit(hit.position,Vector2.DOWN,35,{"caliber_mm":7.92,"power":1.0}); hits += 1
				await frames(1)
			await frames(150)
			if actual: print("BURST ",id," round=",round_index+1," total_shots=",total_shots[0])
			# Exercise the exact lifetime window from the user's error log.
			var orphan := CollisionPolygon2D.new()
			orphan.polygon = PackedVector2Array([Vector2.ZERO,Vector2(10,0),Vector2(0,10)])
			lab.blocking_overlay.shapes.append(orphan)
			lab.blocking_overlay.queue_redraw()
			await frames(2)
			orphan.free()
			lab.player.reset_to(spawn)
		print("STRESS ",id," hits=",hits," cycles=4 shots=",total_shots[0])
		if (total_shots[0] < 500 if actual else hits == 0): failures += 1
		app.queue_free(); await frames(5)
	print("BAKE STRESS failures=",failures)
	quit(1 if failures else 0)
