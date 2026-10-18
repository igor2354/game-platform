class_name CoreCameraSettings
extends Resource

const SAVE_PATH := "user://core_camera.cfg"
const SWITCHES := [
	["camera_enabled", "Слежение камеры включено", "Камера", "Выключено: камера остаётся на месте. Настройки сохраняются до повторного включения."],
	["map_enabled", "Карта уровня включена", "Визуал", "Выключено: карта не открывается по M. Схема строится по геометрии уровня и сохраняет настройки отображения."],
	["visual_enabled", "Эффекты героя включены", "Визуал", "Отключает блюр и сглаживание героя, сохраняя их настройки."],
	["deform_skin_enabled", "Гарри: деформируемый рисунок", "Визуал", "Цельные рукава и ноги на сетке. Выключение возвращает прежний сегментный облик и сохраняет параметры."],
	["sofia_cels_enabled", "София: рисованные кадры на полигоне", "Визуал", "Цельные кадры с собственной анатомией; физика получает их текущую позу. Выключение возвращает прежний облик. Пролог не меняется."]
]
@export var camera_enabled := true
@export var map_enabled := true
@export var visual_enabled := true
@export var deform_skin_enabled := true
@export var deform_mesh_debug := false
@export var sofia_cels_enabled := true

# Offset and look-ahead use screen pixels, so zoom keeps the chosen framing.
const PARAMS := [
	["zoom","Приближение",.5,3.0,.05,"×","Камера"],
	["offset_x","Камера от героя · X",-600.0,600.0,1.0,"px экрана","Камера"],
	["offset_y","Камера от героя · Y",-450.0,450.0,1.0,"px экрана","Камера"],
	["look_ahead","Упреждение по направлению",0.0,350.0,1.0,"px экрана","Камера"],
	["vertical_aim_deadzone","Допуск разворота у вертикали",0.0,80.0,1.0,"°","Камера"],
	["follow_speed","Плавность: скорость слежения",0.0,30.0,.5,"/с","Камера"],
	["look_turn_duration","Плавность смены стороны · время",0.0,1.5,.05,"с","Камера"],
	["character_blur_strength","Интенсивность блюра героя",0.0,1.0,.05,"×","Визуал"],
	["character_blur_length","Максимальное размытие",0.0,32.0,1.0,"px экрана","Визуал"],
	["character_blur_start_speed","Блюр от скорости",0.0,1000.0,10.0,"px/с","Визуал"],
	["deform_pose_smoothing","Гарри: плавность перехода поз",0.0,.20,.01,"с","Визуал"],
	["deform_joint_volume","Гарри: объём локтей и коленей",0.0,1.2,.05,"×","Визуал"],
	["sofia_cel_correction","София: поправка головы к прицелу",0.0,1.0,.05,"×","Визуал"]
]
@export var zoom := 1.0
@export var offset_x := 0.0
@export var offset_y := -278.0
@export var look_ahead := 64.0
@export var vertical_aim_deadzone := 35.0
@export var follow_speed := 8.0
@export var look_turn_duration := .35
@export var limit_to_level := true
@export_category("Визуал")
@export var character_blur_strength := 0.0
@export var character_blur_length := 12.0
@export var character_blur_start_speed := 80.0
@export var character_linear_filter := false
@export var deform_pose_smoothing := .06
@export var deform_joint_volume := .65
@export var sofia_cel_correction := .25

func framing_values() -> Dictionary:
	return {"zoom":zoom,"offset_x":offset_x,"offset_y":offset_y,"look_ahead":look_ahead,"follow_speed":follow_speed,"limit_to_level":limit_to_level,"camera_enabled":camera_enabled}

func as_dictionary() -> Dictionary:
	var values := {"limit_to_level":limit_to_level,"character_linear_filter":character_linear_filter,"deform_mesh_debug":deform_mesh_debug}
	for entry in SWITCHES: values[entry[0]] = get(entry[0])
	for param in PARAMS: values[param[0]] = get(param[0])
	return values
func apply_values(values: Dictionary) -> void:
	for entry in SWITCHES:
		if values.get(entry[0]) is bool: set(entry[0],values[entry[0]])
	for param in PARAMS:
		var value = values.get(param[0],get(param[0]))
		if (value is float or value is int) and is_finite(float(value)):
			set(param[0],clampf(float(value),float(param[2]),float(param[3])))
	if values.get("limit_to_level") is bool: limit_to_level = values.limit_to_level
	if values.get("character_linear_filter") is bool: character_linear_filter = values.character_linear_filter
	if values.get("deform_mesh_debug") is bool: deform_mesh_debug = values.deform_mesh_debug
func set_parameter(key: String,value: float) -> void:
	if not is_finite(value): return
	for param in PARAMS:
		if param[0] == key:
			set(key,clampf(snappedf(value,float(param[4])),float(param[2]),float(param[3])))
			return
func save_saved(path := SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	for key in as_dictionary(): config.set_value("camera",key,get(key))
	return config.save(path)
func load_saved(path := SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	var result := config.load(path)
	if result != OK: return result
	var values := {}
	for key in as_dictionary(): values[key] = config.get_value("camera",key,get(key))
	for entry in SWITCHES: values[entry[0]] = config.get_value("camera",entry[0],true)
	apply_values(values)
	return OK
func as_text() -> String:
	var lines := PackedStringArray()
	for key in as_dictionary(): lines.append("%s = %s" % [key,str(get(key))])
	return "\n".join(lines)
