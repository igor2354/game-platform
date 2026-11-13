extends "res://tools/ubertest_runner.gd"
var checks_done := false
func setup() -> void:
	super.setup()
	if not ready_run: return
	assert(root.mode==Window.MODE_WINDOWED and not root.borderless and not root.unresizable)
	assert(config.balance.is_empty())
	for key in profile_info:
		var info: Dictionary = profile_info[key]
		if info.saved_profile:
			assert(FileAccess.get_sha256(info.source)==FileAccess.get_sha256(info.snapshot))
	var expected_shooting = preload("res://resources/core/shooting.tres").duplicate(true)
	var catalog = preload("res://scripts/campaign/catalog.gd")
	expected_shooting.apply_values(catalog.WEAPONS[catalog.index_for("stg44")].values)
	var pairs := [[stage.player.tuning,preload("res://resources/core/movement.tres").duplicate(true),"settings_path"],[stage.camera_settings,preload("res://resources/core/camera.tres").duplicate(true),"camera_settings_path"],[stage.combat.gun.tuning,expected_shooting,"shooting_settings_path"],[stage.combat.zombie_settings,preload("res://resources/core/zombie.tres").duplicate(true),"zombie_settings_path"],[stage.ragdoll_settings,CoreRagdollSettings.new(),"ragdoll_settings_path"]]
	for pair in pairs:
		if profile_info[pair[2]].saved_profile:
			assert(pair[1].load_saved(profile_info[pair[2]].snapshot)==OK)
		assert(pair[0].as_dictionary()==pair[1].as_dictionary())
	assert(root.find_children("*","Button",true,false).size()>=5)
	toggle_pause()
	assert(paused)
	toggle_pause()
	assert(not paused)
	set_background(true)
	assert(background_mode and root.position.x< -10000)
	set_background(false)
	assert(not background_mode and root.position.x>=0)
	print("UBERTEST_CONTROLS_CHECK PASS: decorated/resizable window, pause/resume, background/restore, all five effective profiles match snapshot loaders")
	checks_done = true
	call_deferred("capture_check")

func capture_check() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(str(config.output).path_join("window_check.png"))
	toggle_pause()
	var before := elapsed
	await create_timer(.3,true,false,true).timeout
	assert(paused and elapsed==before)
	var command := FileAccess.open(str(config.output).path_join("command.json"),FileAccess.WRITE)
	command.store_string('{"action":"pause"}')
	command.close()
	await create_timer(.4,true,false,true).timeout
	assert(not paused and elapsed>before)
	root.mode = Window.MODE_MINIMIZED
	await create_timer(.3,true,false,true).timeout
	assert(paused and minimized_pause)
	root.mode = Window.MODE_WINDOWED
	await create_timer(.3,true,false,true).timeout
	assert(not paused and not minimized_pause)
	toggle_pause()
	var stop := FileAccess.open(str(config.output).path_join("stop"),FileAccess.WRITE)
	stop.close()
	print("UBERTEST_PAUSE_CHECK PASS: elapsed frozen, controller resume, minimize/restore, stop requested while paused")

func finish(reason: String) -> void:
	if ready_run:
		assert(checks_done)
		for info in profile_info.values():
			if info.saved_profile: assert(FileAccess.get_sha256(info.source)==info.sha256)
		assert(stage.combat.gun.shots_fired==0)
		print("UBERTEST_PROFILE_SAFETY PASS: original CFG hashes unchanged, no blind shots")
	super.finish(reason)
