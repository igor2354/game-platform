extends SceneTree

const CATALOG = preload("res://scripts/campaign/catalog.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",label)

func run() -> void:
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("muzzle-smoke-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	var terra := "--terra" in OS.get_cmdline_user_args()
	app.selected_level = "terra" if terra else "polygon"
	for level in ["prologue","prologue_v2","hub"]:
		if "--"+level in OS.get_cmdline_user_args(): app.selected_level = level
	app.launch(app.selected_level != "polygon")
	for frame in 12: await physics_frame
	var lab = app.game
	var gun = lab.player.weapon
	var smoke = gun.muzzle_smoke
	var settings: CoreMovementSettings = lab.player.tuning
	if terra: Input.action_press("core_aim")
	gun.tuning.sound_enabled = false
	gun.tuning.recoil_enabled = false
	gun.tuning.magazine_enabled = false
	gun.aim_override = lab.player.global_position+Vector2(700,-160)
	await physics_frame
	var capture := "--capture" in OS.get_cmdline_user_args()
	for id in ["stg44","mp40","svt","m1911"]:
		CATALOG.equip(gun,id)
		await physics_frame
		gun.tuning.magazine_enabled = false
		gun.tuning.recoil_enabled = false
		gun.tuning.sound_enabled = false
		smoke.clear()
		var outlet: Vector2 = gun.muzzle_position()
		gun._fire()
		check(smoke.portions.size() == 1 and smoke.portions[0].point.is_equal_approx(outlet),id+" actual shot at muzzle")
		if not smoke.portions.is_empty():
			var part: Dictionary = smoke.portions[0]
			var previous_zoom: Vector2 = lab.camera.zoom
			lab.camera.zoom = Vector2.ONE*.75
			lab.camera.force_update_scroll()
			var near_length: float = smoke.world_length(part,settings.muzzle_smoke_size,.25)
			lab.camera.zoom = Vector2.ONE*2.5
			lab.camera.force_update_scroll()
			var far_length: float = smoke.world_length(part,settings.muzzle_smoke_size,.25)
			check(is_equal_approx(near_length,far_length) and is_equal_approx(smoke.world_length(part,settings.muzzle_smoke_size*.5,.25),far_length*.5),id+" world size and size control independent of zoom")
			lab.camera.zoom = previous_zoom
			lab.camera.force_update_scroll()
		var slow_peak := 0.0
		for shot in 4:
			smoke.tick(gun,1.0)
			gun._fire()
			slow_peak = maxf(slow_peak,float(smoke.heat.get(id,0.0)))
		smoke.clear()
		for shot in 5:
			gun._fire()
			smoke.tick(gun,.1)
		check(float(smoke.heat.get(id,0.0)) > slow_peak,id+" fast string retains more heat")
		for frame in 20: smoke.tick(gun,1.0/60.0)
		check(not smoke.portions.any(func(part): return part.residual),id+" short string has no residual smoke")
		smoke.clear()
		for shot in gun.capacity() * 2:
			gun._fire()
			smoke.tick(gun,.13)
			if shot == gun.capacity() - 1: smoke.tick(gun,2.0)
		for frame in 30: smoke.tick(gun,1.0/60.0)
		check(smoke.portions.any(func(part): return part.residual),id+" smoke after two magazines with a reload gap")
		for frame in 480: smoke.tick(gun,1.0/60.0)
		check(smoke.portions.any(func(part): return part.residual),id+" still emits while cooling")
		if capture:
			gun._fire()
			for frame in 7: await physics_frame
			gun.queue_redraw()
			await RenderingServer.frame_post_draw
			var folder := "muzzle_smoke_world_20261105/"+str(app.selected_level)
			var path := preload("res://tools/media_paths.gd").path("docs/core/"+folder+"/"+id+".png")
			check(not path.is_empty() and root.get_texture().get_image().save_png(path) == OK,id+" window capture")
		smoke.tick(gun,12.0)
		check(smoke.portions.is_empty() and smoke.heat.is_empty() and smoke.sustained.is_empty(),id+" smoke and heat expire")
	gun._fire()
	if not smoke.portions.is_empty():
		var point: Vector2 = smoke.portions[0].point
		gun.aim_override = lab.player.global_position+Vector2(-700,-160)
		await physics_frame
		check(not smoke.portions.is_empty() and smoke.portions[0].point == point,"turn retains world origin")
	else:
		check(false,"turn retains world origin")
	settings.muzzle_smoke_enabled = false
	settings.muzzle_residual_enabled = true
	smoke.clear()
	for shot in 100: gun._fire()
	for frame in 20: smoke.tick(gun,1.0/60.0)
	check(not smoke.portions.is_empty() and smoke.portions.all(func(part): return part.residual),"residual independent from shot effect")
	settings.muzzle_smoke_enabled = true
	settings.muzzle_residual_enabled = false
	smoke.clear()
	for shot in 100: gun._fire()
	check(smoke.portions.size() == smoke.LIMIT and smoke.portions.all(func(part): return not part.residual),"bounded shot effects with residual disabled")
	gun.reset_state()
	gun.tuning.magazine_enabled = true
	gun.magazine_ammo = 0
	gun._fire()
	check(smoke.portions.is_empty() and smoke.heat.is_empty(),"dry shot emits nothing after reset")
	settings.muzzle_smoke_opacity = .27
	check(settings.save_saved(lab.settings_path) == OK,"save isolated movement profile")
	var restored := CoreMovementSettings.new()
	check(restored.load_saved(lab.settings_path) == OK and not restored.muzzle_residual_enabled and is_equal_approx(restored.muzzle_smoke_opacity,.27),"CFG preserves switch and value")
	var imported := CoreMovementSettings.new()
	imported.apply_values(JSON.parse_string(JSON.stringify(restored.as_dictionary())))
	check(not imported.muzzle_residual_enabled and is_equal_approx(imported.muzzle_smoke_opacity,.27),"JSON values round trip")
	check(lab.particle_overlay.rows.has("muzzle_smoke_opacity"),"F2 exposes smoke parameter")
	print("Muzzle smoke: %d/%d"%[checks-failures,checks])
	if terra: Input.action_release("core_aim")
	quit(1 if failures else 0)
