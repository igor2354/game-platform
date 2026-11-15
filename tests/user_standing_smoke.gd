extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func run() -> void:
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("weighted-player-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	for entry in [[false,"prologue"],[true,"prologue_v2"]]:
		app.selected_level=entry[1]
		app.launch(entry[0],true)
		await frames(8)
		var hero: CoreMovementPlayer = app.game.player
		var body = hero.body
		check(body.mannequin_visual.rig.get_bone_count()==153 and body.mannequin_visual.get_parent()==body,"Genesis9 visual shared on "+str(entry))
		check(body.mannequin_visual.rig.global_position.is_zero_approx(),"imported skeleton is centered before the depth turn")
		check(body.bones.NearHip.position.is_equal_approx(body.bones.FarHip.position),"projected hip roots coincide")
		var lengths: Array[float] = []
		for key in ["NearElbow","NearWrist","FarElbow","FarWrist","NearKnee","FarKnee"]: lengths.append(body.bones[key].position.length())
		var ladder: Rect2 = hero.ladders[0]
		hero.reset_to(Vector2(ladder.get_center().x,ladder.end.y))
		hero._enter_ladder(ladder)
		Input.action_press("core_up")
		var origin := hero.global_position
		await frames(20)
		Input.action_release("core_up")
		check(hero.global_position.y<origin.y and hero.climbing,"climbs existing ladder")
		for arm in [body.near_arm,body.far_arm]:
			check(arm.hand.distance_to(arm.requested_hand)<.2,"ladder target within anatomical arm reach")
		hero._leave_ladder()
		hero.reset_to(app.game.level.player_spawn())
		await frames(5)
		var before := Time.get_ticks_usec()
		hero.blast_ragdoll.start(Vector2(25,-45),.2,.6)
		print("WEIGHTED_KNOCKDOWN_SETUP_USEC ",Time.get_ticks_usec()-before)
		check(hero.blast_ragdoll.active and body.mannequin_visual.get_parent()==hero.blast_ragdoll.player_skin,"physical fall reuses the live 3D visual")
		check(is_instance_valid(body.mannequin_visual.rig) and body.mannequin_visual.rig.get_bone_count()==153,"physical fall retains the Genesis9 skeleton")
		await frames(12)
		check(not body.mannequin_visual.fall_view.basis.is_equal_approx(Basis.IDENTITY),"physical fall turns the model out of profile")
		hero.blast_ragdoll.cancel()
		check(hero.visuals.visible and hero.collision_layer==2 and body.mannequin_visual.get_parent()==body,"ragdoll cancellation restores live renderer and collider")
		check(body.mannequin_visual.fall_view.basis.is_equal_approx(Basis.IDENTITY),"restored model faces in profile")
		var index := 0
		for key in ["NearElbow","NearWrist","FarElbow","FarWrist","NearKnee","FarKnee"]:
			check(is_equal_approx(lengths[index],body.bones[key].position.length()),"action preserved bone length "+key)
			index+=1
		await app.return_to_menu()
	app.queue_free()
	await process_frame
	print("USER_STANDING failures=",failures)
	quit(int(failures>0))
