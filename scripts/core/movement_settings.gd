class_name CoreMovementSettings
extends Resource

const SAVE_PATH := "user://core_movement.cfg"
# key, label, minimum, maximum, step, unit, group
const PARAMS := [
	["run_speed","Скорость бега",100.0,750.0,10.0,"px/с","Бег"],
	["acceleration","Разгон",200.0,6000.0,50.0,"px/с²","Бег"],
	["braking","Торможение",200.0,8000.0,50.0,"px/с²","Бег"],
	["air_acceleration","Управление в воздухе",200.0,4000.0,50.0,"px/с²","Бег"],
	["jump_speed","Сила прыжка",200.0,1200.0,10.0,"px/с","Прыжок"],
	["jump_cut_speed","Импульс после отпускания",80.0,1200.0,10.0,"px/с","Прыжок"],
	["gravity","Гравитация",500.0,4000.0,50.0,"px/с²","Прыжок"],
	["fall_speed","Максимальная скорость падения",300.0,2400.0,50.0,"px/с","Прыжок"],
	["coyote_time","Прыжок после края",0.0,.30,.01,"с","Прыжок"],
	["jump_buffer_time","Буфер перед приземлением",0.0,.30,.01,"с","Прыжок"],
	["dash_speed","Скорость дэша",300.0,1500.0,10.0,"px/с","Дэш"],
	["dash_duration","Длительность дэша",.06,.60,.01,"с","Дэш"],
	["dash_cooldown","Восстановление от старта",.10,2.0,.01,"с","Дэш"],
	["climb_speed","Скорость подъёма и спуска",40.0,450.0,10.0,"px/с","Лестница"],
	["ladder_snap_speed","Скорость притягивания",60.0,500.0,10.0,"px/с","Лестница"],
	["ladder_regrab_delay","Задержка повторного захвата",.05,.80,.01,"с","Лестница"]
]

@export_category("Бег")
@export var run_speed := 320.0
@export var acceleration := 2400.0
@export var braking := 3000.0
@export var air_acceleration := 1500.0
@export_category("Прыжок")
@export var gravity := 1900.0
@export var fall_speed := 1100.0
@export var jump_speed := 720.0
@export var jump_cut_speed := 260.0
@export var coyote_time := .10
@export var jump_buffer_time := .12
@export_category("Дэш")
@export var dash_speed := 760.0
@export var dash_duration := .16
@export var dash_cooldown := .42
@export_category("Лестница")
@export var climb_speed := 180.0
@export var ladder_snap_speed := 180.0
@export var ladder_regrab_delay := .22

func as_dictionary() -> Dictionary:
	var values := {}
	for param in PARAMS: values[param[0]] = get(param[0])
	return values

func apply_values(values: Dictionary) -> void:
	for param in PARAMS:
		var value = values.get(param[0],get(param[0]))
		if (value is float or value is int) and is_finite(float(value)):
			set(param[0],clampf(float(value),float(param[2]),float(param[3])))
	_normalize()

func set_parameter(key: String,value: float) -> void:
	if not is_finite(value): return
	for param in PARAMS:
		if param[0] == key:
			set(key,clampf(snappedf(value,float(param[4])),float(param[2]),float(param[3])))
			_normalize()
			return

func _normalize() -> void:
	jump_cut_speed = minf(jump_cut_speed,jump_speed)
	dash_cooldown = maxf(dash_cooldown,dash_duration)

func save_saved(path := SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	for param in PARAMS: config.set_value("movement",param[0],get(param[0]))
	return config.save(path)

func load_saved(path := SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	var result := config.load(path)
	if result != OK: return result
	var values := {}
	for param in PARAMS: values[param[0]] = config.get_value("movement",param[0],get(param[0]))
	apply_values(values)
	return OK

func as_text() -> String:
	var lines := PackedStringArray()
	for param in PARAMS: lines.append("%s = %s" % [param[0],str(get(param[0]))])
	return "\n".join(lines)
