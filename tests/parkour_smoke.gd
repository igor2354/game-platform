extends SceneTree
var checks := 0
var failures := 0
var app: Node
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var fixtures: Node2D
var directory := OS.get_environment("TEMP").path_join("parkour-test-%d" % OS.get_process_id())
const ACTIONS := ["core_jump","core_right","core_left","core_fire","core_aim","core_dash","core_grab","core_crouch"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else: failures += 1; push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func release() -> void:
	for action in ACTIONS: Input.action_release(action)
func block(rect: Rect2,one_way := false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 8 if one_way else 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	shape.one_way_collision = one_way
	body.add_child(shape)
	fixtures.add_child(body)
	return body
func course(height: float,width: float,one_way := false,floor_present := true) -> StaticBody2D:
	release()
	if fixtures:
		fixtures.queue_free()
		await frames(2)
	fixtures = Node2D.new()
	lab.add_child(fixtures)
	if floor_present: block(Rect2(7700,760,1000,80))
	return block(Rect2(8000,760-height,width,8 if one_way else height),one_way)
func place(point: Vector2,face := 1.0,grounded := true) -> void:
	release()
	hero.reset_to(point)
	hero.facing = face
	hero.weapon.aim_override = point+Vector2(face*500,-36)
	if grounded: await frames(6)
func hold() -> void:
	Input.action_press("core_jump")
	await frames(2)
func finish() -> void:
	if hero.parkour_active() and hero.parkour.stage == "ledge_hang":
		Input.action_release("core_jump")
		await frames(2)
		Input.action_press("core_jump")
		await frames(2)
	# Both a started pull-up and a vault must finish without holding Jump.
	Input.action_release("core_jump")
	for i in 130:
		await frames(1)
		if not hero.parkour_active(): break
	Input.action_release("core_jump")
	await frames(5)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	for character in (["sofia"] if "--sofia-only" in OS.get_cmdline_user_args() else ["sofia","harry"]):
		app = preload("res://scripts/campaign/frontend.gd").new()
		app.load_user_settings = false
		app.test_settings_directory = directory.path_join(character)
		root.add_child(app)
		app.selected_character = character
		app.launch(false)
		await frames(6)
		lab = app.game
		hero = lab.player
		hero.weapon.tuning.sound_enabled = false
		for face in [1.0,-1.0]:
			await course(48,56)
			var start := Vector2(7982 if face > 0 else 8074,760)
			await place(start,face)
			await frames(8)
			check(not hero.parkour_active(),character+" no automatic capture without held Space "+str(face))
			await hold()
			check(hero.parkour_active() and hero.parkour.kind == "vault",character+" held Space starts chest-high vault "+str(face))
			await finish()
			check(not hero.parkour_active() and hero.is_on_floor() and (hero.position.x > 8070 if face > 0 else hero.position.x < 7986) and absf(hero.position.y-760)<1,character+" vault clears obstacle and lands on far ground "+str(face))
			check(hero.collision_mask == hero.WORLD_MASK and hero.collision_height() == hero.HEIGHT,character+" vault retains full body and world collision")
			await course(70,180)
			await place(Vector2(7982 if face > 0 else 8198,760),face)
			await hold()
			check(hero.mode == "ledge_hang",character+" taller wide ledge enters grip "+str(face))
			var hanging_position := hero.position
			await frames(45)
			check(hero.mode == "ledge_hang" and hero.position.is_equal_approx(hanging_position),character+" holding original Jump does not start pull-up "+str(face))
			Input.action_release("core_jump")
			await frames(45)
			check(hero.mode == "ledge_hang" and hero.position.is_equal_approx(hanging_position),character+" release leaves stable indefinite hang "+str(face))
			await finish()
			check(hero.is_on_floor() and absf(hero.position.y-690)<1 and hero.position.x > 8000 and hero.position.x < 8180,character+" mantles onto ledge "+str(face))
		await course(140,180)
		await place(Vector2(7982,680),1,false)
		await hold()
		check(hero.mode == "ledge_hang",character+" catches reachable edge in mid-air")
		await finish()
		check(hero.is_on_floor() and absf(hero.position.y-620)<1,character+" mid-air catch completes on top")
		await course(140,180,true)
		await place(Vector2(7982,680),1,false)
		await hold()
		check(hero.parkour_active(),character+" catches thin one-way platform edge")
		await finish()
		check(hero.is_on_floor() and absf(hero.position.y-620)<1,character+" one-way edge supports completed mantle")
		await course(70,180)
		await place(Vector2(7982,760))
		await hold()
		Input.action_release("core_jump")
		await frames(2)
		check(hero.parkour_active() and hero.mode == "ledge_hang",character+" releasing Space preserves grip")
		Input.action_press("core_crouch")
		await frames(2)
		check(not hero.parkour_active(),character+" fresh crouch press drops grip")
		await frames(12)
		check(hero.is_on_floor() and hero.position.x < 8000,character+" released grip falls safely")
		for obstacle in [[48,56],[70,180]]:
			for face in [1.0,-1.0]:
				await course(obstacle[0],obstacle[1])
				var point := Vector2(7982 if face > 0 else 8000+obstacle[1]+18,760)
				await place(point,-face)
				# Isolate facing from the ordinary jump launched when capture is rejected.
				hero.tuning.jump_enabled = false
				Input.action_press("core_right" if face > 0 else "core_left")
				await hold()
				check(not hero.parkour_active(),character+" cannot parkour backwards despite movement toward obstacle "+str(obstacle[0])+" "+str(face))
				hero.weapon.aim_override = point+Vector2(face*500,-36)
				await frames(2)
				check(hero.parkour_active(),character+" turning gaze toward obstacle allows held-Jump capture "+str(obstacle[0])+" "+str(face))
				release()
				await finish()
				hero.tuning.jump_enabled = true
		await course(70,180)
		await place(Vector2(7982,760))
		await hold()
		Input.action_press("core_crouch")
		await frames(30)
		check(not hero.parkour_active() and hero.is_on_floor(),character+" crouch cancellation cannot recatch while original Jump stays held")
		release()
		await frames(2)
		await hold()
		check(hero.mode == "ledge_hang",character+" new Jump after dropping rearms capture")
		Input.action_release("core_jump")
		await frames(12)
		Input.action_press("core_jump")
		await frames(3)
		Input.action_release("core_jump")
		await frames(2)
		check(hero.mode == "mantle",character+" fresh Jump starts pull-up and release does not interrupt")
		Input.action_press("core_crouch")
		await frames(2)
		check(not hero.parkour_active(),character+" crouch interrupts pull-up in progress")
		await course(48,56)
		await place(Vector2(7982,760))
		await hold()
		Input.action_release("core_jump")
		await frames(3)
		check(hero.parkour_active() and hero.mode == "vault",character+" vault continues after releasing Jump")
		Input.action_press("core_crouch")
		await frames(2)
		check(not hero.parkour_active(),character+" crouch interrupts vault")
		await course(70,180)
		await place(Vector2(7950,760))
		await hold()
		check(not hero.parkour_active() and hero.velocity.y < 0,character+" out of reach keeps ordinary jump")
		await place(Vector2(7900,760))
		await hold()
		await frames(55)
		Input.action_press("core_crouch")
		await frames(3)
		check(hero.crouching and not hero.parkour_active(),character+" held jump search does not force standing away from ledges")
		await place(Vector2(7982,760))
		hero.tuning.parkour_enabled = false
		await hold()
		check(not hero.parkour_active() and hero.velocity.y < 0,character+" disabled parkour retains jump")
		hero.tuning.parkour_enabled = true
		await place(Vector2(7982,760))
		await hold()
		hero.tuning.parkour_enabled = false
		hero.apply_feature_settings()
		check(not hero.parkour_active() and hero.tuning.parkour_ledge_height == 76,character+" live disable releases grip without resetting parameters")
		hero.tuning.parkour_enabled = true
		await place(Vector2(7982,760))
		await hold()
		var shots := hero.weapon.shots_fired
		Input.action_press("core_fire")
		Input.action_press("core_aim")
		hero.weapon.magazine_ammo = 1
		check(not hero.weapon.request_reload() and not hero.grenades.prepare() and not hero.dash_available(),character+" hands busy: reload grenade and dash unavailable")
		await frames(8)
		check(hero.weapon.shots_fired == shots and not hero.weapon.aiming,character+" no shots or ADS during traversal")
		hero.receive_shove(Vector2(-100,-40))
		check(not hero.parkour_active() and hero.velocity.x == -100,character+" shove interrupts and preserves impulse")
		await place(Vector2(7982,760))
		await hold()
		hero.reset_to(Vector2(7900,760))
		check(not hero.parkour_active() and hero.parkour.cooldown == 0,character+" F8 clears traversal")
		await course(70,180)
		block(Rect2(7980,610,240,30))
		await frames(2)
		await place(Vector2(7982,760))
		await hold()
		check(not hero.parkour_active(),character+" overhead obstruction rejects full-body route")
		await course(200,180)
		await place(Vector2(7982,760))
		await hold()
		check(not hero.parkour_active(),character+" unreachable top cannot be grabbed through wall")
		await course(70,12)
		await place(Vector2(7982,760))
		await hold()
		check(not hero.parkour_active(),character+" narrow post has insufficient standing support")
		await course(48,180)
		await place(Vector2(7982,760))
		await hold()
		check(hero.parkour.kind == "mantle" and hero.parkour_active(),character+" wide low obstacle climbs onto top instead of crossing unlimited distance")
		await finish()
		check(hero.is_on_floor() and absf(hero.position.y-712)<1,character+" wide obstacle finishes on top")
		await course(70,180)
		await place(Vector2(7982,760))
		await hold()
		var position := hero.position
		hero.input_blocker = func(): return true
		await frames(10)
		check(hero.position.is_equal_approx(position) and hero.parkour_active(),character+" UI input blocker holds traversal safely")
		hero.input_blocker = Callable()
		await finish()
		await place(Vector2(7982,760))
		await hold()
		block(Rect2(7998,610,80,30))
		await frames(5)
		await finish()
		check(not hero.parkour_active() and hero.position.x < 8000,character+" new obstruction aborts swept movement without passing through")
		# Existing polygon obstacle, no custom tagging or level-specific trigger.
		await place(Vector2(622,760))
		await hold()
		check(hero.parkour_active(),character+" existing polygon obstacle is climbable")
		await finish()
		check(hero.is_on_floor() and absf(hero.position.y-690)<1,character+" existing polygon mantle finishes")
		await place(Vector2(782,760))
		await hold()
		check(hero.parkour_active() and hero.parkour.kind == "vault",character+" new polygon low block triggers vault")
		await finish()
		check(hero.position.x > 870 and hero.is_on_floor() and absf(hero.position.y-760)<1,character+" new polygon low block clears to far ground")
		var removable := await course(70,180)
		await place(Vector2(7982,760))
		await hold()
		removable.queue_free()
		await frames(3)
		check(not hero.parkour_active(),character+" disappearing surface releases grip")
		await course(140,180,true)
		await place(Vector2(7982,667),1,false)
		await hold()
		check(hero.parkour_active(),character+" thin platform detected between former probe heights")
		await finish()
		await course(70,180)
		await place(Vector2(7982,760))
		hero.tuning.jump_enabled = false
		await hold()
		check(hero.parkour_active(),character+" parkour switch is independent of jump impulse")
		hero.tuning.jump_enabled = true
		var paused_position := hero.position
		paused = true
		await frames(5)
		check(hero.position == paused_position,character+" pause freezes traversal")
		paused = false
		hero.blast_ragdoll.start(Vector2(-100,0),.2,.3)
		check(not hero.parkour_active() and hero.blast_ragdoll.active,character+" ragdoll interrupts traversal")
		hero.reset_to(Vector2(7982,760))
		await frames(6)
		await hold()
		hero.set_current_health(0)
		await frames(2)
		check(not hero.parkour_active(),character+" death releases ledge")
		await place(Vector2(7982,760))
		await hold()
		hero.transition_to(Vector2(7900,760))
		check(not hero.parkour_active(),character+" level transition clears traversal")
		var values := hero.tuning.as_dictionary()
		check(lab.movement_overlay.feature_toggles.has("parkour_enabled") and lab.movement_overlay.rows.has("parkour_reach"),character+" developer UI exposes toggle and numeric sliders")
		hero.tuning.set_parameter("parkour_reach",17)
		hero.tuning.parkour_enabled = false
		check(hero.tuning.save_saved(directory.path_join("movement.cfg")) == OK,character+" isolated CFG saved")
		var loaded := CoreMovementSettings.new()
		loaded.load_saved(directory.path_join("movement.cfg"))
		check(loaded.parkour_reach == 17 and not loaded.parkour_enabled,character+" CFG round-trip retains parkour values")
		var preset := directory.path_join("parkour.json")
		check(lab.export_settings_file(preset),character+" exports parkour to balance JSON")
		hero.tuning.parkour_reach = 3
		hero.tuning.parkour_enabled = true
		check(lab.import_settings_file(preset) and hero.tuning.parkour_reach == 17 and not hero.tuning.parkour_enabled,character+" JSON import restores parkour and UI in isolated five profiles")
		var file := FileAccess.open(directory.path_join("legacy.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"format":"dead-platform-settings","version":1,"movement":{"run_speed":240},"shooting":{"fire_mode":0},"camera":{"zoom":2}}))
		file.close()
		check(lab.import_settings_file(directory.path_join("legacy.json")) and hero.tuning.parkour_enabled and hero.tuning.parkour_reach == 12,character+" old JSON receives parkour defaults")
		hero.tuning.apply_values(values)
		release()
		await app.return_to_menu()
		fixtures = null
		app.launch(true)
		await frames(6)
		lab = app.game
		hero = lab.player
		hero.weapon.tuning.sound_enabled = false
		var root_rect: Rect2 = lab.level.forest.features.root
		await place(Vector2(root_rect.position.x-18,760))
		Input.action_press("core_jump")
		await frames(7)
		check(hero.parkour_active(),character+" held jump catches actual forest trunk after take-off")
		await finish()
		check(hero.is_on_floor() and absf(hero.position.y-root_rect.position.y)<1,character+" forest trunk completes mantle in campaign")
		release()
		await app.return_to_menu()
		app.queue_free()
		fixtures = null
		await frames(3)
	print("PARKOUR: %d/%d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
