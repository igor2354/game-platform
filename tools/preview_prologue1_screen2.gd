extends SceneTree
## Preview/regression of the approved master; reference copies live outside res://.
const MEDIA = preload("res://tools/media_paths.gd")
const F = preload("res://scripts/campaign/forest_prologue.gd")
var lab: CoreMovementLab
var checks := 0
var failures := 0
var output := ""
var folder := "/private/tmp/p1-screen2-%d" % OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if ok: print("PASS ",label)
	else: failures += 1; push_error("FAIL "+label)
func texture(path: String) -> ImageTexture:
	var im := Image.load_from_file(path)
	return ImageTexture.create_from_image(im) if im else null
func grab(viewport: Viewport) -> Image:
	await frames(2)
	RenderingServer.force_draw(false)
	return viewport.get_texture().get_image()
func shot(label: String) -> void:
	var im := await grab(root)
	check(im.save_png(output.path_join(label+".png")) == OK,"capture "+label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	output = MEDIA.path("docs/prologue1_screen2_background/Проверки")
	var source := texture(MEDIA.path("docs/prologue1_screen2_background/Подключено/prologue1_night_continuation.png"))
	var clean := texture(MEDIA.path("docs/prologue1_screen2_background/Подключено/prologue1_night_continuation_clean.png"))
	if source == null or clean == null:
		push_error("Approved reference images are required in the external library")
		quit(1)
		return
	lab = load("res://scenes/campaign/prologue.tscn").instantiate()
	lab.load_user_settings = false
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:
		lab.set(key,folder.path_join(key+".cfg"))
	lab.get_node("World/Player").rig_reference_scale = CoreWorldUnits.LEGACY_SOFIA_SCALE
	root.add_child(lab)
	await frames(10)
	lab.player.weapon.tuning.sound_enabled = false
	for enemy in lab.level.enemies: enemy.test_frozen = true
	lab.camera_settings.apply_values({"zoom":.7,"offset_y":-185,"limit_to_level":true})
	lab._camera_settings_changed()
	lab._update_camera(true)
	lab.player.weapon.aim_override = lab.player.position+Vector2(800,-40)
	await frames(4)
	paused = true
	lab.set_process(false)
	var f = lab.level.forest
	var bg = f.night_background
	bg.set_process(false)
	bg.elapsed = 0
	check(bg.continuation_picture != null and bg.continuation_picture.texture == bg.CONTINUATION_ART,"ordinary campaign loads the approved second screen by default")
	# Reconstruct the old one-screen view for an actual before/after comparison.
	bg.continuation_picture.free()
	bg.continuation_picture = null
	bg.continuation_material = null
	bg.effect_material.set_shader_parameter("right_fade_start",1.0)
	bg.update_background()
	lab.camera.force_update_scroll()
	var old_view := await grab(root)
	var geometry := [f.terrain.duplicate(true),f.surfaces.duplicate(true),f.ladders.duplicate(true)]
	var framing := lab.camera_settings.as_dictionary()
	check(bg.set_continuation_art(source,clean),"external candidate injected without changing runtime resource paths")
	bg.update_background()
	var new_view := await grab(root)
	check(old_view.get_data() == new_view.get_data(),"first screen remains pixel-identical at the start")
	await shot("01_first_screen")
	var position_at_boundary := Vector2.ZERO
	for x in [12.0,17.99,18.0,18.01,24.0,30.0,35.0]:
		lab.player.position = f.ground_point(x)
		lab.player.weapon.aim_override = lab.player.position+Vector2(800,-40)
		lab._update_camera(true)
		lab.camera.force_update_scroll()
		bg.update_background()
		check(bg.visible and (is_equal_approx(bg.opacity,1) if x < 34 else bg.opacity > 0),"background covers second screen / its end fade at route x="+str(x))
		var relative: Vector2 = bg.picture.position-lab.camera.get_screen_center_position()
		if x == 17.99: position_at_boundary = relative
		if x == 18.01: check(relative.distance_to(position_at_boundary) < 4,"no screen-boundary transform jump over 2cm of route")
		await shot("route_%05.2f" % x)
	check(geometry == [f.terrain,f.surfaces,f.ladders] and lab.camera_settings.as_dictionary() == framing and lab.player.character_scale() == 1,"terrain, ladders, player scale and camera profile unchanged")
	lab.player.position = f.ground_point(30)
	lab._update_camera(true)
	lab.camera.force_update_scroll()
	bg.update_background()
	for mode in ["stable_pixel_enabled","world_pixel_enabled"]:
		lab.camera_settings.set(mode,true)
		lab._camera_settings_changed()
		check(lab.stable_pixels.active and bg.visible and lab.telemetry.get_viewport() == root,"second screen world filter and native HUD: "+mode)
		await shot("second_"+mode)
		lab.camera_settings.set(mode,false)
		lab._camera_settings_changed()
	var t: float = bg.elapsed
	await frames(5)
	check(bg.elapsed == t,"paused candidate uses the shared frozen clock")
	lab.camera_settings.p1_night_water_enabled = false
	bg.update_background()
	check(bg.effect_material.get_shader_parameter("water_strength") == 0 and bg.continuation_material.get_shader_parameter("water_strength") == 0,"water toggle applies to both screens")
	lab.camera_settings.p1_night_water_enabled = true
	bg.update_background()
	lab.camera_settings.p1_night_enabled = false
	bg.update_background()
	check(not bg.visible,"master switch hides both screens")
	lab.camera_settings.p1_night_enabled = true
	bg.update_background()
	await panorama(bg,source)
	for x in [40.0,48.0,100.0]:
		lab.player.position = f.ground_point(x)
		bg.update_background()
		check(not bg.visible,"candidate does not extend through the whole level at x="+str(x))
	lab.queue_free()
	paused = false
	await frames(3)
	print("SCREEN 2 PREVIEW: %d/%d; failures=%d" % [checks-failures,checks,failures])
	quit(1 if failures else 0)

func panorama(bg,source: Texture2D) -> void:
	var vp := SubViewport.new()
	var height: int = bg.ART.get_height()
	var ratio: float = height/float(source.get_height())
	vp.size = Vector2i(roundi(source.get_width()*ratio),height)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	for entry in [[source,bg.continuation_material,ratio],[bg.ART,bg.effect_material,1.0]]:
		var pic := Sprite2D.new()
		pic.texture = entry[0]
		pic.centered = false
		pic.scale = Vector2.ONE*entry[2]
		pic.material = entry[1].duplicate()
		pic.material.set_shader_parameter("opacity",1.0)
		vp.add_child(pic)
	var paints := [vp.get_child(0).material,vp.get_child(1).material]
	for phase in [0.0,1.5,3.0]:
		for paint in paints: paint.set_shader_parameter("animation_time",phase)
		var im := await grab(vp)
		check(im.save_png(output.path_join("panorama_%.1f.png" % phase)) == OK,"continuous master phase "+str(phase))
		check(im.detect_alpha() == Image.ALPHA_NONE,"no transparent gap anywhere in the two-screen master")
	# Check that effects animate in the newly drawn RIGHT region, not only the
	# already-existing fire/foliage on the left of the panorama.
	var right := Rect2i(roundi(bg.ART.get_width()*1.05),0,vp.size.x-roundi(bg.ART.get_width()*1.05),vp.size.y)
	for effect in ["static","wind","clouds","water"]:
		for paint in paints:
			for key in bg.EFFECTS: paint.set_shader_parameter(key+"_strength",1.0 if key == effect else 0.0)
		var phases: Array[Image] = []
		for phase in [0.0,1.5,3.0]:
			for paint in paints: paint.set_shader_parameter("animation_time",phase)
			var im := await grab(vp)
			phases.append(im)
			im.save_png(output.path_join("isolated_%s_%.1f.png" % [effect,phase]))
		var same := phases[0].get_region(right).get_data() == phases[1].get_region(right).get_data() and phases[0].get_region(right).get_data() == phases[2].get_region(right).get_data()
		check(same if effect == "static" else not same,"second screen right region: "+effect)
	for paint in paints:
		for key in bg.EFFECTS: paint.set_shader_parameter(key+"_strength",1.0)
	if OS.get_environment("UBERSHRIKE_P1_SCREEN2_CLIP") == "1":
		var clip := output.path_join("Кадры")
		DirAccess.make_dir_recursive_absolute(clip)
		# Render the animation natively at its delivery size; no bitmap resizing.
		var preview_scale := 1152.0/vp.size.x
		vp.size = Vector2i(1152,roundi(height*preview_scale))
		for child in vp.get_children(): child.scale *= preview_scale
		for frame in 48:
			for paint in paints: paint.set_shader_parameter("animation_time",frame/12.0)
			var im := await grab(vp)
			if im.save_png(clip.path_join("%03d.png" % frame)) != OK: push_error("Cannot save animation frame")
		var transition := output.path_join("Переход")
		DirAccess.make_dir_recursive_absolute(transition)
		var pan_scale := 648.0/height
		vp.size = Vector2i(1152,648)
		vp.get_child(0).scale = Vector2.ONE*ratio*pan_scale
		vp.get_child(1).scale = Vector2.ONE*pan_scale
		for frame in 48:
			var pan := .5-.5*cos(TAU*frame/48.0)
			vp.canvas_transform = Transform2D(0,Vector2(-pan*(source.get_width()*ratio*pan_scale-1152),0))
			for paint in paints: paint.set_shader_parameter("animation_time",frame/12.0)
			var im := await grab(vp)
			if im.save_png(transition.path_join("%03d.png" % frame)) != OK: push_error("Cannot save transition frame")
	vp.queue_free()
