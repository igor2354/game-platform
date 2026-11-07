extends RefCounted
const ART = preload("res://scripts/campaign/art.gd")
const WEAPONS = [
	{"id":"stg44","name":"STG-44","description":"Штурмовая винтовка. Универсальное оружие для боя на средней дистанции.","length":35.0,"axis":.22,"grip":.36,"front":.59,"trigger_y":.48,"support_y":.30,"barrel":.28,"stats":[.7,.7,.7,.6,.7],"values":{"damage":35.0,"rounds_per_minute":480.0,"magazine_capacity":30,"starting_reserve":180,"reload_duration":2.4,"fire_mode":0}},
	{"id":"mp40","name":"MP-40","description":"Пистолет-пулемёт. Управляемая автоматическая стрельба на короткой дистанции.","length":31.0,"axis":.17,"grip":.32,"front":.64,"trigger_y":.49,"support_y":.32,"barrel":.25,"stats":[.5,.45,.65,.8,.8],"values":{"damage":25.0,"rounds_per_minute":540.0,"magazine_capacity":32,"starting_reserve":192,"reload_duration":2.2,"fire_mode":0}},
	{"id":"m1911","name":"1911","description":"Самозарядный пистолет. Компактный запасной вариант с одиночным огнём.","length":8.5,"axis":.15,"grip":.23,"front":.23,"trigger_y":.53,"support_y":.53,"barrel":.18,"stats":[.55,.3,.65,.75,.4],"values":{"damage":30.0,"rounds_per_minute":240.0,"magazine_capacity":7,"starting_reserve":70,"reload_duration":1.6,"fire_mode":1}},
	{"id":"svt","name":"СВТ","description":"Самозарядная винтовка. Мощный одиночный огонь и небольшой магазин.","length":45.0,"axis":.22,"grip":.32,"front":.56,"trigger_y":.56,"support_y":.32,"barrel":.30,"stats":[.95,.95,.85,.4,.35],"values":{"damage":65.0,"rounds_per_minute":180.0,"magazine_capacity":10,"starting_reserve":80,"reload_duration":2.8,"fire_mode":1}}]

static func index_for(id: String) -> int:
	for index in WEAPONS.size():
		if WEAPONS[index].id == id: return index
	return 0

# Nominal bore in mm and a gameplay penetration factor, not a muzzle-energy simulation.
static func terrain_ballistics(id: String) -> Dictionary:
	match id:
		"stg44":return {"caliber_mm":7.92,"power":1.0}
		"mp40":return {"caliber_mm":9.0,"power":.55}
		"m1911":return {"caliber_mm":11.43,"power":.65}
		"svt":return {"caliber_mm":7.62,"power":1.8}
	return {"caliber_mm":9.0,"power":1.0}

# Case length and maximum body/rim diameter, mm; not bullet diameter or cartridge OAL.
static func casing_mm(id: String) -> Vector2:
	match id:
		"stg44": return Vector2(33.0,11.95)
		"mp40": return Vector2(19.15,9.96)
		"m1911": return Vector2(22.81,12.19)
		"svt": return Vector2(53.72,14.48)
	return Vector2(33.0,11.95) # Legacy test rifle.

static func equip(controller: CoreShootingController,id: String) -> void:
	controller.equipped_weapon_id = WEAPONS[index_for(id)].id
	controller.tuning.apply_values(WEAPONS[index_for(id)].values)
	controller.apply_tuning()
	controller.refill_ammunition()

static func draw_weapon(canvas: Node2D,id: String,breech: Vector2,direction: Vector2,normal: Vector2,layer := 0,magazine := true,layout: Dictionary = {}) -> void:
	var index := index_for(id)
	var data: Dictionary = WEAPONS[index] if layout.is_empty() else layout
	var texture := ART.weapon(index)
	var size := Vector2(data.length,data.length*texture.get_height()/texture.get_width())
	canvas.draw_set_transform_matrix(Transform2D(direction,normal,breech))
	var split := float(data.grip) if id != "m1911" else 0.0
	var start := split if layer > 0 else 0.0
	var end := split if layer < 0 else 1.0
	if end > start:
		if not magazine and id != "m1911" and layer >= 0:
			_draw_without_magazine(canvas,data,start,end)
		else:
			canvas.draw_texture_rect_region(texture,Rect2(Vector2(size.x*(start-data.grip),-size.y*data.axis),Vector2(size.x*(end-start),size.y)),Rect2(Vector2(texture.get_width()*start,0),Vector2(texture.get_width()*(end-start),texture.get_height())))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

static func rear_grip(data: Dictionary) -> Vector2:
	var image := ART.weapon(index_for(data.id))
	var height: float = data.length*image.get_height()/image.get_width()
	return Vector2(0,height*(float(data.get("trigger_y",.53))-float(data.axis)))

static func front_grip(data: Dictionary) -> Vector2:
	if data.id == "m1911": return rear_grip(data)+Vector2(.8,.3)
	var image := ART.weapon(index_for(data.id))
	var height: float = data.length*image.get_height()/image.get_width()
	return Vector2(data.length*(data.front-data.grip),height*(float(data.get("support_y",.43))-float(data.axis)))

static func magazine_outline(id: String) -> PackedVector2Array:
	match id:
		"stg44": return PackedVector2Array([Vector2(.49,.38),Vector2(.55,.36),Vector2(.56,.57),Vector2(.59,.75),Vector2(.63,.87),Vector2(.57,.97),Vector2(.53,.85),Vector2(.50,.64)])
		"mp40": return PackedVector2Array([Vector2(.669,.505),Vector2(.727,.505),Vector2(.725,.901),Vector2(.670,.906)])
		"svt": return PackedVector2Array([Vector2(.381,.478),Vector2(.461,.462),Vector2(.461,.580),Vector2(.386,.608)])
	return PackedVector2Array([Vector2(.1,.86),Vector2(.3,.86),Vector2(.3,.98),Vector2(.1,.98)])

static func magazine_shape(id: String) -> PackedVector2Array:
	if id.is_empty():
		return PackedVector2Array([Vector2(-3,-4.5),Vector2(3,-4.5),Vector2(4.6,-2),Vector2(4.6,2),Vector2(3,4.5),Vector2(-3,4.5),Vector2(-4.6,2),Vector2(-4.6,-2)])
	if id == "m1911":
		return Geometry2D.convex_hull(pistol_magazine_outline()).slice(0,-1)
	var data: Dictionary = WEAPONS[index_for(id)]
	var texture := ART.weapon(index_for(id))
	var size := Vector2(data.length,data.length*texture.get_height()/texture.get_width())
	var center := magazine_center(id)
	var points := magazine_outline(id)
	for index in points.size():
		points[index] = (points[index]-center)*size
	return Geometry2D.convex_hull(points).slice(0,-1)

static func magazine_center(id: String) -> Vector2:
	var points := magazine_outline(id)
	var center := Vector2.ZERO
	for p in points: center += p
	return center/points.size()

static func magazine_local(data: Dictionary) -> Vector2:
	var texture := ART.weapon(index_for(data.id))
	var size := Vector2(data.length,data.length*texture.get_height()/texture.get_width())
	return (magazine_center(data.id)-Vector2(data.grip,data.axis))*size

static func _textured_polygon(canvas: Node2D,points: PackedVector2Array,data: Dictionary,origin: Vector2) -> void:
	var texture := ART.weapon(index_for(data.id)) as AtlasTexture
	var size := Vector2(data.length,data.length*texture.get_height()/texture.get_width())
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	for p in points:
		vertices.append((p-origin)*size)
		uv.append((texture.region.position+p*texture.region.size)/ART.WEAPONS.get_size())
	canvas.draw_polygon(vertices,PackedColorArray([Color.WHITE]),uv,ART.WEAPONS)

static func _draw_without_magazine(canvas: Node2D,data: Dictionary,start: float,end: float) -> void:
	var outline := magazine_outline(data.id)
	var vertices := PackedVector2Array([Vector2(start,0),Vector2(end,0),Vector2(end,1),Vector2(start,1)])
	vertices.append_array(outline)
	var indices := Geometry2D.triangulate_delaunay(vertices)
	for i in range(0,indices.size(),3):
		var triangle := PackedVector2Array([vertices[indices[i]],vertices[indices[i+1]],vertices[indices[i+2]]])
		var center := (triangle[0]+triangle[1]+triangle[2])/3
		if center.x < start or center.x > end or Geometry2D.is_point_in_polygon(center,outline): continue
		var valid := true
		for j in 3:
			if Geometry2D.is_point_in_polygon(((triangle[j]+triangle[(j+1)%3])*.5).lerp(center,.001),outline): valid = false
		if valid: _textured_polygon(canvas,triangle,data,Vector2(data.grip,data.axis))

static func draw_magazine(canvas: Node2D,id: String,point: Vector2,direction: Vector2,normal: Vector2) -> void:
	canvas.draw_set_transform_matrix(Transform2D(direction,normal,point))
	if id == "m1911":
		canvas.draw_colored_polygon(pistol_magazine_outline(), Color("34383b"))
		for detail in pistol_magazine_details():
			canvas.draw_colored_polygon(detail.points, detail.color)
	else:
		var data: Dictionary = WEAPONS[index_for(id)]
		_textured_polygon(canvas,magazine_outline(id),data,magazine_center(id))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

static func pistol_magazine_outline() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-.48,-1.78),Vector2(-.27,-2),Vector2(.42,-2),Vector2(.49,1.7),Vector2(.57,1.74),Vector2(.57,2),Vector2(-.55,2),Vector2(-.55,1.73)])

static func pistol_magazine_details() -> Array[Dictionary]:
	var details: Array[Dictionary] = [
		{"points": PackedVector2Array([Vector2(-.38,-1.72),Vector2(-.28,-1.88),Vector2(-.24,1.63),Vector2(-.41,1.69)]), "color": Color("62696c")},
		{"points": PackedVector2Array([Vector2(.24,-1.9),Vector2(.38,-1.92),Vector2(.43,1.64),Vector2(.29,1.68)]), "color": Color("23282b")},
		{"points": PackedVector2Array([Vector2(-.52,1.77),Vector2(.53,1.77),Vector2(.53,1.89),Vector2(-.52,1.89)]), "color": Color("747a7c")},
	]
	for y in [-1.08, -.58, -.08, .42, .92, 1.42]:
		details.append({"points": PackedVector2Array([Vector2(-.08,y),Vector2(0,y-.08),Vector2(.08,y),Vector2(0,y+.08)]), "color": Color("171a1c")})
	return details

static func magazine_shell(id: String) -> Dictionary:
	if id == "m1911":
		return {"points":pistol_magazine_outline(), "texture":null, "uv":PackedVector2Array()}
	var data: Dictionary = WEAPONS[index_for(id)]
	var texture := ART.weapon(index_for(id)) as AtlasTexture
	var size := Vector2(data.length, data.length * texture.get_height() / texture.get_width())
	var center := magazine_center(id)
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for point in magazine_outline(id):
		points.append((point - center) * size)
		uv.append((texture.region.position + point * texture.region.size) / ART.WEAPONS.get_size())
	return {"points":points, "texture":ART.WEAPONS, "uv":uv}
