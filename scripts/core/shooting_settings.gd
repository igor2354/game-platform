class_name CoreShootingSettings
extends Resource

const SAVE_PATH := "user://core_shooting.cfg"
const SWITCHES := [
	["weapon_enabled", "Оружие включено", "Оружие", "Отключает стрельбу, прицеливание и перезарядку, сохраняя боезапас."],
	["hip_enabled", "Стрельба от бедра включена", "От бедра", "Выключено: стрелять можно только при прицеливании, если оно включено."],
	["ads_enabled", "Прицеливание включено", "Прицел", "Отключает ПКМ, точный прицел и замедление при прицеливании."],
	["recoil_enabled", "Отдача включена", "Отдача", "Подброс и увод перекрестия меняют направление пуль и оружия. Выключение убирает также откат и тряску камеры; разброс независим."],
	["recoil_continuous_enabled", "Непрерывный подброс и увод", "Отдача", "Каждый выстрел продолжает смещать прицел без углового предела. Мышь работает относительно движения, без упора в край рабочего стола."],
	["recoil_auto_enabled", "Автокомпенсация отдачи", "Отдача", "Возвращает только оставшуюся отдачу. Уже компенсированное мышью движение повторно не вычитается. Не выбирает цели."],
	["recoil_auto_during_fire", "Автокомпенсация во время очереди", "Отдача", "Включено: возврат увода начинается после заданной паузы от начала очереди. Выключено: после паузы с последнего выстрела. Ручная компенсация работает всегда."],
	["hide_cursor_in_game", "Скрывать курсор в игре", "Отдача", "Перекрестие остаётся видимым. Выключено: дополнительная стрелка совпадает с перекрестием. В меню и на паузе обычный курсор виден всегда."],
	["sound_enabled", "Звуки оружия включены", "Звук", "Отключает выстрелы, попадания, убийства, перезарядку и звуковые предупреждения боезапаса."],
	["damage_enabled", "Урон пуль включён", "Урон", "Пули попадают и отмечают попадание, но не снимают HP и не отрывают конечности. Физические импульсы предметам сохраняются."],
	["magazine_enabled", "Магазин и перезарядка включены", "Магазин", "Выключено: стрельба без расхода патронов и без перезарядки. Реальный боезапас сохраняется."],
	["movement_spread_enabled", "Разброс от движения включён", "Разброс в движении", "Выключение сразу убирает штраф за движение. Базовый разброс и рост при очереди сохраняются."]
]
@export var weapon_enabled := true
@export var hip_enabled := true
@export var ads_enabled := true
@export var recoil_enabled := true
@export var recoil_continuous_enabled := false
@export var recoil_auto_enabled := true
@export var recoil_auto_during_fire := true
@export var hide_cursor_in_game := true
@export var sound_enabled := true
@export var damage_enabled := true
@export var magazine_enabled := true
@export var movement_spread_enabled := true

enum FireMode { AUTO, SINGLE }
const PARAMS := [
	["rounds_per_minute","Темп стрельбы",120.0,1800.0,10.0,"/мин","Оружие"],
	["bullet_speed","Скорость пули",600.0,4000.0,50.0,"px/с","Оружие"],
	["damage","Урон",5.0,100.0,5.0,"HP","Оружие"],
	["magazine_capacity","Вместимость магазина",1.0,150.0,1.0,"патронов","Магазин"],
	["starting_reserve","Запас при старте",0.0,1000.0,1.0,"патронов","Магазин"],
	["reload_duration","Время перезарядки",.5,6.0,.05,"с","Магазин"],
	["reload_move_multiplier","Скорость при перезарядке",.2,1.0,.05,"доля","Магазин"],
	["hip_spread","Начальный разброс ±",0.0,15.0,.5,"°","От бедра"],
	["hip_max_spread","Максимальный разброс ±",0.0,35.0,.5,"°","От бедра"],
	["spread_per_shot","Рост разброса за выстрел",0.0,5.0,.05,"°","От бедра"],
	["spread_recovery","Восстановление разброса",2.0,60.0,1.0,"°/с","От бедра"],
	["hip_move_multiplier","Скорость при очереди",.3,1.0,.05,"доля","От бедра"],
	["hip_slow_ramp","Время нарастания замедления",.05,1.0,.05,"с","От бедра"],
	["movement_spread_forward","При движении вперёд · добавка ±",0.0,35.0,.1,"°","Разброс в движении"],
	["movement_spread_backward","При движении назад · добавка ±",0.0,35.0,.1,"°","Разброс в движении"],
	["movement_spread_start_speed","Скорость начала штрафа",0.0,1000.0,5.0,"px/с","Разброс в движении"],
	["movement_spread_full_speed","Скорость полного штрафа",10.0,2000.0,5.0,"px/с","Разброс в движении"],
	["movement_spread_rise_time","Плавность нарастания",0.0,2.0,.05,"с","Разброс в движении"],
	["movement_spread_recovery_time","Плавность восстановления",0.0,3.0,.05,"с","Разброс в движении"],
	["movement_spread_ads_multiplier","Штраф в прицеле",0.0,2.0,.05,"×","Разброс в движении"],
	["ads_move_multiplier","Скорость в прицеле",.1,1.0,.05,"доля","Прицел"],
	["sway_radius","Амплитуда покачивания",0.0,40.0,1.0,"px","Прицел"],
	["sway_frequency","Частота покачивания",.1,3.0,.1,"Гц","Прицел"],
	["aim_mouse_sensitivity","Чувствительность прицела",.1,3.0,.001,"×","Отдача"],
	["recoil_auto_input_grace","Пауза автокомпенсации после мыши",0.0,.5,.001,"с","Отдача"],
	["recoil_auto_retarget_threshold","Порог ручного перенаведения",0.0,120.0,.001,"px экрана","Отдача"],
	["hip_recoil_auto_strength","Интенсивность автокомпенсации",0.0,2.0,.001,"×","Отдача"],
	["ads_recoil_auto_strength","Интенсивность автокомпенсации в прицеле",0.0,2.0,.001,"×","Отдача"],
	["recoil_angle","Подброс за выстрел",0.0,15.0,.001,"°","Отдача"],
	["recoil_return","Плавность возврата подброса",5.0,60.0,.01,"/с","Отдача"],
	["hip_recoil_climb","Увод вверх за выстрел",0.0,8.0,.001,"°","Отдача"],
	["hip_recoil_max_angle","Предел подброса и увода",0.0,60.0,.001,"°","Отдача"],
	["hip_recoil_return_delay","Пауза перед возвратом увода",0.0,2.0,.001,"с","Отдача"],
	["hip_recoil_climb_recovery","Скорость возврата увода",0.0,60.0,.001,"°/с","Отдача"],
	["hip_recoil_horizontal","Случайный увод вбок за выстрел ±",0.0,5.0,.001,"°","Отдача"],
	["hip_recoil_horizontal_bias","Постоянный увод вбок за выстрел",-3.0,3.0,.001,"°","Отдача"],
	["hip_recoil_horizontal_limit","Предел бокового увода ±",0.0,20.0,.001,"°","Отдача"],
	["hip_recoil_first_shot_multiplier","Подброс первого выстрела",0.0,3.0,.001,"×","Отдача"],
	["ads_recoil_angle","Подброс за выстрел в прицеле",0.0,15.0,.001,"°","Отдача"],
	["ads_recoil_return","Плавность возврата подброса в прицеле",5.0,60.0,.01,"/с","Отдача"],
	["ads_recoil_climb","Увод вверх за выстрел в прицеле",0.0,8.0,.001,"°","Отдача"],
	["ads_recoil_max_angle","Предел подброса и увода в прицеле",0.0,60.0,.001,"°","Отдача"],
	["ads_recoil_return_delay","Пауза перед возвратом в прицеле",0.0,2.0,.001,"с","Отдача"],
	["ads_recoil_climb_recovery","Скорость возврата увода в прицеле",0.0,60.0,.001,"°/с","Отдача"],
	["ads_recoil_horizontal","Боковой случайный увод в прицеле ±",0.0,5.0,.001,"°","Отдача"],
	["ads_recoil_horizontal_bias","Постоянный увод вбок в прицеле",-3.0,3.0,.001,"°","Отдача"],
	["ads_recoil_horizontal_limit","Предел бокового увода в прицеле ±",0.0,20.0,.001,"°","Отдача"],
	["ads_recoil_first_shot_multiplier","Подброс первого выстрела в прицеле",0.0,3.0,.001,"×","Отдача"],
	["recoil_back","Откат оружия",0.0,12.0,.01,"px","Отдача"],
	["ads_recoil_back_multiplier","Откат оружия в прицеле",0.0,1.0,.001,"×","Отдача"],
	["ads_recoil_camera_multiplier","Толчок камеры в прицеле",0.0,2.0,.001,"×","Отдача"],
	["camera_kick","Толчок камеры",0.0,8.0,.01,"px","Отдача"],
	["camera_shake","Дрожание камеры",0.0,5.0,.01,"px","Отдача"],
	["camera_return","Возврат камеры",5.0,60.0,.01,"/с","Отдача"],
	["kill_camera_boost","Усиление при убийстве",0.0,4.0,.01,"×","Отдача"],
	["shot_volume","Громкость выстрела",-40.0,0.0,1.0,"dB","Звук"],
	["hit_volume","Громкость попадания",-40.0,0.0,1.0,"dB","Звук"],
	["kill_volume","Громкость убийства",-40.0,0.0,1.0,"dB","Звук"],
	["reload_volume","Громкость перезарядки",-40.0,0.0,1.0,"dB","Звук"],
	["low_ammo_threshold","Порог малого остатка",0.0,.5,.01,"доля","Звук"],
	["low_ammo_pitch","Тон при малом остатке",.7,1.7,.01,"×","Звук"],
	["last_shot_accent","Акцент последнего выстрела",0.0,2.0,.05,"×","Звук"],
	["head_damage_multiplier","Урон в голову",.5,5.0,.1,"×","Урон"],
	["torso_damage_multiplier","Урон в туловище",.25,3.0,.05,"×","Урон"],
	["arm_damage_multiplier","Урон в здоровье через руки",0.0,1.0,.05,"×","Урон"],
	["leg_damage_multiplier","Урон в здоровье через ноги",0.0,1.0,.05,"×","Урон"],
	["arm_durability","Прочность каждой руки",5.0,200.0,5.0,"HP","Урон"],
	["leg_durability","Прочность каждой ноги",5.0,200.0,5.0,"HP","Урон"]]

@export var rounds_per_minute := 1000.0
@export var bullet_speed := 2400.0
@export var damage := 25.0
@export var magazine_capacity := 71
@export var starting_reserve := 213
@export var reload_duration := 2.4
@export var reload_move_multiplier := .75
@export var reload_volume := -18.0
@export var low_ammo_threshold := .30
@export var low_ammo_pitch := 1.30
@export var last_shot_accent := 1.0
@export var hip_spread := 3.0
@export var hip_max_spread := 16.0
@export var spread_per_shot := 1.25
@export var spread_recovery := 18.0
@export var hip_move_multiplier := .65
@export var hip_slow_ramp := .25
@export var movement_spread_forward := 3.0
@export var movement_spread_backward := 6.0
@export var movement_spread_start_speed := 10.0
@export var movement_spread_full_speed := 320.0
@export var movement_spread_rise_time := .15
@export var movement_spread_recovery_time := .30
@export var movement_spread_ads_multiplier := 0.0
@export var ads_move_multiplier := .30
@export var sway_radius := 10.0
@export var sway_frequency := .7
@export_enum("Автоматический","Одиночный") var fire_mode: int = FireMode.AUTO
@export var recoil_back := 5.0
@export var aim_mouse_sensitivity := 1.0
@export var recoil_auto_input_grace := .06
@export var recoil_auto_retarget_threshold := 8.0
@export var hip_recoil_auto_strength := 1.0
@export var ads_recoil_auto_strength := 1.0
@export var recoil_angle := 2.4
@export var recoil_return := 24.0
@export var hip_recoil_climb := .65
@export var hip_recoil_max_angle := 18.0
@export var hip_recoil_return_delay := .18
@export var hip_recoil_climb_recovery := 8.0
@export var hip_recoil_horizontal := .25
@export var hip_recoil_horizontal_bias := 0.0
@export var hip_recoil_horizontal_limit := 3.0
@export var hip_recoil_first_shot_multiplier := 1.0
@export var ads_recoil_angle := 1.2
@export var ads_recoil_return := 24.0
@export var ads_recoil_climb := .35
@export var ads_recoil_max_angle := 12.0
@export var ads_recoil_return_delay := .22
@export var ads_recoil_climb_recovery := 6.0
@export var ads_recoil_horizontal := .12
@export var ads_recoil_horizontal_bias := 0.0
@export var ads_recoil_horizontal_limit := 2.0
@export var ads_recoil_first_shot_multiplier := 1.0
@export var ads_recoil_back_multiplier := .55
@export var ads_recoil_camera_multiplier := .55
@export var camera_kick := 2.8
@export var camera_shake := 1.2
@export var camera_return := 22.0
@export var kill_camera_boost := 1.8
@export var shot_volume := -18.0
@export var hit_volume := -13.0
@export var kill_volume := -10.0
@export var head_damage_multiplier := 2.0
@export var torso_damage_multiplier := 1.0
@export var arm_damage_multiplier := .25
@export var leg_damage_multiplier := .35
@export var arm_durability := 50.0
@export var leg_durability := 50.0

func as_dictionary() -> Dictionary:
	var values := {}
	for entry in SWITCHES: values[entry[0]] = get(entry[0])
	for param in PARAMS: values[param[0]] = get(param[0])
	values["fire_mode"] = fire_mode
	return values
func apply_values(values: Dictionary) -> void:
	for entry in SWITCHES:
		if values.get(entry[0]) is bool: set(entry[0],values[entry[0]])
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
	magazine_capacity = clampi(magazine_capacity,1,150)
	starting_reserve = clampi(starting_reserve,0,1000)
	hip_max_spread = maxf(hip_spread,hip_max_spread)
	movement_spread_full_speed = maxf(movement_spread_start_speed+1,movement_spread_full_speed)
func save_saved(path := SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	for key in as_dictionary(): config.set_value("shooting",key,get(key))
	return config.save(path)
func load_saved(path := SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	var result := config.load(path)
	if result != OK: return result
	var defaults := CoreShootingSettings.new()
	var values := {}
	for key in as_dictionary(): values[key] = config.get_value("shooting",key,defaults.get(key))
	apply_values(values)
	return OK
func as_text() -> String:
	var lines := PackedStringArray()
	for key in as_dictionary(): lines.append("%s = %s" % [key,str(get(key))])
	return "\n".join(lines)
