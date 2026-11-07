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
		app.launch(entry[0])
		await frames(8)
		var hero: CoreMovementPlayer = app.game.player
		var body = hero.body
		check(body.get_script().resource_path.ends_with("user_standing_body.gd") and body.bones.size()==18 and body.mesh_pieces.size()==6,"weighted model shared on "+str(entry))
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
		check(hero.blast_ragdoll.active and not hero.blast_ragdoll.player_skin.pieces.is_empty(),"physical fall retains new artwork")
		check(hero.blast_ragdoll.player_skin.pieces.all(func(p):return p.mesh!=null),"all corpse surfaces come from weighted mesh")
		await frames(12)
		hero.blast_ragdoll.cancel()
		check(hero.visuals.visible and hero.collision_layer==2,"ragdoll cancellation restores live renderer and collider")
		var index := 0
		for key in ["NearElbow","NearWrist","FarElbow","FarWrist","NearKnee","FarKnee"]:
			check(is_equal_approx(lengths[index],body.bones[key].position.length()),"action preserved bone length "+key)
			index+=1
		await app.return_to_menu()
	app.queue_free()
	await process_frame
	print("USER_STANDING failures=",failures)
	quit(int(failures>0))
