extends SceneTree
## Explicit repair tool. Dry-run by default; --apply writes the five real profiles.
const SETTINGS_FILE = preload("res://scripts/core/settings_file.gd")
func _initialize() -> void: call_deferred("restore")
func restore() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Provide the previously exported JSON path; optional --apply.")
		quit(1)
		return
	var source_path: String = args[0]
	var resources := {"movement":CoreMovementSettings.new(),"shooting":CoreShootingSettings.new(),"camera":CoreCameraSettings.new(),"zombie":CoreZombieSettings.new(),"ragdoll":CoreRagdollSettings.new()}
	var result := SETTINGS_FILE.read_file(source_path,resources)
	if result.has("error"):
		push_error(str(result.error))
		quit(1)
		return
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	var checked := 0
	for section in resources:
		resources[section].apply_values(result.values[section])
		var actual: Dictionary = resources[section].as_dictionary()
		for key in source.get(section,{}):
			if not actual.has(key): continue
			var expected: Variant = source[section][key]
			var equal: bool = actual[key] == expected if expected is bool else is_equal_approx(float(actual[key]),float(expected))
			if not equal:
				push_error("Export value would change: "+section+"."+key)
				quit(1)
				return
			checked += 1
	print("RESTORE VALIDATED: ",checked," supplied values; five sections; missing new fields use defaults.")
	if "--apply" not in args:
		quit()
		return
	var temporary := OS.get_environment("TEMP") if OS.has_feature("windows") else "/private/tmp"
	var backup := temporary.path_join("dead-platform-profile-repair-%d" % Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(backup)
	var paths := {"movement":CoreMovementSettings.SAVE_PATH,"shooting":CoreShootingSettings.SAVE_PATH,"camera":CoreCameraSettings.SAVE_PATH,"zombie":CoreZombieSettings.SAVE_PATH,"ragdoll":CoreRagdollSettings.SAVE_PATH}
	for section in paths:
		var path: String = paths[section]
		if FileAccess.file_exists(path):
			var error := DirAccess.copy_absolute(ProjectSettings.globalize_path(path),backup.path_join(path.get_file()))
			if error != OK:
				push_error("Could not retain pre-repair profile: "+section)
				quit(1)
				return
	for section in paths:
		if resources[section].save_saved(paths[section]) != OK:
			push_error("Could not restore profile: "+section)
			quit(1)
			return
		var loaded: Resource = resources[section].duplicate()
		if loaded.load_saved(paths[section]) != OK:
			push_error("Could not reread restored profile: "+section)
			quit(1)
			return
		var reread: Dictionary = loaded.as_dictionary()
		for key in source.get(section,{}):
			if not reread.has(key): continue
			var expected: Variant = source[section][key]
			var equal: bool = reread[key] == expected if expected is bool else is_equal_approx(float(reread[key]),float(expected))
			if not equal:
				push_error("Saved verification failed: "+section+"."+key)
				quit(1)
				return
		print("RESTORED AND VERIFIED: ",section," -> ",ProjectSettings.globalize_path(paths[section]))
	var receipt := {"source":source_path,"verified_supplied_values":checked,"pre_repair_backup":backup,"restored_paths":paths,"missing_fields":"current defaults"}
	var file := FileAccess.open(backup.path_join("receipt.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"\t"))
	file.close()
	print("RESTORE COMPLETE: ",checked," supplied values matched after saving. Receipt: ",backup.path_join("receipt.json"))
	quit()
