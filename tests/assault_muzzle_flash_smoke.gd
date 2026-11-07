extends SceneTree
const FLASH = preload("res://scripts/core/assault_muzzle_flash.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1

class Preview extends Node2D:
	var light := false
	func _draw() -> void:
		draw_rect(Rect2(0,0,1050,820),Color("c9c7bf") if light else Color("202b30"))
		var font := ThemeDB.fallback_font
		var settings := CoreShootingSettings.new()
		for row in 3:
			for phase in 3:
				var root := Vector2(75+phase*340,150+row*250)
				var flash = FLASH.new();flash.start(settings)
				flash.rows=PackedInt32Array([row,row,row])
				flash.age=[0.0,.013,.04][phase]
				flash.draw_on(self,root,Vector2.RIGHT,Vector2.DOWN,.65,1)
				draw_line(root-Vector2(25,0),root,Color("6d828a"),3)
				draw_string(font,root+Vector2(-40,125),"row %d / stage %d"%[row+1,phase+1],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.BLACK if light else Color.WHITE)

func run() -> void:
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("assault-flash-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	var character := "harry" if "--harry" in OS.get_cmdline_user_args() else "sofia"
	root.add_child(app);app.selected_character=character;app.selected_level="polygon";app.launch(false)
	await frames(12)
	var lab=app.game
	var gun=lab.player.weapon
	var settings: CoreShootingSettings=gun.tuning
	var atlas = preload("res://scripts/campaign/art.gd").weapon(0) as AtlasTexture
	var layout: Dictionary=CATALOG.WEAPONS[0]
	if character=="harry": layout=preload("res://scripts/campaign/harry_stg_pose.gd").art_data()
	var outlet: Vector2=FLASH.muzzle_offset(lab.player)
	var reconstructed_source_y: float=outlet.y*atlas.get_width()/float(layout.length)+float(layout.axis)*atlas.get_height()+atlas.region.position.y
	check(is_equal_approx(reconstructed_source_y,184.0),character+" visual outlet maps to barrel not front sight")
	settings.sound_enabled=false;settings.recoil_enabled=false
	check(lab.shooting_overlay.groups.has("Вспышка") and lab.shooting_overlay.rows.has("assault_flash_decay"),"F2 controls present")
	lab.shooting_overlay.rows.assault_flash_decay.slider.value=.055
	check(is_equal_approx(settings.assault_flash_decay,.055) and is_equal_approx(lab.shooting_overlay.rows.assault_flash_decay.number.value,.055),"slider and numeric input synchronise")
	settings.assault_flash_enabled=false
	settings.save_saved(app.test_settings_directory.path_join("flash.cfg"))
	var loaded := CoreShootingSettings.new()
	loaded.load_saved(app.test_settings_directory.path_join("flash.cfg"))
	check(not loaded.assault_flash_enabled and is_equal_approx(loaded.assault_flash_decay,.055),"disabled settings persist in CFG")
	var imported := CoreShootingSettings.new()
	imported.apply_values(JSON.parse_string(JSON.stringify(loaded.as_dictionary())))
	check(not imported.assault_flash_enabled and is_equal_approx(imported.assault_flash_decay,.055),"JSON roundtrip preserves toggle and timing")
	settings.assault_flash_enabled=true;settings.assault_flash_decay=.040
	var flash=FLASH.new();flash.random.seed=38511
	var reached := {}
	var mixed := false
	for shot in 120:
		flash.start(settings)
		if flash.rows[0]!=flash.rows[1] or flash.rows[1]!=flash.rows[2]: mixed=true
		var sequence: PackedInt32Array=flash.rows.duplicate()
		for phase in 3:
			if shot==0: check(flash.stage()==phase,"shot %d ordered phase %d"%[shot,phase])
			reached[str(flash.frame())]=true
			var before: Vector2i=flash.frame()
			for draw_request in 5: flash.frame()
			if shot==0: check(flash.frame()==before and flash.rows==sequence,"repeated draws keep phase choice stable")
			flash.tick(float(flash.durations[phase])+.000001)
		if shot==0: check(not flash.active and flash.stage()==-1,"finished flash hides after third phase")
	check(reached.size()==9 and mixed,"all nine frames reached with independent per-phase rows")
	var image := FLASH.TEXTURE.get_image()
	for row in 3:
		for phase in 3:
			var region: Rect2=FLASH.REGIONS[row][phase]
			var root: Vector2=FLASH.ROOTS[row][phase]
			check(Rect2(Vector2.ZERO,Vector2(image.get_size())).encloses(region) and region.has_point(root) and not image.get_region(Rect2i(region)).is_invisible(),"frame %d/%d valid source and anchor"%[row,phase])
			var dest: Rect2=FLASH.destination(row,phase,.5)
			check((dest.position+(root-region.position)*.5).is_zero_approx(),"frame %d/%d maps emission root to muzzle"%[row,phase])
	flash.start(settings);flash.tick(.025);flash.start(settings)
	check(flash.age==0 and flash.stage()==0,"new shot restarts at ignition")
	CATALOG.equip(gun,"stg44")
	var ballistics_rng: int=gun.rng.state
	var recoil_rng: int=gun.recoil_rng.state
	var sound_rng: int=gun.cosmetic_rng.state
	gun.assault_flash.start(settings)
	check(gun.rng.state==ballistics_rng and gun.recoil_rng.state==recoil_rng and gun.cosmetic_rng.state==sound_rng,"flash RNG isolated from bullets recoil audio and casings")
	gun.aim_override=lab.player.global_position+Vector2(700,-100)
	gun._fire()
	check(gun.assault_flash.active and gun.assault_flash.stage()==0,"real STG shot starts animation")
	var age: float=gun.assault_flash.age
	paused=true;await frames(4)
	check(gun.assault_flash.age==age,"pause freezes flash")
	paused=false;await frames(10)
	check(not gun.assault_flash.active,"live update finishes flash")
	for id in ["mp40","svt","m1911"]:
		CATALOG.equip(gun,id);gun._fire()
		check(gun.assault_flash.active and gun.assault_flash.weapon_id==id,id+" selects its own V2 sheet")
	CATALOG.equip(gun,"stg44");gun._fire()
	settings.assault_flash_enabled=false;gun.apply_tuning()
	check(not gun.assault_flash.active and settings.assault_flash_decay==.040,"disable hides flash without erasing parameters")
	settings.assault_flash_enabled=true;gun._fire();gun.reset_state()
	check(not gun.assault_flash.active,"reset clears sequence")
	gun._fire();CATALOG.equip(gun,"mp40")
	check(not gun.assault_flash.active,"weapon switch cancels old assault flash")
	if "--capture" in OS.get_cmdline_user_args():
		var folder := preload("res://tools/media_paths.gd").path("docs/core/assault_flash_20261102")
		var viewport := SubViewport.new();viewport.size=Vector2i(1050,820)
		viewport.world_2d=World2D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var preview := Preview.new();viewport.add_child(preview)
		for light in [false,true]:
			preview.light=light;preview.queue_redraw()
			await frames(2);await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(folder.path_join("frames_light.png" if light else "frames_dark.png"))
		viewport.queue_free()
		CATALOG.equip(gun,"stg44")
		for label in ["right","left","up"]:
			var offset := Vector2(700,-50) if label=="right" else Vector2(-700,-50) if label=="left" else Vector2(500,-500)
			gun.aim_override=lab.player.global_position+offset
			await frames(35)
			gun._fire();gun.assault_flash.rows=PackedInt32Array([0,1,2]);gun.assault_flash.age=.013
			lab.process_mode=Node.PROCESS_MODE_DISABLED
			await frames(2);await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join("game_"+("harry_" if character=="harry" else "")+label+".png"))
			lab.process_mode=Node.PROCESS_MODE_INHERIT
	app.queue_free();await frames(3)
	print("ASSAULT MUZZLE FLASH ",checks-failures,"/",checks)
	quit(1 if failures else 0)

