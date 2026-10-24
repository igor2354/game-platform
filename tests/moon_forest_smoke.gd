extends SceneTree
var lab: CoreMovementLab
var checks := 0
var failures := 0
var directory := (OS.get_environment("TEMP") if not OS.get_environment("TEMP").is_empty() else "/private/tmp").path_join("moon-forest-%d" % OS.get_process_id())
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	for entry in [["settings_path","movement.cfg"],["shooting_settings_path","shooting.cfg"],["camera_settings_path","camera.cfg"],["zombie_settings_path","zombie.cfg"],["ragdoll_settings_path","ragdoll.cfg"]]:
		lab.set(entry[0],directory.path_join(entry[1]))
	root.add_child(lab)
	await frames(8)
	var hero := lab.player
	var forest: CanvasLayer = lab.moon_forest
	var mat: ShaderMaterial = forest.effect_material
	check(lab._overlays().all(func(overlay): return overlay.settings_path.begins_with(directory+"/")),"all five profile paths are isolated")
	check(forest.visible and forest.opacity == 1 and forest.layer < 0,"animated art is behind gameplay at polygon spawn")
	check(forest.picture.mouse_filter == Control.MOUSE_FILTER_IGNORE and forest.picture.size == root.get_visible_rect().size,"backdrop fits the viewport without consuming input")
	check(forest.left_picture.texture.resource_path == "res://resources/campaign/prologue_forest_4k.png" and forest.left_picture.mouse_filter == Control.MOUSE_FILTER_IGNORE,"the left panel reuses the requested 4K asset without consuming input")
	check(is_equal_approx(forest.left_rect.size.y,forest.night_rect.size.y) and is_equal_approx(forest.left_rect.size.x/forest.left_rect.size.y,3840.0/2160.0),"both pictures share a height and the new source keeps its aspect ratio")
	check(forest.left_rect.position.x < forest.night_rect.position.x and is_equal_approx(forest.left_rect.end.x,forest.night_rect.position.x+forest.night_rect.size.x*.025),"the new panel sits on the left behind the original soft edge")
	check(lab.level.floors.size() == 2 and lab.level.enemies.size() == 7 and lab.level.transition_doors.size() == 4 and hero.is_on_floor(),"floor, enemies, transition doors and actor collision are preserved")
	check(lab.camera_overlay.groups == ["Камера","Визуал","Нуар","Окружение","Пиксельный мир","Сетка уровня"],"original camera/visual pages remain with a separate environment page")
	var balance := hero.tuning.as_dictionary()
	var ammunition := hero.weapon.magazine_ammo
	lab.camera_overlay.feature_toggles.forest_enabled.button_pressed = false
	await frames(2)
	check(not forest.visible and lab.level.atmosphere_opacity == 0,"master switch restores original backdrop/grid")
	check(hero.tuning.as_dictionary() == balance and hero.weapon.magazine_ammo == ammunition,"switching atmosphere preserves balance and ammunition")
	lab.camera_overlay.feature_toggles.forest_enabled.button_pressed = true
	await frames(2)
	for key in forest.EFFECTS:
		var setting: String = "forest_"+key+"_strength"
		lab.camera_settings.set(setting,1.7)
		lab.camera_overlay.feature_toggles["forest_"+key+"_enabled"].button_pressed = false
		await frames(2)
		check(mat.get_shader_parameter(key+"_strength") == 0 and is_equal_approx(lab.camera_settings.get(setting),1.7),"disable preserves effect strength: "+key)
		lab.camera_overlay.feature_toggles["forest_"+key+"_enabled"].button_pressed = true
		await frames(2)
		check(is_equal_approx(mat.get_shader_parameter(key+"_strength"),1.7),"reenable restores effect: "+key)
	var start_time: float = forest.elapsed
	await frames(5)
	check(forest.elapsed > start_time,"animation clock advances during gameplay")
	paused = true
	start_time = forest.elapsed
	for i in 4: await process_frame
	check(is_equal_approx(forest.elapsed,start_time),"pause freezes all atmospheric motion")
	lab.camera_settings.forest_water_strength = 2.2
	for i in 3: await process_frame
	check(is_equal_approx(mat.get_shader_parameter("water_strength"),2.2),"live controls still refresh on pause")
	paused = false
	lab.camera_settings.look_ahead = 0
	lab._update_camera(true)
	await frames(3)
	var initial_x: float = forest.night_rect.position.x
	hero.reset_to(Vector2(-1100,760))
	lab._update_camera(true)
	await frames(3)
	check(forest.visible and forest.opacity == 1 and forest.left_rect.intersects(Rect2(Vector2.ZERO,root.get_visible_rect().size)),"moving left reveals the neighboring picture at full opacity")
	check(absf(forest.night_rect.position.x-initial_x-1260*lab.camera_settings.zoom) < 1,"the two-panel background travels with the horizontal camera instead of following the player on screen")
	lab.camera_settings.zoom = 2
	lab._update_camera(true)
	await frames(3)
	check(is_equal_approx(forest.left_rect.size.y,forest.night_rect.size.y) and is_equal_approx(forest.left_rect.size.x/forest.left_rect.size.y,3840.0/2160.0),"zoom preserves the panels' shared height and source proportions")
	lab.camera_settings.zoom = 1
	lab._update_camera(true)
	hero.reset_to(Vector2(4980,760))
	await frames(3)
	check(not forest.visible and lab.level.atmosphere_opacity == 0,"outside the local area original polygon visuals remain")
	lab._recover()
	await frames(3)
	check(forest.visible and forest.opacity == 1,"F8 recovery returns to the animated start area")
	check(lab.export_settings_file(directory+"/forest.json"),"export includes atmosphere settings")
	lab.camera_settings.forest_water_strength = .1
	lab.camera_settings.forest_water_enabled = false
	check(lab.import_settings_file(directory+"/forest.json") and lab.camera_settings.forest_water_enabled and is_equal_approx(lab.camera_settings.forest_water_strength,2.2),"JSON import restores toggles and numeric values")
	var restored := CoreCameraSettings.new()
	check(restored.load_saved(lab.camera_settings_path) == OK and restored.forest_enabled and is_equal_approx(restored.forest_water_strength,2.2),"CFG persists the environment controls")
	var legacy := ConfigFile.new()
	legacy.set_value("camera","zoom",1.25)
	legacy.save(directory+"/legacy.cfg")
	var old := CoreCameraSettings.new()
	check(old.load_saved(directory+"/legacy.cfg") == OK and old.forest_enabled and old.forest_wind_strength == 1 and old.zoom == 1.25,"old CFG preserves framing and receives deliberate atmosphere defaults")
	lab.queue_free()
	await frames(3)
	lab = load("res://scenes/campaign/prologue.tscn").instantiate()
	lab.load_user_settings = false
	for entry in [["settings_path","movement.cfg"],["shooting_settings_path","shooting.cfg"],["camera_settings_path","camera.cfg"],["zombie_settings_path","zombie.cfg"],["ragdoll_settings_path","ragdoll.cfg"]]:
		lab.set(entry[0],directory.path_join(entry[1]))
	root.add_child(lab)
	await frames(4)
	check(lab.campaign_mode and lab.moon_forest == null and lab.level.atmosphere_opacity == 0,"forest prologue geometry and backdrop are unchanged")
	lab.queue_free()
	await frames(3)
	print("MOON FOREST: %d/%d passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
