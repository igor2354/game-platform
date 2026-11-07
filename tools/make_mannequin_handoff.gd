extends SceneTree
## Artist handoff only. No changes to runtime resources or rig.
const MEDIA = preload("res://tools/media_paths.gd")
const P = preload("res://scripts/core/mannequin_profile.gd")
const CELL := Vector2i(1024,2048)
const OFFSET := Vector2(312,80)
const FACTOR := 4.0
const POINTS := {"skull":Vector2(76,64),"neck":Vector2(64,83),"shoulder":Vector2(43,96),"elbow":Vector2(37,164),"wrist":Vector2(55,231),"fingers":Vector2(63,270),"waist":Vector2(49,198),"hip":Vector2(40,234),"knee":Vector2(43,323),"ankle":Vector2(26,411),"heel":Vector2(17,445),"toe":Vector2(87,443),"sole":Vector2(40,452)}
const CAPS := {"skull":20,"neck":24,"shoulder":44,"elbow":32,"wrist":20,"waist":40,"hip":48,"knee":40,"ankle":28}
const PARTS := [
	["00_head","ГОЛОВА","C",["skull"]],
	["01_neck","ШЕЯ","C",["skull","neck"]],
	["02_torso","КОРПУС + ЖИВОТ","C",["neck","waist","shoulder"]],
	["03_pelvis","ТАЗ","C",["waist","hip"]],
	["04_N_L_upper_arm","ПЛЕЧО · БЛИЖНЕЕ L","N",["shoulder","elbow"]],
	["05_N_L_forearm","ПРЕДПЛЕЧЬЕ · БЛИЖНЕЕ L","N",["elbow","wrist"]],
	["06_F_R_upper_arm","ПЛЕЧО · ДАЛЬНЕЕ R","F",["shoulder","elbow"]],
	["07_F_R_forearm","ПРЕДПЛЕЧЬЕ · ДАЛЬНЕЕ R","F",["elbow","wrist"]],
	["08_N_L_hand","КИСТЬ · БЛИЖНЯЯ L","N",["wrist","fingers"]],
	["09_N_L_thigh","БЕДРО · БЛИЖНЕЕ L","N",["hip","knee"]],
	["10_F_R_hand","КИСТЬ · ДАЛЬНЯЯ R","F",["wrist","fingers"]],
	["11_F_R_thigh","БЕДРО · ДАЛЬНЕЕ R","F",["hip","knee"]],
	["12_N_L_shin","ГОЛЕНЬ · БЛИЖНЯЯ L","N",["knee","ankle"]],
	["13_N_L_foot","СТОПА · БЛИЖНЯЯ L","N",["ankle","heel","toe"]],
	["14_F_R_shin","ГОЛЕНЬ · ДАЛЬНЯЯ R","F",["knee","ankle"]],
	["15_F_R_foot","СТОПА · ДАЛЬНЯЯ R","F",["ankle","heel","toe"]]
]
var output: String
var reference: Texture2D
var photo_uri: String
func mapped(point: Vector2) -> Vector2: return OFFSET+point*FACTOR
func color_of(side: String) -> Color: return Color("f4af62") if side == "F" else Color("54d4e8") if side == "N" else Color("b9d0df")
func shape(id: String) -> PackedVector2Array:
	var points: Array
	if "head" in id: points = [Vector2(58,41),Vector2(59,23),Vector2(69,13),Vector2(82,10),Vector2(98,18),Vector2(107,33),Vector2(104,51),Vector2(95,67),Vector2(86,72),Vector2(76,65),Vector2(66,58)]
	elif "neck" in id: points = [Vector2(64,53),Vector2(79,62),Vector2(75,75),Vector2(69,87),Vector2(56,91),Vector2(47,80),Vector2(57,66)]
	elif "torso" in id: points = [Vector2(54,76),Vector2(65,81),Vector2(72,94),Vector2(78,121),Vector2(77,158),Vector2(75,190),Vector2(69,207),Vector2(33,208),Vector2(25,185),Vector2(20,147),Vector2(20,113),Vector2(27,92),Vector2(42,81)]
	elif "pelvis" in id: points = [Vector2(29,190),Vector2(68,190),Vector2(73,211),Vector2(68,237),Vector2(57,246),Vector2(37,246),Vector2(21,233),Vector2(17,218),Vector2(21,200)]
	elif "upper_arm" in id: points = [Vector2(32,83),Vector2(44,81),Vector2(57,87),Vector2(63,98),Vector2(57,119),Vector2(47,149),Vector2(45,168),Vector2(32,171),Vector2(26,154),Vector2(25,130),Vector2(25,105)]
	elif "forearm" in id: points = [Vector2(29,155),Vector2(44,154),Vector2(50,171),Vector2(57,195),Vector2(62,223),Vector2(61,234),Vector2(49,238),Vector2(43,220),Vector2(35,199),Vector2(28,178),Vector2(25,163)]
	elif "hand" in id: points = [Vector2(48,226),Vector2(59,226),Vector2(63,238),Vector2(74,248),Vector2(75,258),Vector2(71,270),Vector2(65,275),Vector2(53,273),Vector2(45,267),Vector2(46,251)]
	elif "thigh" in id: points = [Vector2(28,222),Vector2(50,221),Vector2(66,235),Vector2(69,258),Vector2(65,291),Vector2(57,318),Vector2(50,333),Vector2(34,332),Vector2(25,319),Vector2(28,294),Vector2(25,266),Vector2(24,241)]
	elif "shin" in id: points = [Vector2(33,314),Vector2(52,315),Vector2(55,329),Vector2(47,347),Vector2(43,380),Vector2(41,405),Vector2(36,418),Vector2(19,417),Vector2(14,399),Vector2(11,372),Vector2(10,357),Vector2(16,337),Vector2(25,321)]
	else: points = [Vector2(19,403),Vector2(36,402),Vector2(43,419),Vector2(59,427),Vector2(78,430),Vector2(86,436),Vector2(87,447),Vector2(77,454),Vector2(30,454),Vector2(10,450),Vector2(10,436),Vector2(14,421)]
	var result := PackedVector2Array()
	for point in points: result.append(mapped(point))
	return result
func polygon_string(points: PackedVector2Array) -> String:
	var values := PackedStringArray()
	for point in points: values.append("%s,%s" % [point.x,point.y])
	return " ".join(values)
func svg_content(part: Array) -> String:
	var color := "#"+color_of(part[2]).to_html(false)
	var result := '<rect width="1024" height="2048" fill="#172832"/><text x="36" y="48" fill="white" font-size="28">%s</text><text x="36" y="80" fill="%s" font-size="22">%s · ПЕРЕД +X →</text>' % [part[0],color,part[1]]
	result += '<image href="%s" x="312" y="80" width="500" height="1840" opacity="0.12"/>' % photo_uri
	result += '<rect x="312" y="80" width="500" height="1840" fill="none" stroke="#526570" stroke-dasharray="8 8"/>'
	result += '<polygon points="%s" fill="%s" fill-opacity="0.28" stroke="%s" stroke-width="3"/>' % [polygon_string(shape(part[0])),color,color]
	for name in part[3]:
		var position := mapped(POINTS[name])
		if CAPS.has(name): result += '<circle cx="%s" cy="%s" r="%s" fill="none" stroke="#f7ce75" stroke-width="2" stroke-dasharray="7 5"/>' % [position.x,position.y,CAPS[name]]
		result += '<path d="M %s %s h 20 M %s %s v 20" stroke="white" stroke-width="2"/>' % [position.x-10,position.y,position.x,position.y-10]
		result += '<text x="%s" y="%s" fill="white" font-size="20">%s (%s,%s)</text>' % [position.x+18,position.y-12,name,position.x,position.y]
	result += '<text x="36" y="1970" fill="white" font-size="23">PNG 1024×2048 · НЕ обрезать холст · НЕ менять масштаб</text><text x="36" y="2008" fill="#f7ce75" font-size="20">Жёлтые круги: запас сустава. Направляющие убрать из финального PNG.</text>'
	return result
class HandoffPanel extends Node2D:
	var host: SceneTree
	var master := false
	func _draw() -> void:
		var count := 1 if master else 16
		var font := ThemeDB.fallback_font
		for i in count:
			var part: Array = host.PARTS[i]
			var origin := Vector2.ZERO if master else Vector2((i%4)*1024,(i/4)*2048)
			draw_set_transform(origin)
			draw_rect(Rect2(Vector2.ZERO,host.CELL),Color("172832"))
			draw_rect(Rect2(Vector2.ZERO,host.CELL),Color("576e78"),false,2)
			draw_texture_rect(host.reference,Rect2(312,80,500,1840),false,Color(1,1,1,.16 if not master else .8))
			draw_string(font,Vector2(36,48),"ОБЩИЙ МАСТЕР · 1024×2048" if master else part[0],HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color.WHITE)
			draw_string(font,Vector2(36,80),"ПРОФИЛЬ ВПРАВО · +X →" if master else part[1]+" · +X →",HORIZONTAL_ALIGNMENT_LEFT,-1,22,host.color_of(part[2]))
			if not master:
				var points: PackedVector2Array = host.shape(part[0])
				draw_colored_polygon(points,Color(host.color_of(part[2]),.28))
				points.append(points[0])
				draw_polyline(points,host.color_of(part[2]),3,true)
			var names: Array = host.POINTS.keys() if master else part[3]
			for name in names:
				var position: Vector2 = host.mapped(host.POINTS[name])
				if host.CAPS.has(name): draw_arc(position,host.CAPS[name],0,TAU,48,Color("f7ce75"),2,true)
				draw_line(position-Vector2(10,0),position+Vector2(10,0),Color.WHITE,2)
				draw_line(position-Vector2(0,10),position+Vector2(0,10),Color.WHITE,2)
				var label_position := position+Vector2(18,-12)
				if master and name == "hip":
					label_position = Vector2(36,1040)
					draw_line(label_position+Vector2(220,-6),position,Color.WHITE,1.5)
				draw_string(font,label_position,"%s (%s,%s)" % [name,position.x,position.y],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color.WHITE)
			draw_string(font,Vector2(36,1970),"Сначала согласовать цельный профиль и суставы" if master else "PNG 1024×2048 · НЕ обрезать холст · НЕ менять масштаб",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
			draw_string(font,Vector2(36,2008),"Рисунок — ориентир; направляющие не входят в игровой PNG",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("f7ce75"))
		draw_set_transform_matrix(Transform2D.IDENTITY)
func render(master: bool,path: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = CELL if master else Vector2i(4096,8192)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var panel := HandoffPanel.new()
	panel.host = self
	panel.master = master
	viewport.add_child(panel)
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := viewport.get_texture().get_image()
	picture.save_png(output.path_join(path))
	if not master:
		picture.resize(2048,4096,Image.INTERPOLATE_LANCZOS)
		picture.save_png(output.path_join("sheet_preview.png"))
	viewport.queue_free()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	output = MEDIA.path("docs/core/mannequin_handoff_20261101/")
	DirAccess.make_dir_recursive_absolute(output.path_join("cells"))
	var source := MEDIA.path("docs/core/profile_rebuild_20261101/source_crop.png")
	var image := Image.load_from_file(source)
	reference = ImageTexture.create_from_image(image)
	photo_uri = "data:image/png;base64,"+Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(source))
	var atlas := '<svg xmlns="http://www.w3.org/2000/svg" width="4096" height="8192" viewBox="0 0 4096 8192" font-family="Arial,sans-serif">'
	var rows := []
	for i in 16:
		var part: Array = PARTS[i]
		var content := svg_content(part)
		atlas += '<g transform="translate(%s %s)">%s</g>' % [(i%4)*1024,(i/4)*2048,content]
		var cell := FileAccess.open(output.path_join("cells/"+part[0]+".svg"),FileAccess.WRITE)
		cell.store_string('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="2048" font-family="Arial,sans-serif">'+content+'</svg>')
		var anchors := {}
		for name in part[3]: anchors[name] = [mapped(POINTS[name]).x,mapped(POINTS[name]).y]
		rows.append({"file":part[0]+".png","row":i/4+1,"column":i%4+1,"side":part[2],"anchors":anchors,"canvas":[1024,2048]})
	atlas += '</svg>'
	var file := FileAccess.open(output.path_join("sheet_4096x8192.svg"),FileAccess.WRITE)
	file.store_string(atlas)
	file = FileAccess.open(output.path_join("layout.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"proposal_for_user_review_not_runtime_art","origin":"upper_left","x":"right","y":"down","atlas_size":[4096,8192],"cell_size":[1024,2048],"parts":rows},"\t"))
	Image.create(1024,2048,false,Image.FORMAT_RGBA8).save_png(output.path_join("blank_part_1024x2048.png"))
	await render(true,"00_master_guide.png")
	await render(false,"sheet_4096x8192.png")
	print("HANDOFF ",output)
	quit()
