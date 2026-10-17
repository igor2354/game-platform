extends RefCounted
const ART = preload("res://scripts/campaign/art.gd")
const CHARACTERS = [
	{"id":"harry","name":"Гарри","role":"СОЛДАТ-ВЫЖИВШИЙ"},
	{"id":"sofia","name":"София Шоль","role":"СОЛДАТ-ВЫЖИВШИЙ"}]
const WEAPONS = [
	{"id":"stg44","name":"STG-44","description":"Штурмовая винтовка. Универсальное оружие для боя на средней дистанции.","length":48.0,"axis":.30,"grip":.40,"front":.67,"barrel":.28,"stats":[.7,.7,.7,.6,.7],"values":{"damage":35.0,"rounds_per_minute":480.0,"magazine_capacity":30,"starting_reserve":180,"reload_duration":2.4,"fire_mode":0}},
	{"id":"mp40","name":"MP-40","description":"Пистолет-пулемёт. Управляемая автоматическая стрельба на короткой дистанции.","length":42.0,"axis":.31,"grip":.39,"front":.63,"barrel":.25,"stats":[.5,.45,.65,.8,.8],"values":{"damage":25.0,"rounds_per_minute":540.0,"magazine_capacity":32,"starting_reserve":192,"reload_duration":2.2,"fire_mode":0}},
	{"id":"m1911","name":"1911","description":"Самозарядный пистолет. Компактный запасной вариант с одиночным огнём.","length":20.0,"axis":.27,"grip":.28,"front":.47,"barrel":.18,"stats":[.55,.3,.65,.75,.4],"values":{"damage":30.0,"rounds_per_minute":240.0,"magazine_capacity":7,"starting_reserve":70,"reload_duration":1.6,"fire_mode":1}},
	{"id":"svt","name":"СВТ","description":"Самозарядная винтовка. Мощный одиночный огонь и небольшой магазин.","length":58.0,"axis":.36,"grip":.37,"front":.63,"barrel":.30,"stats":[.95,.95,.85,.4,.35],"values":{"damage":65.0,"rounds_per_minute":180.0,"magazine_capacity":10,"starting_reserve":80,"reload_duration":2.8,"fire_mode":1}}]

static func index_for(id: String) -> int:
	for index in WEAPONS.size():
		if WEAPONS[index].id == id: return index
	return 0

static func equip(controller: CoreShootingController,id: String) -> void:
	controller.equipped_weapon_id = WEAPONS[index_for(id)].id
	controller.tuning.apply_values(WEAPONS[index_for(id)].values)
	controller.apply_tuning()
	controller.refill_ammunition()

static func draw_weapon(canvas: Node2D,id: String,breech: Vector2,direction: Vector2,normal: Vector2) -> void:
	var index := index_for(id)
	var data: Dictionary = WEAPONS[index]
	var texture := ART.weapon(index)
	var size := Vector2(data.length,data.length*texture.get_height()/texture.get_width())
	canvas.draw_set_transform_matrix(Transform2D(direction,normal,breech))
	canvas.draw_texture_rect(texture,Rect2(Vector2(-size.x*data.grip,-size.y*data.axis),size),false)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
