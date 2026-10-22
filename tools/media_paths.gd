extends RefCounted
## Development outputs live outside res://. Runtime assets are promoted separately.
static func path(logical_path: String) -> String:
	var project_root := ProjectSettings.globalize_path("res://").trim_suffix("/").replace("\\","/")
	var library_root := OS.get_environment("UBERSHRIKE_MEDIA_ROOT").replace("\\","/")
	if library_root.is_empty():
		library_root = project_root.get_base_dir().get_base_dir().get_base_dir()
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/media_paths.json"))
	var chosen := ""
	for prefix in rules:
		if (logical_path == prefix or logical_path.begins_with(prefix+"/")) and prefix.length() > chosen.length():
			chosen = prefix
	if chosen.is_empty():
		push_error("No external media destination for "+logical_path)
		return ""
	var output := library_root.path_join(str(rules[chosen])+logical_path.substr(chosen.length())).simplify_path()
	var root_prefix := library_root.simplify_path().trim_suffix("/")+"/"
	if not output.begins_with(root_prefix) or output.begins_with(project_root+"/"):
		push_error("Media destination must be outside the game project: "+output)
		return ""
	var directory := output if output.get_extension().is_empty() else output.get_base_dir()
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		push_error("Cannot create media directory: "+directory)
		return ""
	return output
