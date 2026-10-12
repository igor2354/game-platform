class_name CoreShootingSettings
extends Resource

const SAVE_PATH := "user://core_shooting.cfg"
enum FireMode { AUTO, SINGLE }
const PARAMS := [
	["rounds_per_minute","Темп стрельбы",120.0,1800.0,10.0,"/мин","Оружие"],
	["bullet_speed","Скорость пули",600.0,4000.0,50.0,"px/с","Оружие"],
	["damage","Урон",5.0,100.0,5.0,"HP","Оружие"],
	["hip_spread","Начальный разброс ±",0.0,15.0,.5,"°","От бедра"],
	["hip_max_spread","Максимальный разброс ±",0.0,35.0,.5,"°","От бедра"],
	["spread_per_shot","Рост разброса за выстрел",0.0,5.0,.05,"°","От бедра"],
	["spread_recovery","Восстановление разброса",2.0,60.0,1.0,"°/с","От бедра"],
	["hip_move_multiplier","Скорость при очереди",.3,1.0,.05,"доля","От бедра"],
	["hip_slow_ramp","Время нарастания замедления",.05,1.0,.05,"с","От бедра"],
	["ads_move_multiplier","Скорость в прицеле",.1,1.0,.05,"доля","Прицел"],
	["sway_radius","Амплитуда покачивания",0.0,40.0,1.0,"px","Прицел"],
	["sway_frequency","Частота покачивания",.1,3.0,.1,"Гц","Прицел"],
	["recoil_back","Откат оружия",0.0,12.0,.5,"px","Отдача"],
	["recoil_angle","Подброс ствола",0.0,8.0,.2,"°","Отдача"],
	["recoil_return","Возврат оружия",5.0,60.0,1.0,"/с","Отдача"],
	["camera_kick","Толчок камеры",0.0,8.0,.2,"px","Отдача"],
	["camera_shake","Дрожание камеры",0.0,5.0,.1,"px","Отдача"],
	["camera_return","Возврат камеры",5.0,60.0,1.0,"/с","Отдача"],
	["kill_camera_boost","Усиление при убийстве",0.0,4.0,.1,"×","Отдача"],
	["shot_volume","Громкость выстрела",-40.0,0.0,1.0,"dB","Звук"],
	["hit_volume","Громкость попадания",-40.0,0.0,1.0,"dB","Звук"],
	["kill_volume","Громкость убийства",-40.0,0.0,1.0,"dB","Звук"]]

@export var rounds_per_minute := 1000.0
@export var bullet_speed := 2400.0
@export var damage := 25.0
@export var hip_spread := 3.0
@export var hip_max_spread := 16.0
@export var spread_per_shot := 1.25
@export var spread_recovery := 18.0
@export var hip_move_multiplier := .65
@export var hip_slow_ramp := .25
@export var ads_move_multiplier := .30
@export var sway_radius := 10.0
@export var sway_frequency := .7
@export_enum("Автоматический","Одиночный") var fire_mode: int = FireMode.AUTO
@export var recoil_back := 5.0
@export var recoil_angle := 2.4
@export var recoil_return := 24.0
@export var camera_kick := 2.8
@export var camera_shake := 1.2
@export var camera_return := 22.0
@export var kill_camera_boost := 1.8
@export var shot_volume := -18.0
@export var hit_volume := -13.0
@export var kill_volume := -10.0

func as_dictionary() -> Dictionary:
	var values := {}
	for param in PARAMS: values[param[0]] = get(param[0])
	values["fire_mode"] = fire_mode
	return values
func apply_values(values: Dictionary) -> void:
	for param in PARAMS:
		var value = values.get(param[0],get(param[0]))
		if (value is int or value is float) and is_finite(float(value)):
			set(param[0],clampf(float(value),param[2],param[3]))
	_normalize()
	var mode = values.get("fire_mode",fire_mode)
	if (mode is int or mode is float) and is_finite(float(mode)): set_fire_mode(int(mode))
func set_fire_mode(mode: int) -> void:
	fire_mode = clampi(mode,FireMode.AUTO,FireMode.SINGLE)
func set_parameter(key: String,value: float) -> void:
	if not is_finite(value): return
	for param in PARAMS:
		if param[0] == key:
			set(key,clampf(snappedf(value,param[4]),param[2],param[3]))
			_normalize()
			return
func _normalize() -> void:
	hip_max_spread = maxf(hip_spread,hip_max_spread)
func save_saved(path := SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	for param in PARAMS: config.set_value("shooting",param[0],get(param[0]))
	config.set_value("shooting","fire_mode",fire_mode)
	return config.save(path)
func load_saved(path := SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	var result := config.load(path)
	if result != OK: return result
	var values := {}
	for param in PARAMS: values[param[0]] = config.get_value("shooting",param[0],get(param[0]))
	values["fire_mode"] = config.get_value("shooting","fire_mode",fire_mode)
	apply_values(values)
	return OK
func as_text() -> String:
	var lines := PackedStringArray()
	for param in PARAMS: lines.append("%s = %s" % [param[0],str(get(param[0]))])
	lines.append("fire_mode = %d" % fire_mode)
	return "\n".join(lines)
