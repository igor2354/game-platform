extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var gun: CoreShootingController
var checks := 0
var failures := 0
var directory := (OS.get_environment("TEMP") if OS.has_feature("windows") else "/private/tmp").path_join("reload-test-%d" % OS.get_process_id())
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func release() -> void:
	for action in ["core_fire","core_aim","core_right","core_left","core_jump","core_crouch","core_sprint","core_up","core_dash"]: Input.action_release(action)
func key(code: Key,echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	root.push_input(event,true)
	event.pressed = false
	root.push_input(event,true)
	await frames(2)
func setup(capacity := 10,reserve := 30) -> void:
	release()
	gun.tuning.apply_values({"magazine_capacity":capacity,"starting_reserve":reserve,"reload_duration":.5,"reload_move_multiplier":.75,"fire_mode":0})
	hero.reset_to(Vector2(160,760))
	gun.aim_override = hero.position+Vector2(1000,-36)
	await frames(5)
func run() -> void:
	root.size = Vector2i(1440,900)
	root.gui_embed_subwindows = true
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("FAIL cannot create isolated reload-test directory")
		quit(1)
		return
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	lab.settings_path = directory+"/movement.cfg"
	lab.shooting_settings_path = directory+"/shooting.cfg"
	lab.camera_settings_path = directory+"/camera.cfg"
	lab.zombie_settings_path = directory+"/zombie.cfg"
	lab.ragdoll_settings_path = directory+"/ragdoll.cfg"
	root.add_child(lab)
	check(lab._overlays().all(func(overlay): return overlay.settings_path.begins_with(directory+"/")),"all actual save paths are isolated before imports")
	hero = lab.player
	gun = hero.weapon
	await frames(8)
	check(gun.magazine_ammo == 71 and gun.reserve_ammo == 213 and lab.ammo_label.visible and lab.ammo_label.text.contains("71/71"),"ordinary startup has a finite PPSh drum, finite reserve and visible ammo HUD")
	check(InputMap.action_get_events("core_reload")[0].physical_keycode == KEY_R and InputMap.action_get_events("core_reset")[0].physical_keycode == KEY_F8,"R reloads and F8 replaces the old reset key")
	await setup(3,2)
	Input.action_press("core_fire")
	await frames(40)
	check(gun.shots_fired == 3 and gun.magazine_ammo == 0 and gun.reserve_ammo == 2,"automatic fire consumes exactly one magazine and stops without spending reserve")
	check(not gun.firing and gun.movement_multiplier == 1 and gun.burst_time == 0,"holding an empty trigger does not retain shooting slowdown")
	Input.action_release("core_fire")
	await frames(2)
	Input.action_press("core_fire")
	await frames(30)
	check(gun.shots_fired == 3 and gun.dry_clicks == 1,"empty trigger gives one dry click instead of bullets or repeated automatic clicking")
	release()
	await frames(2)
	var position := hero.position
	await key(KEY_R)
	check(gun.reloading and hero.position == position and lab.respawns == 0,"a physical R key begins reload without resetting or moving the hero")
	var remaining := gun.reload_left
	await key(KEY_R,true)
	check(gun.reload_left < remaining,"key repeat cannot restart or lengthen an active reload")
	await frames(35)
	check(not gun.reloading and gun.magazine_ammo == 2 and gun.reserve_ammo == 0 and gun.reloads_completed == 1,"reload transfers the available reserve only, allowing a partly filled magazine")
	Input.action_press("core_fire")
	await frames(20)
	release()
	check(gun.shots_fired == 5 and gun.magazine_ammo == 0 and not gun.request_reload(),"a depleted reserve cannot create ammunition")
	await setup(10,20)
	gun.magazine_ammo = 4
	check(gun.request_reload(),"a partial magazine may be reloaded")
	await frames(18)
	check(gun.magazine_ammo == 4 and gun.reserve_ammo == 20 and gun.old_magazine_dropped,"round transfer is deferred while the old drum is visibly removed")
	await frames(20)
	check(gun.magazine_ammo == 10 and gun.reserve_ammo == 14 and gun.reload_cues == 3 and gun.effects.filter(func(effect): return effect.kind == "magazine").size() == 1,"partial reload conserves rounds and produces one dropped drum plus three mechanical cues")
	check(not gun.request_reload(),"a full magazine cannot start another reload")
	# Stand/crouch, both sides, live arm manipulation and a stable camera gaze.
	for side in [-1.0,1.0]:
		for crouched in [false,true]:
			await setup(10,20)
			gun.tuning.reload_duration = 1.5
			gun.aim_override = hero.position+Vector2(side*1000,-30)
			if crouched: Input.action_press("core_crouch")
			await frames(8)
			gun.magazine_ammo = 3
			Input.action_press("core_aim")
			await frames(10)
			check(gun.request_reload(),"reload starts while aiming, side %s crouch %s" % [side,crouched])
			var hands_move := false
			var grips_ok := true
			var muzzle_raised := true
			var front_arm_stable := true
			var held_direction := hero.body.facing
			for i in 80:
				await frames(1)
				var pose := gun.visual_pose()
				front_arm_stable = front_arm_stable and hero.body.near_arm.get_index() > hero.visuals.gun.get_index() and hero.visuals.gun.get_index() > hero.visuals.reload_magazine.get_index() and hero.visuals.reload_magazine.get_index() > hero.body.far_arm.get_index() and not hero.body.near_arm.hand_in_front and not hero.body.far_arm.hand_in_front and not hero.body.near_arm.foreground.visible and not hero.body.far_arm.foreground.visible
				if gun.reloading and gun.reload_progress() >= .2 and gun.reload_progress() <= .89:
					muzzle_raised = muzzle_raised and pose.direction.y < -.5 and pose.direction.x*side > .5
				grips_ok = grips_ok and hero.body.near_arm.hand.distance_to(pose.rear_grip) < .001 and hero.body.far_arm.hand.distance_to(pose.front_grip) < .001 and hero.body.facing == held_direction
				hands_move = hands_move or hero.body.far_arm.hand.distance_to(pose.breech+pose.direction*20+pose.normal*3) > 8
			check(grips_ok and hands_move and not gun.aiming and gun.magazine_ammo == 3,"main hand holds the gun while the support hand changes the magazine and operates the bolt")
			check(muzzle_raised,"reload keeps the muzzle upward and in the held facing, side %s crouch %s" % [side,crouched])
			check(hero.visuals.reload_magazine.get_parent() == hero.visuals and hero.visuals.reload_magazine.get_index() > hero.body.far_arm.get_index() and hero.visuals.reload_magazine.get_index() < hero.body.get_index() and hero.visuals.reload_magazine.get_index() < hero.body.near_arm.get_index() and hero.visuals.reload_magazine.get_index() < hero.visuals.gun.get_index(),"reload drum stays behind torso, weapon and near arm, but in front of far arm, side %s crouch %s" % [side,crouched])
			check(front_arm_stable and hero.body.far_arm.get_index() < hero.body.get_index(),"every phase keeps near arm > weapon > drum > far arm, with both hands on their own arm layer")
			await frames(15)
			check(gun.magazine_ammo == 10 and hero.body.far_arm.get_index() < hero.body.get_index() and hero.body.near_arm.get_index() > hero.visuals.gun.get_index() and not hero.body.far_arm.foreground.visible and not hero.body.near_arm.foreground.visible and not hero.body.far_arm.hand_in_front and not hero.body.near_arm.hand_in_front,"completion restores normal arms with no leftover foreground hand layer")
	await setup(10,20)
	gun.tuning.reload_duration = 1.5
	gun.magazine_ammo = 2
	gun.request_reload()
	Input.action_press("core_right")
	Input.action_press("core_sprint")
	await frames(22)
	check(gun.reloading and not hero.sprinting and absf(hero.velocity.x-hero.tuning.run_speed*.75) < 1,"reload permits movement but applies its own slowdown and prevents sprint")
	Input.action_press("core_jump")
	await frames(8)
	check(not hero.is_on_floor() and gun.reloading,"ordinary jump does not cancel magazine handling")
	release()
	await setup(10,20)
	gun.tuning.reload_duration = 1.5
	gun.magazine_ammo = 2
	gun.request_reload()
	await frames(20)
	var held := [gun.reload_left,gun.magazine_ammo,gun.reserve_ammo,hero.body.far_arm.hand,gun.effects.duplicate(true)]
	paused = true
	await frames(25)
	check(held == [gun.reload_left,gun.magazine_ammo,gun.reserve_ammo,hero.body.far_arm.hand,gun.effects.duplicate(true)],"pause freezes reload progress, hand pose, inventory and the dropped magazine")
	paused = false
	gun.tuning.reload_duration = .5
	await frames(15)
	check(gun.reloading and gun.reload_duration_active == 1.5,"editing duration does not retime an already started reload")
	Input.action_press("core_dash")
	await frames(3)
	check(hero.dash_left > 0 and not gun.reloading and gun.magazine_ammo == 2 and gun.reserve_ammo == 20,"dash interrupts reload without granting or losing rounds")
	await setup(10,20)
	gun.magazine_ammo = 2
	gun.request_reload()
	hero.set_current_health(0)
	await frames(2)
	check(not gun.reloading and gun.magazine_ammo == 2 and gun.reserve_ammo == 20,"death cancels the transaction without transferring rounds")
	await setup(10,20)
	gun.magazine_ammo = 2
	gun.request_reload()
	paused = true
	hero.set_current_health(0)
	hero.set_current_health(100)
	check(not gun.reloading and gun.magazine_ammo == 2 and gun.reserve_ammo == 20,"manual death and revival on pause cannot resume an interrupted reload")
	paused = false
	await setup(10,20)
	hero.reset_to(Vector2(1446,760))
	gun.magazine_ammo = 2
	gun.request_reload()
	Input.action_press("core_up")
	await frames(5)
	check(hero.climbing and not gun.reloading and gun.magazine_ammo == 2,"entering a ladder interrupts reload and restores ladder grips")
	# Trigger behavior on completion stays different for single and auto fire.
	for mode in [0,1]:
		await setup(3,6)
		gun.tuning.set_fire_mode(mode)
		gun.magazine_ammo = 0
		gun.request_reload()
		Input.action_press("core_fire")
		await frames(38)
		check((gun.shots_fired > 0 if mode == 0 else gun.shots_fired == 0),"held trigger after reload respects the selected fire mode "+str(mode))
		release()
		await frames(2)
		if mode == 1:
			Input.action_press("core_fire")
			await frames(3)
			check(gun.shots_fired == 1 and gun.magazine_ammo == 2,"single mode fires once after a fresh press following reload")
	await setup(10,20)
	gun.magazine_ammo = 7
	gun.tuning.apply_values({"magazine_capacity":4})
	gun.apply_tuning()
	check(gun.magazine_ammo == 4 and gun.reserve_ammo == 23,"reducing magazine size returns overflow to reserve")
	gun.tuning.apply_values({"magazine_capacity":15})
	gun.apply_tuning()
	check(gun.magazine_ammo == 4 and gun.reserve_ammo == 23,"increasing magazine size cannot generate new rounds")
	var dev := lab.developer_mode
	dev.set_enabled(true)
	dev.show_overlay(1)
	lab.shooting_overlay.tabs.current_tab = lab.shooting_overlay.groups.find("Магазин")
	check(lab.shooting_overlay.rows.has("magazine_capacity") and lab.shooting_overlay.rows.has("starting_reserve") and lab.shooting_overlay.rows.has("reload_duration") and lab.shooting_overlay.rows.has("reload_move_multiplier"),"F4 has a dedicated ammunition page with all balance controls")
	var line: LineEdit = lab.shooting_overlay.rows.magazine_capacity.number.get_line_edit()
	line.grab_focus()
	await process_frame
	line.text = "11"
	await key(KEY_R)
	check(not gun.reloading and hero.position == Vector2(160,760),"typing R in a balance field cannot reload or reset the game")
	dev.set_enabled(false)
	check(gun.capacity() == 11,"closing settings commits the magazine capacity edit")
	gun.magazine_ammo = 2
	gun.reserve_ammo = 5
	gun.request_reload()
	paused = true
	dev.set_enabled(true)
	dev.show_section(CoreDeveloperMode.Section.TESTING)
	var shots := gun.shots_fired
	dev.ammo_button.pressed.emit()
	check(paused and not gun.reloading and gun.magazine_ammo == 11 and gun.reserve_ammo == 20 and gun.shots_fired == shots,"developer resupply works on pause without resetting combat statistics")
	dev.set_enabled(false)
	paused = false
	gun.magazine_ammo = 2
	gun.reserve_ammo = 1
	await key(KEY_F7)
	check(gun.magazine_ammo == 2 and gun.reserve_ammo == 1,"enemy respawn does not refill player ammunition")
	await key(KEY_F8)
	check(gun.magazine_ammo == 11 and gun.reserve_ammo == 20 and lab.respawns == 1,"F8 returns the player to start with configured ammunition")
	gun.tuning.save_saved(directory+"/weapon.cfg")
	var loaded := CoreShootingSettings.new()
	check(loaded.load_saved(directory+"/weapon.cfg") == OK and loaded.magazine_capacity == 11 and loaded.reload_duration == .5,"shooting profile preserves ammunition and reload settings")
	var legacy := ConfigFile.new()
	legacy.set_value("shooting","damage",30)
	legacy.save(directory+"/old.cfg")
	loaded = CoreShootingSettings.new()
	check(loaded.load_saved(directory+"/old.cfg") == OK and loaded.magazine_capacity == 71 and loaded.starting_reserve == 213,"old profiles receive the default magazine and reserve")
	lab.export_settings_file(directory+"/balance.json")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"/balance.json"))
	check(data.shooting.magazine_capacity == 11 and data.shooting.reload_duration == .5 and not data.shooting.has("magazine_ammo") and not data.shooting.has("reloading"),"JSON carries balance values without saving live ammunition or animation state")
	release()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
