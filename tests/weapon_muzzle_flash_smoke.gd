extends SceneTree
const FLASH = preload("res://scripts/core/assault_muzzle_flash.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
const IDS := ["stg44","mp40","svt","m1911"]
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1

class Preview extends Node2D:
	var weapon_id := "mp40"
	var light := false
	func _draw() -> void:
		draw_rect(Rect2(0,0,1050,820),Color("c9c7bf") if light else Color("202b30"))
		var settings := CoreShootingSettings.new()
		for row in 3:
			for stage in 3:
				var root := Vector2(60+stage*345,145+row*250)
				var flash=FLASH.new();flash.start(settings,weapon_id)
				flash.rows=PackedInt32Array([row,row,row])
				for previous in stage: flash.age+=flash.durations[previous]
				flash.age+=.000001
				flash.draw_on(self,root,Vector2.RIGHT,Vector2.DOWN,.60,1)
				draw_line(root-Vector2(25,0),root,Color("6d828a"),3)
				draw_string(ThemeDB.fallback_font,root+Vector2(-30,130),"%s / %d.%d"%[weapon_id,row+1,stage+1],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.BLACK if light else Color.WHITE)

func run() -> void:
	var capture := "--capture" in OS.get_cmdline_user_args()
	var character := "mannequin_v6"
	var app=preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("weapon-flash-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app);app.selected_level="polygon";app.launch(false)
	await frames(12)
	var lab=app.game
	var gun=lab.player.weapon
	var settings: CoreShootingSettings=gun.tuning
	settings.sound_enabled=false;settings.recoil_enabled=false;settings.magazine_enabled=false
	gun.aim_override=lab.player.global_position+Vector2(700,-50)
	var paths := {}
	for id in IDS:
		CATALOG.equip(gun,id)
		var key: String=FLASH.prefix(id)
		var path: String=FLASH.texture_for(id).resource_path
		check(not paths.has(path) and path.contains("muzzle_v2.png"),id+" selects unique approved sheet")
		paths[path]=true
		check(lab.shooting_overlay.rows.has(key+"_decay"),id+" independent F2 controls")
		lab.shooting_overlay.rows[key+"_decay"].slider.value=.057
		check(is_equal_approx(float(settings.get(key+"_decay")),.057) and is_equal_approx(lab.shooting_overlay.rows[key+"_decay"].number.value,.057),id+" slider and numeric field")
		settings.set(key+"_enabled",false)
		settings.save_saved(app.test_settings_directory.path_join(id+".cfg"))
		var loaded := CoreShootingSettings.new();loaded.load_saved(app.test_settings_directory.path_join(id+".cfg"))
		var imported := CoreShootingSettings.new();imported.apply_values(JSON.parse_string(JSON.stringify(loaded.as_dictionary())))
		check(not imported.get(key+"_enabled") and is_equal_approx(float(imported.get(key+"_decay")),.057),id+" disabled CFG and JSON preserve values")
		settings.set(key+"_enabled",true)
		settings.set(key+"_decay",CoreShootingSettings.new().get(key+"_decay"))
		var flash=FLASH.new();flash.random.seed=236
		var reached := {};var ordered := true;var stable := true
		for shot in 120:
			flash.start(settings,id)
			for phase in 3:
				ordered=ordered and flash.stage()==phase
				var before: Vector2i=flash.frame()
				reached[str(before)]=true
				for draw_request in 5: flash.frame()
				stable=stable and flash.frame()==before
				flash.tick(float(flash.durations[phase])+.000001)
		check(reached.size()==9 and ordered and stable and not flash.active,id+" all9 frames with ordered stable phases")
		var image: Image=FLASH.texture_for(id).get_image()
		for row in 3:
			for phase in 3:
				var region: Rect2=FLASH.regions_for(id)[row][phase]
				var root: Vector2=FLASH.roots_for(id)[row][phase]
				var dest: Rect2=FLASH.destination(row,phase,.5,id)
				check(Rect2(Vector2.ZERO,Vector2(image.get_size())).encloses(region) and region.has_point(root) and not image.get_region(Rect2i(region)).is_invisible() and (dest.position+(root-region.position)*.5).is_zero_approx(),id+" frame %d/%d nonempty and anchored"%[row,phase])
		var atlas=preload("res://scripts/campaign/art.gd").weapon(CATALOG.index_for(id)) as AtlasTexture
		var layout: Dictionary=CATALOG.WEAPONS[CATALOG.index_for(id)]
		var pixel_scale: float=float(layout.length)/atlas.get_width()
		var reconstructed: Vector2=(FLASH.muzzle_offset(lab.player)+Vector2(float(layout.grip)*float(layout.length),float(layout.axis)*atlas.get_height()*pixel_scale))/pixel_scale+atlas.region.position
		check(reconstructed.is_equal_approx(FLASH.OUTLETS[id]),character+" "+id+" outlet accounts for art bounds and placement")
		var rng_state: int=gun.rng.state
		var recoil_state: int=gun.recoil_rng.state
		var cosmetic_state: int=gun.cosmetic_rng.state
		gun.assault_flash.start(settings,id)
		check(gun.rng.state==rng_state and gun.recoil_rng.state==recoil_state and gun.cosmetic_rng.state==cosmetic_state,id+" isolated visual RNG")
		await frames(3);gun._fire()
		check(gun.assault_flash.active and gun.assault_flash.weapon_id==id and gun.assault_flash.stage()==0,id+" real shot selects correct sheet and ignition")
		var age: float=gun.assault_flash.age
		paused=true;await frames(3)
		check(gun.assault_flash.age==age,id+" pause freezes animation")
		paused=false;await frames(15)
		check(not gun.assault_flash.active,id+" live update completes animation")
		gun._fire();settings.set(key+"_enabled",false);gun.apply_tuning()
		check(not gun.assault_flash.active and settings.get(key+"_size")==1.0,id+" independent disable keeps size")
		settings.set(key+"_enabled",true);gun._fire();gun.reset_state()
		check(not gun.assault_flash.active,id+" reset removes flash")
		gun._fire();CATALOG.equip(gun,"mp40" if id!="mp40" else "svt")
		check(not gun.assault_flash.active,id+" weapon switch cancels previous sequence")
		if capture:
			var folder := preload("res://tools/media_paths.gd").path("docs/core/all_muzzle_20261105")
			if not folder.is_empty():
				var viewport := SubViewport.new();viewport.size=Vector2i(1050,820);viewport.world_2d=World2D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
				root.add_child(viewport)
				var preview := Preview.new();preview.weapon_id=id;viewport.add_child(preview)
				for light in [false,true]:
					preview.light=light;preview.queue_redraw();await frames(2);await RenderingServer.frame_post_draw
					viewport.get_texture().get_image().save_png(folder.path_join(id+("_light.png" if light else "_dark.png")))
				viewport.queue_free()
			CATALOG.equip(gun,id)
			for label in ["right","left","up"]:
				gun.aim_override=lab.player.global_position+(Vector2(700,-50) if label=="right" else Vector2(-700,-50) if label=="left" else Vector2(500,-500))
				await frames(35);gun._fire();gun.assault_flash.rows=PackedInt32Array([0,1,2]);gun.assault_flash.age=float(gun.assault_flash.durations[0])+.001
				lab.process_mode=Node.PROCESS_MODE_DISABLED
				await frames(2);await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(folder.path_join(character+"_"+id+"_"+label+".png"))
				lab.process_mode=Node.PROCESS_MODE_INHERIT
	gun.equipped_weapon_id="";gun.apply_tuning();gun._fire()
	check(not gun.assault_flash.active and gun.flash_left>0,"legacy unnamed test rifle stays unchanged")
	app.queue_free();await frames(3)
	print("WEAPON MUZZLE FLASH ",character," ",checks-failures,"/",checks)
	quit(1 if failures else 0)
