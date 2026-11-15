class_name CoreShootingSettings
extends Resource

const SAVE_PATH := "user://core_shooting.cfg"
const SWITCHES := [
	["body_recoil_3d_enabled","Отдача корпусом · 3D","Оружие","Импульс через плечо и корпус, без отделения приклада."],
	["procedural_feet_3d_enabled","Процедурные опоры · 3D","Оружие","Постановка стоп при разворотах и вертикальном наведении."],
	["relaxed_carry_3d_enabled","Спокойная переноска STG · 3D","Оружие","Опускать STG без противников поблизости. Параметры сохраняются при отключении."],
	["assault_tracer_enabled", "Трассер STG-44", "Трассеры", "Свой лист: возникновение, след в полёте, затухание на месте попадания. Случайный вариант каждой стадии, без влияния на пули. Выключение сохраняет параметры."],
	["smg_tracer_enabled", "Трассер MP-40", "Трассеры", "Свой лист: возникновение, след в полёте, затухание на месте попадания. Случайный вариант каждой стадии, без влияния на пули. Выключение сохраняет параметры."],
	["rifle_tracer_enabled", "Трассер СВТ", "Трассеры", "Свой лист: возникновение, след в полёте, затухание на месте попадания. Случайный вариант каждой стадии, без влияния на пули. Выключение сохраняет параметры."],
	["pistol_tracer_enabled", "Трассер 1911", "Трассеры", "Свой лист: возникновение, след в полёте, затухание на месте попадания. Случайный вариант каждой стадии, без влияния на пули. Выключение сохраняет параметры."],
	["smg_flash_enabled", "Вспышка MP-40 V2", "Вспышка", "Свой лист, все9 рисунков. Порядок стадий сохраняется, вариант каждой стадии случаен. Выключение не стирает параметры."],
	["rifle_flash_enabled", "Вспышка СВТ V2", "Вспышка", "Свой лист, все9 рисунков. Порядок стадий сохраняется, вариант каждой стадии случаен. Выключение не стирает параметры."],
	["pistol_flash_enabled", "Вспышка 1911 V2", "Вспышка", "Свой лист, все9 рисунков. Порядок стадий сохраняется, вариант каждой стадии случаен. Выключение не стирает параметры."],
	["assault_flash_enabled", "Вспышка STG-44 V2", "Вспышка", "Все9 рисунков листа штурмовой винтовки. Стадии идут по порядку; на каждую стадию выбирается один из3 вариантов. Не влияет на пули. Выключение сохраняет параметры."],
	["enemy_impact_enabled", "Кровь при попадании", "Импакт", "Направленные капли в точке попадания по живому противнику. Только визуал: без оглушения и изменения урона. Выключение сохраняет параметры."],
	["ads_spread_enabled", "Разброс очереди в ADS", "Прицел", "В ADS выстрелы накапливают отдельный реальный разброс. Луч и перекрестие показывают тот же угол. Выключение сохраняет параметры; разброс движения независим."],
	["aim_beam_enabled", "Луч вместо перекрестия", "Прицел", "Два варианта прицела. Выключено — прежнее перекрестие; включено — светлый сектор реального разброса. Видим только игроку."],
	["weapon_enabled", "Оружие включено", "Оружие", "Отключает стрельбу, прицеливание и перезарядку, сохраняя боезапас."],
	["hip_enabled", "Стрельба от бедра включена", "От бедра", "Выключено: стрелять можно только при прицеливании, если оно включено."],
	["ads_enabled", "Прицеливание включено", "Прицел", "Отключает ПКМ, точный прицел и замедление при прицеливании."],
	["recoil_enabled", "Отдача включена", "Отдача", "Подброс и увод перекрестия меняют направление пуль и оружия. Выключение убирает также откат и тряску камеры; разброс независим."],
	["recoil_continuous_enabled", "Непрерывный подброс и увод", "Отдача", "Каждый выстрел продолжает смещать прицел без углового предела. Мышь работает относительно движения, без упора в край рабочего стола."],
	["recoil_auto_enabled", "Автокомпенсация отдачи", "Отдача", "Возвращает только оставшуюся отдачу. Уже компенсированное мышью движение повторно не вычитается. Не выбирает цели."],
	["recoil_auto_during_fire", "Автокомпенсация во время очереди", "Отдача", "Включено: возврат увода начинается после заданной паузы от начала очереди. Выключено: после паузы с последнего выстрела. Ручная компенсация работает всегда."],
	["hide_cursor_in_game", "Скрывать курсор в игре", "Отдача", "Выбранный прицел остаётся видимым. Выключено: дополнительная стрелка совпадает с точкой наведения. В меню и на паузе обычный курсор виден всегда."],
	["sound_enabled", "Звуки оружия включены", "Звук", "Отключает выстрелы, попадания, убийства, перезарядку и звуковые предупреждения боезапаса."],
	["damage_enabled", "Урон пуль включён", "Урон", "Пули попадают и отмечают попадание, но не снимают HP и не отрывают конечности. Физические импульсы предметам сохраняются."],
	["magazine_enabled", "Магазин и перезарядка включены", "Магазин", "Выключено: стрельба без расхода патронов и без перезарядки. Реальный боезапас сохраняется."],
	["movement_spread_enabled", "Разброс от движения включён", "Разброс в движении", "Выключение сразу убирает штраф за движение. Базовый разброс и рост при очереди сохраняются."]
]
@export var relaxed_carry_3d_enabled := true
@export var relaxed_carry_3d_radius := 10.0
@export var relaxed_carry_3d_delay := 3.0
@export var weapon_pose_3d_blend := .14
@export var body_recoil_3d_enabled := true
@export var body_recoil_3d_strength := 1.0
@export var body_recoil_3d_ammo := 1.0
@export var body_recoil_3d_hip_multiplier := 2.0
@export var procedural_feet_3d_step_time := .16
@export var procedural_feet_3d_lift := .045
@export var procedural_feet_3d_stride := .16
@export var procedural_feet_3d_turn := 20.0
@export var procedural_feet_3d_enabled := true
@export var weapon_enabled := true
@export var assault_tracer_enabled := true
@export var assault_tracer_ignition := 0.02
@export var assault_tracer_decay := 0.04
@export var assault_tracer_length := 0.65
@export var assault_tracer_width := 0.018
@export var assault_tracer_opacity := 1.0
@export var smg_tracer_enabled := true
@export var smg_tracer_ignition := 0.02
@export var smg_tracer_decay := 0.035
@export var smg_tracer_length := 0.45
@export var smg_tracer_width := 0.014
@export var smg_tracer_opacity := 1.0
@export var rifle_tracer_enabled := true
@export var rifle_tracer_ignition := 0.02
@export var rifle_tracer_decay := 0.045
@export var rifle_tracer_length := 0.9
@export var rifle_tracer_width := 0.016
@export var rifle_tracer_opacity := 1.0
@export var pistol_tracer_enabled := true
@export var pistol_tracer_ignition := 0.02
@export var pistol_tracer_decay := 0.03
@export var pistol_tracer_length := 0.35
@export var pistol_tracer_width := 0.012
@export var pistol_tracer_opacity := 1.0
@export var smg_flash_enabled := true
@export var smg_flash_ignition := 0.01
@export var smg_flash_peak := 0.015
@export var smg_flash_decay := 0.035
@export var smg_flash_size := 1.0
@export var smg_flash_opacity := 1.0
@export var rifle_flash_enabled := true
@export var rifle_flash_ignition := 0.012
@export var rifle_flash_peak := 0.022
@export var rifle_flash_decay := 0.045
@export var rifle_flash_size := 1.0
@export var rifle_flash_opacity := 1.0
@export var pistol_flash_enabled := true
@export var pistol_flash_ignition := 0.01
@export var pistol_flash_peak := 0.015
@export var pistol_flash_decay := 0.03
@export var pistol_flash_size := 1.0
@export var pistol_flash_opacity := 1.0
@export var assault_flash_enabled := true
@export var assault_flash_ignition := .012
@export var assault_flash_peak := .018
@export var assault_flash_decay := .040
@export var assault_flash_size := 1.0
@export var assault_flash_opacity := 1.0
@export var enemy_impact_enabled := true
@export var enemy_impact_count := 26.0
@export var enemy_impact_duration := .15
@export var enemy_impact_size := 1.0
@export var enemy_impact_reach := 1.0
@export var enemy_impact_spread := 48.0
@export var enemy_impact_gravity := 300.0
@export var enemy_impact_opacity := .95
@export var aim_beam_enabled := true
@export var ads_spread_enabled := true
@export var ads_spread := 0.0
@export var ads_max_spread := 4.0
@export var ads_spread_per_shot := .35
@export var ads_spread_recovery := 8.0
@export var beam_hip_opacity := .055
@export var beam_ads_opacity := .16
@export var beam_edge_softness := .3
@export var beam_line_width := 1.4
@export var beam_distance_fade := .65
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
	["body_recoil_3d_hip_multiplier","3D · Отдача от бедра",1,3,.05,"×","Оружие"],
	["body_recoil_3d_ammo","3D · Импульс боеприпаса",.25,2,.05,"×","Оружие"],
	["procedural_feet_3d_step_time","3D · Время перестановки стопы",.1,.35,.01,"с","Оружие"],
	["procedural_feet_3d_lift","3D · Подъём стопы",.015,.08,.005,"м","Оружие"],
	["procedural_feet_3d_stride","3D · Порог перестановки",.1,.35,.01,"м","Оружие"],
	["procedural_feet_3d_turn","3D · Поворот до перестановки",10,40,1,"°","Оружие"],
	["body_recoil_3d_strength","3D · Сила отдачи корпуса",0,2,.05,"×","Оружие"],
	["relaxed_carry_3d_radius","3D · Радиус боевой готовности",1,30,.5,"м","Оружие"],
	["relaxed_carry_3d_delay","3D · Переноска после стрельбы",0,10,.1,"с","Оружие"],
	["weapon_pose_3d_blend","3D · Плавность стойки",.05,.5,.01,"с","Оружие"],
	["assault_tracer_ignition","STG-44 · Появление",0.005,0.1,0.001,"с","Трассеры"],
	["assault_tracer_decay","STG-44 · Затухание",0.01,0.15,0.001,"с","Трассеры"],
	["assault_tracer_length","STG-44 · Длина",0.1,3,0.01,"м","Трассеры"],
	["assault_tracer_width","STG-44 · Толщина",0.005,0.08,0.001,"м","Трассеры"],
	["assault_tracer_opacity","STG-44 · Непрозрачность",0.1,1,0.05,"доля","Трассеры"],
	["smg_tracer_ignition","MP-40 · Появление",0.005,0.1,0.001,"с","Трассеры"],
	["smg_tracer_decay","MP-40 · Затухание",0.01,0.15,0.001,"с","Трассеры"],
	["smg_tracer_length","MP-40 · Длина",0.1,3,0.01,"м","Трассеры"],
	["smg_tracer_width","MP-40 · Толщина",0.005,0.08,0.001,"м","Трассеры"],
	["smg_tracer_opacity","MP-40 · Непрозрачность",0.1,1,0.05,"доля","Трассеры"],
	["rifle_tracer_ignition","СВТ · Появление",0.005,0.1,0.001,"с","Трассеры"],
	["rifle_tracer_decay","СВТ · Затухание",0.01,0.15,0.001,"с","Трассеры"],
	["rifle_tracer_length","СВТ · Длина",0.1,3,0.01,"м","Трассеры"],
	["rifle_tracer_width","СВТ · Толщина",0.005,0.08,0.001,"м","Трассеры"],
	["rifle_tracer_opacity","СВТ · Непрозрачность",0.1,1,0.05,"доля","Трассеры"],
	["pistol_tracer_ignition","1911 · Появление",0.005,0.1,0.001,"с","Трассеры"],
	["pistol_tracer_decay","1911 · Затухание",0.01,0.15,0.001,"с","Трассеры"],
	["pistol_tracer_length","1911 · Длина",0.1,3,0.01,"м","Трассеры"],
	["pistol_tracer_width","1911 · Толщина",0.005,0.08,0.001,"м","Трассеры"],
	["pistol_tracer_opacity","1911 · Непрозрачность",0.1,1,0.05,"доля","Трассеры"],
	["smg_flash_ignition","MP-40 · Возникновение",0.005,0.08,0.001,"с","Вспышка"],
	["smg_flash_peak","MP-40 · Полная сила",0.005,0.08,0.001,"с","Вспышка"],
	["smg_flash_decay","MP-40 · Затухание",0.005,0.15,0.001,"с","Вспышка"],
	["smg_flash_size","MP-40 · Размер",0.25,3,0.05,"×","Вспышка"],
	["smg_flash_opacity","MP-40 · Непрозрачность",0.1,1,0.05,"доля","Вспышка"],
	["rifle_flash_ignition","СВТ · Возникновение",0.005,0.08,0.001,"с","Вспышка"],
	["rifle_flash_peak","СВТ · Полная сила",0.005,0.08,0.001,"с","Вспышка"],
	["rifle_flash_decay","СВТ · Затухание",0.005,0.15,0.001,"с","Вспышка"],
	["rifle_flash_size","СВТ · Размер",0.25,3,0.05,"×","Вспышка"],
	["rifle_flash_opacity","СВТ · Непрозрачность",0.1,1,0.05,"доля","Вспышка"],
	["pistol_flash_ignition","1911 · Возникновение",0.005,0.08,0.001,"с","Вспышка"],
	["pistol_flash_peak","1911 · Полная сила",0.005,0.08,0.001,"с","Вспышка"],
	["pistol_flash_decay","1911 · Затухание",0.005,0.15,0.001,"с","Вспышка"],
	["pistol_flash_size","1911 · Размер",0.25,3,0.05,"×","Вспышка"],
	["pistol_flash_opacity","1911 · Непрозрачность",0.1,1,0.05,"доля","Вспышка"],
	["assault_flash_ignition","STG-44 · Возникновение",.005,.08,.001,"с","Вспышка"],
	["assault_flash_peak","STG-44 · Полная сила",.005,.08,.001,"с","Вспышка"],
	["assault_flash_decay","STG-44 · Затухание",.005,.15,.001,"с","Вспышка"],
	["assault_flash_size","STG-44 · Размер",.25,3.0,.05,"×","Вспышка"],
	["assault_flash_opacity","STG-44 · Непрозрачность",.1,1.0,.05,"доля","Вспышка"],
	["enemy_impact_count","Количество капель",4.0,64.0,1.0,"шт.","Импакт"],
	["enemy_impact_duration","Время рассеивания",.05,.5,.01,"с","Импакт"],
	["enemy_impact_size","Размер капель",.3,3.0,.05,"×","Импакт"],
	["enemy_impact_reach","Дальность выброса",.2,3.0,.05,"×","Импакт"],
	["enemy_impact_spread","Угол выброса ±",5.0,90.0,1.0,"°","Импакт"],
	["enemy_impact_gravity","Падение капель",0.0,1200.0,10.0,"ед./с²","Импакт"],
	["enemy_impact_opacity","Непрозрачность",.1,1.0,.05,"доля","Импакт"],
	["ads_spread","Начальный разброс ADS ±",0.0,15.0,.1,"°","Прицел"],
	["ads_max_spread","Максимальный разброс ADS ±",0.0,35.0,.1,"°","Прицел"],
	["ads_spread_per_shot","Рост разброса ADS за выстрел",0.0,5.0,.05,"°","Прицел"],
	["ads_spread_recovery","Восстановление разброса ADS",.1,60.0,.1,"°/с","Прицел"],
	["beam_hip_opacity","Заметность луча от бедра",0.0,.5,.005,"доля","Прицел"],
	["beam_ads_opacity","Заметность луча в прицеле",0.0,.5,.005,"доля","Прицел"],
	["beam_edge_softness","Мягкость границ сектора",0.0,1.0,.01,"доля","Прицел"],
	["beam_line_width","Толщина точной линии",.5,4.0,.1,"px экрана","Прицел"],
	["beam_distance_fade","Затухание вдали",0.0,1.0,.01,"доля","Прицел"],
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
	["casing_volume","Громкость падения гильз",-60.0,0.0,1.0,"dB","Звук"],
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
@export var casing_volume := -15.0
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
	ads_max_spread = maxf(ads_spread,ads_max_spread)
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
