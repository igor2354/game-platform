extends SceneTree
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame;await process_frame
func run() -> void:
	var app=preload("res://scripts/campaign/frontend.gd").new();app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("prologue-shot-stability-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app);app.selected_level="prologue_v2";app.selected_character="sofia";app.launch(true);await frames(15)
	var lab=app.game;var terrain=lab.level.get_node("Terraforming")
	var geo=preload("res://scripts/campaign/forest_prologue_v2.gd")
	var targets: Array=[geo.point(21.13,0)]
	for key in ["house_roof","bunker_roof_solid"]:
		for patch in terrain.owners:
			if key in patch.id:targets.append(Vector2(patch.box.get_center().x,patch.box.position.y));break
	if targets.size()!=3:print("FAIL missing prologue material targets");quit(1);return
	var weapon=lab.player.weapon;weapon.tuning.magazine_enabled=false;weapon.tuning.sound_enabled=false
	lab.player.invulnerable=true
	# Force spanning several frames so subsequent shots overlap unfinished work.
	lab.player.tuning.terra_support_budget_ms=.25
	var per_stage:=100 if "--short" in OS.get_cmdline_user_args() else 200
	var target_shots:=per_stage*3
	var stage:=-1
	for frame in 5200:
		var next:=mini(2,weapon.shots_fired/per_stage)
		var point: Vector2=targets[next]
		if next!=stage or frame%30==0:
			lab.player.global_position=point+Vector2(0,-50);lab.player.velocity=Vector2.ZERO
			stage=next
		Input.action_press("core_aim");Input.action_press("core_fire")
		weapon.aim_override=point+Vector2(0,300)
		await frames(1)
		if frame%600==0:print("PROLOGUE BURST frame=",frame," shots=",weapon.shots_fired," material_stage=",stage)
		if weapon.shots_fired>=target_shots:break
	Input.action_release("core_fire");Input.action_release("core_aim");await frames(240)
	var invalid:=false;var damaged:=0;var patches:=0
	for patch in terrain.owners:
		if not is_instance_valid(patch.grid):continue
		patches+=1;damaged+=patch.grid.bullet_erased.size()
		for body in patch.grid.get_children():
			if body is RigidBody2D:
				if not body.global_position.is_finite() or not body.linear_velocity.is_finite() or not is_finite(body.angular_velocity):invalid=true
	print("PROLOGUE BURST shots=",weapon.shots_fired," active_patches=",patches," removed_pixels=",damaged," invalid=",invalid)
	var passed: bool=weapon.shots_fired>=target_shots and patches>=3 and damaged>0 and not invalid
	print("PASS %d real ADS shots on prologue soil, wood and concrete"%target_shots if passed else "FAIL prologue shooting stress")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var folder:=preload("res://tools/media_paths.gd").path("docs/core/prologue2_components_20261102")
		root.get_texture().get_image().save_png(folder.path_join("prologue_after_%d.png"%target_shots))
	app.queue_free();await frames(4);quit(0 if passed else 1)
