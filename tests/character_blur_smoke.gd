extends SceneTree
var checks := 0
var failures := 0
var lab: CoreMovementLab
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	await frames(8)
	var hero := lab.player
	var visual := hero.visuals
	var settings := lab.camera_settings
	check(settings.character_blur_strength == 0 and not settings.character_linear_filter and hero.body.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,"testing defaults disable blur and linear texture softening")
	check(hero.body.get_parent() == visual and hero.body.near_arm.get_parent() == visual and visual.gun.get_parent() == visual and hero.weapon.get_parent() == hero,"body, hands and gun share an effect; reticle and particles stay outside")
	check(hero.body.z_index == visual.z_index and hero.body.far_arm.z_index == visual.z_index and hero.body.near_arm.z_index == visual.z_index and visual.gun.z_index == visual.z_index,"all character layers participate in CanvasGroup compositing")
	hero.set_physics_process(false)
	hero.velocity = Vector2(520,0)
	visual.update_effect()
	check(visual.material == null and visual.blur_offset == Vector2.ZERO,"zero intensity bypasses the blur shader even at sprint speed")
	var overlay := lab.camera_overlay
	overlay.toggle()
	overlay.tabs.current_tab = 1
	check(overlay.tabs.get_tab_title(1) == "Визуал" and overlay.character_filter_toggle != null and overlay.rows.size() == CoreCameraSettings.PARAMS.size(),"F5 preserves the blur sliders and filtering toggle alongside current visual controls")
	overlay.rows.character_blur_strength.slider.value = .5
	overlay.rows.character_blur_length.number.value = 20
	overlay.rows.character_blur_start_speed.slider.value = 100
	visual.update_effect()
	check(visual.material == visual.blur_material and absf(visual.blur_offset.x-10) < .001,"configured intensity and radius are used at full sprint speed")
	hero.velocity.x = -520
	visual.update_effect()
	check(absf(visual.blur_offset.x+10) < .001,"reverse movement mirrors the effect")
	hero.velocity = Vector2(0,-520)
	visual.update_effect()
	check(visual.blur_offset.distance_to(Vector2(0,-10)) < .001,"vertical movement uses its own motion direction")
	hero.velocity = Vector2(50,0)
	visual.update_effect()
	check(visual.material == null,"movement below the threshold stays sharp")
	hero.velocity = Vector2(3000,0)
	visual.update_effect()
	check(is_equal_approx(visual.blur_offset.length(),10),"fast custom dashes cannot exceed the configured blur radius")
	lab.camera_settings.zoom = .5
	lab._update_camera()
	visual.update_effect()
	var scale_x := absf(visual.get_global_transform_with_canvas().get_scale().x)
	check(visual.fit_margin*scale_x >= visual.blur_offset.length() and visual.clear_margin == visual.fit_margin,"zooming out preserves enough composite margin for the full blur")
	overlay.character_filter_toggle.button_pressed = true
	visual.update_effect()
	check(hero.body.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,"texture softening is independently configurable")
	var framing := settings.framing_values()
	var camera_position := lab.camera.position
	overlay.rows.character_blur_strength.number.value = .75
	lab._update_camera()
	check(settings.framing_values() == framing and lab.camera.position == camera_position,"changing visuals does not change framing or snap camera smoothing")
	paused = true
	visual.update_effect()
	check(visual.material == null and visual.blur_offset == Vector2.ZERO and settings.character_blur_strength == .75,"pause removes motion blur without changing saved intensity")
	paused = false
	visual.update_effect()
	check(visual.material != null and is_equal_approx(visual.blur_offset.length(),15),"unpausing restores the configured effect")
	var path := (OS.get_environment("TEMP") if not OS.get_environment("TEMP").is_empty() else "/tmp").path_join("character-visuals-%d.cfg" % OS.get_process_id())
	var loaded := CoreCameraSettings.new()
	check(settings.save_saved(path) == OK and loaded.load_saved(path) == OK and loaded.character_blur_strength == .75 and loaded.character_blur_length == 20 and loaded.character_blur_start_speed == 100 and loaded.character_linear_filter,"all visual settings persist in the camera profile")
	DirAccess.remove_absolute(path)
	overlay.reset_button.pressed.emit()
	visual.update_effect()
	check(settings.character_blur_strength == 0 and not settings.character_linear_filter and visual.material == null,"Reset restores sharp testing defaults")
	hero.velocity = Vector2.ZERO
	hero.set_physics_process(true)
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
