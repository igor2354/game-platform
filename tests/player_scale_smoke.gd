extends SceneTree
var checks := 0
var failures := 0
var app: Node
var lab: CoreMovementLab
var hero: CoreMovementPlayer
const CATALOG = preload("res://scripts/campaign/catalog.gd")
const ACTIONS := ["core_right","core_left","core_jump","core_dash","core_crouch","core_up","core_down","core_fire","core_aim","core_grab"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else: failures += 1; push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func release() -> void:
	for action in ACTIONS: Input.action_release(action)
func place() -> void:
	release()
	hero.reset_to(Vector2(7800,760))
	hero.weapon.aim_override = Vector2(9000,500)
	await frames(6)
func block(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)
	lab.add_child(body)
	return body
func same_values(a: Dictionary,b: Dictionary) -> bool:
	if a.size()!=b.size():return false
	for key in a:
		if not b.has(key):return false
		if (a[key] is float or a[key] is int) and (b[key] is float or b[key] is int):
			if absf(float(a[key])-float(b[key]))>.000001:return false
		elif a[key]!=b[key]:return false
	return true

func run() -> void:
	var directory := (OS.get_environment("TEMP") if OS.has_feature("windows") else "/private/tmp").path_join("player-scale-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = directory
	root.add_child(app)
	app.begin_selection(false)
	app.select_character("sofia")
	app.launch(false)
	await frames(8)
	lab = app.game
	hero = lab.player
	check(lab._overlays().all(func(overlay): return overlay.settings_path.begins_with(directory+"/")),"all five profile paths isolated")
	check(lab.camera_overlay.rows.has("player_scale") and lab.camera_overlay.feature_toggles.has("player_scale_enabled"),"developer menu exposes independent switch and numeric slider")
	var floor := block(Rect2(7400,760,2400,100))
	var initial_level_transform := lab.level.transform
	var initial_ladders := hero.ladders.duplicate()
	var framing := lab.camera_settings.framing_values().duplicate()
	var initial_movement := hero.tuning.as_dictionary().duplicate()
	hero.weapon.tuning.sound_enabled = false
	hero.weapon.tuning.recoil_enabled = false
	CATALOG.equip(hero.weapon,"stg44")
	# A profile round-trip and old-profile default must preserve the independent switch.
	var settings := CoreCameraSettings.new()
	settings.player_scale_enabled = true
	settings.player_scale = 2.75/CoreWorldUnits.LEGACY_SOFIA_SCALE
	settings.save_saved(directory.path_join("scale.cfg"))
	var loaded := CoreCameraSettings.new()
	loaded.load_saved(directory.path_join("scale.cfg"))
	check(loaded.player_scale_enabled and is_equal_approx(loaded.player_scale,2.75/CoreWorldUnits.LEGACY_SOFIA_SCALE),"scale CFG roundtrip")
	var old := ConfigFile.new()
	old.set_value("camera","zoom",1.5)
	old.save(directory.path_join("old.cfg"))
	loaded.load_saved(directory.path_join("old.cfg"))
	check(not loaded.player_scale_enabled,"old profiles do not enable scale")
	# Preserve the original physical fixture sizes; UI factors now use the normalized baseline.
	for factor in [.5,1.0,2.0,4.0]:
		await place()
		var feet := hero.global_position
		var target := lab.camera_target(1)
		lab.camera_settings.player_scale_enabled = true
		lab.camera_settings.player_scale = factor/CoreWorldUnits.LEGACY_SOFIA_SCALE
		lab._camera_settings_changed()
		await frames(4)
		check(is_equal_approx(hero.body_scale,factor) and hero.scale.is_equal_approx(Vector2.ONE*factor),"uniform root scale "+str(factor))
		check(hero.global_position.distance_to(feet) < .2 and hero.is_on_floor(),"feet stay on unchanged floor "+str(factor))
		check(lab.camera_target(1).distance_to(target) < .2 and lab.camera_settings.framing_values() == framing,"camera framing independent "+str(factor))
		check(lab.level.transform == initial_level_transform and hero.ladders == initial_ladders,"level and ladders unchanged "+str(factor))
		# Real ray hits the enlarged capsule near its top, above the original body at 2x/4x.
		var origin := hero.global_position-Vector2(80*factor,hero.world_height()*.7)
		var query := PhysicsRayQueryParameters2D.create(origin,origin+Vector2(160*factor,0),2)
		check(hero.get_world_2d().direct_space_state.intersect_ray(query).get("collider") == hero,"scaled physical capsule is hit "+str(factor))
		hero.weapon._update_aim()
		check(hero.weapon.pivot().distance_to(hero.to_global(hero.weapon.visual_pose().breech)) < .001,"gun breech matches drawing "+str(factor))
		var fired := hero.weapon.shots_fired
		hero.weapon._fire()
		check(hero.weapon.shots_fired == fired+1,"shooting functional "+str(factor))
		var bullet: Node2D = get_nodes_in_group("core_projectiles").back()
		var expected: Vector2 = hero.weapon.pivot()+hero.weapon.aim_direction*hero.weapon.muzzle_distance()*factor
		check(bullet.global_position.distance_to(expected) < .01,"bullet exits scaled muzzle "+str(factor))
		bullet.queue_free()
		check(hero.weapon.request_reload(),"reload starts "+str(factor))
		hero.weapon._tick_reload(hero.weapon.reload_duration_active+.1)
		check(not hero.weapon.reloading and hero.weapon.magazine_ammo == hero.weapon.capacity(),"reload completes "+str(factor))
		var grenade_origin := hero.grenades.launch_origin()
		check(grenade_origin.distance_to(hero.to_global(hero.grenades.hand_point())) < .01,"grenade starts at scaled hand "+str(factor))
		check(hero.grenades.prepare(),"grenade can be equipped "+str(factor))
		check(is_equal_approx(hero.grenades.held_grenade.collider.shape.radius,hero.grenades.tuning.grenade_radius*factor),"grenade contact scales with equipment "+str(factor))
		hero.grenades.holster()
		hero._update_crouch(true)
		check(hero.crouching and is_equal_approx(hero.world_height(),hero.tuning.local_value("crouch_height")*factor),"crouch scales physical body "+str(factor))
		hero._try_stand()
		var start := hero.position
		Input.action_press("core_right")
		await frames(60)
		check(hero.position.x > start.x+10,"running functional "+str(factor))
		Input.action_press("core_jump")
		await frames(8)
		check(hero.position.y < start.y-5,"jump functional "+str(factor))
		release()
		await place()
		hero._start_dash(1)
		var dash_start := hero.position
		await frames(5)
		check(hero.position.x > dash_start.x+10,"dash functional "+str(factor))
		await place()
		# Force a real ladder action in open air, using the world's unchanged rung grid.
		hero.global_position = Vector2(7800,600)
		hero._enter_ladder(Rect2(7791,100,18,660))
		Input.action_press("core_up")
		await frames(6)
		check(hero.climbing and hero.position.y < 600,"ladder ascent functional "+str(factor))
		hero.body.advance(0)
		var finite := true
		for arm in [hero.body.near_arm,hero.body.far_arm]: finite = finite and arm.hand.is_finite() and arm.hand.distance_to(arm.requested_hand) < .2
		check(finite,"ladder hands reach rungs "+str(factor))
		hero._leave_ladder()
		release()
		await place()
		var pose := hero.body.ragdoll_pose()
		hero.blast_ragdoll.start(Vector2(80,-40),.2,.7)
		await frames(2)
		var rig: Node2D = hero.blast_ragdoll.rig
		check(is_equal_approx(rig.parts.head.dimensions.x,pose.parts.head.dimensions.x*factor),"ragdoll physical anatomy scaled "+str(factor))
		check(rig.has_node("HeldWeapon") and is_equal_approx(rig.get_node("HeldWeapon").get_child(0).shape.size.y,2.2*factor),"ragdoll weapon contact scaled "+str(factor))
		hero.request_body_scale(1.25)
		check(is_equal_approx(hero.body_scale,factor),"active ragdoll defers resize "+str(factor))
		hero.requested_body_scale = factor
		hero.blast_ragdoll._begin_recovery(Vector2(7800,759.5))
		for i in 50:
			if not hero.blast_ragdoll.active: break
			hero.blast_ragdoll._tick_recovery(.016)
		check(not hero.blast_ragdoll.active and absf(hero.global_position.y-759.5) < 1,"scaled recovery returns to standing "+str(factor))
		if hero.blast_ragdoll.active: hero.blast_ragdoll.cancel()
		await frames(2)
	# Enlarged actor traverses a real low obstacle with unchanged world geometry.
	await place()
	hero.request_body_scale(2)
	var obstacle := block(Rect2(7840,720,60,40))
	await frames(3)
	hero.weapon.aim_override = Vector2(9000,600)
	hero.weapon._update_aim()
	check(hero.parkour.try_start(1,true),"scaled parkour accepts reachable obstacle")
	for i in 100:
		if not hero.parkour.active: break
		hero.parkour.tick(.016,false,false,true)
		await frames(1)
	check(not hero.parkour.active and hero.global_position.x > 7840,"scaled parkour completes traversal")
	obstacle.queue_free()
	await frames(2)
	await place()
	hero.request_body_scale(2)
	var crate := load("res://scenes/core/physics_crate.tscn").instantiate() as RigidBody2D
	crate.position = Vector2(7862,728)
	lab.add_child(crate)
	await frames(8)
	Input.action_press("core_grab")
	await frames(2)
	Input.action_release("core_grab")
	check(hero.pushing,"scaled Sofia grabs unchanged crate")
	hero.body.advance(0)
	var palms := true
	for arm in [hero.body.near_arm,hero.body.far_arm]:
		var point: Vector2 = crate.to_local(hero.to_global(arm.hand))
		palms = palms and absf(point.x) < 33 and absf(point.y) < 33
	check(palms,"scaled palms remain on crate surface")
	hero.stop_pushing()
	crate.queue_free()
	await frames(2)
	# Do not grow through a ceiling. Request remains pending and applies when clear.
	await place()
	hero.request_body_scale(1)
	await frames(3)
	var ceiling := block(Rect2(7720,660,160,10))
	await frames(3)
	hero.request_body_scale(2)
	check(hero.body_scale == 1 and hero.requested_body_scale == 2,"growth blocked by real ceiling")
	ceiling.queue_free()
	await frames(5)
	check(hero.body_scale == 2,"pending growth applies after ceiling removed")
	lab.camera_settings.player_scale = 1.3
	lab.camera_settings.player_scale_enabled = false
	lab._camera_settings_changed()
	check(is_equal_approx(hero.character_scale(),1) and lab.camera_settings.player_scale == 1.3,"disable restores new 1x without erasing slider")
	lab.camera_overlay.feature_toggles.player_scale_enabled.button_pressed = true
	lab.camera_overlay.rows.player_scale.slider.value = 1.2
	check(is_equal_approx(hero.character_scale(),1.2),"actual developer controls apply scale")
	check(lab.export_settings_file(directory.path_join("balance.json")),"scale settings export with full balance")
	lab.camera_overlay.rows.player_scale.slider.value = 1.0
	check(lab.import_settings_file(directory.path_join("balance.json")) and is_equal_approx(hero.character_scale(),1.2),"JSON import reapplies requested scale")
	check(same_values(hero.tuning.as_dictionary(),initial_movement),"movement tuning unchanged")
	floor.queue_free()
	app.queue_free()
	await frames(3)
	# The same persisted size is applied by the campaign without changing its world.
	var campaign: CoreMovementLab = load("res://scenes/campaign/prologue.tscn").instantiate()
	campaign.load_user_settings = false
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]: campaign.set(key,directory.path_join("campaign-"+key+".cfg"))
	campaign.get_node("World/Player").character_id = "sofia"
	campaign.get_node("World/Player").sofia_cel_variant = true
	root.add_child(campaign)
	await frames(6)
	var prologue_feet := campaign.player.global_position
	var prologue_camera := campaign.camera_target(1)
	campaign.camera_settings.apply_values({"player_scale_enabled":true,"player_scale":1.2})
	campaign._camera_settings_changed()
	await frames(3)
	check(is_equal_approx(campaign.player.character_scale(),1.2) and campaign.player.global_position.distance_to(prologue_feet) < .2,"Sofia scale applies in prologue")
	check(campaign.camera_target(1).distance_to(prologue_camera) < .2,"prologue camera stays independent")
	campaign.queue_free()
	await frames(3)
	print("PLAYER SCALE: %d/%d" % [checks-failures,checks])
	quit(1 if failures else 0)
