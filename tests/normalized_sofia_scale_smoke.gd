extends SceneTree
const SETTINGS_FILE = preload("res://scripts/core/settings_file.gd")
var checks := 0
var failures := 0
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var directory := ""
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;push_error("FAIL "+label)
func close(a: float,b: float) -> bool: return absf(a-b)<.001
func same_values(a: Dictionary,b: Dictionary) -> bool:
	if a.size()!=b.size():return false
	for key in a:
		if not b.has(key):return false
		if (a[key] is float or a[key] is int) and (b[key] is float or b[key] is int):
			if absf(float(a[key])-float(b[key]))>.000001:return false
		elif a[key]!=b[key]:return false
	return true

func run() -> void:
	directory=OS.get_environment("TEMP").path_join("normalized-sofia-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(directory)
	var legacy:=ConfigFile.new()
	legacy.set_value("camera","player_scale_enabled",true);legacy.set_value("camera","player_scale",2.85)
	legacy.set_value("camera","zoom",2.25);legacy.set_value("camera","offset_y",-278)
	legacy.save(directory.path_join("camera.cfg"))
	var camera:=CoreCameraSettings.new()
	check(camera.load_saved(directory.path_join("camera.cfg"))==OK and close(camera.player_scale,1),"old CFG 2.85 becomes normalized 1.00")
	check(close(camera.zoom,2.25) and close(camera.offset_y,-278),"camera framing is not rebased")
	camera.save_saved(directory.path_join("camera_v2.cfg"))
	var again:=CoreCameraSettings.new();again.load_saved(directory.path_join("camera_v2.cfg"))
	check(again.as_dictionary()==camera.as_dictionary(),"new camera CFG is idempotent")
	var movement:=ConfigFile.new()
	var old_values:={"run_speed":115.0,"slow_walk_speed":45.0,"sprint_speed":195.0,"jump_speed":120.0,"jump_cut_speed":50.0,"gravity":350.0,"crouch_height":44.0,"slide_height":32.0,"push_hand_height":40.0,"push_hand_spacing":8.0,"sprint_duration":3.0,"parkour_mantle_time":.7,"parkour_vault_time":.45,"sprint_auto_max_width":96.0}
	for key in old_values:movement.set_value("movement",key,old_values[key])
	movement.save(directory.path_join("movement.cfg"))
	var tuning:=CoreMovementSettings.new()
	check(tuning.load_saved(directory.path_join("movement.cfg"))==OK,"legacy movement CFG loads")
	for key in old_values:
		check(close(tuning.get(key),old_values[key]*(1 if key=="sprint_duration" else 1.0/2.85 if key in CoreMovementSettings.RIG_DURATION_KEYS else 2.85)),"legacy world conversion "+key)
	tuning.save_saved(directory.path_join("movement_v2.cfg"))
	var tuning_again:=CoreMovementSettings.new();tuning_again.load_saved(directory.path_join("movement_v2.cfg"))
	check(same_values(tuning_again.as_dictionary(),tuning.as_dictionary()),"new movement CFG does not multiply values a second time")
	lab=load("res://scenes/campaign/prologue_v2.tscn").instantiate();lab.load_user_settings=false
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:lab.set(key,directory.path_join("live_"+key+".cfg"))
	lab.get_node("World/Player").character_id="sofia";lab.get_node("World/Player").sofia_cel_variant=true
	root.add_child(lab);await frames(12);hero=lab.player
	preload("res://scripts/campaign/catalog.gd").equip(hero.weapon,"stg44");hero.weapon.tuning.sound_enabled=false
	check(close(lab.camera_settings.player_scale,1) and close(hero.character_scale(),1),"ver2 and applied Sofia both expose new 1.00")
	check(close(hero.world_height(),182.4) and close(hero.world_radius()*2,79.8),"standing world capsule is unchanged")
	check(close(hero.body_scale,2.85) and hero.scale.is_equal_approx(Vector2.ONE*2.85),"original sprite and rig transform stays physically unchanged")
	check(close(hero.motion_value("run_speed"),327.75) and close(hero.motion_value("gravity"),997.5),"rebased movement preserves world speed and gravity")
	check(close(hero.tuning.crouch_height,125.4) and close(hero.tuning.local_value("crouch_height"),44),"world crouch dimension converts to unchanged rig capsule")
	var bounds:=lab.level.campaign_bounds();var zoom:=lab.camera_settings.zoom;var framing:=lab.camera_settings.framing_values()
	lab.camera_settings.player_scale_enabled=true;lab.camera_settings.player_scale=1.2;lab._camera_settings_changed();await frames(3)
	check(close(hero.character_scale(),1.2) and close(hero.world_height(),218.88),"new 1.20 scales the approved baseline uniformly")
	check(close(hero.motion_value("run_speed"),393.3),"new scale multiplies velocity once")
	check(lab.level.campaign_bounds()==bounds and lab.camera_settings.framing_values()==framing and lab.camera_settings.zoom==zoom,"level and camera settings remain unchanged")
	lab.camera_settings.player_scale_enabled=false;lab._camera_settings_changed();await frames(3)
	check(close(hero.character_scale(),1) and close(lab.camera_settings.player_scale,1.2),"disable returns to new baseline and retains slider value")
	check(lab.telemetry.text.contains("Размер: 1.00") and lab.telemetry.text.contains("км/ч") and lab.telemetry.text.contains("м/с²") and lab.telemetry.text.contains("Капсула"),"HUD presents normalized size and dimensional metrics")
	lab.camera_settings.player_scale=1;lab.camera_settings.player_scale_enabled=true;lab._camera_settings_changed()
	var ceiling:=StaticBody2D.new();ceiling.collision_layer=1
	var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(400,10)
	shape.shape=box;shape.position=hero.position-Vector2(0,190);ceiling.add_child(shape);lab.add_child(ceiling);await frames(2)
	hero.request_character_scale(1.2);await frames(2)
	check(close(hero.character_scale(),1) and close(hero.requested_body_scale/hero.reference_body_scale(),1.2),"unsafe growth waits under ceiling in normalized units")
	hero.request_character_scale(1);ceiling.queue_free();await frames(2)
	var exports:=directory.path_join("profile.json")
	check(lab.export_settings_file(exports),"current JSON exports")
	var original:=lab.player.tuning.as_dictionary().duplicate();var original_camera:=lab.camera_settings.as_dictionary().duplicate()
	var imported:=lab.import_settings_file(exports)
	check(imported and same_values(lab.player.tuning.as_dictionary(),original) and lab.camera_settings.as_dictionary()==original_camera,"new JSON roundtrip preserves normalized world values")
	check(lab.import_settings_file(exports) and same_values(lab.player.tuning.as_dictionary(),original),"repeated JSON import cannot rebase twice")
	var old_json:={"format":"dead-platform-settings","version":1,"movement":old_values,"shooting":{},"camera":{"player_scale_enabled":true,"player_scale":2.85,"zoom":2.25}}
	var f:=FileAccess.open(directory.path_join("legacy.json"),FileAccess.WRITE);f.store_string(JSON.stringify(old_json));f.close()
	check(lab.import_settings_file(directory.path_join("legacy.json")) and close(hero.character_scale(),1) and close(hero.tuning.run_speed,327.75),"legacy JSON migrates camera and movement atomically")
	check(close(hero.world_height(),182.4) and close(lab.camera_settings.zoom,2.25),"legacy import preserves physical Sofia and requested camera framing")
	old_json.camera.scale_basis_version=99
	f=FileAccess.open(directory.path_join("future.json"),FileAccess.WRITE);f.store_string(JSON.stringify(old_json));f.close()
	var before:=hero.tuning.as_dictionary().duplicate()
	check(not lab.import_settings_file(directory.path_join("future.json")) and before==hero.tuning.as_dictionary(),"unknown basis rejected without partial mutation")
	lab.queue_free();await frames(3);print("NORMALIZED SOFIA: %d/%d"%[checks-failures,checks]);quit(1 if failures else 0)
