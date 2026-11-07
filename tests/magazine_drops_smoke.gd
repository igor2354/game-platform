extends SceneTree

const CATALOG = preload("res://scripts/campaign/catalog.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func drops(gun: CoreShootingController) -> Array[Node]:
	return gun.get_children().filter(func(node): return node.has_meta("dropped_magazine"))

func run() -> void:
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("magazine-drops-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	app.selected_level = "terra"
	app.launch(true)
	await frames(12)
	var lab: CoreMovementLab = app.game
	var gun := lab.player.weapon
	gun.aim_cursor.focus_override = true
	gun.aim_cursor.sync_context()
	var floor_y: float = lab.level.player_spawn().y
	for id in ["", "stg44", "mp40", "m1911", "svt"]:
		if id.is_empty(): gun.equipped_weapon_id = ""
		else: CATALOG.equip(gun, id)
		gun.tuning.reload_duration = 1.0
		gun.tuning.sound_enabled = false
		gun.magazine_ammo = 3
		gun.reserve_ammo = 200
		var count := drops(gun).size()
		check(gun.request_reload(), id + " partial reload starts")
		while gun.reloading and gun.reload_progress() < .47: await frames(1)
		check(gun.reloading and gun.visual_pose().magazine_visible, id + " partial magazine is held during stow")
		await frames(65)
		check(drops(gun).size() == count and gun.magazine_ammo + gun.reserve_ammo == 203, id + " partial reload conserves ammo without a drop")
		gun.magazine_ammo = 0
		check(gun.request_reload(), id + " empty reload starts")
		while gun.reloading and gun.reload_progress() < .47: await frames(1)
		check(gun.empty_magazine_detached and not gun.visual_pose().magazine_visible, id + " empty magazine released")
		if id == "mp40" and "--capture" in OS.get_cmdline_user_args():
			lab.process_mode = Node.PROCESS_MODE_DISABLED
			await process_frame
			await RenderingServer.frame_post_draw
			var folder := preload("res://tools/media_paths.gd").path("docs/core/reload_drops_20261104")
			check(root.get_texture().get_image().save_png(folder.path_join("mp40_without_magazine.png")) == OK, "MP-40 capture saved")
			lab.process_mode = Node.PROCESS_MODE_INHERIT
		gun.cancel_reload()
		check(gun.request_reload(), id + " interrupted reload can restart")
		await frames(260)
		var fallen := drops(gun)
		check(fallen.size() == count + 1, id + " drop persists and retry cannot duplicate it")
		if fallen.size() > count:
			var body := fallen.back() as RigidBody2D
			check(body.sleeping and absf(body.angular_velocity) < .1 and absf(body.global_position.y - floor_y) < 40, id + " magazine rests on its shaped collider")
	gun.clear_dropped_magazines()
	await frames(2)
	check(drops(gun).is_empty(), "range reset can clear drops")
	var ground = lab.level.ground
	var floor_point := Vector2(lab.level.player_spawn().x + 450, floor_y)
	gun._drop_magazine(gun._reload_pose(.42))
	var magazine := drops(gun).back() as RigidBody2D
	magazine.global_position = floor_point + Vector2(0, -30)
	magazine.linear_velocity = Vector2.ZERO
	await frames(180)
	check(magazine.sleeping, "magazine sleeps before terrain changes")
	var before := magazine.global_position
	var removed: int = ground.deform(ground.to_local(floor_point), 105, 220, false)
	await frames(85)
	check(removed > 0 and magazine.global_position.y > before.y + 8, "real terrain rebuild drops the sleeping magazine")

	var shell: Dictionary = gun.casing_motion.spawn(magazine.global_position + Vector2(15, -20), Vector2.RIGHT, Vector2(3, 1), "stg44", gun.cosmetic_rng)
	shell.state = "rest"
	shell.velocity = Vector2.ZERO
	gun.effects.append(shell)
	var far_shell := shell.duplicate()
	far_shell.point += Vector2(1000, 0)
	gun.effects.append(far_shell)
	var blast := CoreExplosionSettings.new()
	blast.explosion_radius = 100
	blast.explosion_audio_enabled = false
	blast.explosion_visuals_enabled = false
	ground.tuning.terra_explosions_enabled = false
	CoreExplosion.spawn(lab.level, magazine.global_position + Vector2(-35, -25), blast)
	check(not magazine.sleeping and magazine.linear_velocity.x > 0 and magazine.linear_velocity.y < 0, "blast wakes and pushes magazine away")
	check(shell.state == "air" and shell.velocity.x > 0 and shell.velocity.y < 0, "blast relaunches nearby casing")
	check(far_shell.state == "rest", "blast leaves distant casing alone")
	check(lab.shooting_overlay.rows.has("casing_volume"), "casing volume slider is registered")
	gun.tuning.set_parameter("casing_volume", -8)
	var settings_file: String = app.test_settings_directory.path_join("casing-test.cfg")
	var loaded := CoreShootingSettings.new()
	check(gun.tuning.save_saved(settings_file) == OK and loaded.load_saved(settings_file) == OK and loaded.casing_volume == -8, "casing volume survives profile round trip")
	var audio_floor := StaticBody2D.new()
	audio_floor.set_meta("terra_material", 3)
	lab.level.add_child(audio_floor)
	var contact := {"collider": audio_floor, "position": floor_point, "normal": Vector2.UP}
	var audio = gun.casing_audio
	audio.rng.seed = 13
	audio.play(gun, contact, floor_point, -8)
	var first := gun.get_child(-1) as AudioStreamPlayer
	lab.camera.zoom *= .5
	audio = preload("res://scripts/core/casing_audio.gd").new()
	audio.rng.seed = 13
	audio.play(gun, contact, floor_point, -8)
	var second := gun.get_child(-1) as AudioStreamPlayer
	check(first != null and second != null and first != second and is_equal_approx(first.volume_db, second.volume_db), "camera zoom cannot change casing gain")
	for material in [1, 3, 4, 5]:
		audio_floor.set_meta("terra_material", material)
		var previous: AudioStreamPlayer
		var distinct := true
		for index in 12:
			audio.play(gun, contact, floor_point, 0)
			var current := gun.get_child(-1) as AudioStreamPlayer
			distinct = distinct and current != null and current != previous
			if previous and current:
				distinct = distinct and current.stream != previous.stream and current.pitch_scale != previous.pitch_scale and current.volume_db != previous.volume_db
				previous.free()
			previous = current
		if previous: previous.free()
		check(distinct, "no consecutive timbre, pitch or level repetition on material %d" % material)
	await app.return_to_menu()
	await frames(2)
	# The audio thread uses real time even with accelerated fixed-fps tests.
	OS.delay_msec(200)
	await frames(2)
	print("MAGAZINE DROPS: %d/%d" % [checks - failures, checks])
	quit(1 if failures else 0)
