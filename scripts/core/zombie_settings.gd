class_name CoreZombieSettings
extends Resource

const SAVE_PATH := "user://core_zombie.cfg"
const SWITCHES := [
	["vision_enabled","Замечать игрока зрением","Зрение","Выключение прекращает зрительное преследование. Слух и попадания остаются независимыми."],
	["hearing_enabled","Слышать игрока","Слух","Выключение очищает память шума и прекращает его поиск. Зрение и попадания остаются независимыми."],
	["movement_enabled","Двигаться самостоятельно","Движение","Выключает патруль, погоню и поиск, включая ползание. Обнаружение и атаки продолжают работать; гравитация и внешние толчки сохраняются."],
	["combat_enabled","Атаковать в ближнем бою","Бой","Выключение отменяет текущий замах и новые удары. Сбрасывание игрока настраивается отдельно."],
	["crawl_enabled","Ползать при потере ноги","Ползание","Выключает самостоятельное ползание. Зомби остаётся лежать, но может замечать и атаковать игрока. Для ползания также нужно включить движение."],
	["shove_enabled","Сбрасывать игрока","Сбрасывание","Выключение отменяет подготовку сбрасывания. Обычная ближняя атака настраивается отдельно."],
	["damage_reaction_enabled","Реагировать на попадания игрока","Попадания","Выключает реакцию ИИ на попадания. Урон и потеря конечностей продолжают работать."],
	["stun_enabled","Поддаваться ошеломлению","Ошеломление","Дэш сквозь зомби прерывает его действия. Выключение сразу снимает ошеломление; остальные настройки сохраняются."]
]
@export var vision_enabled := true
@export var hearing_enabled := true
@export var movement_enabled := true
@export var combat_enabled := true
@export var crawl_enabled := true
@export var shove_enabled := true
@export var stun_enabled := true
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
	["crawl_speed","Скорость на ровной поверхности",0.0,100.0,1.0,"px/с","Ползание"],
	["crawl_max_angle","Допустимый угол склона",0.0,60.0,1.0,"°","Ползание"],
	["crawl_uphill_multiplier","Скорость вверх",.1,2.0,.05,"×","Ползание"],
	["crawl_downhill_multiplier","Скорость вниз",.1,2.0,.05,"×","Ползание"],
	["crawl_step_height","Высота небольшой ступени",0.0,24.0,1.0,"px","Ползание"],
	["attack_range","Дальность удара",30.0,120.0,1.0,"px","Бой"],
	["attack_damage","Урон удара двумя руками",1.0,100.0,1.0,"HP","Бой"],
	["attack_windup","Время замаха",.1,2.0,.05,"с","Бой"],
	["attack_recovery","Восстановление после удара",.2,3.0,.05,"с","Бой"],
	["shove_delay","Задержка сбрасывания",.15,1.5,.05,"с","Сбрасывание"],
	["shove_speed","Толчок в сторону",100.0,600.0,10.0,"px/с","Сбрасывание"],
	["shove_lift","Толчок вверх",80.0,360.0,10.0,"px/с","Сбрасывание"],
	["shove_damage","Урон при сбрасывании",0.0,100.0,1.0,"HP","Сбрасывание"],
	["shove_cooldown","Перерыв между толчками",.4,3.0,.1,"с","Сбрасывание"],
	["damage_memory_time","Память источника урона",.1,15.0,.1,"с","Попадания"],
	["damage_chase_multiplier","Скорость к источнику урона",.1,3.0,.05,"×","Попадания"],
	["dash_stun_duration","Ошеломление от дэша",.1,10.0,.1,"с","Ошеломление"]
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
@export var crawl_max_angle := 45.0
@export var crawl_uphill_multiplier := .65
@export var crawl_downhill_multiplier := 1.15
@export var crawl_step_height := 12.0
@export var attack_range := 58.0
@export var attack_damage := 15.0
@export var attack_windup := .4
@export var attack_recovery := .8
@export var shove_delay := .45
@export var shove_speed := 260.0
@export var shove_lift := 180.0
@export var shove_damage := 10.0
@export var shove_cooldown := 1.2
@export var damage_reaction_enabled := true
@export var damage_memory_time := 1.5
@export var damage_chase_multiplier := 1.0
@export var dash_stun_duration := 1.5

func as_dictionary() -> Dictionary:
	var values := {}
	for entry in SWITCHES: values[entry[0]] = get(entry[0])
	for param in PARAMS: values[param[0]] = get(param[0])
	return values
func crawl_slope_multiplier(angle: float,uphill: bool) -> float:
	if angle < .01: return 1.0
	var weight := clampf(angle/maxf(.01,crawl_max_angle),0,1)
	return lerpf(1.0,crawl_uphill_multiplier if uphill else crawl_downhill_multiplier,weight)
func apply_values(values: Dictionary) -> void:
	for param in PARAMS:
		var value = values.get(param[0],get(param[0]))
		if (value is float or value is int) and is_finite(float(value)):
			set(param[0],clampf(float(value),float(param[2]),float(param[3])))
	forget_range = maxf(detection_range,forget_range)
	for entry in SWITCHES:
		if values.get(entry[0]) is bool: set(entry[0],values[entry[0]])
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
