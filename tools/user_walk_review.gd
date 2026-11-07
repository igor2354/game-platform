extends Node2D
## External review only: this script is copied outside the game before running.
const MODEL = preload("res://resources/core/user_standing/Standing.scn")
var data: Dictionary
var actor: Node2D
var bones: Dictionary = {}
var rests: Dictionary = {}
var keys: Array[Dictionary] = []
var soles: Dictionary = {}
var time := 0.0
var playing := true
var capturing := false
var stride := 0.0
var ankle_start := Vector2.ZERO
var ankle_half := Vector2.ZERO
var half_distance := 0.0
var travelled := 0.0
var reference: Texture2D
var comparison := false
var key_models: Array[Node2D] = []
var original_lengths: Dictionary = {}
var largest_contact_correction := 0.0
var sole_review := false
var smooth_body := false
var body_height_base := 730.0
var symmetric_walk := false
var body_cos := 0.0
var body_sin := 0.0
var neutral_sole_error := 0.0
var equal_length_error := 0.0

func _ready() -> void:
	if ProjectSettings.get_setting("application/config/name")!="Ходьба — внешний просмотр":
		push_error("Run this viewer only in its external authoring project")
		get_tree().quit(1)
		return
	data=JSON.parse_string(FileAccess.get_file_as_string("res://walk_keys.json"))
	actor=MODEL.instantiate()
	actor.position=Vector2(750,730)
	actor.scale=Vector2.ONE*8
	add_child(actor)
	for bone: Bone2D in actor.find_children("*","Bone2D",true,false):
		bones[str(bone.name)]=bone
		rests[str(bone.name)]=bone.rest
		original_lengths[str(bone.name)]=bone.position.length()
	symmetric_walk=bool(data.get("symmetric_walk",false)) or "--symmetric-walk" in OS.get_cmdline_user_args()
	if symmetric_walk:equalize_legs()
	for poly: Polygon2D in actor.find_children("*","Polygon2D",true,false):
		poly.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		if poly.name=="FarLeg" and not symmetric_walk:
			var skeleton: Skeleton2D=actor.get_node("Rig")
			var hip_path := skeleton.get_path_to(bones.FarHip)
			var pelvis_weights := PackedFloat32Array()
			pelvis_weights.resize(poly.polygon.size())
			var hip_y: float=rest_world("FarHip").origin.y
			for index in poly.get_bone_count():
				if poly.get_bone_path(index)!=hip_path:continue
				var values := poly.get_bone_weights(index)
				for vertex in values.size():
					var blend := smoothstep(hip_y,hip_y+4.7,poly.polygon[vertex].y)
					pelvis_weights[vertex]=values[vertex]*(1-blend)
					values[vertex]*=blend
				poly.set_bone_weights(index,values)
			poly.add_bone(skeleton.get_path_to(bones.Pelvis),pelvis_weights)
		for side in ["Near","Far"]:
			var key: String = side+"Ankle"
			var path: NodePath=(actor.get_node("Rig") as Skeleton2D).get_path_to(bones[key])
			for index in poly.get_bone_count():
				if poly.get_bone_path(index)!=path: continue
				var points: PackedVector2Array=soles.get(side,PackedVector2Array())
				var texture_image := poly.texture.get_image()
				var factor: float=(poly.polygon[1].x-poly.polygon[0].x)/(poly.uv[1].x-poly.uv[0].x)
				var origin: Vector2=poly.polygon[0]-poly.uv[0]*factor
				var ankle_y: float=actor.to_local(bones[key].global_position).y
				for x in texture_image.get_width():
					for y in range(texture_image.get_height()-1,-1,-1):
						if texture_image.get_pixel(x,y).a<.5:continue
						var point := origin+Vector2(x+.5,y+.5)*factor
						if point.y>ankle_y:
							points.append(bones[key].global_transform.affine_inverse()*(actor.global_transform*point))
						break
				soles[side]=points
	neutral_sole_error=absf(foot_bottom("Near")-foot_bottom("Far"))/actor.scale.y
	for joint in ["Knee","Ankle"]:equal_length_error=maxf(equal_length_error,absf(bones["Near"+joint].position.length()-bones["Far"+joint].position.length()))
	if symmetric_walk:
		var neutral := PackedScene.new()
		assert(neutral.pack(actor)==OK)
		assert(ResourceSaver.save(neutral,"res://EqualLegRig.scn",ResourceSaver.FLAG_COMPRESS)==OK)
		assert(neutral_sole_error<.00001 and equal_length_error<.00001)
	if "--sole-review" in OS.get_cmdline_user_args():
		sole_review=true
		capturing=true
		await capture_sole_registration()
		return
	for i in 4: keys.append(make_key(i))
	if symmetric_walk:
		symmetrize_leg_keys()
		prepare_body_curve()
	if "--leveled-walk" in OS.get_cmdline_user_args():
		register_far_boot()
		smooth_body=true
		body_height_base=-INF
		for i in 128:
			var p := float(i)/128
			pose(p)
			actor.position=Vector2(750,730)
			var w := 1.0 if p<.4 else 1.0-smoothstep(.4,.5,p) if p<.5 else 0.0 if p<.9 else smoothstep(.9,1.0,p)
			var plane := lerpf(foot_bottom("Far"),foot_bottom("Near"),w)
			body_height_base=maxf(body_height_base,730+(730-plane)-hip_bob(p)*actor.scale.y)
	pose(0)
	float_pose(0)
	ankle_start=local_ankle("Near")
	pose(.5)
	float_pose(.5)
	half_distance=ankle_start.x-local_ankle("Near").x
	ankle_half=local_ankle("Far")
	pose(1)
	float_pose(1)
	stride=half_distance+ankle_half.x-local_ankle("Far").x
	assert(stride>0)
	pose(0)
	float_pose(0)
	reference=load("res://approved_reference.png")
	if "--capture" in OS.get_cmdline_user_args():
		capturing=true
		await capture()
	else: queue_redraw()

func angle(a: Array,b: Array) -> float:
	return Vector2(float(b[0])-a[0],float(b[1])-a[1]).angle()

func equalize_legs() -> void:
	# User 08.11: equal projected limbs. Reuse the approved near-leg artwork,
	# not a stretch of the mismatched far drawing. No changes to the near leg.
	for joint in ["Hip","Knee","Ankle","Toe"]:
		var near: Bone2D=bones["Near"+joint]
		var far: Bone2D=bones["Far"+joint]
		far.transform=near.rest
		far.rest=near.rest
		rests["Far"+joint]=near.rest
		original_lengths["Far"+joint]=near.position.length()
	for name in ["FarLeg","FarLegBacking"]:
		if actor.has_node(name):
			var old := actor.get_node(name)
			actor.remove_child(old)
			old.free()
	var skeleton: Skeleton2D=actor.get_node("Rig")
	for source_name in ["Body","HiddenTorso"]:
		var source: Polygon2D=actor.get_node(source_name)
		var poly: Polygon2D=source.duplicate()
		poly.name="FarLeg" if source_name=="Body" else "FarLegBacking"
		var faces: Array[PackedInt32Array]=[]
		var hip_y: float=rest_world("NearHip").origin.y
		for face in poly.polygons:
			var keep := true
			for index in face:keep=keep and poly.polygon[index].y>=hip_y-.5
			if keep:faces.append(face)
		poly.polygons=faces
		for i in poly.get_bone_count():
			var bone_path := str(poly.get_bone_path(i))
			for joint in ["Hip","Knee","Ankle","Toe"]:bone_path=bone_path.replace("Near"+joint,"Far"+joint)
			poly.set_bone_path(i,NodePath(bone_path))
		actor.add_child(poly)
		poly.owner=actor
		actor.move_child(poly,actor.get_node("Body").get_index())
		poly.skeleton=poly.get_path_to(skeleton)

func symmetrize_leg_keys() -> void:
	var old: Array[Dictionary]=keys.duplicate(true)
	for i in 4:
		var opposite := (i+2)%4
		var pelvis: float=lerp_angle(old[i].Pelvis,old[opposite].Pelvis,.5)
		keys[i].Spine+=old[i].Pelvis-pelvis
		keys[i].Pelvis=pelvis
		for side in ["Near","Far"]:
			var j := i if side=="Near" else opposite
			var k := (j+2)%4
			var hip: float=lerp_angle(old[j].NearHip+old[j].Pelvis,old[k].FarHip+old[k].Pelvis,.5)
			var knee: float=lerp_angle(old[j].NearKnee,old[k].FarKnee,.5)
			var boot: float=lerp_angle(old[j].Pelvis+old[j].NearHip+old[j].NearKnee+old[j].NearAnkle,old[k].Pelvis+old[k].FarHip+old[k].FarKnee+old[k].FarAnkle,.5)
			keys[i][side+"Hip"]=hip-pelvis
			keys[i][side+"Knee"]=knee
			keys[i][side+"Ankle"]=boot-hip-knee

func prepare_body_curve() -> void:
	# Author a smooth twice-per-cycle body path ONCE from the supporting leg.
	# The swinging shoe never pulls the torso down during playback.
	var raw: Array[float]=[]
	for i in 128:
		var p := float(i)/128
		pose(p)
		actor.position=Vector2(750,730)
		raw.append(1460-foot_bottom("Near" if p<.5 else "Far"))
	body_height_base=0
	for i in raw.size():
		var phase := float(i)/raw.size()*TAU*2
		body_height_base+=raw[i]/raw.size()
		body_cos+=2*raw[i]*cos(phase)/raw.size()
		body_sin+=2*raw[i]*sin(phase)/raw.size()
	var clearance := 0.0
	for i in raw.size():
		var phase := float(i)/raw.size()*TAU*2
		clearance=maxf(clearance,raw[i]-(body_height_base+body_cos*cos(phase)+body_sin*sin(phase)))
	body_height_base+=clearance

func rest_world(key: String) -> Transform2D:
	var bone: Bone2D=bones[key]
	var chain: Array[String] = []
	var cursor: Node=bone
	while cursor is Bone2D:
		chain.push_front(str(cursor.name));cursor=cursor.get_parent()
	var result := Transform2D.IDENTITY
	for name in chain: result=result*rests[name]
	return result

func make_key(index: int) -> Dictionary:
	var source: Dictionary=data.keys[index]
	var rotations: Dictionary={}
	var hip_rest: Vector2=rest_world("NearHip").origin
	var chest_rest: Vector2=rest_world("Spine").origin
	rotations.Pelvis=angle(source.hip,source.chest)-(chest_rest-hip_rest).angle()
	rotations.Spine=angle(source.chest,source.neck)-bones.Neck.position.angle()-rotations.Pelvis
	rotations.Neck=angle(source.neck,source.head)-bones.HeadPivot.position.angle()-rotations.Pelvis-rotations.Spine
	rotations.HeadPivot=-rotations.Pelvis-rotations.Spine-rotations.Neck
	# Torso/roots retain the approved bind geometry. Angles transfer; lengths don't.
	for side in ["Near","Far"]:
		var prefix: String = side.to_lower()+"_"
		var hip_axis: Vector2=bones[side+"Knee"].position
		var knee_axis: Vector2=bones[side+"Ankle"].position
		var thigh := angle(source.hip,source[prefix+"knee"])
		var shin := angle(source[prefix+"knee"],source[prefix+"ankle"])
		rotations[side+"Hip"]=thigh-hip_axis.angle()-rotations.Pelvis
		rotations[side+"Knee"]=shin-thigh+hip_axis.angle()-knee_axis.angle()
		var boot_angle := deg_to_rad(float(data["foot_angles_"+side.to_lower()][index]))
		rotations[side+"Ankle"]=boot_angle-rotations.Pelvis-rotations[side+"Hip"]-rotations[side+"Knee"]
		var upper := angle(source.shoulder,source[prefix+"elbow"])
		var lower := angle(source[prefix+"elbow"],source[prefix+"wrist"])
		var elbow_axis: Vector2=bones[side+"Elbow"].position
		var wrist_axis: Vector2=bones[side+"Wrist"].position
		rotations[side+"Shoulder"]=upper-elbow_axis.angle()-rotations.Pelvis-rotations.Spine
		rotations[side+"Elbow"]=lower-upper+elbow_axis.angle()-wrist_axis.angle()
		rotations[side+"Wrist"]=0.0
	return rotations

func cubic_angle(a: float,b: float,c: float,d: float,u: float) -> float:
	# Unwrap neighbouring rotations before a periodic Hermite interpolation.
	a=b+wrapf(a-b,-PI,PI)
	c=b+wrapf(c-b,-PI,PI)
	d=c+wrapf(d-c,-PI,PI)
	return .5*((2*b)+(-a+c)*u+(2*a-5*b+4*c-d)*u*u+(-a+3*b-3*c+d)*u*u*u)

func pose(phase: float) -> void:
	for name in bones: bones[name].transform=rests[name]
	var p := fposmod(phase,1.0)*4
	var segment := floori(p)
	var u := p-segment
	for name in keys[0]:
		bones[name].rotation=cubic_angle(keys[posmod(segment-1,4)][name],keys[segment][name],keys[(segment+1)%4][name],keys[(segment+2)%4][name],u)

func local_ankle(side: String) -> Vector2:
	return actor.to_local(bones[side+"Ankle"].global_position)

func foot_bottom(side: String) -> float:
	var result := -INF
	for point in soles[side]: result=maxf(result,bones[side+"Ankle"].to_global(point).y)
	return result

func register_far_boot() -> float:
	var delta_local := (foot_bottom("Far")-foot_bottom("Near"))/actor.scale.y
	for poly: Polygon2D in actor.find_children("*","Polygon2D",true,false):
		if poly.name!="FarLeg":continue
		var skeleton: Skeleton2D=actor.get_node("Rig")
		for i in poly.get_bone_count():
			if poly.get_bone_path(i)!=skeleton.get_path_to(bones.FarAnkle):continue
			var weights := poly.get_bone_weights(i)
			var vertices := poly.polygon
			for v in vertices.size(): vertices[v].y-=delta_local*weights[v]
			poly.polygon=vertices
	var corrected: PackedVector2Array=soles.Far
	for i in corrected.size():corrected[i].y-=delta_local
	soles.Far=corrected
	return delta_local

func capture_sole_registration() -> void:
	var original := PackedScene.new()
	assert(original.pack(actor)==OK)
	var before: Node2D=original.instantiate()
	before.position=Vector2(400,730)
	before.scale=Vector2.ONE*7
	add_child(before)
	actor.position=Vector2(1100,730)
	actor.scale=Vector2.ONE*7
	var delta_local := register_far_boot()
	var report := {"date":"2026-11-08","far_boot_visual_shift_y":-delta_local,"hips_coincide":rest_world("NearHip").origin.distance_to(rest_world("FarHip").origin)<.00001,"rest_sole_error_pixels":absf(foot_bottom("Near")-foot_bottom("Far")),"bone_positions_changed":false,"image_rescaled":false,"game_changed":false,"walk_bob_fixed":false}
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("sole_alignment.png"))==OK)
	var file := FileAccess.open("res://sole_alignment.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	var packed := PackedScene.new()
	assert(packed.pack(actor)==OK)
	assert(ResourceSaver.save(packed,"res://LeveledCandidate.scn",ResourceSaver.FLAG_COMPRESS)==OK)
	print("SOLE_ALIGNMENT ",JSON.stringify(report))
	get_tree().quit()

func correct_contact(side: String,vertical_delta: float) -> void:
	# Retarget contact with rotations only. No leg rescaling or side swaps.
	var hip: Vector2=actor.to_local(bones[side+"Hip"].global_position)
	var target := local_ankle(side)+Vector2(0,vertical_delta/actor.scale.y)
	var direction := target-hip
	var upper: float=bones[side+"Knee"].position.length()
	var lower: float=bones[side+"Ankle"].position.length()
	var distance := clampf(direction.length(),absf(upper-lower)+.001,upper+lower-.001)
	var along := (upper*upper-lower*lower+distance*distance)/(2*distance)
	var height := sqrt(maxf(0,upper*upper-along*along))
	var knee := hip+direction.normalized()*along-Vector2(-direction.y,direction.x).normalized()*height
	var foot_angle: float=bones.Pelvis.rotation+bones[side+"Hip"].rotation+bones[side+"Knee"].rotation+bones[side+"Ankle"].rotation
	bones[side+"Hip"].rotation=(knee-hip).angle()-bones[side+"Knee"].position.angle()-bones.Pelvis.rotation
	bones[side+"Knee"].rotation=(target-knee).angle()-bones[side+"Ankle"].position.angle()-bones[side+"Hip"].rotation-bones.Pelvis.rotation
	bones[side+"Ankle"].rotation=foot_angle-bones[side+"Hip"].rotation-bones[side+"Knee"].rotation-bones.Pelvis.rotation
	largest_contact_correction=maxf(largest_contact_correction,absf(vertical_delta)/actor.scale.y)

func float_pose(phase: float) -> void:
	# Contact uses opaque shoe pixels; translucent grid stock is not a sole.
	actor.position=Vector2(750,730)
	if symmetric_walk:
		actor.position.y=body_height_base+body_cos*cos(phase*TAU*2)+body_sin*sin(phase*TAU*2)
		for side in ["Near","Far"]:
			var correction := 730-foot_bottom(side)
			if correction<-.001:correct_contact(side,correction)
		return
	if smooth_body:
		actor.position.y=body_height_base+hip_bob(phase)*actor.scale.y
		for side in ["Near","Far"]:
			var correction := 730-foot_bottom(side)
			if correction<-.001:correct_contact(side,correction)
		return
	var p := fposmod(phase,1)
	var near_weight := 1.0 if p<.4 else 1.0-smoothstep(.4,.5,p) if p<.5 else 0.0 if p<.9 else smoothstep(.9,1.0,p)
	var plane := lerpf(foot_bottom("Far"),foot_bottom("Near"),near_weight)
	for side in ["Near","Far"]:
		var delta_y := plane-foot_bottom(side)
		if delta_y<-.001: correct_contact(side,delta_y)
	actor.position.y+=730-plane

func hip_bob(phase: float) -> float:
	# User hip-height marks set the body motion. Shoes no longer move the torso.
	var p := fposmod(phase,1)*4
	var i := floori(p)
	var u := p-i
	var values: Array[float] = []
	var average := 0.0
	for key in data.keys:average+=float(key.hip[1])/4
	for key in data.keys:values.append((float(key.hip[1])-average)*63.42/630.0)
	return .5*((2*values[i])+(-values[posmod(i-1,4)]+values[(i+1)%4])*u+(2*values[posmod(i-1,4)]-5*values[i]+4*values[(i+1)%4]-values[(i+2)%4])*u*u+(-values[posmod(i-1,4)]+3*values[i]-3*values[(i+1)%4]+values[(i+2)%4])*u*u*u)

func apply_phase(phase: float) -> void:
	pose(phase)
	float_pose(phase)
	var p := fposmod(phase,1)
	travelled=ankle_start.x-local_ankle("Near").x if p<.5 else half_distance+ankle_half.x-local_ankle("Far").x
	queue_redraw()

func _process(delta: float) -> void:
	if capturing or comparison or not playing:return
	time+=delta
	apply_phase(time/1.25)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_SPACE:playing=not playing
		if event.keycode==KEY_R:time=0;apply_phase(0)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	if sole_review:
		draw_string(font,Vector2(55,55),"СТОЙКА · ПРОВЕРКА УРОВНЯ ПОДОШВ",HORIZONTAL_ALIGNMENT_LEFT,-1,29,Color("25343c"))
		draw_string(font,Vector2(240,135),"До поправки",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("25343c"))
		draw_string(font,Vector2(930,135),"Дальний ботинок выровнен",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("25343c"))
		for x in [400,1100]:draw_line(Vector2(x-200,foot_bottom("Near")),Vector2(x+220,foot_bottom("Near")),Color("66756c"),2)
		draw_string(font,Vector2(55,850),"Смещён только рисунок дальнего ботинка. Крепления, длины костей и масштаб сохранены.",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("25343c"))
		draw_string(font,Vector2(55,900),"Внешняя проверка стойки. Коррекция движения корпуса в цикле — отдельная задача.",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("25343c"))
		return
	draw_string(font,Vector2(55,55),"ХОДЬБА · ПЕРЕНОС СОГЛАСОВАННЫХ ФАЗ",HORIZONTAL_ALIGNMENT_LEFT,-1,29,Color("25343c"))
	if comparison:
		draw_string(font,Vector2(55,102),"Сверху — согласованный лист. Снизу — те же фазы на текущем риге.",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("25343c"))
		var borders := [0,425,800,1235,1671]
		for i in 4:
			var width := float(borders[i+1]-borders[i])
			var factor := 335.0/665.0
			draw_texture_rect_region(reference,Rect2(Vector2(235+i*365-width*factor*.5,130),Vector2(width*factor,335)),Rect2(borders[i],95,width,665))
		for i in 4:
			draw_line(Vector2(90+i*365,870),Vector2(365+i*365,870),Color("66756c"),2)
			draw_string(font,Vector2(220+i*365,910),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("25343c"))
	else:
		draw_string(font,Vector2(55,102),"Пробный цикл на риге · свободные руки · без оружия",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("25343c"))
		draw_line(Vector2(160,730),Vector2(1340,730),Color("66756c"),2)
		var spacing := stride*8
		for i in range(-4,5):
			var x := 750+i*spacing-travelled*8
			if x>160 and x<1340: draw_line(Vector2(x,735),Vector2(x,750),Color("8d9b90"),2)
		draw_string(font,Vector2(55,850),"Стороны и порядок шага сохранены. Руки второй фазы исправлены. Это первая проба.",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("25343c"))
		draw_string(font,Vector2(55,895),"Это внешний просмотр: игровой цикл пока не заменён. Пробел — пауза, R — сначала.",HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("25343c"))

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://frames"))
	var max_length_error := 0.0
	var max_floor_error := 0.0
	var max_support_error := 0.0
	var root_heights: Array[float]=[]
	var captured_angles: Array=[]
	var captured_offsets: Array=[]
	for frame in 64:
		apply_phase(float(frame)/64)
		root_heights.append(bones.Pelvis.global_position.y)
		var sample: Array=[]
		for name in bones:sample.append(bones[name].rotation)
		captured_angles.append(sample)
		captured_offsets.append([(actor.position.x-750)/actor.scale.x,(actor.position.y-730)/actor.scale.y])
		max_support_error=maxf(max_support_error,absf(foot_bottom("Near" if frame<32 else "Far")-730))
		for name in bones:max_length_error=maxf(max_length_error,absf(bones[name].position.length()-original_lengths[name]))
		var bottom := -INF
		for side in soles:
			for point in soles[side]: bottom=maxf(bottom,bones[side+"Ankle"].to_global(point).y)
		max_floor_error=maxf(max_floor_error,absf(bottom-730))
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("frames/%03d.png"%frame))==OK)
	# Side-by-side acceptance sheet reuses the same rendered rig at exact keys.
	comparison=true
	actor.hide()
	for i in 4:
		apply_phase(float(i)/4)
		var packed := PackedScene.new()
		assert(packed.pack(actor)==OK)
		var copy: Node2D=packed.instantiate()
		copy.show()
		copy.scale=Vector2.ONE*5
		copy.position=Vector2(235+i*365,870+(actor.position.y-730)*5/8)
		add_child(copy)
		key_models.append(copy)
	queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("comparison.png"))==OK)
	var half_difference := 0.0
	var adjacent_delta := 0.0
	for i in root_heights.size():
		half_difference=maxf(half_difference,absf(root_heights[i]-root_heights[(i+32)%64]))
		adjacent_delta=maxf(adjacent_delta,absf(root_heights[i]-root_heights[(i+1)%64]))
	var report := {"frames":64,"bones":bones.size(),"max_length_error":max_length_error,"max_floor_error_pixels":max_floor_error,"stride_local":stride,"max_contact_retarget_local":largest_contact_correction,"side_mapping_legs":data.near_front_legs,"side_mapping_arms":data.near_front_arms,"game_modified":false,"symmetric_walk":symmetric_walk,"neutral_sole_error_local":neutral_sole_error,"leg_segment_length_difference":equal_length_error,"hip_height_difference_half_cycle_px":half_difference,"max_hip_movement_per_frame_px":adjacent_delta,"max_support_sole_error_px":max_support_error,"body_curve_cos_px":body_cos,"body_curve_sin_px":body_sin}
	var file := FileAccess.open("res://verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	if symmetric_walk:
		var poses_file := FileAccess.open("res://approved_cycle_samples.json",FileAccess.WRITE)
		var sole_y := -INF
		for point in soles.Near:sole_y=maxf(sole_y,point.y)
		poses_file.store_string(JSON.stringify({"names":bones.keys(),"angles":captured_angles,"offsets":captured_offsets,"stride":stride,"sole_y":sole_y}))
	print("WALK_REVIEW ",JSON.stringify(report))
	assert(max_length_error<.0001 and max_floor_error<.01)
	if symmetric_walk:assert(half_difference<.001 and max_support_error<.01)
	get_tree().quit()
