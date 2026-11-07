extends SceneTree
## Deterministic segmentation requested by the user; no generated replacement art.
const P = preload("res://scripts/core/mannequin_profile.gd")
const MEDIA = preload("res://tools/media_paths.gd")
const KEYS := ["head","torso","pelvis","left_upper_arm","left_forearm","left_thigh","left_shin","left_foot"]
var source: Image
var master: Image
var images: Dictionary = {}
var far_hand: Image
var hidden_cloth: Image
func inside(point: Vector2,polygon: Array) -> bool:
	return Geometry2D.is_point_in_polygon(point,PackedVector2Array(polygon))
func foreground(point: Vector2) -> bool:
	if not inside(point,P.OUTLINE): return false
	var color := source.get_pixelv(Vector2i(point))
	var background := source.get_pixel(124,int(point.y))
	var distance := Vector3(color.r-background.r,color.g-background.g,color.b-background.b).length()
	if distance >= .085: return true
	# Remove only background-colored pixels along the traced outside edge.
	for i in P.OUTLINE.size():
		var closest := Geometry2D.get_closest_point_to_segment(point,P.OUTLINE[i],P.OUTLINE[(i+1)%P.OUTLINE.size()])
		if point.distance_to(closest) < 2.0: return false
	return true
func owner(point: Vector2) -> String:
	if point.y < 73 and point.x > 56: return "head"
	if inside(point,P.HAND) or (point.x > 72 and point.y > 234 and point.y < 273): return "left_forearm"
	if inside(point,P.FOREARM): return "left_forearm"
	if inside(point,P.ARM): return "left_upper_arm"
	if point.y < 198: return "torso"
	if point.y < 234: return "pelvis"
	if point.y < 323: return "left_thigh"
	if point.y < 411: return "left_shin"
	return "left_foot"
func hidden_color(x: int,y: int,body_key: String) -> Color:
	# Only hidden albedo is borrowed; its old silhouette/pivots are NEVER used.
	# Sample rib-side cloth, away from the old shoulder and chest protrusion.
	if hidden_cloth != null and body_key == "torso":
		var u := clampf(float(x-24)/50,0,1)
		var v := clampf(float(y-75)/123,0,1)
		var color := hidden_cloth.get_pixel(int(lerpf(515,575,u)),int(lerpf(150,805,v)))
		color.a = 1
		return color
	if body_key == "left_thigh":
		return source.get_pixel(int(lerpf(31,40,clampf(float(x-24)/43,0,1))),y)
	var color := Color(0,0,0,0)
	var count := 0
	for dy in range(-7,8):
		for sample_x in (range(67,75) if body_key != "left_thigh" else range(31,41)):
			var sample_y := clampi(y+dy,0,459)
			var point := Vector2(sample_x+.5,sample_y+.5)
			if not inside(point,P.OUTLINE) or owner(point) != body_key: continue
			color += source.get_pixel(sample_x,sample_y)
			count += 1
	if count == 0: return source.get_pixel(70 if body_key != "left_thigh" else 36,y)
	color /= count
	color *= lerpf(.88,1.0,clampf(float(x-24)/50,0,1))
	color.a = 1
	return color
func _initialize() -> void:
	var folder := ProjectSettings.globalize_path("res://../../../6_Концепты геймплея/АНИМАЦИЯ/Для анимации/Кандидаты/Зомби_мужчина_01_Подготовка_2026-11-01/")
	source = Image.load_from_file(folder+"00_source_sheet.png").get_region(Rect2i(320,5,125,460))
	hidden_cloth = Image.load_from_file(folder+"04_profile_body_v2.png")
	master = Image.create(125,460,false,Image.FORMAT_RGBA8)
	far_hand = Image.create(125,460,false,Image.FORMAT_RGBA8)
	for key in KEYS: images[key] = Image.create(125,460,false,Image.FORMAT_RGBA8)
	for y in 460:
		for x in 125:
			var point := Vector2(x+.5,y+.5)
			if not foreground(point): continue
			var color := source.get_pixel(x,y)
			master.set_pixel(x,y,color)
			if x >= 75 and y >= 238 and y < 270:
				far_hand.set_pixel(x,y,color)
				continue
			images[owner(point)].set_pixel(x,y,color)
	# Reconstruct only hidden clothing surfaces, inside the original silhouette.
	# These pixels are covered by their original owners in the rest pose.
	for y in 411:
		for x in 125:
			if master.get_pixel(x,y).a == 0: continue
			var point := Vector2(x+.5,y+.5)
			var key := owner(point)
			if key not in ["left_upper_arm","left_forearm"]: continue
			var body_key := "torso" if y < 198 else "pelvis" if y < 234 else "left_thigh"
			# Never grow the body outside its natural side-profile contour.
			if y < 78 or x < 24 or x > (74 if y < 234 else 67): continue
			var color := hidden_color(x,y,body_key)
			images[body_key].set_pixel(x,y,color)
	# Small joint caps reuse the very same source pixels. No second muscles/cuffs.
	for pair in [["torso","left_upper_arm",P.SHOULDER,10.0],["left_upper_arm","left_forearm",P.ELBOW,8.0],["pelvis","left_thigh",P.HIP,12.0],["left_thigh","left_shin",P.KNEE,10.0],["left_shin","left_foot",P.ANKLE,7.0]]:
		for y in 460:
			for x in 125:
				if Vector2(x,y).distance_to(pair[2]) > pair[3] or master.get_pixel(x,y).a == 0: continue
				for key in [pair[0],pair[1]]: images[key].set_pixel(x,y,master.get_pixel(x,y))
	# Hidden far limbs inherit the same projected anatomy, never another camera view.
	for suffix in ["upper_arm","forearm","thigh","shin","foot"]:
		images["right_"+suffix] = images["left_"+suffix].duplicate()
	# Reconstruct the hidden far palm from this SAME view, preserving the small
	# visible far-finger patch from the reference. No doubled hands in one piece.
	for y in 460:
		for x in 125:
			if y >= 231: images.right_forearm.set_pixel(x,y,Color.TRANSPARENT)
	for y in range(231,276):
		for x in range(44,76):
			var target := Vector2i(x+13,y-3)
			if master.get_pixelv(target).a == 0: continue
			var color: Color = images.left_forearm.get_pixel(x,y)
			if color.a > 0: images.right_forearm.set_pixelv(target,color)
	for y in 460:
		for x in 125:
			if far_hand.get_pixel(x,y).a > 0: images.right_forearm.set_pixel(x,y,far_hand.get_pixel(x,y))
	var output := MEDIA.path("docs/core/profile_rebuild_20261101/segments/")
	DirAccess.make_dir_recursive_absolute(output)
	master.save_png(output.path_join("master.png"))
	for key in images: images[key].save_png(output.path_join(key+".png"))
	var bounds := {}
	for key in images:
		var rect: Rect2i = images[key].get_used_rect()
		bounds[key] = [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
	var file := FileAccess.open(output.path_join("bounds.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(bounds,"\t"))
	print("PREPARED ",output)
	quit()
