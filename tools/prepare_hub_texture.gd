extends SceneTree
func _initialize() -> void:
	var source := ProjectSettings.globalize_path("res://../../../2_Локации/Концепты локаций/ХАБ/Кандидаты/ХАБ_Мрачные_2D_2026-10-31/Железнодорожное убежище — реконструкция 8K.png")
	var picture:=Image.load_from_file(source)
	if not picture or picture.get_size()!=Vector2i(7680,2560): push_error("Unexpected hub source");quit(1);return
	DirAccess.make_dir_recursive_absolute("res://resources/campaign/hub_8k")
	var out:=preload("res://tools/media_paths.gd").path("docs/core/hub_visual_20261101")
	DirAccess.make_dir_recursive_absolute(out.path_join("runtime_tiles"))
	var approved: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tools/runtime_media.json"))
	for i in 8:
		var left:=maxi(0,i*960-2);var right:=mini(7680,(i+1)*960+2)
		var relative:="resources/campaign/hub_8k/tile_%02d.png"%i
		if relative not in approved: push_error("Hub derivative is not approved for runtime");quit(1);return
		var prepared:=out.path_join("runtime_tiles/tile_%02d.png"%i)
		var error:=picture.get_region(Rect2i(left,0,right-left,2560)).save_png(prepared)
		if error!=OK: push_error("Cannot save hub tile");quit(1);return
		if DirAccess.copy_absolute(prepared,ProjectSettings.globalize_path("res://"+relative))!=OK: push_error("Cannot install approved derivative");quit(1);return
	picture.get_region(Rect2i(2288,900,600,1237)).save_png(out.path_join("source_stair_inspection.png"))
	print("HUB TEXTURES: 8 exact source tiles, 2px gutters, no resampling")
	quit()
