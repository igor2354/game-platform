extends SceneTree
## Stable vertical framing, edge-triggered scrolling and profile compatibility.
const MEDIA = preload("res://tools/media_paths.gd")
const F = preload("res://scripts/campaign/forest_prologue.gd")
var lab: CoreMovementLab
var checks := 0
var failures := 0
var directory := "/private/tmp/camera-vertical-%d" % OS.get_process_id()
var output := ""
var samples := []
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if ok: print("PASS ",label)
	else: failures += 1; push_error("FAIL "+label)
func shot(name: String) -> void:
	if output.is_empty(): return
	await frames(3)
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"capture "+name)
func fixture(scene: String) -> void:
	lab = load(scene).instantiate()
	lab.load_user_settings = false
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:
		lab.set(key,directory.path_join(key+".cfg"))
	lab.get_node("World/Player").rig_reference_scale = CoreWorldUnits.LEGACY_SOFIA_SCALE
	root.add_child(lab)
	await frames(8)
	lab.player.set_physics_process(false)
	lab.player.weapon.tuning.sound_enabled = false
	for enemy in lab.level.enemies: enemy.test_frozen = true
	lab.camera_settings.apply_values({"zoom":.7,"offset_y":-185,"limit_to_level":true})
	lab._camera_settings_changed()
	lab._update_camera(true)
func screen_y(point: Vector2) -> float:
	return (root.canvas_transform*point).y
func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var before := OS.get_environment("UBERSHRIKE_VERTICAL_BASELINE") == "1"
	if OS.get_environment("UBERSHRIKE_VERTICAL_CAPTURE") == "1":
		output = MEDIA.path("docs/core/prologue1_vertical_frame_2026-11-01/"+("До" if before else "После"))
	await fixture("res://scenes/campaign/prologue.tscn")
	var f = lab.level.forest
	var transform_before: Transform2D = f.backdrop.global_transform
	var geometry := [f.terrain.duplicate(true),f.surfaces.duplicate(true),f.ladders.duplicate(true)]
	var landmark: Vector2 = f.ground_point(9)
	for x in [1.43,5.0,9.0,13.0,17.0,9.0,1.43]:
		# Ordinary movement samples: do not invoke teleport/reset camera logic.
		lab.player.position = f.ground_point(x)
		lab.player.weapon.aim_override = lab.player.position+Vector2(800,-40)
		await frames(45)
		lab.camera.force_update_scroll()
		samples.append({"x":x,"camera_y":lab.camera.get_screen_center_position().y,"landmark_y":screen_y(landmark)})
		if x in [1.43,9.0]: await shot("slope_%.2f_%d" % [x,samples.size()])
	var ys := samples.map(func(item): return item.landmark_y)
	print("SLOPE SAMPLES ",JSON.stringify(samples))
	if before:
		print("BASELINE landmark drift: ",ys.max()-ys.min()," px; transform unchanged: ",transform_before == f.backdrop.global_transform)
		quit()
		return
	check(ys.max()-ys.min() < .1,"up/down slope and return leave terrain screen Y fixed")
	check(transform_before == f.backdrop.global_transform and geometry == [f.terrain,f.surfaces,f.ladders],"gameplay transform, collision terrain and ladders unchanged")
	# Run the real controller on the opening rise and back, not only position samples.
	lab._recover()
	lab.player.set_physics_process(true)
	await frames(8)
	var walk_origin := lab.player.position
	var walk_ys := []
	var walk_peak := walk_origin.x
	for side in ["core_right","core_left"]:
		Input.action_press(side)
		for i in 90:
			await frames(1)
			walk_ys.append(screen_y(landmark))
			walk_peak = maxf(walk_peak,lab.player.position.x)
		Input.action_release(side)
	print("WALK origin=",walk_origin," peak_x=",walk_peak," end=",lab.player.position," terrain_drift=",walk_ys.max()-walk_ys.min())
	check(walk_peak-walk_origin.x > 250 and lab.player.position.x < walk_peak-100 and walk_ys.max()-walk_ys.min() < .1,"real controller traverses slope in both directions without vertical scrolling")
	await frames(20)
	var jump_start := lab.player.position.y
	Input.action_press("core_jump")
	await frames(3)
	var jump_highest := lab.player.position.y
	for i in 90:
		if i == 40: Input.action_release("core_jump")
		await frames(1)
		jump_highest = minf(jump_highest,lab.player.position.y)
		walk_ys.append(screen_y(landmark))
	print("JUMP rise=",jump_start-jump_highest," terrain_drift=",walk_ys.max()-walk_ys.min()," mode=",lab.player.mode)
	check(jump_start-jump_highest > 40 and walk_ys.max()-walk_ys.min() < .1,"real jump inside safe frame does not move terrain vertically")
	lab.player.set_physics_process(false)
	await verify_frame()
	lab.queue_free()
	await frames(3)
	await fixture("res://scenes/main.tscn")
	await verify_frame()
	lab.queue_free()
	await frames(3)
	print("VERTICAL FRAME: %d/%d; failures=%d" % [checks-failures,checks,failures])
	quit(1 if failures else 0)

func verify_frame() -> void:
	lab.set_process(false)
	var origin := lab.player.position
	for zoom in [.5,1.0,3.0]:
		lab.camera_settings.zoom = zoom
		lab._camera_settings_changed()
		lab._update_camera(true)
		var height := lab.camera.position.y
		lab.player.position.y -= 20
		lab._update_camera()
		check(is_equal_approx(lab.camera.position.y,height),"small elevation stays static at zoom "+str(zoom))
		lab.player.position = origin
	lab.camera_settings.zoom = .7
	lab.camera_settings.follow_speed = 8
	lab._update_camera(true)
	lab.camera.force_update_scroll()
	var initial := lab.camera.position.y
	for offset in [-80,-180,0,-60,0]:
		lab.player.position.y = origin.y+offset
		lab._update_camera()
	check(absf(lab.camera.position.y-initial) < .01,"small height changes keep the chosen vertical target")
	lab.player.position.y = origin.y-900
	lab._update_camera()
	var upper := lab.camera.position.y
	var center := lab.camera.get_screen_center_position().y
	check(upper < initial-100 and center > upper+.1,"upper edge starts a smoothed translation instead of a snap")
	await frames(90)
	lab.camera.force_update_scroll()
	check(absf(lab.camera.get_screen_center_position().y-upper) < 1,"upper edge translation settles")
	lab.player.position.y += 100
	lab._update_camera()
	check(is_equal_approx(lab.camera.position.y,upper),"moving back inside frame does not recenter camera")
	lab.player.position.y = origin.y+350
	lab._update_camera()
	check(lab.camera.position.y > upper+100,"lower edge follows a descent without locking out lower routes")
	paused = true
	lab._update_camera()
	var frozen := lab.camera.get_screen_center_position()
	lab.player.position.y += 200
	lab._update_camera()
	check(lab.camera.get_screen_center_position().distance_to(frozen) < .01,"pause freezes edge translation")
	paused = false
	lab.camera_settings.vertical_frame_enabled = false
	lab._update_camera()
	lab.player.position.y -= 40
	lab._update_camera()
	check(absf(lab.camera.position.y-(lab.player.position.y-CoreMovementPlayer.HEIGHT*.5+lab.camera_settings.offset_y/lab.camera_settings.zoom)) < .01,"switch off restores continuous vertical following")
	lab.camera_settings.vertical_frame_enabled = true
	lab._update_camera(true)
	var teleported := lab.camera.get_screen_center_position().y
	lab.player.position.y -= 1200
	lab._update_camera(true)
	lab.camera.force_update_scroll()
	check(lab.camera.get_screen_center_position().y < teleported-1100,"teleport resets framing without traversing the old scene")
	# Pose changes must not move the standing-frame boundary.
	lab.player.position = origin
	lab._update_camera(true)
	initial = lab.camera.position.y
	Input.action_press("core_crouch")
	lab.player._update_crouch(true)
	lab._update_camera()
	Input.action_release("core_crouch")
	lab.player._update_crouch(false)
	check(is_equal_approx(lab.camera.position.y,initial),"crouch does not change the standing-frame anchor")
	for mode in ["stable_pixel_enabled","world_pixel_enabled"]:
		lab.camera_settings.set(mode,true)
		lab._camera_settings_changed()
		lab._update_camera(true)
		initial = lab.camera.position.y
		lab.player.position.y -= 50
		lab._update_camera()
		check(is_equal_approx(lab.camera.position.y,initial) and lab.telemetry.get_viewport() == root,"stable height and native-resolution HUD: "+mode)
		lab.camera_settings.set(mode,false)
		lab._camera_settings_changed()
	var overlay := lab.camera_overlay
	check(overlay.rows.has("vertical_frame_top") and overlay.rows.has("vertical_frame_bottom") and overlay.feature_toggles.has("vertical_frame_enabled"),"developer camera has independent switch and two numeric sliders")
	if lab.level.prologue_mode and not output.is_empty():
		lab.player.position = origin
		lab._update_camera(true)
		lab.developer_mode.toggle_overlay(lab._ui_overlays().find(overlay))
		overlay.tabs.current_tab = 0
		await shot("camera_settings")
		lab.developer_mode.set_enabled(false)
	lab.camera_settings.apply_values({"vertical_frame_enabled":false,"vertical_frame_top":17.5,"vertical_frame_bottom":9.5})
	check(lab.camera_settings.save_saved(lab.camera_settings_path) == OK,"new framing saves to isolated CFG")
	var loaded := CoreCameraSettings.new()
	check(loaded.load_saved(lab.camera_settings_path) == OK and not loaded.vertical_frame_enabled and loaded.vertical_frame_top == 17.5 and loaded.vertical_frame_bottom == 9.5,"CFG retains switch and both margins")
	var json_path := directory.path_join("balance.json")
	check(lab.export_settings_file(json_path),"framing exports with balance JSON")
	lab.camera_settings.vertical_frame_top = 0
	check(lab.import_settings_file(json_path) and lab.camera_settings.vertical_frame_top == 17.5,"JSON restores framing without touching real profiles")
	var legacy := ConfigFile.new()
	legacy.set_value("camera","scale_basis_version",2)
	legacy.set_value("camera","zoom",.7)
	legacy.set_value("camera","offset_y",-185)
	legacy.save(lab.camera_settings_path)
	loaded = CoreCameraSettings.new()
	check(loaded.load_saved(lab.camera_settings_path) == OK and loaded.vertical_frame_enabled and loaded.vertical_frame_top == 12 and loaded.zoom == .7 and loaded.offset_y == -185,"legacy CFG enables stable framing and preserves user zoom/offset")
