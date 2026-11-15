extends SceneTree
## Background transforms stay in the world while the camera, player and UI move.
const MEDIA = preload("res://tools/media_paths.gd")
var lab: CoreMovementLab
var checks := 0
var failures := 0
var output := ""
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if ok: print("PASS ",label)
	else: failures += 1; push_error("FAIL "+label)
func shot(label: String) -> void:
	if output.is_empty(): return
	await frames(2)
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)
func transforms(bg) -> Array:
	return [bg.picture.global_transform,bg.continuation_picture.global_transform]
func run() -> void:
	var before := OS.get_environment("UBERSHRIKE_FIXED_BG_BASELINE") == "1"
	if OS.get_environment("UBERSHRIKE_FIXED_BG_CAPTURE") == "1":
		output = MEDIA.path("docs/prologue1_screen2_background/Проверки/2026-11-08_Фиксированный_фон/"+("До" if before else "После"))
	var folder := "/private/tmp/p1-fixed-bg-profile-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	lab = load("res://scenes/campaign/prologue.tscn").instantiate()
	lab.load_user_settings = false
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]: lab.set(key,folder.path_join(key+".cfg"))
	lab.get_node("World/Player").rig_reference_scale = CoreWorldUnits.LEGACY_SOFIA_SCALE
	root.add_child(lab)
	await frames(10)
	lab.player.weapon.tuning.sound_enabled = false
	for enemy in lab.level.enemies: enemy.test_frozen = true
	lab.camera_settings.apply_values({"zoom":.7,"offset_y":-185,"limit_to_level":true})
	lab._camera_settings_changed()
	lab._update_camera(true)
	var f = lab.level.forest
	var bg = f.night_background
	await frames(5)
	var anchor := transforms(bg)
	var gameplay: Transform2D = f.backdrop.global_transform
	var geometry := [f.terrain.duplicate(true),f.surfaces.duplicate(true),f.ladders.duplicate(true)]
	var samples := []
	for x in [2.0,12.0,18.0,30.0]:
		lab._teleport_player(f.ground_point(x))
		lab.player.weapon.aim_override = lab.player.position+Vector2(800,-40)
		await frames(5)
		samples.append({"x":x,"background_center":str(bg.picture.global_position),"camera_center":str(lab.camera.get_screen_center_position())})
		if not before: check(transforms(bg) == anchor,"both background images fixed in world at x="+str(x))
		await shot("route_%.0f" % x)
	print("ANCHOR SAMPLES ",JSON.stringify(samples))
	if before: lab.queue_free(); await frames(2); quit(); return
	for side in [-1,1]:
		lab.player.weapon.aim_override = lab.player.position+Vector2(side*800,-40)
		await frames(30)
		check(transforms(bg) == anchor,"aim/camera turn cannot drag background: "+str(side))
	for zoom in [.5,1.0,3.0]:
		lab.camera_settings.zoom = zoom
		lab._camera_settings_changed()
		lab._update_camera(true)
		await frames(3)
		check(transforms(bg) == anchor,"zoom changes the view, not world placement: "+str(zoom))
	lab.camera_settings.zoom = .7
	lab._camera_settings_changed()
	lab._recover()
	await frames(3)
	var start: Vector2 = lab.player.position
	Input.action_press("core_right")
	await frames(60)
	Input.action_release("core_right")
	check(lab.player.position.x > start.x+50 and transforms(bg) == anchor,"real movement leaves background transform fixed")
	check(f.backdrop.global_transform == gameplay and geometry == [f.terrain,f.surfaces,f.ladders] and lab.player.character_scale() == 1,"gameplay plane, collisions and player scale unchanged")
	var t: float = bg.elapsed
	await frames(5)
	check(bg.elapsed > t and bg.effect_material.get_shader_parameter("animation_time") == bg.continuation_material.get_shader_parameter("animation_time"),"shared effect clock still animates both screens")
	paused = true
	await frames(2)
	t = bg.elapsed
	await frames(5)
	check(bg.elapsed == t and transforms(bg) == anchor,"pause freezes effects without relocating background")
	for mode in ["stable_pixel_enabled","world_pixel_enabled"]:
		lab.camera_settings.set(mode,true)
		lab._camera_settings_changed()
		await frames(3)
		check(transforms(bg) == anchor and lab.telemetry.get_viewport() == root,"fixed background with native HUD: "+mode)
		lab.camera_settings.set(mode,false)
		lab._camera_settings_changed()
	lab.camera_settings.p1_night_enabled = false
	bg.update_background()
	check(not bg.visible and transforms(bg) == anchor,"master disable does not reset world placement")
	lab.camera_settings.p1_night_enabled = true
	bg.update_background()
	check(bg.visible and transforms(bg) == anchor,"reenabling restores the same world placement")
	paused = false
	lab.queue_free()
	await frames(3)
	print("FIXED BACKGROUND: %d/%d; failures=%d" % [checks-failures,checks,failures])
	quit(1 if failures else 0)
