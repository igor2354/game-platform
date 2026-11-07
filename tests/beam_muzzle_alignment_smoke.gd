extends SceneTree
const CATALOG=preload("res://scripts/campaign/catalog.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame;await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run() -> void:
	var app=preload("res://scripts/campaign/frontend.gd").new();app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("beam-outlet-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	for character in ["sofia","harry"]:
		if "--capture-only" in OS.get_cmdline_user_args() and character!="sofia":continue
		app.selected_character=character;app.selected_level="terra";app.launch(true);await frames(10)
		var lab=app.game;var hero=lab.player;var gun=hero.weapon
		gun.aim_cursor.focus_override=true;gun.aim_cursor.sync_context()
		hero.reset_to(lab.level.player_spawn()+Vector2(500,0));await frames(10)
		gun.tuning.sound_enabled=false;gun.tuning.damage_enabled=false;gun.tuning.magazine_enabled=false
		for data in CATALOG.WEAPONS:
			if "--capture-only" in OS.get_cmdline_user_args() and data.id!="stg44":continue
			CATALOG.equip(gun,data.id)
			for ads in [false,true]:
				if ads:Input.action_press("core_aim")
				else:Input.action_release("core_aim")
				for side in [-1,1]:
					if "--capture-only" in OS.get_cmdline_user_args() and side!=1:continue
					for slope in [-.6,0.0,.6]:
						if "--capture-only" in OS.get_cmdline_user_args() and slope!=0:continue
						gun.aim_override=hero.global_position+Vector2(side*700,-100+slope*700);await frames(10)
						gun._update_aim();var pose: Dictionary=gun.visual_pose()
						var offset: Vector2=gun.assault_flash.muzzle_offset(hero)
						var drawn: Vector2=hero.to_global(pose.breech+pose.direction*offset.x+pose.normal*offset.y)
						gun.aim_beam._physics_process(0)
						check(gun.muzzle_position().distance_to(drawn)<.001 and gun.aim_beam.origin.distance_to(drawn)<.001,character+data.id+" cone begins at actual drawn barrel "+str([ads,side,slope]))
						var emitted: Array=[];var callback:=func(point,_dir,_ads,_spread):emitted.append(point)
						gun.shot_fired.connect(callback);gun._fire();gun.shot_fired.disconnect(callback)
						check(not emitted.is_empty() and emitted[0].distance_to(drawn)<.001,"actual projectile shares the same pre-recoil outlet")
						gun.aim_beam._physics_process(0)
						check(gun.aim_beam.origin.distance_to(gun.muzzle_position())<.001,"cone follows post-shot recoil outlet")
						if "--capture" in OS.get_cmdline_user_args() and character=="sofia" and data.id=="stg44" and side==1 and slope==0:
							lab.process_mode=Node.PROCESS_MODE_DISABLED;await process_frame;await RenderingServer.frame_post_draw
							var folder:=preload("res://tools/media_paths.gd").path("docs/core/beam_muzzle_20261103")
							root.get_texture().get_image().save_png(folder.path_join("ads.png" if ads else "hip.png"));lab.process_mode=Node.PROCESS_MODE_INHERIT
		Input.action_release("core_aim");await app.return_to_menu()
	print("BEAM MUZZLE ",checks," checks / ",failures," failures")
	app.queue_free();await frames(3);quit(1 if failures else 0)
