extends SceneTree
var failures := 0
var checks := 0
const CATALOG = preload("res://scripts/campaign/catalog.gd")
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func run() -> void:
	var folder := ""
	if "--capture" in OS.get_cmdline_user_args(): folder = preload("res://tools/media_paths.gd").path("docs/core/casings_persistent_20261104")
	for id in ["prologue","prologue_v2","hub","polygon","terra"]:
		var app = preload("res://scripts/campaign/frontend.gd").new()
		app.load_user_settings = false
		app.test_settings_directory = OS.get_environment("TEMP").path_join("casings-blocking-%d-%s"%[OS.get_process_id(),id])
		DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
		root.add_child(app); app.selected_level=id; app.launch(id!="polygon")
		await frames(15)
		var lab = app.game
		var overlay = lab.blocking_overlay
		lab.camera_settings.blocking_overlay_enabled=false
		overlay.apply_settings(lab.camera_settings)
		lab.developer_mode.debug_toggle.button_pressed=true
		lab.developer_mode._apply_debug()
		await frames(3)
		check(overlay.visible and not overlay.shapes.is_empty(),id+": F1 uses live collision overlay")
		if lab.level.forest and id!="terra": check(not lab.level.forest.debug_geometry,id+": no opaque legacy debug drawing")
		lab.developer_mode.debug_toggle.button_pressed=false; lab.developer_mode._apply_debug()
		check(not overlay.visible,id+": F1 off respects disabled setting")
		lab.camera_settings.blocking_overlay_enabled=true;overlay.apply_settings(lab.camera_settings)
		lab.developer_mode._apply_debug()
		check(overlay.visible and is_equal_approx(overlay.fill_opacity,.18),id+": independent translucent setting survives F1 off")
		if id=="prologue_v2":
			var gun = lab.player.weapon
			for weapon_id in ["stg44","mp40","m1911","svt"]:
				CATALOG.equip(gun,weapon_id);gun.effects.clear();gun.aim_direction=Vector2.RIGHT;gun._fire()
				var casings = gun.effects.filter(func(e):return e.get("kind")=="casing")
				check(casings.size()==1,weapon_id+": actual shot ejects case")
				if casings.is_empty(): continue
				var e: Dictionary = casings[0]
				if weapon_id=="stg44" and not folder.is_empty():
					await frames(2); await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(folder.path_join("stg44_case.png"))
				var mm: Vector2 = e.size_world/CoreWorldUnits.units(.001)/lab.player.character_scale()
				check(mm.is_equal_approx(CATALOG.casing_mm(weapon_id)),weapon_id+": physical size independent of legacy rig scale")
				CATALOG.equip(gun,"mp40" if weapon_id!="mp40" else "svt")
				check(e.weapon_id==weapon_id and mm.is_equal_approx(CATALOG.casing_mm(weapon_id)),weapon_id+": emitted case unchanged by weapon swap")
			CATALOG.equip(gun,"stg44");gun.effects.clear()
		if not folder.is_empty() and id in ["prologue","prologue_v2"]:
			await frames(3);await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join(id+".png"))
		app.queue_free();await frames(4)
	print("CASINGS BLOCKING ",checks-failures,"/",checks)
	quit(1 if failures else 0)
