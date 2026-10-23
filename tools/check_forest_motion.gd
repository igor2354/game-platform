extends SceneTree
## Render the accepted effects and corrected foliage at source resolution.
const MEDIA = preload("res://tools/media_paths.gd")
const ART = preload("res://resources/core/moon_forest.png")
const CURRENT = preload("res://shaders/core_moon_forest.gdshader")
var directory: String
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var base := MEDIA.path("docs/moon_forest_preview")
	directory = base.path_join("wood-check")
	DirAccess.make_dir_recursive_absolute(directory)
	var old := Shader.new()
	old.code = FileAccess.get_file_as_string(base.path_join("approved-elements/reference.gdshader"))
	if old.code.is_empty(): push_error("Missing approved reference shader"); quit(1); return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1672,941)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var picture := TextureRect.new()
	picture.texture = ART
	picture.size = Vector2(1672,941)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	viewport.add_child(picture)
	for version in ["before","after"]:
		var mat := ShaderMaterial.new()
		mat.shader = old if version == "before" else CURRENT
		picture.material = mat
		mat.set_shader_parameter("viewport_size",Vector2(1672,941))
		mat.set_shader_parameter("art_top",0.0)
		mat.set_shader_parameter("art_height",941.0)
		for effect in ["wind","clouds","water","fire","smoke"]:
			for key in ["wind","clouds","water","fire","smoke"]:
				mat.set_shader_parameter(key+"_strength",(3.0 if effect == "wind" else 1.0) if effect == key else 0.0)
			for time in [0.0,1.5]:
				mat.set_shader_parameter("animation_time",time)
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				var path := directory.path_join(version+"_"+effect+("_a.png" if time == 0 else "_b.png"))
				var result := viewport.get_texture().get_image().save_png(path)
				if result != OK: push_error("Cannot save "+path); quit(1); return
	viewport.queue_free()
	await process_frame
	print("FOREST MOTION RENDER: ",directory)
	quit()
