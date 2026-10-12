class_name CoreZombieSettings
extends Resource

const SAVE_PATH := "user://core_zombie.cfg"
const PARAMS := [
	["detection_range","Дальность обнаружения",32.0,1200.0,1.0,"px","Зрение"],
	["vision_angle","Угол обзора перед собой",20.0,180.0,5.0,"°","Зрение"],
	["vision_offset_x","Смещение конуса · X",-120.0,120.0,1.0,"px","Зрение"],
	["forget_range","Дальность удержания цели",32.0,1600.0,1.0,"px","Зрение"],
	["lose_sight_delay","Время до потери цели",.1,10.0,.1,"с","Зрение"],
	["hearing_range","Радиус слуха · 360°",0.0,800.0,1.0,"px","Слух"],
	["shot_noise_multiplier","Шум выстрела",0.0,10.0,.1,"×","Слух"],
	["movement_noise_multiplier","Шум движения",0.0,3.0,.05,"×","Слух"],
	["noise_occlusion_multiplier","Слышимость через преграду",0.0,1.0,.05,"×","Слух"],
	["noise_memory_time","Память услышанного шума",.1,15.0,.1,"с","Слух"],
	["patrol_radius","Радиус патруля от старта",32.0,600.0,1.0,"px","Движение"],
	["patrol_speed","Скорость патруля и возврата",10.0,240.0,1.0,"px/с","Движение"],
	["chase_speed","Скорость преследования",10.0,320.0,1.0,"px/с","Движение"],
	["crawl_speed","Скорость ползания",0.0,100.0,1.0,"px/с","Движение"],
	["attack_range","Дальность удара",30.0,120.0,1.0,"px","Бой"],
	["attack_damage","Урон удара двумя руками",1.0,100.0,1.0,"HP","Бой"],
	["attack_windup","Время замаха",.1,2.0,.05,"с","Бой"],
	["attack_recovery","Восстановление после удара",.2,3.0,.05,"с","Бой"]
]
@export var detection_range := 360.0
@export var vision_angle := 120.0
@export var vision_offset_x := 0.0
@export var forget_range := 540.0
@export var lose_sight_delay := 1.5
@export var hearing_range := 180.0
@export var shot_noise_multiplier := 4.0
@export var movement_noise_multiplier := 1.0
@export var noise_occlusion_multiplier := .5
@export var noise_memory_time := 5.0
@export var patrol_radius := 180.0
@export var patrol_speed := 55.0
@export var chase_speed := 105.0
@export var crawl_speed := 22.0
@export var attack_range := 58.0
@export var attack_damage := 15.0
@export var attack_windup := .4
@export var attack_recovery := .8

func as_dictionary() -> Dictionary:
	var values := {}
	for param in PARAMS: values[param[0]] = get(param[0])
	return values
func apply_values(values: Dictionary) -> void:
	for param in PARAMS:
		var value = values.get(param[0],get(param[0]))
		if (value is float or value is int) and is_finite(float(value)):
			set(param[0],clampf(float(value),float(param[2]),float(param[3])))
	forget_range = maxf(detection_range,forget_range)
func set_parameter(key: String,value: float) -> void:
	if not is_finite(value): return
	for param in PARAMS:
		if param[0] == key:
			apply_values({key:snappedf(value,float(param[4]))})
			return
func save_saved(path := SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	for key in as_dictionary(): config.set_value("zombie",key,get(key))
	return config.save(path)
func load_saved(path := SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	var result := config.load(path)
	if result != OK: return result
	var values := {}
	for key in as_dictionary(): values[key] = config.get_value("zombie",key,get(key))
	apply_values(values)
	return OK
func as_text() -> String:
	var lines := PackedStringArray()
	for key in as_dictionary(): lines.append("%s = %s" % [key,str(get(key))])
	return "\n".join(lines)
