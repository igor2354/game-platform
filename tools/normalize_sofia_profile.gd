extends SceneTree
## --apply-user intentionally saves only the migrated movement and camera profiles.
const MEDIA=preload("res://tools/media_paths.gd")
const PATHS=[CoreMovementSettings.SAVE_PATH,CoreCameraSettings.SAVE_PATH,CoreShootingSettings.SAVE_PATH,CoreZombieSettings.SAVE_PATH,CoreRagdollSettings.SAVE_PATH]
var lab:CoreMovementLab
var output:=""
func _initialize() -> void:call_deferred("run")
func frames(n:int) -> void:
	for i in n:await physics_frame;await process_frame
func capture(name:String) -> void:
	await frames(4);await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(output.path_join(name+".png"))
	print("CAPTURE ",error," ",name)
func hashes() -> Dictionary:
	var result:={}
	for p in PATHS:result[p.get_file()]=FileAccess.get_sha256(ProjectSettings.globalize_path(p))
	return result
func write_json(name:String,data:Variant) -> void:
	var f:=FileAccess.open(output.path_join(name+".json"),FileAccess.WRITE);f.store_string(JSON.stringify(data,"\t"));f.close()
func run() -> void:
	var apply:="--apply-user" in OS.get_cmdline_user_args()
	output=MEDIA.path("docs/locations/mvp_village/Проверки/normalized_sofia_2026-10-25")
	var before:=hashes()
	if apply:
		if not FileAccess.file_exists(output.path_join("profiles_before.json")):write_json("profiles_before",before)
		for p in PATHS.slice(0,2):
			var backup:=output.path_join(p.get_file().get_basename()+"_before.cfg")
			if not FileAccess.file_exists(backup):
				if DirAccess.copy_absolute(ProjectSettings.globalize_path(p),backup)!=OK:push_error("Backup failed");quit(1);return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1600,900));root.size=Vector2i(1600,900)
	lab=load("res://scenes/campaign/prologue_v2.tscn").instantiate();lab.load_user_settings=apply or "--capture-user" in OS.get_cmdline_user_args()
	if not apply:
		var isolated:=OS.get_environment("TEMP").path_join("normalize-ui-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(isolated)
		for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:lab.set(key,isolated.path_join(key+".cfg"))
	lab.get_node("World/Player").character_id="sofia";lab.get_node("World/Player").sofia_cel_variant=true
	root.add_child(lab);await frames(12)
	preload("res://scripts/campaign/catalog.gd").equip(lab.player.weapon,"stg44");lab.player.weapon.tuning.sound_enabled=false
	if apply:
		if "--from-original-backup" in OS.get_cmdline_user_args():
			var approved_after:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output.path_join("profiles_after.json")))
			if hashes()!=approved_after:push_error("Profiles changed since this migration; preserve user edits");quit(1);return
			if lab.player.tuning.load_saved(output.path_join("core_movement_before.cfg"))!=OK:quit(1);return
			lab.movement_overlay._sync();lab._player_settings_changed()
		lab.movement_overlay.save_button.pressed.emit();lab.camera_overlay.save_button.pressed.emit()
		write_json("profiles_after",hashes())
		for p in PATHS.slice(2):
			if before[p.get_file()]!=FileAccess.get_sha256(ProjectSettings.globalize_path(p)):push_error("Unrelated profile modified");quit(1);return
	lab.camera_settings.noir_enabled=false;lab.camera_settings.pixel_enabled=false;lab.camera_settings.world_pixel_enabled=false;lab.camera_settings.stable_pixel_enabled=false;lab._camera_settings_changed()
	lab.player.weapon.aim_override=lab.player.position+Vector2(1000,-100)
	lab.developer_mode.set_enabled(true);lab.developer_mode.show_overlay(2)
	lab.camera_overlay.tabs.current_tab=lab.camera_overlay.groups.find("Размер героя")
	await capture("scale_1_00")
	lab.developer_mode.show_overlay(0);lab.movement_overlay.tabs.current_tab=lab.movement_overlay.groups.find("Бег")
	await capture("movement_world_units")
	lab.movement_overlay.tabs.current_tab=lab.movement_overlay.groups.find("Приседание")
	await capture("crouch_world_units")
	lab.developer_mode.set_enabled(false);await capture("hud_world_metrics")
	lab._toggle_level_map();await capture("map_metric_axes");lab._toggle_level_map()
	var result:={"applied_scale":lab.player.character_scale(),"world_height":lab.player.world_height(),"world_width":lab.player.world_radius()*2,"run_world_speed":lab.player.motion_value("run_speed"),"gravity_world":lab.player.motion_value("gravity"),"world_units_per_meter":CoreWorldUnits.UNITS_PER_METER,"telemetry":lab.telemetry.text,"movement":lab.player.tuning.as_dictionary(),"camera":lab.camera_settings.as_dictionary(),"apply_user":apply}
	write_json("normalized_profile_report",result)
	print("NORMALIZE PROFILE: scale=",lab.player.character_scale()," height=",lab.player.world_height()," speed=",lab.player.motion_value("run_speed")," apply_user=",apply)
	lab.queue_free();await frames(3);quit()
