extends SceneTree
## Export the actual runtime contour; no scene or tuning mutation.
const V2=preload("res://scripts/campaign/forest_prologue_v2.gd")
func xy(p:Vector2) -> Array:return [(p.x-V2.ORIGIN.x)/V2.UPM,(V2.ORIGIN.y-p.y)/V2.UPM]
func rect(r:Rect2) -> Array:return [xy(r.position)[0],xy(r.position)[1],r.size.x/V2.UPM,r.size.y/V2.UPM]
func _initialize() -> void:
	var f:=V2.new()
	var result:={"units_per_meter":V2.UPM,"world_origin":[V2.ORIGIN.x,V2.ORIGIN.y],"length_m":484,"top_m":16,"bottom_m":-12,"pixels_per_meter":80,"geometry_sha256":FileAccess.get_sha256("res://scripts/campaign/forest_prologue_v2.gd"),"sections":[],"terrain":[],"surfaces":[],"platforms":[],"obstacles":[],"ladders":[],"features":{}}
	for s in f.sections:result.sections.append({"id":s.id,"title":s.label,"start":s.start_m,"length":s.width_m})
	for polygon in f.terrain:
		var points:=[]
		for p in polygon:points.append(xy(p))
		result.terrain.append(points)
	for surface in f.surfaces:
		var points:=[]
		for p in surface:points.append(xy(p))
		result.surfaces.append(points)
	for source in f.platforms:
		for r in preload("res://scripts/core/platform_surfaces.gd").split(source,f.ladders):result.platforms.append(rect(r))
	for r in f.obstacles:result.obstacles.append(rect(r))
	for r in f.ladders:result.ladders.append(rect(r))
	for key in f.features:result.features[key]=rect(f.features[key])
	var output:=preload("res://tools/media_paths.gd").path("docs/locations/mvp_village/Кандидаты/prologue_v2_visual_2026-10-25/Подготовка/layout.json")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));f.free()
	print("ART LAYOUT ",output);quit()
