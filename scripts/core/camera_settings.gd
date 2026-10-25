class_name CoreCameraSettings
extends Resource

@export var scale_basis_version := 2

const SAVE_PATH := "user://core_camera.cfg"
const SWITCHES := [
	["blocking_overlay_enabled", "Блокинг поверх окружения", "Визуал", "Бирюзовый контур — реальные неподвижные коллизии; жёлтый — зоны лестниц и односторонние платформы. Заливка регулируется ниже. Не меняет физику и не включает остальную отладку F1."],
	["player_scale_enabled", "Изменять общий размер героя", "Размер героя", "Равномерно меняет тело, оружие, коллизии и параметры движения. Базовые числа профиля сохраняются; уровень и камера прежние. Под тесным потолком или во время падения изменение ждёт безопасного места."],
	["camera_enabled", "Слежение камеры включено", "Камера", "Выключено: камера остаётся на месте. Настройки сохраняются до повторного включения."],
	["map_enabled", "Карта уровня включена", "Визуал", "Выключено: карта не открывается по M. Схема строится по геометрии уровня и сохраняет настройки отображения."],
	["visual_enabled", "Эффекты героя включены", "Визуал", "Отключает блюр и сглаживание героя, сохраняя их настройки."],
	["pixel_enabled", "Пиксельный фильтр", "Визуал", "Размер пикселя задаётся ниже. Работает отдельно и вместе с нуаром; интерфейс остаётся чётким."],
	["world_pixel_enabled", "Пиксели закреплены за уровнем", "Сетка уровня", "Постоянная плотность в координатах мира. Приоритет над экранным фильтром и режимом целевой высоты. Интерфейс — полное разрешение."],
	["stable_pixel_enabled", "Стабильный пиксельный мир", "Пиксельный мир", "Низкое разрешение мира и целочисленное увеличение. Интерфейс и все меню — в полном разрешении. Приоритет над старым пиксельным фильтром."],
	["scale_reference_enabled", "Линейка и образцы масштаба на полигоне", "Визуал", "Рабочая сверка по Софии и коллажу. В прологе не создаётся. Размеры образцов ещё не утверждены."],
	["noir_enabled", "Чёрно-белый нуар · красные акценты", "Нуар", "Обрабатывает игровой мир; интерфейс и прицел сохраняют цвет. Выключение сохраняет параметры фильтра."],
	["deform_skin_enabled", "Гарри: деформируемый рисунок", "Визуал", "Цельные рукава и ноги на сетке. Выключение возвращает прежний сегментный облик и сохраняет параметры."],
	["sofia_cels_enabled", "София: рисованные кадры", "Визуал", "Цельные кадры с собственной анатомией на полигоне и в кампании; физика получает их текущую позу. Выключение возвращает прежний облик."],
	["forest_enabled", "Лесные фоны у старта полигона", "Окружение", "4K-лес слева и анимированный лунный лес справа. Коллизии и геометрия прежние. Выключение сохраняет все параметры."],
	["forest_wind_enabled", "Ветер только в листве", "Окружение", "Колебания красной листвы. Стволы, крупные ветви и цельные силуэты елей неподвижны."],
	["forest_clouds_enabled", "Движение облаков", "Окружение", "Мягкая деформация неба; луна остаётся неподвижной."],
	["forest_smoke_enabled", "Движение дыма", "Окружение", "Завихрения трёх нарисованных столбов дыма."],
	["forest_fire_enabled", "Мерцание пожаров", "Окружение", "Подвижность и нерегулярная яркость огня в дальнем городе."],
	["forest_water_enabled", "Рябь и блики ручья", "Окружение", "Локальная анимация нарисованной воды. Игровой физики воды не добавляет."]
]
@export var camera_enabled := true
@export var player_scale_enabled := false
@export var player_scale := 1.0
@export var map_enabled := true
@export var visual_enabled := true
@export var blocking_overlay_enabled := false
@export var blocking_overlay_opacity := .18
@export var noir_enabled := false
@export var pixel_enabled := false
@export var stable_pixel_enabled := false
@export var world_pixel_enabled := false
@export var scale_reference_enabled := false
@export var deform_skin_enabled := true
@export var deform_mesh_debug := false
@export var sofia_cels_enabled := true
@export var forest_enabled := true
@export var forest_wind_enabled := true
@export var forest_clouds_enabled := true
@export var forest_smoke_enabled := true
@export var forest_fire_enabled := true
@export var forest_water_enabled := true

# Offset and look-ahead use screen pixels, so zoom keeps the chosen framing.
const PARAMS := [
	["blocking_overlay_opacity","Прозрачная заливка блокинга",0.0,1.0,.05,"×","Визуал"],
	["player_scale","Общий масштаб героя",.5/CoreWorldUnits.LEGACY_SOFIA_SCALE,4.0/CoreWorldUnits.LEGACY_SOFIA_SCALE,.01,"×","Размер героя"],
	["zoom","Приближение",.5,3.0,.05,"×","Камера"],
	["offset_x","Камера от героя · X",-600.0,600.0,1.0,"px экрана","Камера"],
	["offset_y","Камера от героя · Y",-450.0,450.0,1.0,"px экрана","Камера"],
	["look_ahead","Упреждение по направлению",0.0,350.0,1.0,"px экрана","Камера"],
	["vertical_aim_deadzone","Допуск разворота у вертикали",0.0,80.0,1.0,"°","Камера"],
	["follow_speed","Плавность: скорость слежения",0.0,30.0,.5,"/с","Камера"],
	["look_turn_duration","Плавность смены стороны · время",0.0,1.5,.05,"с","Камера"],
	["pixel_size","Размер пикселя",1.0,16.0,1.0,"px экрана","Визуал"],
	["world_pixel_size","Размер клетки на уровне",.5,8.0,.25,"ед./пиксель","Сетка уровня"],
	["stable_pixel_height","Детализация мира · целевая высота",180.0,1080.0,180.0,"px буфера","Пиксельный мир"],
	["character_blur_strength","Интенсивность блюра героя",0.0,1.0,.05,"×","Визуал"],
	["character_blur_length","Максимальное размытие",0.0,32.0,1.0,"px экрана","Визуал"],
	["character_blur_start_speed","Блюр от скорости",0.0,1000.0,10.0,"px/с","Визуал"],
	["deform_pose_smoothing","Гарри: плавность перехода поз",0.0,.20,.01,"с","Визуал"],
	["deform_joint_volume","Гарри: объём локтей и коленей",0.0,1.2,.05,"×","Визуал"],
	["sofia_cel_correction","София: поправка головы к прицелу",0.0,1.0,.05,"×","Визуал"],
	["noir_strength","Сила фильтра",0.0,1.0,.05,"×","Нуар"],
	["noir_contrast","Контраст полутонов",.6,1.6,.05,"×","Нуар"],
	["noir_gamma","Осветление полутонов",.5,1.8,.05,"×","Нуар"],
	["noir_shadow_lift","Свет в глубоких тенях",0.0,.2,.005,"×","Нуар"],
	["noir_highlight_cap","Предел яркости бликов",.55,1.0,.01,"×","Нуар"],
	["noir_red_strength","Сила красных акцентов",0.0,1.0,.05,"×","Нуар"],
	["noir_red_width","Диапазон красных оттенков",2.0,40.0,1.0,"°","Нуар"],
	["noir_red_feather","Мягкость отбора красного",1.0,20.0,1.0,"°","Нуар"],
	["noir_red_saturation","Минимальная насыщенность красного",.1,.9,.01,"×","Нуар"],
	["noir_red_brightness","Яркость красного",.5,2.0,.05,"×","Нуар"],
	["forest_radius","Лес: радиус области от старта",600.0,6000.0,100.0,"px","Окружение"],
	["forest_wind_strength","Ветер: сила",0.0,3.0,.05,"×","Окружение"],
	["forest_wind_speed","Ветер: темп",0.0,3.0,.05,"×","Окружение"],
	["forest_clouds_strength","Облака: сила движения",0.0,3.0,.05,"×","Окружение"],
	["forest_clouds_speed","Облака: темп",0.0,3.0,.05,"×","Окружение"],
	["forest_smoke_strength","Дым: сила движения",0.0,3.0,.05,"×","Окружение"],
	["forest_smoke_speed","Дым: темп",0.0,3.0,.05,"×","Окружение"],
	["forest_fire_strength","Пожары: сила мерцания",0.0,3.0,.05,"×","Окружение"],
	["forest_fire_speed","Пожары: темп",0.0,3.0,.05,"×","Окружение"],
	["forest_water_strength","Вода: сила ряби",0.0,3.0,.05,"×","Окружение"],
	["forest_water_speed","Вода: темп",0.0,3.0,.05,"×","Окружение"]
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
@export var pixel_size := 3.0
@export var stable_pixel_height := 360.0
@export var world_pixel_size := 2.0
@export var character_blur_strength := 0.0
@export var character_blur_length := 12.0
@export var character_blur_start_speed := 80.0
@export var character_linear_filter := false
@export var deform_pose_smoothing := .06
@export var deform_joint_volume := .65
@export var sofia_cel_correction := .25
@export_category("Нуар")
@export var noir_strength := 1.0
@export var noir_contrast := 1.05
@export var noir_gamma := 1.05
@export var noir_shadow_lift := .045
@export var noir_highlight_cap := .86
@export var noir_red_strength := 1.0
@export var noir_red_width := 12.0
@export var noir_red_feather := 6.0
@export var noir_red_saturation := .45
@export var noir_red_brightness := 1.2

@export var forest_radius := 1800.0
@export var forest_wind_strength := 1.0
@export var forest_wind_speed := 1.0
@export var forest_clouds_strength := 1.0
@export var forest_clouds_speed := 1.0
@export var forest_smoke_strength := 1.0
@export var forest_smoke_speed := 1.0
@export var forest_fire_strength := 1.0
@export var forest_fire_speed := 1.0
@export var forest_water_strength := 1.0
@export var forest_water_speed := 1.0

func framing_values() -> Dictionary:
	return {"zoom":zoom,"offset_x":offset_x,"offset_y":offset_y,"look_ahead":look_ahead,"follow_speed":follow_speed,"limit_to_level":limit_to_level,"camera_enabled":camera_enabled}

func as_dictionary() -> Dictionary:
	var values := {"scale_basis_version":2,"limit_to_level":limit_to_level,"character_linear_filter":character_linear_filter,"deform_mesh_debug":deform_mesh_debug}
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
	var version = config.get_value("camera","scale_basis_version",1)
	if version != 1 and version != 2: return ERR_INVALID_DATA
	var values := {"scale_basis_version":version}
	for key in as_dictionary():
		if config.has_section_key("camera",key): values[key] = config.get_value("camera",key)
	for entry in SWITCHES: values[entry[0]] = config.get_value("camera",entry[0],false if entry[0] in ["blocking_overlay_enabled","player_scale_enabled","noir_enabled","pixel_enabled","stable_pixel_enabled","world_pixel_enabled","scale_reference_enabled"] else true)
	apply_values(migrate_profile(values))
	return OK
static func migrate_profile(source: Dictionary) -> Dictionary:
	var values := source.duplicate(true)
	if values.get("scale_basis_version",1) == 1 and (values.get("player_scale") is float or values.get("player_scale") is int):
		values.player_scale = float(values.player_scale)/CoreWorldUnits.LEGACY_SOFIA_SCALE
	values["scale_basis_version"] = 2
	return values

func as_text() -> String:
	var lines := PackedStringArray()
	for key in as_dictionary(): lines.append("%s = %s" % [key,str(get(key))])
	return "\n".join(lines)
