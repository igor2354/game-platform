extends SceneTree
var checks := 0
var failures := 0
var lab: CoreMovementLab
var directory := "/private/tmp/indoor-lighting-%d" % OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for tick in count: await physics_frame; await process_frame
func new_lab(campaign := false) -> CoreMovementLab:
	var instance: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	instance.campaign_mode = campaign
	instance.get_node("World/Level").prologue_mode = campaign
	instance.load_user_settings = false
	instance.settings_path = directory+"/movement.cfg"
	instance.shooting_settings_path = directory+"/shooting.cfg"
	instance.camera_settings_path = directory+"/camera.cfg"
	instance.zombie_settings_path = directory+"/zombie.cfg"
	instance.ragdoll_settings_path = directory+"/ragdoll.cfg"
	root.add_child(instance)
	return instance
func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(1600,900)
	lab = new_lab()
	await frames(8)
	var room := lab.level.indoor_lighting
	var lamp := room.lamp
	var enemy := lab.level.indoor_zombie
	var hero := lab.player
	var tuning := lab.zombie_settings
	check(room != null and enemy in lab.level.enemies and enemy.target == hero and enemy.tuning == tuning,"a separate room contains a fully connected patrol enemy")
	check(room.contains_point(enemy.global_position-Vector2(0,1)) and not room.contains_point(lab.level.zombie.global_position),"lighting is restricted to the room")
	check(not lamp.broken and lamp.health == tuning.lamp_health,"the wall lamp starts intact")
	check(enemy.state == CoreZombie.State.PATROL and enemy.is_on_floor(),"the new enemy naturally patrols without player detection")
	var min_x := enemy.position.x
	var max_x := min_x
	for tick in 800:
		await physics_frame
		min_x = minf(min_x,enemy.position.x)
		max_x = maxf(max_x,enemy.position.x)
	check(max_x-min_x > 300 and min_x > 6020 and max_x < 6940,"the patrol reverses and stays in the interior")
	# Enter through the real 104 px doorway with ordinary actor collision.
	for other in lab.level.enemies: other.set_test_frozen(true)
	hero.reset_to(Vector2(5940,760))
	Input.action_press("core_right")
	await frames(48)
	Input.action_release("core_right")
	check(hero.position.x > 6040 and hero.is_on_floor(),"the standing player can walk through the entrance")
	hero.reset_to(CoreIndoorLighting.TEST_SPAWN)
	hero.set_physics_process(false)
	enemy.set_test_frozen(false)
	enemy.reset_target()
	enemy.set_physics_process(false)
	enemy.facing = -1
	enemy.position = Vector2(6580,760)
	hero.global_position = enemy.global_position+Vector2(-220,0)
	await frames(2)
	check(is_equal_approx(enemy.vision_radius(tuning.detection_range),360) and enemy.sees_player(360),"an intact lamp preserves ordinary long-range detection")
	# Actual bullet ray and the shared damage resolver, not a scripted lamp break.
	var bullet := CoreProjectile.new()
	bullet.shooter = hero.get_rid()
	bullet.damage = tuning.lamp_health*.4
	bullet.position = lamp.global_position+Vector2(-100,0)
	bullet.direction = Vector2.RIGHT
	lab.add_child(bullet)
	await frames(6)
	check(not lamp.broken and is_equal_approx(lamp.health,tuning.lamp_health*.6),"a real bullet hits and damages the fixture without turning off an intact lamp")
	var disabled_hit := {"collider":lamp,"position":lamp.global_position}
	CoreProjectile.resolve_impact(disabled_hit,100,Vector2.RIGHT,Callable(),hero.position,false,hero)
	check(not lamp.broken,"disabled projectile damage cannot break the lamp")
	CoreProjectile.resolve_impact(disabled_hit,100,Vector2.RIGHT,Callable(),hero.position,true,hero)
	await frames(2)
	check(lamp.broken and lamp.health == 0 and room.light_level(enemy.position-Vector2(0,32)) == 0,"breaking the lamp removes the illumination")
	check(is_equal_approx(enemy.vision_radius(360),90) and is_equal_approx(enemy.effective_vision_angle(),78),"darkness scales range and angle without editing base zombie settings")
	check(not enemy.sees_player(360) and not enemy.sees_player(tuning.forget_range),"darkness limits both initial detection and visual target retention")
	hero.position = enemy.position+Vector2(-65,0)
	check(enemy.sees_player(360),"the enemy still sees a close player in darkness")
	hero.position = enemy.vision_origin()+Vector2(-cos(deg_to_rad(45)),sin(deg_to_rad(45)))*70+Vector2(0,32)
	check(not enemy.sees_player(360),"a close player outside the narrowed dark cone is unseen")
	hero.position = enemy.position+Vector2(-220,0)
	check(enemy.hear_noise(hero.position,1,"shot"),"a gunshot still alerts the darkened patrol")
	check(enemy.state == CoreZombie.State.INVESTIGATE and enemy.noise_memory_left > 0,"darkness preserves the heard source and investigation")
	check(is_equal_approx(lab.level.zombie.vision_radius(360),360) and is_equal_approx(lab.level.zombie.effective_vision_angle(),120),"outdoor enemies keep their original vision")
	tuning.lighting_enabled = false
	lab._zombie_settings_changed()
	check(enemy.sees_player(360) and not room.shade.visible and lamp.broken,"disabling the mechanic restores vision and visuals without repairing the lamp")
	tuning.lighting_enabled = true
	tuning.dark_vision_range = .4
	tuning.dark_vision_angle = .8
	tuning.indoor_ambient = .5
	lab._zombie_settings_changed()
	check(is_equal_approx(enemy.vision_radius(360),252) and is_equal_approx(enemy.effective_vision_angle(),108),"ambient light interpolates range and angle immediately")
	tuning.indoor_ambient = 0
	lamp.reset_lamp()
	tuning.lamp_radius = 80
	lab._zombie_settings_changed()
	check(is_equal_approx(enemy.vision_radius(360),144),"an intact short-range lamp does not illuminate the whole room")
	tuning.lamp_radius = 680
	tuning.lamp_intensity = 0
	lab._zombie_settings_changed()
	check(room.light_level(enemy.position-Vector2(0,32)) == 0,"zero brightness turns off illumination while retaining lamp health")
	tuning.lamp_intensity = 1
	tuning.lamp_health = 60
	lab._zombie_settings_changed()
	check(lamp.health == 25,"raising maximum lamp HP does not heal it")
	lamp.reset_lamp()
	check(lamp.health == 60 and enemy.sees_player(360),"repair restores the configured lamp HP and ordinary sight")
	# A fixture is a bullet target, not a wall in the enemy line-of-sight mask.
	check(enemy._clear_sight(Vector2(6370,566),Vector2(6550,566)),"the back-wall fixture does not occlude vision")
	check(not enemy._clear_sight(Vector2(6900,700),Vector2(7010,700)),"the room's end wall blocks vision")
	check(not enemy._clear_sight(Vector2(6300,550),Vector2(6300,470)),"the ceiling blocks vision")
	check(lab.zombie_overlay.groups.has("Освещение") and lab.zombie_overlay.zombie_toggles.has("lighting_enabled") and lab.zombie_overlay.rows.has("dark_vision_range"),"the mechanic has its own developer tab, switch and numeric controls")
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(3)
	lab.zombie_overlay.tabs.current_tab = 8
	lab.zombie_overlay.zombie_toggles.lighting_enabled.button_pressed = false
	check(not tuning.lighting_enabled and tuning.lamp_health == 60 and not room.shade.visible,"the live developer switch keeps all numeric parameters")
	check(lab.export_settings_file(directory+"/lighting.json"),"lighting exports through the existing JSON")
	tuning.dark_vision_range = .9
	check(lab.import_settings_file(directory+"/lighting.json") and tuning.dark_vision_range == .4 and not tuning.lighting_enabled,"JSON import restores all lighting values and the toggle")
	var fresh := CoreZombieSettings.new()
	check(fresh.load_saved(lab.zombie_settings_path) == OK and fresh.as_dictionary() == tuning.as_dictionary(),"CFG persists lighting with the existing zombie settings")
	var legacy := ConfigFile.new()
	legacy.set_value("zombie","detection_range",450.0)
	legacy.save(directory+"/legacy.cfg")
	fresh = CoreZombieSettings.new()
	fresh.load_saved(directory+"/legacy.cfg")
	check(fresh.lighting_enabled and fresh.dark_vision_range == .25 and fresh.detection_range == 450,"old CFG receives deliberate lighting defaults")
	var saved := tuning.as_dictionary()
	tuning.apply_values({"lighting_enabled":true,"movement_enabled":false,"hearing_enabled":false,"combat_enabled":false})
	lab._zombie_settings_changed()
	enemy.reset_target()
	enemy.facing = -1
	hero.position = enemy.home-Vector2(260,0)
	enemy.set_physics_process(true)
	await frames(5)
	check(enemy.state == CoreZombie.State.CHASE and enemy.visual_target_known,"the live AI acquires the player in an illuminated room")
	lamp.take_projectile_damage(100)
	await frames(5)
	check(enemy.visual_target_known and enemy.unseen_left > 0 and enemy.unseen_left < tuning.lose_sight_delay,"breaking the lamp preserves and ages legitimate last-seen memory")
	await frames(110)
	check(not enemy.visual_target_known and enemy.state != CoreZombie.State.CHASE,"without fresh sight or sound, the darkened enemy eventually stops tracking")
	hero.position = enemy.position-Vector2(65,0)
	await frames(5)
	check(enemy.state == CoreZombie.State.CHASE and enemy.visual_target_known,"the live AI reacquires a player who enters the dark short-range cone")
	tuning.apply_values(saved)
	lab._zombie_settings_changed()
	lamp.take_projectile_damage(100)
	lab._respawn_enemies()
	check(lamp.broken and enemy.health == enemy.maximum_health(),"F7 respawns enemies and preserves the destroyed lamp")
	lab._recover()
	check(not lamp.broken and lamp.health == 60 and not tuning.lighting_enabled,"F8 repairs the room without changing balance settings")
	var campaign := new_lab(true)
	check(campaign.level.indoor_lighting == null and campaign.level.indoor_zombie == null and campaign.level.enemies.size() == 6 and campaign.level.floors[1].end.x == 5900,"the campaign keeps its old test floor and gets no lighting room or additional enemy")
	campaign.queue_free()
	lab.queue_free()
	await frames(3)
	for path in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(path))
	DirAccess.remove_absolute(directory)
	print("INDOOR LIGHTING: %d/%d passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
