extends SceneTree
## Format conversion only: source pixels are packed/resized as complete frames.
## No body pieces are rotated, composited or painted by this importer.
const ART = preload("res://scripts/core/concept_zombie_art.gd")
const PARTS := ["head","torso","left_arm","right_arm","left_leg","right_leg"]
const CELL := 256
const ANCHOR := Vector2(128,224)
var failures := 0
func _initialize() -> void: call_deferred("run")
func row_bands(image: Image) -> Array[Vector2i]:
	# Painted horizontal poses occupy less height than standing poses. The
	# source keeps four rows, but their vertical spacing need not be uniform.
	var result: Array[Vector2i] = []
	var start := -1
	var last := -1
	for y in image.get_height():
		var pixels := 0
		for x in image.get_width():
			if image.get_pixel(x,y).a > .15: pixels += 1
		if pixels >= 8:
			if start < 0: start = y
			last = y
		elif start >= 0 and y-last > 0:
			if last-start > 12: result.append(Vector2i(start,last+1))
			start = -1
	if start >= 0 and last-start > 12: result.append(Vector2i(start,last+1))
	return result
func guide(clip: String,frame: int) -> Dictionary:
	# Non-rendered landmarks used to label pixels for damage/dismemberment.
	# They never generate or deform an animation frame.
	var t := float(frame)/15
	var wave := sin(t*TAU)
	var standing := {"head":[Vector2(5,-59),Vector2(5,-54),5.5],"torso":[Vector2(0,-49),Vector2(-2,-26),7.0],
		"left_arm":[Vector2(8,-49),Vector2(13,-28),3.3],"right_arm":[Vector2(-5,-48),Vector2(-6,-25),3.8],
		"left_leg":[Vector2(1,-25),Vector2(12,-2),4.0],"right_leg":[Vector2(-4,-25),Vector2(-10,-2),4.0]}
	if clip in ["patrol","chase"]:
		standing.right_arm[1].x += wave*4
		standing.left_arm[1].x -= wave*4
		standing.right_leg[1].x = -wave*11
		standing.left_leg[1].x = wave*11
	if clip in ["windup","strike","recover"]:
		var reach := smoothstep(.6,1,t) if clip == "windup" else 1.0 if clip == "strike" else 1-smoothstep(0,1,t)
		for side in ["left_arm","right_arm"]:
			standing[side][1] = standing[side][1].lerp(Vector2(33,-45),reach)
			standing[side][0].x += reach*4
		standing.head[0].x += reach*5
		standing.head[1].x += reach*5
	var prone := {"head":[Vector2(26,-14),Vector2(26,-9),5.5],"torso":[Vector2(17,-12),Vector2(-8,-10),7.0],
		"left_arm":[Vector2(18,-15),Vector2(29,-4),3.2],"right_arm":[Vector2(12,-13),Vector2(23+wave*2,-3),3.8],
		"left_leg":[Vector2(-8,-11),Vector2(-31,-4),3.4],"right_leg":[Vector2(-9,-6),Vector2(-29,-2),3.8]}
	if clip.begins_with("crawl_"):
		var reach := smoothstep(.6,1,t) if clip.ends_with("windup") else 1.0 if clip.ends_with("strike") else 1-smoothstep(0,1,t) if clip.ends_with("recover") else 0.0
		prone.right_arm[1] += Vector2(reach*10,-reach*3)
	if clip == "shove": prone.right_arm[1] += Vector2(-6,-sin(t*PI)*23)
	var amount := 1.0 if clip in ["crawl","prone_idle","shove","prone_death","prone_stunned"] or clip.begins_with("crawl_") else 0.0
	if clip in ["fall","death"]: amount = smoothstep(0,1,t)
	if clip == "get_up": amount = 1-smoothstep(0,1,t)
	var result := {}
	for part in PARTS:
		result[part] = [standing[part][0].lerp(prone[part][0],amount),standing[part][1].lerp(prone[part][1],amount),lerpf(standing[part][2],prone[part][2],amount)]
	return result
func label(point: Vector2,landmarks: Dictionary) -> int:
	var best := INF
	var result := 2
	var head: Array = landmarks.head
	var head_axis: Vector2 = (head[0]-landmarks.torso[0]).normalized()
	var separator: Vector2 = head[0]-head_axis*7
	if (point-separator).dot(head_axis) > 0 and point.distance_to(head[0]) < 12:
		return 1
	for index in PARTS.size():
		var p: Array = landmarks[PARTS[index]]
		var closest := Geometry2D.get_closest_point_to_segment(point,p[0],p[1])
		var distance: float = point.distance_to(closest)/p[2]
		if distance < best:
			best = distance
			result = index+1
	return result
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://resources/core/concept_zombie/frames")
	var metadata := {}
	for clip in ART.CLIPS:
		var source_path: String = "res://resources/core/concept_zombie/frame_sources/"+clip+".png"
		var source := Image.load_from_file(ProjectSettings.globalize_path(source_path))
		if not source or source.is_empty():
			push_error("Missing whole-frame source: "+clip)
			failures += 1
			continue
		if source.get_width() != source.get_height() or source.get_pixel(0,0).a > .01:
			push_error("Expected transparent square 4x4 source: "+clip)
			failures += 1
			continue
		var images: Array[Image] = []
		var bounds: Array[Rect2i] = []
		var rows := row_bands(source)
		if rows.size() != 4:
			push_error("Expected four distinct transparent sprite rows: %s, got %d" % [clip,rows.size()])
			failures += 1
			continue
		var max_height := 0
		var max_width := 0
		for frame in 16:
			var first := Vector2i(frame%4*source.get_width()/4,maxi(0,rows[frame/4].x-2))
			var last := Vector2i((frame%4+1)*source.get_width()/4,mini(source.get_height(),rows[frame/4].y+2))
			var image := source.get_region(Rect2i(first,last-first))
			var used := image.get_used_rect()
			images.append(image)
			bounds.append(used)
			max_height = maxi(max_height,used.size.y)
			max_width = maxi(max_width,used.size.x)
		var low: bool = clip.begins_with("crawl") or clip in ["prone_idle","prone_death","prone_stunned","shove"]
		var factor := minf(192.0/max_height,228.0/max_width)
		if low: factor = minf(180.0/max_width,110.0/max_height)
		if clip == "airborne": factor = minf(165.0/max_height,220.0/max_width)
		var atlas := Image.create(CELL*4,CELL*4,false,Image.FORMAT_RGBA8)
		var mask := Image.create(CELL*4,CELL*4,false,Image.FORMAT_RGBA8)
		metadata[clip] = []
		for frame in 16:
			var used := bounds[frame]
			if not used.has_area():
				push_error("Empty painted frame %s:%d" % [clip,frame])
				failures += 1
				continue
			var crop := images[frame].get_region(used)
			crop.resize(maxi(1,roundi(used.size.x*factor)),maxi(1,roundi(used.size.y*factor)),Image.INTERPOLATE_LANCZOS)
			var resized_bounds := crop.get_used_rect()
			crop = crop.get_region(resized_bounds)
			var x := roundi(ANCHOR.x+(used.position.x-images[frame].get_width()*.5)*factor)+resized_bounds.position.x
			var destination := Vector2i(clampi(x,2,CELL-crop.get_width()-2),224-crop.get_height())
			var origin := Vector2i(frame%4,frame/4)*CELL
			atlas.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),origin+destination)
			var boxes := {}
			var landmarks := guide(clip,frame)
			for y in range(destination.y,destination.y+crop.get_height()):
				for px in range(destination.x,destination.x+crop.get_width()):
					if atlas.get_pixelv(origin+Vector2i(px,y)).a <= 0: continue
					var point := (Vector2(px,y)-ANCHOR)/3.0
					var index := label(point,landmarks)
					mask.set_pixelv(origin+Vector2i(px,y),Color(float(index)/255,0,0,1))
					# Soft fringe/dust still gets masked, but cannot enlarge a
					# damage rectangle over another anatomical region.
					if atlas.get_pixelv(origin+Vector2i(px,y)).a < .15: continue
					var part: String = PARTS[index-1]
					var pixel := Rect2(point,Vector2.ONE/3)
					boxes[part] = boxes[part].merge(pixel) if boxes.has(part) else pixel
			var record := {}
			for part in PARTS:
				var rect: Rect2 = boxes.get(part,Rect2(landmarks[part][0]-Vector2.ONE,Vector2.ONE*2))
				record[part] = [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
			metadata[clip].append(record)
		atlas.save_png("res://resources/core/concept_zombie/frames/"+clip+".png")
		mask.save_png("res://resources/core/concept_zombie/frames/"+clip+"_mask.png")
		print("PACKED ",clip," 16 complete painted frames")
	var data := preload("res://scripts/core/concept_zombie_frame_data.gd").new()
	data.clips = metadata
	ResourceSaver.save(data,"res://resources/core/concept_zombie/frames/anatomy.tres")
	print("WHOLE FRAME IMPORT: ",metadata.size(),"/",ART.CLIPS.size()," clips, errors ",failures)
	quit(0 if failures == 0 else 1)
