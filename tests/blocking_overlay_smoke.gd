extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS ",label)
	else: failures += 1; push_error("FAIL "+label)
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func run() -> void:
	var temp := OS.get_environment("TEMP").path_join("blocking-overlay-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(temp)
	for scene in ["res://scenes/main.tscn","res://scenes/campaign/prologue.tscn","res://scenes/campaign/prologue_v2.tscn"]:
		var lab: CoreMovementLab = load(scene).instantiate()
		lab.load_user_settings = false
		for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]: lab.set(key,temp.path_join(key+".cfg"))
		lab.get_node("World/Player").character_id = "sofia"
		lab.get_node("World/Player").sofia_cel_variant = true
		root.add_child(lab); await frames(8)
		check(not lab.blocking_overlay.visible,"overlay off by default: "+scene)
		var framing := lab.camera_settings.framing_values()
		var bodies := lab.level.find_children("*","StaticBody2D",true,false).size()
		lab.camera_settings.apply_values({"blocking_overlay_opacity":.35})
		lab.camera_overlay.feature_toggles.blocking_overlay_enabled.button_pressed = true
		lab._camera_settings_changed(); await frames(2)
		check(lab.blocking_overlay.visible and lab.blocking_overlay.shapes.size()>0,"actual collision shapes available: "+scene)
		check(is_equal_approx(lab.blocking_overlay.fill_opacity,.35),"opacity applies independently: "+scene)
		check(lab.level.find_children("*","StaticBody2D",true,false).size()==bodies and lab.camera_settings.framing_values()==framing,"physics and framing preserved: "+scene)
		var config := ConfigFile.new()
		lab.camera_settings.save_saved(temp.path_join("overlay.cfg"))
		var restored := CoreCameraSettings.new(); restored.load_saved(temp.path_join("overlay.cfg"))
		check(restored.blocking_overlay_enabled and is_equal_approx(restored.blocking_overlay_opacity,.35),"profile round trip: "+scene)
		config.load(temp.path_join("overlay.cfg")); config.erase_section_key("camera","blocking_overlay_enabled"); config.save(temp.path_join("old.cfg"))
		restored.load_saved(temp.path_join("old.cfg"))
		check(not restored.blocking_overlay_enabled,"old profile defaults to off: "+scene)
		if lab.level.forest:
			lab.developer_mode.toggle_debug(); lab.developer_mode._apply_debug()
			lab.developer_mode.toggle_debug(); lab.developer_mode._apply_debug()
			check(lab.blocking_overlay.visible and not lab.level.forest.debug_geometry,"F1 remains independent: "+scene)
		if scene.ends_with("prologue_v2.tscn") and OS.get_environment("UBERSHRIKE_BLOCKING_CAPTURE")=="1":
			lab.player.reset_to(preload("res://scripts/campaign/forest_prologue_v2.gd").point(315,3.8))
			lab.set_process(false); lab.camera.zoom=Vector2.ONE; lab.camera.position=lab.player.position+Vector2(0,-170); lab.camera.reset_smoothing(); lab.camera.force_update_scroll()
			for child in lab.get_children():
				if child is CanvasLayer: child.hide()
			await frames(3); await RenderingServer.frame_post_draw
			var path := preload("res://tools/media_paths.gd").path("docs/locations/mvp_village/Проверки/blocking_overlay_2026-10-25")
			DirAccess.make_dir_recursive_absolute(path)
			check(root.get_texture().get_image().save_png(path.path_join("overlay.png"))==OK,"project screenshot saved")
		lab.camera_settings.blocking_overlay_enabled=false; lab._camera_settings_changed(); await frames(2)
		check(not lab.blocking_overlay.visible and is_equal_approx(lab.camera_settings.blocking_overlay_opacity,.35),"off preserves opacity: "+scene)
		lab.queue_free(); await frames(3)
	print("BLOCKING OVERLAY: %d/%d"%[checks-failures,checks]); quit(1 if failures else 0)
