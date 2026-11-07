extends SceneTree
const WALK = preload("res://resources/core/user_standing/walk_cycle.gd")
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func frames(count: int) -> void:
	for i in count:await physics_frame;await process_frame
func run() -> void:
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("walk-cycle-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	for entry in [[false,"prologue"],[true,"prologue"],[true,"prologue_v2"],[true,"hub"],[true,"terra"]]:
		app.selected_level=entry[1]
		app.launch(entry[0])
		await frames(8)
		var hero: CoreMovementPlayer=app.game.player
		var body=hero.body
		for key in ["Hip","Knee","Ankle","Toe"]:check(body.bones["Near"+key].rest.is_equal_approx(body.bones["Far"+key].rest),"equal rest "+key+str(entry))
		hero.set_physics_process(false)
		body.state="walk"
		body.walk_blend=1
		var max_error := 0.0
		var heights: Array[float]=[]
		for frame in 64:
			body.phase=float(frame)/64
			body._show_frame()
			max_error=maxf(max_error,body.model.position.distance_to(Vector2(WALK.OFFSETS[frame][0],WALK.OFFSETS[frame][1])))
			for key in ["Pelvis","NearHip","NearKnee","NearAnkle","FarHip","FarKnee","FarAnkle"]:
				var index := WALK.NAMES.find(key)
				max_error=maxf(max_error,absf(angle_difference(body.bones[key].rotation,WALK.ANGLES[frame][index])))
			heights.append(body.model.position.y)
		check(max_error<.0001,"64 approved samples reproduced "+str(entry))
		var half_error := 0.0
		for i in 32:half_error=maxf(half_error,absf(heights[i]-heights[i+32]))
		check(half_error<.0001,"no asymmetric body dip "+str(entry))
		if entry[0]==false:
			var catalog=preload("res://scripts/campaign/catalog.gd")
			for weapon in catalog.WEAPONS:
				catalog.equip(hero.weapon,weapon.id)
				hero.weapon.aim_override=hero.global_position+Vector2(400,-hero.world_height()*.6)
				body.facing=1
				var grips_ok := true
				for i in 4:
					body.phase=float(i)/4
					body._show_frame()
					hero.weapon._update_aim()
					body.update_arms()
					var pose: Dictionary=hero.weapon.visual_pose()
					grips_ok=grips_ok and body.near_arm.hand.distance_to(pose.rear_grip)<.2 and body.far_arm.hand.distance_to(pose.front_grip)<.2
				check(grips_ok,"walk weapon grips "+weapon.id)
		body.reset_visual()
		check(body.walk_blend==0 and absf(body.bones.Pelvis.rotation)<.0001,"idle clears cycle pelvis "+str(entry))
		hero.set_physics_process(true)
		Input.action_press("core_walk")
		Input.action_press("core_right")
		var origin := hero.global_position
		await frames(20)
		Input.action_release("core_right")
		Input.action_release("core_walk")
		check(hero.global_position.x>origin.x and body.state=="walk" and body.walk_blend>.99,"Ctrl walk activates cycle "+str(entry))
		await frames(20)
		check(body.walk_blend<.001,"walk exit blend completes "+str(entry))
		await app.return_to_menu()
	app.queue_free()
	await process_frame
	print("PLAYER_WALK failures=",failures)
	quit(int(failures>0))
