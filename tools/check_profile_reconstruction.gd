extends SceneTree
const ART = preload("res://scripts/core/mannequin_art.gd")
const P = preload("res://scripts/core/mannequin_profile.gd")
const T = preload("res://scripts/core/mannequin_textures.gd")
const MEDIA = preload("res://tools/media_paths.gd")
class Figure extends Node2D:
	func _draw() -> void:
		var base := Transform2D(Vector2(1/P.PIXEL,0),Vector2(0,1/P.PIXEL),P.ORIGIN)
		ART.draw_pose(self,ART.pose("bind",0),base,CoreEnemyDummy.PARTS)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var values := ART.pose("bind",0)
	var expected := Transform2D(Vector2(P.PIXEL,0),Vector2(0,P.PIXEL),-P.ORIGIN*P.PIXEL)
	for key in values.parts:
		var part: Dictionary = values.parts[key]
		var actual := Transform2D(part.rotation,part.position)*T.source_transform(key)
		if actual.origin.distance_to(expected.origin) > .0001 or actual.x.distance_to(expected.x) > .0001 or actual.y.distance_to(expected.y) > .0001:
			push_error("FAIL rest transform does not reconstruct source: "+key)
			quit(1)
			return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(125,460)
	viewport.transparent_bg = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(Figure.new())
	await process_frame
	await RenderingServer.frame_post_draw
	var reconstructed := viewport.get_texture().get_image()
	var master := Image.load_from_file(MEDIA.path("docs/core/profile_rebuild_20261101/segments/master.png"))
	var different := 0
	var tested := 0
	var alpha_difference := 0
	for y in 460:
		for x in 125:
			var a := master.get_pixel(x,y)
			var b := reconstructed.get_pixel(x,y)
			if a.a == 0 and b.a == 0: continue
			tested += 1
			if absf(a.a-b.a) > .02: alpha_difference += 1
			if maxf(maxf(absf(a.r-b.r),absf(a.g-b.g)),absf(a.b-b.b)) > .02 or absf(a.a-b.a) > .02: different += 1
	reconstructed.save_png(MEDIA.path("docs/core/profile_rebuild_20261101/reconstructed_1x.png"))
	print("PROFILE REST: transforms=13/13, different=",different,"/",tested," alpha=",alpha_difference)
	var result := {"transform_checks":13,"different_pixels":different,"visible_pixels":tested,"alpha_different_pixels":alpha_difference}
	var file := FileAccess.open(MEDIA.path("docs/core/profile_rebuild_20261101/reconstruction.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	quit(0 if different < tested*.01 else 1)
