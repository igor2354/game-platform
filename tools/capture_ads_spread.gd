extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
var directory := ""
var samples := []
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func shot(name: String,gun: Node) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name+".png"))
	samples.append({"name":name,"actual_spread_degrees":gun.spread_degrees(),"beam_half_angle_degrees":rad_to_deg(gun.aim_beam.half_angle),"ads_bloom":gun.ads_bloom})
func run() -> void:
	directory = MEDIA.path("docs/core/aim_ads_burst_20261030")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,900)
	var app := preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("ads-capture-%d" % OS.get_process_id())
	app.selected_character = "sofia"
	root.add_child(app)
	app.launch(false)
	await frames(10)
	var lab: CoreMovementLab = app.game
	var gun := lab.player.weapon
	lab.aim_cursor.focus_override = true
	gun.aim_override = lab.player.global_position+Vector2(1200,-180)
	gun.tuning.sound_enabled = false
	gun.tuning.damage_enabled = false
	gun.tuning.recoil_enabled = false
	gun.tuning.magazine_enabled = false
	Input.action_press("core_aim")
	await frames(20)
	await shot("ads_ready",gun)
	Input.action_press("core_fire")
	await frames(48)
	await shot("ads_beam_burst",gun)
	gun.tuning.aim_beam_enabled = false
	await frames(10)
	await shot("ads_classic_burst",gun)
	gun.tuning.aim_beam_enabled = true
	Input.action_release("core_fire")
	await frames(50)
	await shot("ads_recovered",gun)
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(1)
	lab.shooting_overlay.tabs.current_tab = lab.shooting_overlay.groups.find("Прицел")
	await frames(3)
	await shot("settings",gun)
	Input.action_release("core_aim")
	var file := FileAccess.open(directory.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(samples,"\t"))
	file.close()
	print("ADS CAPTURE: ",samples)
	quit()
