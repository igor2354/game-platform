extends "res://walk_math.gd"
## External authoring only. Reuses angle math; never changes the game model.
var baseline := 680.0
var root_base := 680.0
var root_bob: Array[float]=[]

func _ready() -> void:
	assert(ProjectSettings.get_setting("application/config/name")=="Бег — внешняя проба")
	data=JSON.parse_string(FileAccess.get_file_as_string("res://run_keys.json"))
	actor=MODEL.instantiate()
	actor.position=Vector2(600,baseline)
	actor.scale=Vector2.ONE*6
	add_child(actor)
	for bone: Bone2D in actor.find_children("*","Bone2D",true,false):
		bones[str(bone.name)]=bone
		rests[str(bone.name)]=bone.rest
		original_lengths[str(bone.name)]=bone.position.length()
	for poly: Polygon2D in actor.find_children("*","Polygon2D",true,false):
		poly.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		for side in ["Near","Far"]:
			var path: NodePath=actor.get_node("Rig").get_path_to(bones[side+"Ankle"])
			for index in poly.get_bone_count():
				if poly.get_bone_path(index)!=path:continue
				var points: PackedVector2Array=soles.get(side,PackedVector2Array())
				var img := poly.texture.get_image()
				var factor: float=(poly.polygon[1].x-poly.polygon[0].x)/(poly.uv[1].x-poly.uv[0].x)
				var origin: Vector2=poly.polygon[0]-poly.uv[0]*factor
				var ankle_y: float=actor.to_local(bones[side+"Ankle"].global_position).y
				for x in img.get_width():
					for y in range(img.get_height()-1,-1,-1):
						if img.get_pixel(x,y).a<.5:continue
						var point := origin+Vector2(x+.5,y+.5)*factor
						if point.y>ankle_y:points.append(bones[side+"Ankle"].to_local(actor.to_global(point)))
						break
				soles[side]=points
	for i in 8:
		keys.append(make_key(i))
		root_bob.append((float(data.keys[i].pelvis[1])-float(data.keys[2].pelvis[1]))*.07)
	pose(.25)
	root_base=baseline+baseline-maxf(foot_bottom("Near"),foot_bottom("Far"))
	if "--capture" in OS.get_cmdline_user_args():
		capturing=true
		await capture()

func make_key(index: int) -> Dictionary:
	var source: Dictionary=data.keys[index]
	var result := super.make_key(index)
	var pelvis := angle(source.pelvis,source.chest)-(rest_world("Spine").origin-rest_world("Pelvis").origin).angle()
	var delta: float=pelvis-result.Pelvis
	result.Pelvis=pelvis
	result.Spine-=delta
	for side in ["Near","Far"]:result[side+"Hip"]-=delta
	return result

func pose(phase: float) -> void:
	for name in bones:bones[name].transform=rests[name]
	var p := fposmod(phase,1)*8
	var i := floori(p)
	var u := p-i
	for name in keys[0]:bones[name].rotation=lerp_angle(keys[i][name],keys[(i+1)%8][name],u)
	# Root curve follows the user's pelvis marks, independent of whichever foot is lower.
	actor.position=Vector2(600,root_base+lerpf(root_bob[i],root_bob[(i+1)%8],smoothstep(0,1,u)))

func apply_phase(phase: float) -> void:
	pose(phase)
	for side in ["Near","Far"]:
		var delta_y := baseline-foot_bottom(side)
		if delta_y<-.001:correct_contact(side,delta_y)
	queue_redraw()

func _process(delta: float) -> void:
	if capturing or not playing:return
	time+=delta
	apply_phase(time/.96)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(35,45),"БЕГ · ПЕРВАЯ ПРИМЕРКА НА РИГЕ",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("25343c"))
	draw_string(font,Vector2(35,85),"Углы по твоим точкам · длины костей сохранены",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("25343c"))
	draw_line(Vector2(140,baseline),Vector2(1060,baseline),Color("66756c"),2)
	draw_string(font,Vector2(35,745),"Черновая проба: стороны скрытых цепочек и контакт стоп требуют проверки.",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("794b25"))
	draw_string(font,Vector2(35,785),"В игру не подключено · Пробел — пауза · R — сначала",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("25343c"))

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://frames"))
	var max_length_error := 0.0
	var max_penetration := 0.0
	for i in 48:
		apply_phase(float(i)/48)
		for name in bones:max_length_error=maxf(max_length_error,absf(bones[name].position.length()-original_lengths[name]))
		max_penetration=maxf(max_penetration,maxf(foot_bottom("Near"),foot_bottom("Far"))-baseline)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://frames/%03d.png"%i))==OK)
	var report := {"frames":48,"bones":bones.size(),"max_bone_length_change":max_length_error,"max_floor_penetration_px":max_penetration,"game_changed":false,"contacts_solved":false,"side_mapping":"provisional"}
	var file := FileAccess.open("res://verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("RUN_STUDY ",JSON.stringify(report))
	assert(max_length_error<.0001)
	get_tree().quit()

