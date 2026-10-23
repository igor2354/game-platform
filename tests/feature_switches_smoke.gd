extends SceneTree
var lab: CoreMovementLab
var checks := 0
var failures := 0
var directory := (OS.get_environment("TEMP") if not OS.get_environment("TEMP").is_empty() else "/tmp").path_join("feature-switches-%d" % OS.get_process_id())
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame
func flag(overlay: CoreMovementOverlay,key: String,value: bool) -> void:
	overlay.feature_toggles[key].button_pressed = value
func release() -> void:
	for action in ["core_left","core_right","core_walk","core_sprint","core_jump","core_dash","core_crouch","core_up","core_fire","core_aim"]: Input.action_release(action)
func reset() -> void:
	release()
	lab.player.reset_to(CoreMovementLevel.SPAWN)
	await frames(8)
func run() -> void:
	root.size = Vector2i(1600,900)
	root.gui_embed_subwindows = true
	DirAccess.make_dir_recursive_absolute(directory)
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	lab.settings_path = directory+"/movement.cfg"
	lab.shooting_settings_path = directory+"/shooting.cfg"
	lab.camera_settings_path = directory+"/camera.cfg"
	lab.zombie_settings_path = directory+"/zombie.cfg"
	lab.ragdoll_settings_path = directory+"/ragdoll.cfg"
	root.add_child(lab)
	await frames(8)
	var hero := lab.player
	var gun := hero.weapon
	var move := lab.movement_overlay
	var shoot := lab.shooting_overlay
	var cam := lab.camera_overlay
	gun.aim_override = hero.position+Vector2(3000,-36)
	var total := 0
	for overlay in lab._ui_overlays():
		var toggles: Dictionary = overlay.zombie_toggles if overlay.settings is CoreZombieSettings else overlay.feature_toggles
		var covered_groups := {}
		for entry in overlay.settings.SWITCHES:
			if toggles.has(entry[0]): covered_groups[entry[2]] = true
		total += covered_groups.size()
		var defaults_match := true
		for key in toggles: defaults_match = defaults_match and toggles[key].button_pressed == overlay.defaults.get(key)
		check(covered_groups.size() == overlay.groups.size() and defaults_match,"every mechanic has a master switch with deliberate defaults, including opt-in noir: "+overlay.heading_text)
	check(total == 40,"all 40 mechanic pages have switches")
	flag(move,"run_enabled",false)
	Input.action_press("core_right")
	await frames(30)
	check(absf(hero.velocity.x) < 1,"disabling Run stops ordinary horizontal movement")
	Input.action_press("core_walk")
	await frames(30)
	check(hero.walking and absf(hero.velocity.x-140) < 1,"Walk remains independent while Run is off")
	flag(move,"run_enabled",true)
	await reset()
	flag(move,"walk_enabled",false)
	Input.action_press("core_walk")
	Input.action_press("core_right")
	await frames(30)
	check(not hero.walking and absf(hero.velocity.x-320) < 1,"disabling Walk leaves normal Run available")
	flag(move,"walk_enabled",true)
	await reset()
	flag(move,"sprint_enabled",false)
	Input.action_press("core_sprint")
	Input.action_press("core_right")
	await frames(30)
	check(not hero.sprinting and absf(hero.velocity.x-320) < 1,"Sprint switch disables sprint rather than rewriting its speed")
	flag(move,"sprint_enabled",true)
	await reset()
	flag(move,"jump_enabled",false)
	Input.action_press("core_jump")
	await frames(2)
	check(hero.jumps == 0 and hero.is_on_floor(),"Jump switch blocks new jumps")
	Input.action_release("core_jump")
	await frames(1)
	flag(move,"jump_enabled",true)
	Input.action_press("core_jump")
	await frames(2)
	check(hero.jumps == 1 and hero.velocity.y < 0,"reenabling Jump restores its original impulse")
	await reset()
	flag(move,"dash_enabled",false)
	Input.action_press("core_dash")
	await frames(2)
	check(hero.dashes == 0 and not hero.dash_available(),"Dash switch blocks activation")
	Input.action_release("core_dash")
	await frames(1)
	flag(move,"dash_enabled",true)
	Input.action_press("core_dash")
	await frames(1)
	flag(move,"dash_enabled",false)
	check(hero.dashes == 1 and hero.dash_left == 0 and hero.get_collision_mask_value(3),"disabling an active dash safely restores enemy collisions")
	flag(move,"dash_enabled",true)
	await reset()
	Input.action_press("core_crouch")
	await frames(2)
	flag(move,"crouch_enabled",false)
	check(not hero.crouching and hero.collision_height() == CoreMovementPlayer.HEIGHT,"Crouch switch exits crouch when headroom is clear")
	flag(move,"crouch_enabled",true)
	await reset()
	Input.action_press("core_sprint")
	Input.action_press("core_right")
	await frames(30)
	Input.action_press("core_crouch")
	await frames(1)
	check(hero.slide_left > 0,"slide starts normally before being switched off")
	flag(move,"slide_enabled",false)
	check(hero.slide_left == 0 and hero.tuning.slide_damage == 25,"Slide switch cancels the active action without changing damage settings")
	flag(move,"slide_enabled",true)
	await reset()
	var ladder: Rect2 = hero.ladders[0]
	hero.reset_to(Vector2(ladder.get_center().x,ladder.end.y))
	flag(move,"ladder_enabled",false)
	check(not hero.ladder_here(-1).has_area(),"Ladder switch blocks ladder capture")
	flag(move,"ladder_enabled",true)
	hero._enter_ladder(ladder)
	flag(move,"ladder_enabled",false)
	check(not hero.climbing and hero.get_collision_mask_value(4),"disabling ladder use restores platform collisions")
	flag(move,"ladder_enabled",true)
	await reset()
	flag(move,"slopes_enabled",false)
	check(hero.tuning.slope_multiplier(35,true) == 1 and hero.tuning.uphill_multiplier == .7,"Slope switch bypasses its speed effect without erasing multipliers")
	flag(move,"slopes_enabled",true)
	flag(move,"backward_enabled",false)
	check(hero.backward_speed_multiplier(-1) == 1 and hero.tuning.run_backward_multiplier == .7,"Backward switch bypasses slowdown without erasing settings")
	flag(move,"backward_enabled",true)
	flag(move,"acceleration_enabled",false)
	check(is_equal_approx(hero.tuning.acceleration_step(0,320,0,2400,1.0/60).x,40) and hero.tuning.acceleration_smoothing == .15,"Acceleration switch selects the linear response while preserving smoothing")
	flag(move,"acceleration_enabled",true)
	flag(lab.health_overlay,"health_enabled",false)
	check(not hero.take_damage(20) and hero.health == 100 and not hero.invulnerable,"Health switch blocks incoming damage independently of the immortality tool")
	flag(lab.health_overlay,"health_enabled",true)
	check(hero.take_damage(20) and hero.health == 80,"reenabling Health restores normal damage")
	await reset()
	flag(shoot,"weapon_enabled",false)
	Input.action_press("core_fire")
	await frames(8)
	check(gun.shots_fired == 0,"Weapon switch blocks firing")
	flag(shoot,"weapon_enabled",true)
	flag(shoot,"hip_enabled",false)
	await frames(8)
	check(gun.shots_fired == 0,"Hip switch blocks hip fire")
	Input.action_press("core_aim")
	await frames(8)
	check(gun.aiming and gun.shots_fired > 0,"ADS fire still works while hip fire is disabled")
	var shots := gun.shots_fired
	flag(shoot,"ads_enabled",false)
	await frames(8)
	check(not gun.aiming and gun.shots_fired == shots,"ADS switch disables precision aiming and its firing path")
	flag(shoot,"hip_enabled",true)
	flag(shoot,"ads_enabled",true)
	await reset()
	gun.magazine_ammo = 0
	gun.reserve_ammo = 17
	flag(shoot,"magazine_enabled",false)
	Input.action_press("core_fire")
	await frames(8)
	check(gun.shots_fired > 0 and gun.magazine_ammo == 0 and gun.reserve_ammo == 17 and not gun.request_reload(),"Magazine switch gives infinite firing without changing stored ammunition")
	flag(shoot,"magazine_enabled",true)
	shots = gun.shots_fired
	await frames(8)
	check(gun.shots_fired == shots and gun.request_reload(),"reenabling Magazine restores empty-magazine restrictions and reload")
	flag(shoot,"magazine_enabled",false)
	check(not gun.reloading and gun.reserve_ammo == 17,"disabling Magazine cancels reload without transferring ammunition")
	flag(shoot,"magazine_enabled",true)
	await reset()
	flag(shoot,"recoil_enabled",false)
	flag(shoot,"sound_enabled",false)
	gun._fire()
	gun._on_impact(hero.position,true,true)
	gun._play_reload_sound("dry")
	await frames(1)
	check(gun.recoil_back == 0 and gun.recoil_angle == 0 and lab.camera_kick == Vector2.ZERO and lab.camera_shake == 0,"Recoil switch suppresses weapon and kill camera impulses")
	check(not gun.shot_audio.playing and not gun.kill_audio.playing and not gun.reload_audio.playing and gun.kill_sounds_played == 0,"Sound switch suppresses shot, kill and reload audio")
	flag(shoot,"recoil_enabled",true)
	flag(shoot,"sound_enabled",true)
	var enemy := lab.level.enemies[0]
	enemy.reset_target()
	flag(shoot,"damage_enabled",false)
	CoreProjectile.resolve_impact({"collider":enemy,"position":enemy.position},100,Vector2.RIGHT,Callable(),hero.position,gun.tuning.damage_enabled)
	check(enemy.health == 100 and enemy.missing_parts.is_empty(),"Damage switch keeps targets alive and intact on hit")
	flag(shoot,"damage_enabled",true)
	CoreProjectile.resolve_impact({"collider":enemy,"position":enemy.position},10,Vector2.RIGHT,Callable(),hero.position,gun.tuning.damage_enabled)
	check(enemy.health == 90,"reenabling Damage restores actual projectile damage")
	hero.set_physics_process(false)
	hero.velocity = Vector2(520,0)
	lab.camera_settings.character_blur_strength = 1
	lab.camera_settings.character_linear_filter = true
	flag(cam,"visual_enabled",false)
	hero.visuals.update_effect()
	check(hero.visuals.material == null and hero.body.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and lab.camera_settings.character_blur_strength == 1,"Visual switch bypasses blur and filtering while keeping their values")
	flag(cam,"visual_enabled",true)
	hero.visuals.update_effect()
	check(hero.visuals.material != null and hero.body.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,"reenabling Visual restores the configured effects")
	flag(cam,"camera_enabled",false)
	await frames(3)
	var centre := lab.camera.get_screen_center_position()
	hero.position.x += 100
	await frames(6)
	check(lab.camera.get_screen_center_position().distance_to(centre) < .1,"Camera switch freezes the actual rendered view")
	flag(cam,"camera_enabled",true)
	await frames(6)
	check(lab.camera.get_screen_center_position().distance_to(centre) > 1,"reenabling Camera resumes following the hero")
	hero.set_physics_process(true)
	await reset()
	var doll: Node2D = lab.level.ragdoll_mannequin
	doll.activate()
	await frames(3)
	flag(lab.ragdoll_overlay,"simulation_enabled",false)
	var pose: Transform2D = doll.parts.torso.global_transform
	var impacts: int = doll.impacts
	doll.parts.torso.receive_projectile_impulse(Vector2.RIGHT,doll.parts.torso.global_position,25)
	await frames(8)
	check(doll.parts.values().all(func(part): return part.freeze) and doll.parts.torso.global_transform == pose and doll.impacts == impacts,"Mannequin switch freezes pose and ignores new impulses")
	flag(lab.ragdoll_overlay,"simulation_enabled",true)
	await frames(4)
	check(doll.active and doll.parts.values().all(func(part): return not part.freeze and part.global_position.is_finite()),"reenabling Mannequin resumes the existing ragdoll")
	for overlay in lab._ui_overlays():
		for key in overlay.feature_toggles: flag(overlay,key,false)
	paused = true
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.set_enabled(false)
	check(paused and lab._ui_overlays().all(func(overlay): return overlay.feature_toggles.values().all(func(toggle): return not toggle.button_pressed)),"switch states survive closing developer mode on pause")
	lab._recover()
	check(not hero.dash_available() and not doll.simulation_enabled and lab._ui_overlays().all(func(overlay): return overlay.feature_toggles.values().all(func(toggle): return not toggle.button_pressed)),"resetting the arena preserves all disabled features")
	lab.developer_mode.save_all()
	var profiles_ok := true
	for overlay in lab._overlays():
		var candidate: Resource = overlay.defaults.duplicate()
		profiles_ok = profiles_ok and candidate.load_saved(overlay.settings_path) == OK and candidate.as_dictionary() == overlay.settings.as_dictionary()
	check(profiles_ok,"all new switches persist through the five existing CFG profiles")
	var legacy_cfg_ok := true
	for overlay in lab._overlays():
		if overlay.settings is CoreZombieSettings: continue
		var config := ConfigFile.new()
		config.load(overlay.settings_path)
		var section: String = "movement" if overlay.settings is CoreMovementSettings else "shooting" if overlay.settings is CoreShootingSettings else "camera" if overlay.settings is CoreCameraSettings else "ragdoll"
		for entry in overlay.settings.SWITCHES: config.erase_section_key(section,entry[0])
		config.save(directory+"/legacy.cfg")
		var candidate: Resource = overlay.settings.duplicate()
		candidate.load_saved(directory+"/legacy.cfg")
		for entry in overlay.settings.SWITCHES: legacy_cfg_ok = legacy_cfg_ok and candidate.get(entry[0]) == overlay.defaults.get(entry[0])
	check(legacy_cfg_ok,"legacy CFG profiles restore deliberate defaults even after live switches were off")
	check(lab.export_settings_file(directory+"/switches.json"),"feature states export through the existing JSON format")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"/switches.json"))
	for section in lab._settings_resources():
		if section == "zombie": continue
		for entry in lab._settings_resources()[section].SWITCHES: data[section].erase(entry[0])
	var file := FileAccess.open(directory+"/legacy.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var imported := lab.import_settings_file(directory+"/legacy.json")
	var json_defaults_match := true
	for overlay in lab._ui_overlays():
		for key in overlay.feature_toggles: json_defaults_match = json_defaults_match and overlay.feature_toggles[key].button_pressed == overlay.defaults.get(key)
	check(imported and json_defaults_match,"legacy JSON without new switches restores their deliberate defaults")
	release()
	lab.queue_free()
	await process_frame
	await create_timer(.2).timeout
	for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory+"/"+filename)
	DirAccess.remove_absolute(directory)
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
