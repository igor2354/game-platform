extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
class Probe extends "res://scripts/core/live_zombie.gd":
	var draw_mode := "full"
	var lock_pose := false
	var physics_us := 0
	var draw_us := 0
	var detached_draw_us := 0
	var pose_us := 0
	var fixed: Dictionary = {}
	func _physics_process(delta: float) -> void:
		var start := Time.get_ticks_usec()
		super._physics_process(delta)
		physics_us += Time.get_ticks_usec()-start
	func current_pose() -> Dictionary:
		var start := Time.get_ticks_usec()
		var result: Dictionary
		if lock_pose:
			if fixed.is_empty(): fixed = LIVE_ART.pose("idle",0)
			result = fixed
		else: result = super.current_pose()
		pose_us += Time.get_ticks_usec()-start
		return result
	func _draw_actor_body() -> void:
		var start := Time.get_ticks_usec()
		if draw_mode != "none": super._draw_actor_body()
		draw_us += Time.get_ticks_usec()-start
	func _draw_detached() -> void:
		var start := Time.get_ticks_usec()
		super._draw_detached()
		detached_draw_us += Time.get_ticks_usec()-start
	func draw_live_piece(canvas: CanvasItem,key: String,transform: Transform2D,dimensions: Vector2,tint: Color) -> void:
		if draw_mode == "rect":
			canvas.draw_set_transform_matrix(transform)
			canvas.draw_rect(Rect2(-dimensions*.5,dimensions),tint)
		else: super.draw_live_piece(canvas,key,transform,dimensions,tint)
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func run() -> void:
	var display = preload("res://scripts/ui/display_options.gd").access(self,false)
	display.settings_path = OS.get_environment("TEMP").path_join("mannequin-profile-display-%d.cfg" % OS.get_process_id())
	display.select(Vector2i(1600,900),false)
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.selected_character = "sofia"
	app.test_settings_directory = OS.get_environment("TEMP").path_join("mannequin-hit-profile-%d" % OS.get_process_id())
	root.add_child(app)
	app.launch(false)
	await frames(12)
	var lab: CoreMovementLab = app.game
	var camera := CoreCameraSettings.new()
	camera.load_saved()
	lab.camera_settings.apply_values(camera.as_dictionary())
	lab._camera_settings_changed()
	lab._teleport_player(Vector2(4800,760))
	lab.player.set_physics_process(false)
	lab.player.set_invulnerable(true)
	lab.aim_cursor.focus_override = true
	for e in lab.level.enemies: e.set_test_frozen(true); e.hide()
	var probe := Probe.new()
	probe.position = Vector2(5200,760)
	probe.body_size = Vector2(32,64)*2.85
	probe.tuning = lab.zombie_settings.duplicate()
	probe.tuning.movement_enabled = false
	probe.tuning.combat_enabled = false
	probe.tuning.vision_enabled = false
	probe.tuning.hearing_enabled = false
	lab.level.add_child(probe)
	probe.target = lab.player
	probe.set_invulnerable(true)
	var gun := lab.player.weapon
	probe.damage_tuning = gun.tuning
	gun.tuning.sound_enabled = false
	gun.tuning.magazine_enabled = false
	gun.tuning.recoil_enabled = false
	gun.tuning.hip_spread = 0
	gun.tuning.hip_max_spread = 0
	gun.tuning.aim_beam_enabled = false
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var rows := []
	for repetition in (1 if "--quick" in OS.get_cmdline_user_args() else 3):
		for kind in ["idle","hit","rect","hit","none","hit","sever","ragdoll"]:
			Input.action_release("core_fire")
			probe.reset_target()
			probe.position = Vector2(4870 if kind.begins_with("close") else 5200,760)
			probe.draw_mode = "none" if kind == "close_none" else kind if kind in ["rect","none"] else "full"
			if kind == "sever":
				probe._sever_part("left_arm",Vector2.RIGHT)
				probe._sever_part("left_leg",Vector2.LEFT)
			if kind == "ragdoll": probe.blast_ragdoll.start(Vector2(150,-80),.45,.12)
			probe.lock_pose = kind == "fixed_pose"
			gun.aim_override = probe.global_position+Vector2(0,-350 if kind in ["miss","close_miss"] else -20 if kind.begins_with("close") else -140)
			gun._update_aim()
			await frames(15)
			probe.physics_us = 0; probe.draw_us = 0; probe.pose_us = 0; probe.detached_draw_us = 0
			var shots := gun.shots_fired
			var hits := probe.received_hits
			var times := []
			var gun_us := 0
			var previous := Time.get_ticks_usec()
			if kind != "idle": Input.action_press("core_fire")
			for i in 90:
				var start := Time.get_ticks_usec()
				gun.update_state(root.get_process_delta_time(),true)
				gun.finish_tick()
				lab.player.body.update_arms()
				gun_us += Time.get_ticks_usec()-start
				await process_frame
				var now := Time.get_ticks_usec()
				times.append((now-previous)/1000.0); previous = now
			times.sort()
			var row := {"repeat":repetition,"case":kind,"median_ms":times[45],"p95_ms":times[85],"gun_cpu_ms_per_frame":gun_us/90000.0,"target_physics_ms_per_frame":probe.physics_us/90000.0,"target_pose_ms_per_frame":probe.pose_us/90000.0,"target_draw_ms_per_frame":probe.draw_us/90000.0,"shots":gun.shots_fired-shots,"hits":probe.received_hits-hits,"parts":probe.detached_parts.size()}
			rows.append(row)
			row["detached_draw_ms_per_frame"] = probe.detached_draw_us/90000.0
			var contour_max := 0
			var contour_total := 0
			for contour in preload("res://scripts/core/mannequin_art.gd").silhouette_cache.values():
				contour_max = maxi(contour_max,contour.size())
				contour_total += contour.size()
			row["cached_contour_max"] = contour_max
			row["cached_contour_total"] = contour_total
			print("PROFILE ",JSON.stringify(row))
	Input.action_release("core_fire")
	var output := "profile_final.json" if "--quick" in OS.get_cmdline_user_args() else "profile_after.json"
	var file := FileAccess.open(MEDIA.path("docs/core/mannequin_cutout_20261101/"+output),FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"));file.close()
	quit()
