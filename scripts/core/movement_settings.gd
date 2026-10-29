class_name CoreMovementSettings
extends Resource

const SAVE_PATH := "user://core_movement.cfg"
# Version 2 values are world units at the approved Sofia baseline (new 1.00x).
@export var scale_basis_version := 2
@export var parkour_basis_version := 2
const MANUAL_PARKOUR_KEYS := ["parkour_reach","parkour_ledge_height","parkour_vault_height","parkour_vault_width","parkour_clearance","parkour_drop_limit"]
const RIG_DURATION_KEYS := ["parkour_mantle_time","parkour_vault_time"]
const LOCAL_GEOMETRY_KEYS := ["crouch_height","slide_height","push_hand_height","push_hand_spacing"]
const SCALED_MOTION_KEYS := ["run_speed","sprint_speed","slow_walk_speed","jump_speed",
	"jump_cut_speed","gravity","fall_speed","dash_speed","climb_speed","ladder_snap_speed",
	"push_speed","acceleration","braking","air_acceleration","slow_walk_acceleration",
	"slow_walk_braking","slow_walk_air_acceleration","slide_braking","slide_min_speed",
	"slide_damage_min_speed","slide_knockdown_min_speed"]
const SWITCHES := [
	["parkour_enabled", "Паркур включён", "Паркур", "Лицом к краю удерживайте пробел для хвата. Повторное нажатие — подъём, C — прервать. Низкое узкое препятствие преодолевается сразу."],
	["sprint_auto_parkour_enabled", "Автопаркур при спринте", "Паркур", "Shift + движение: автоматически преодолевать препятствия от колена до груди. Размеры считаются относительно роста героя; C — прервать."],
	["run_enabled", "Бег включён", "Бег", "Отключает обычный бег. Ходьба, приседание, спринт и специальные действия включаются отдельно."],
	["jump_enabled", "Прыжок включён", "Прыжок", "Запрещает новые прыжки; гравитация и уже начатый полёт сохраняются."],
	["dash_enabled", "Дэш включён", "Дэш", "Запрещает новые дэши и завершает текущий с безопасным восстановлением коллизий."],
	["ladder_enabled", "Лестницы включены", "Лестница", "Отключает захват лестниц; герой отпускает уже захваченную лестницу."],
	["slopes_enabled", "Влияние склонов на скорость", "Склоны", "Отключает замедление вверх и ускорение вниз. Форма поверхности и настройки дэша сохраняются."],
	["crouch_enabled", "Приседание включено", "Приседание", "Отключает приседание; под низким потолком герой встанет только при достаточном месте."],
	["sprint_enabled", "Спринт включён", "Спринт", "Отключает спринт и расход его запаса. Обычное движение сохраняется."],
	["slide_enabled", "Подкат включён", "Подкат", "Отключает подкат, его урон и сбивание. Приседание включается отдельно."],
	["walk_enabled", "Медленная ходьба включена", "Ходьба", "Отключает режим Ctrl, оставляя обычный бег и другие способы движения."],
	["backward_enabled", "Замедление движения задом", "Движение задом", "Выключено: движение задом имеет полный темп выбранного способа передвижения."],
	["acceleration_enabled", "Плавность разгона включена", "Разгон", "Выключено: прежний линейный разгон, без сглаживания. Значения ускорения и торможения сохраняются."],
	["health_enabled", "Получать урон", "Здоровье", "Выключено: входящий урон не уменьшает HP. Ручное изменение HP, лечение и отдельное бессмертие остаются доступны."],
	["push_enabled", "Захват и перемещение включены", "Толкание", "G — взять/отпустить предмет; A/D — толкать и тянуть. Выключение освобождает руки; гравитация и импульсы пуль сохраняются."]
]
@export var parkour_enabled := true
@export var sprint_auto_parkour_enabled := true
@export var run_enabled := true
@export var jump_enabled := true
@export var dash_enabled := true
@export var ladder_enabled := true
@export var slopes_enabled := true
@export var crouch_enabled := true
@export var sprint_enabled := true
@export var slide_enabled := true
@export var walk_enabled := true
@export var backward_enabled := true
@export var acceleration_enabled := true
@export var health_enabled := true
@export var push_enabled := true

# key, label, minimum, maximum, step, unit, group
const PARAMS := [
	["sprint_auto_min_height_ratio","Автопаркур · нижняя граница",.10,.50,.01,"× роста","Паркур"],
	["sprint_auto_max_height_ratio","Автопаркур · верхняя граница",.50,.95,.01,"× роста","Паркур"],
	["sprint_auto_max_width","Автопаркур · ширина при 1×",79.8,456.0,0.01,"px","Паркур"],
	["sprint_auto_vault_time","Автопаркур · время преодоления",.15,1.2,.01,"с","Паркур"],
	["parkour_reach","Дистанция захвата от тела · при 1×",5.7,68.4,.01,"px","Паркур"],
	["parkour_ledge_height","Высота досягаемого уступа · при 1×",136.8,285.0,.01,"px","Паркур"],
	["parkour_vault_height","Предел низкого препятствия · при 1×",68.4,159.6,.01,"px","Паркур"],
	["parkour_vault_width","Предел ширины препятствия · при 1×",79.8,456.0,.01,"px","Паркур"],
	["parkour_clearance","Зазор над препятствием · при 1×",5.7,45.6,.01,"px","Паркур"],
	["parkour_hang_time","Минимальное время фиксации хвата",0.05,0.6,0.01,"с","Паркур"],
	["parkour_mantle_time","Время подъёма",0.0877193,0.52631579,0.01,"с","Паркур"],
	["parkour_vault_time","Время преодоления",0.0877193,0.42105263,0.01,"с","Паркур"],
	["parkour_regrab_delay","Задержка повторного захвата",0.1,1.0,0.05,"с","Паркур"],
	["parkour_drop_limit","Допустимый спуск за препятствием · при 1×",0.0,228.0,.01,"px","Паркур"],
	["run_speed","Скорость бега",285.0,2137.5,0.01,"px/с","Бег"],
	["acceleration","Разгон",570.0,17100.0,0.01,"px/с²","Бег"],
	["braking","Торможение",570.0,22800.0,0.01,"px/с²","Бег"],
	["air_acceleration","Управление в воздухе",57.0,11400.0,0.01,"px/с²","Бег"],
	["jump_speed","Сила прыжка",114.0,3420.0,0.01,"px/с","Прыжок"],
	["jump_cut_speed","Импульс после отпускания",57.0,3420.0,0.01,"px/с","Прыжок"],
	["gravity","Гравитация",285.0,11400.0,0.01,"px/с²","Прыжок"],
	["fall_speed","Максимальная скорость падения",855.0,6840.0,0.01,"px/с","Прыжок"],
	["coyote_time","Прыжок после края",0.0,.30,.01,"с","Прыжок"],
	["jump_buffer_time","Буфер перед приземлением",0.0,.30,.01,"с","Прыжок"],
	["dash_speed","Скорость дэша",855.0,4275.0,0.01,"px/с","Дэш"],
	["dash_duration","Длительность дэша",.06,.60,.01,"с","Дэш"],
	["dash_cooldown","Восстановление от старта",.10,2.0,.01,"с","Дэш"],
	["climb_speed","Скорость подъёма и спуска",114.0,1282.5,0.01,"px/с","Лестница"],
	["ladder_snap_speed","Скорость притягивания",171.0,1425.0,0.01,"px/с","Лестница"],
	["ladder_regrab_delay","Задержка повторного захвата",.05,.80,.01,"с","Лестница"],
	["uphill_multiplier","Скорость на крутом подъёме",.20,1.0,.01,"×","Склоны"],
	["downhill_multiplier","Скорость на крутом спуске",1.0,1.50,.01,"×","Склоны"],
	["slope_start_angle","Угол начала эффекта",0.0,15.0,1.0,"°","Склоны"],
	["slope_full_angle","Угол полного эффекта",16.0,45.0,1.0,"°","Склоны"],
	["crouch_height","Высота в приседе",91.2,159.6,0.01,"px","Приседание"],
	["crouch_speed_multiplier","Скорость в приседе",.1,1.0,.05,"×","Приседание"],
	["crouch_noise_multiplier","Шум шагов в приседе",0.0,1.0,.05,"×","Приседание"],
	["walk_jump_multiplier","Дальность прыжка · бег",.25,2.0,.05,"×","Бег"],
	["sprint_duration","Максимальное время спринта",.2,15.0,.1,"с","Спринт"],
	["sprint_recovery_time","Полное восстановление спринта",.2,15.0,.1,"с","Спринт"],
	["sprint_speed","Скорость спринта",285.0,3420.0,0.01,"px/с","Спринт"],
	["sprint_jump_multiplier","Дальность прыжка · спринт",.25,2.0,.05,"×","Спринт"],
	["sprint_noise_multiplier","Шум шагов в спринте",0.0,3.0,.05,"×","Спринт"],
	["dash_uphill_multiplier","Скорость дэша вверх",.2,2.0,.05,"×","Дэш"],
	["dash_downhill_multiplier","Скорость дэша вниз",.2,2.0,.05,"×","Дэш"],
	["dash_slope_start_angle","Угол начала эффекта дэша",0.0,15.0,1.0,"°","Дэш"],
	["dash_slope_full_angle","Угол полного эффекта дэша",16.0,45.0,1.0,"°","Дэш"],
	["slide_speed_multiplier","Начальная скорость подката",.5,3.0,.05,"×","Подкат"],
	["slide_min_speed","Минимальная скорость старта",142.5,2850.0,0.01,"px/с","Подкат"],
	["slide_duration","Длительность подката",.1,2.0,.05,"с","Подкат"],
	["slide_braking","Торможение подката",0.0,8550.0,0.01,"px/с²","Подкат"],
	["slide_cooldown","Восстановление от старта",.1,3.0,.05,"с","Подкат"],
	["slide_height","Высота в подкате",79.8,119.7,0.01,"px","Подкат"],
	["slide_damage","Урон при столкновении",0.0,100.0,1.0,"HP","Подкат"],
	["slide_damage_min_speed","Минимальная скорость урона",0.0,2850.0,0.01,"px/с","Подкат"],
	["slide_knockdown_chance","Шанс сбивания",0.0,1.0,.05,"×","Подкат"],
	["slide_knockdown_min_speed","Минимальная скорость сбивания",0.0,2850.0,0.01,"px/с","Подкат"],
	["slide_knockdown_duration","Время на земле · люди",.2,5.0,.1,"с","Подкат"],
	["slide_zombie_knockdown_duration","Время на земле · зомби",.2,5.0,.1,"с","Подкат"],
	["slide_knockback_speed","Сила отбрасывания",0.0,600.0,10.0,"px/с","Подкат"],
	["slow_walk_speed","Скорость ходьбы",57.0,2137.5,0.01,"px/с","Ходьба"],
	["slow_walk_acceleration","Разгон ходьбы",570.0,17100.0,0.01,"px/с²","Ходьба"],
	["slow_walk_braking","Торможение ходьбы",570.0,22800.0,0.01,"px/с²","Ходьба"],
	["slow_walk_air_acceleration","Управление в воздухе",57.0,11400.0,0.01,"px/с²","Ходьба"],
	["slow_walk_jump_multiplier","Дальность прыжка · ходьба",.25,2.0,.05,"×","Ходьба"],
	["slow_walk_noise_multiplier","Шум шагов при ходьбе",0.0,3.0,.05,"×","Ходьба"],
	["run_backward_multiplier","Скорость бега задом",.1,1.0,.05,"×","Движение задом"],
	["slow_walk_backward_multiplier","Скорость ходьбы задом",.1,1.0,.05,"×","Движение задом"],
	["crouch_backward_multiplier","Скорость в приседе задом",.1,1.0,.05,"×","Движение задом"],
	["acceleration_smoothing","Плавность разгона",0.0,1.0,.01,"с","Разгон"],
	["max_health","Максимальное здоровье героя",1.0,1000.0,1.0,"HP","Здоровье"],
	["push_speed","Скорость толкания и тяги",57.0,684.0,0.01,"px/с","Толкание"],
	["push_force","Максимальное усилие",0.0,40000.0,500.0,"Н","Толкание"],
	["push_response","Сила выхода на скорость",10.0,500.0,10.0,"×","Толкание"],
	["push_activation_delay","Задержка усилия после захвата",0.0,.5,.01,"с","Толкание"],
	["push_contact_distance","Свободный ход захвата",0.0,12.0,.5,"px","Толкание"],
	["push_animation_rate","Темп шагов с предметом",.25,2.5,.05,"×","Толкание"],
	["push_hand_height","Высота захвата руками",57.0,153.9,0.01,"px","Толкание"],
	["push_hand_spacing","Разнос кистей по высоте",0.0,57.0,0.01,"px","Толкание"]
]

@export_category("Паркур")
@export var parkour_reach := 34.2
@export var parkour_ledge_height := 216.6
@export var parkour_vault_height := 136.8
@export var parkour_vault_width := 273.6
@export var parkour_clearance := 11.4
@export var parkour_hang_time := 0.14
@export var parkour_mantle_time := 0.22807017543859648
@export var parkour_vault_time := 0.1929824561403509
@export var parkour_regrab_delay := 0.25
@export var parkour_drop_limit := 91.2
@export var sprint_auto_min_height_ratio := .25
@export var sprint_auto_max_height_ratio := .75
@export var sprint_auto_max_width := 273.6
@export var sprint_auto_vault_time := .32
@export_category("Здоровье")
@export var max_health := 100.0
@export_category("Бег")
@export var run_speed := 912.0
@export var acceleration := 6840.0
@export var acceleration_smoothing := .15
@export var braking := 8550.0
@export var air_acceleration := 4275.0
# Legacy profile key: this is the default run's jump factor.
@export var walk_jump_multiplier := 1.0
@export_category("Ходьба")
@export var slow_walk_speed := 399.0
@export var slow_walk_acceleration := 2850.0
@export var slow_walk_braking := 5130.0
@export var slow_walk_air_acceleration := 2565.0
@export var slow_walk_jump_multiplier := 1.0
@export var slow_walk_noise_multiplier := .5
@export_category("Движение задом")
@export var run_backward_multiplier := .7
@export var slow_walk_backward_multiplier := .8
@export var crouch_backward_multiplier := .8
@export_category("Спринт")
@export var sprint_speed := 1482.0
@export var sprint_jump_multiplier := 1.15
@export var sprint_noise_multiplier := 1.5
@export var sprint_duration := 3.0
@export var sprint_recovery_time := 2.0
@export_category("Прыжок")
@export var gravity := 5415.0
@export var fall_speed := 3135.0
@export var jump_speed := 2052.0
@export var jump_cut_speed := 741.0
@export var coyote_time := .10
@export var jump_buffer_time := .12
@export_category("Дэш")
@export var air_dash_enabled := true
@export var dash_speed := 2166.0
@export var dash_duration := .16
@export var dash_cooldown := .42
@export_category("Дэш на склонах")
@export var dash_uphill_multiplier := 1.0
@export var dash_downhill_multiplier := 1.0
@export var dash_slope_start_angle := 3.0
@export var dash_slope_full_angle := 35.0
@export_category("Лестница")
@export var climb_speed := 513.0
@export var ladder_snap_speed := 513.0
@export var ladder_regrab_delay := .22
@export_category("Склоны")
@export var uphill_multiplier := .70
@export var downhill_multiplier := 1.15
@export var slope_start_angle := 3.0
@export var slope_full_angle := 35.0
@export_category("Приседание")
@export var crouch_height := 119.7
@export var crouch_speed_multiplier := .45
@export var crouch_noise_multiplier := .4
@export_category("Подкат")
@export var slide_speed_multiplier := 1.35
@export var slide_min_speed := 712.5
@export var slide_duration := .65
@export var slide_braking := 1710.0
@export var slide_cooldown := .8
@export var slide_height := 91.2
@export var slide_damage := 25.0
@export var slide_damage_min_speed := 285.0
@export_category("Сбивание подкатом")
@export var slide_knockdown_enabled := true
@export var slide_knockdown_chance := 1.0
@export var slide_knockdown_min_speed := 570.0
# Keep the legacy profile key for the human timer.
@export var slide_knockdown_duration := 1.5
@export var slide_zombie_knockdown_duration := 3.0
@export var slide_knockback_speed := 180.0
@export_category("Толкание")
@export var push_speed := 285.0
@export var push_force := 16000.0
@export var push_response := 250.0
@export var push_activation_delay := .08
@export var push_contact_distance := 4.0
@export var push_animation_rate := 1.0
@export var push_hand_height := 114.0
@export var push_hand_spacing := 22.8

func acceleration_step(speed: float,target: float,current_acceleration: float,rate: float,delta: float) -> Vector2:
	# Limit jerk while ramping up; taper acceleration using the remaining
	# velocity distance needed to stop that acceleration at the target.
	if not acceleration_enabled or acceleration_smoothing <= 0 or delta <= 0:
		return Vector2(move_toward(speed,target,rate*delta),0)
	var error := target-speed
	if absf(error) < .00001: return Vector2(target,0)
	var jerk := rate/acceleration_smoothing
	var desired := signf(error)*minf(rate,sqrt(2*jerk*absf(error)))
	var next_acceleration := move_toward(current_acceleration,desired,jerk*delta)
	var next_speed := speed+(current_acceleration+next_acceleration)*.5*delta
	# Monotonic response for live target changes; never overshoot a speed cap.
	next_speed = clampf(next_speed,minf(speed,target),maxf(speed,target))
	if is_equal_approx(next_speed,target): return Vector2(target,0)
	return Vector2(next_speed,next_acceleration)

func acceleration_time(speed: float,rate: float) -> float:
	var base := absf(speed)/rate
	if not acceleration_enabled or acceleration_smoothing <= 0: return base
	return base+acceleration_smoothing if base >= acceleration_smoothing else 2*sqrt(base*acceleration_smoothing)

func slope_multiplier(angle_degrees: float,uphill: bool) -> float:
	if not slopes_enabled: return 1.0
	# Ease the angle contribution at both ends; acceleration handles changes
	# in the target speed, including direction reversals and flat crests.
	var weight := smoothstep(slope_start_angle,slope_full_angle,absf(angle_degrees))
	return lerpf(1.0,uphill_multiplier if uphill else downhill_multiplier,weight)

func dash_slope_multiplier(angle_degrees: float,uphill: bool) -> float:
	var weight := smoothstep(dash_slope_start_angle,dash_slope_full_angle,absf(angle_degrees))
	return lerpf(1.0,dash_uphill_multiplier if uphill else dash_downhill_multiplier,weight)

func as_dictionary() -> Dictionary:
	var values := {"scale_basis_version":2,"parkour_basis_version":2,"slide_knockdown_enabled":slide_knockdown_enabled,"air_dash_enabled":air_dash_enabled}
	for entry in SWITCHES: values[entry[0]] = get(entry[0])
	for param in PARAMS: values[param[0]] = get(param[0])
	return values

func apply_values(values: Dictionary) -> void:
	for entry in SWITCHES:
		if values.get(entry[0]) is bool: set(entry[0],values[entry[0]])
	if values.get("air_dash_enabled") is bool: air_dash_enabled = values.air_dash_enabled
	if values.get("slide_knockdown_enabled") is bool: slide_knockdown_enabled = values.slide_knockdown_enabled
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
	sprint_speed = maxf(sprint_speed,run_speed)
	slow_walk_speed = minf(slow_walk_speed,run_speed)
	jump_cut_speed = minf(jump_cut_speed,jump_speed)
	dash_cooldown = maxf(dash_cooldown,dash_duration)
	slide_cooldown = maxf(slide_cooldown,slide_duration)

func slow_walk_jump_range() -> float:
	return slow_walk_speed*slow_walk_jump_multiplier*2*jump_speed/gravity

func jump_range(sprint: bool) -> float:
	var speed := sprint_speed if sprint else run_speed
	var multiplier := sprint_jump_multiplier if sprint else walk_jump_multiplier
	return speed*multiplier*2*jump_speed/gravity

func save_saved(path := SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	for key in as_dictionary(): config.set_value("movement",key,get(key))
	return config.save(path)

func load_saved(path := SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	var result := config.load(path)
	if result != OK: return result
	var version = config.get_value("movement","scale_basis_version",1)
	if version != 1 and version != 2: return ERR_INVALID_DATA
	var parkour_version = config.get_value("movement","parkour_basis_version",1)
	if parkour_version != 1 and parkour_version != 2: return ERR_INVALID_DATA
	var values := {"scale_basis_version":version,"parkour_basis_version":parkour_version}
	for key in as_dictionary():
		if config.has_section_key("movement",key): values[key] = config.get_value("movement",key)
	for entry in SWITCHES: values[entry[0]] = config.get_value("movement",entry[0],true)
	apply_values(migrate_profile(values))
	return OK

static func migrate_profile(source: Dictionary) -> Dictionary:
	var values := source.duplicate(true)
	if values.get("parkour_basis_version",1) == 1:
		for key in MANUAL_PARKOUR_KEYS:
			if values.get(key) is float or values.get(key) is int:
				values[key] = float(values[key])*CoreWorldUnits.LEGACY_SOFIA_SCALE
	values["parkour_basis_version"] = 2
	if values.get("scale_basis_version",1) == 1:
		for key in SCALED_MOTION_KEYS+LOCAL_GEOMETRY_KEYS+["sprint_auto_max_width"]:
			if values.get(key) is float or values.get(key) is int:
				values[key] = float(values[key])*CoreWorldUnits.LEGACY_SOFIA_SCALE
		for key in RIG_DURATION_KEYS:
			if values.get(key) is float or values.get(key) is int:
				values[key] = float(values[key])/CoreWorldUnits.LEGACY_SOFIA_SCALE
	values["scale_basis_version"] = 2
	return values

func local_value(key: String) -> float:
	return float(get(key))/CoreWorldUnits.LEGACY_SOFIA_SCALE

func as_text() -> String:
	var lines := PackedStringArray()
	for key in as_dictionary(): lines.append("%s = %s" % [key,str(get(key))])
	return "\n".join(lines)
