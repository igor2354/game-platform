class_name CoreCameraSettings
extends Resource

const SAVE_PATH := "user://core_camera.cfg"
# Offset and look-ahead use screen pixels, so zoom keeps the chosen framing.
const PARAMS := [
	["zoom","Приближение",.5,3.0,.05,"×","Камера"],
	["offset_x","Камера от героя · X",-600.0,600.0,1.0,"px экрана","Камера"],
	["offset_y","Камера от героя · Y",-450.0,450.0,1.0,"px экрана","Камера"],
	["look_ahead","Упреждение по направлению",0.0,350.0,1.0,"px экрана","Камера"],
	["follow_speed","Плавность: скорость слежения",0.0,30.0,.5,"/с","Камера"]
]
@export var zoom := 1.0
@export var offset_x := 0.0
@export var offset_y := -278.0
@export var look_ahead := 64.0
@export var follow_speed := 8.0
@export var limit_to_level := true

func as_dictionary() -> Dictionary:
	var values := {"limit_to_level":limit_to_level}
	for param in PARAMS: values[param[0]] = get(param[0])
	return values
func apply_values(values: Dictionary) -> void:
	for param in PARAMS:
		var value = values.get(param[0],get(param[0]))
		if (value is float or value is int) and is_finite(float(value)):
			set(param[0],clampf(float(value),float(param[2]),float(param[3])))
	if values.get("limit_to_level") is bool: limit_to_level = values.limit_to_level
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
	apply_values(values)
	return OK
func as_text() -> String:
	var lines := PackedStringArray()
	for key in as_dictionary(): lines.append("%s = %s" % [key,str(get(key))])
	return "\n".join(lines)
