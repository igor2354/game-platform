extends SceneTree
const MOUNT = preload("res://scripts/campaign/weapon_mount.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else: failures += 1; push_error("FAIL "+message)
func run() -> void:
	var campaign := "--campaign" in OS.get_cmdline_user_args()
	var app := preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("down-aim-cache-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	app.begin_selection(campaign)
	app.select_character("sofia")
	app.launch(campaign)
	for i in 8: await physics_frame; await process_frame
	var hero: CoreMovementPlayer = app.game.player
	hero.set_physics_process(false)
	app.game.aim_cursor.set_process(false)
	var gun := hero.weapon
	gun.tuning.sound_enabled = false
	MOUNT.diagnostics_enabled = true
	for data in CATALOG.WEAPONS:
		hero.reset_to(Vector2(12400,760) if campaign else Vector2(1900,760))
		CATALOG.equip(gun,data.id)
		hero.body.state = "idle"
		hero.body.down_aim_blend = 1
		gun.aiming = true
		gun.ads_blend = 1
		gun.aim_override = hero.position+Vector2(0,8)
		MOUNT.cache.clear()
		MOUNT.fit_requests = 0
		gun._update_aim()
		check(MOUNT.fit_requests <= 5,"one fit per bearing iteration, no double down-mount fit: "+data.id)
		hero.body.update_arms()
		var expected := gun.visual_pose()
		MOUNT.cache.clear()
		MOUNT.searches = 0
		MOUNT.fit_requests = 0
		for i in 100:
			gun._update_aim()
			gun.visual_pose()
			hero.body.update_arms()
		check(MOUNT.fit_requests == 0 and MOUNT.searches == 0 and gun.visual_pose() == expected,"100 unchanged cursor/arm/draw updates need zero mount searches: "+data.id)
		gun.aim_override = hero.position+Vector2(8,8)
		gun._update_aim()
		var aim_error := absf((gun.aim_point-gun.pivot()).cross(gun.aim_direction))
		print("BEARING ",data.id," error_world_units=",aim_error)
		check(MOUNT.fit_requests > 0 and aim_error < .1,"cursor motion recomputes the ballistic bearing immediately: "+data.id)
		MOUNT.fit_requests = 0
		gun.recoil_back = 1.2
		gun._update_aim()
		check(MOUNT.fit_requests > 0,"same-tick physical recoil invalidates the aim solution: "+data.id)
		paused = true
		MOUNT.fit_requests = 0
		gun.ads_blend = .35
		hero.body.down_aim_blend = .5
		gun._update_aim()
		check(MOUNT.fit_requests > 0,"paused ADS/artwork edits invalidate the aim solution: "+data.id)
		paused = false
		hero.body.down_aim_blend = 1
		gun.ads_blend = 1
		gun.aim_override = hero.position+Vector2(0,8)
		gun._update_aim()
		var before := gun.shots_fired
		gun._fire()
		hero.body.update_arms()
		var pose := gun.visual_pose()
		check(gun.shots_fired == before+1 and hero.body.near_arm.hand.distance_to(pose.rear_grip) < .1 and hero.body.far_arm.hand.distance_to(pose.front_grip) < .1,"real recoil shot retains both fixed-length weapon grips: "+data.id)
	MOUNT.diagnostics_enabled = false
	await app.return_to_menu()
	app.queue_free()
	for i in 3: await process_frame
	print("DOWNWARD AIM CACHE: %d/%d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
