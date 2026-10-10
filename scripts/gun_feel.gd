class_name GunFeel
extends RefCounted
# Every number that shapes how the PPSh feels. The F3 tuner edits these live
# and can save them to user://, so code reads values here instead of constants.

const SAVE_PATH := "user://gun_feel.cfg"
# key, label, min, max, step
const PARAMS := [
	["rpm","Темп, выстр/мин",300.0,1200.0,10.0],
	["hip_spread_min","Разброс: первый выстрел, °",0.0,6.0,0.1],
	["hip_spread_max","Разброс: длинная очередь, °",0.0,15.0,0.1],
	["bloom_per_shot","Рост разброса за выстрел",0.0,0.5,0.01],
	["bloom_delay","Пауза до сведения, мс",0.0,500.0,10.0],
	["bloom_recovery","Сведение разброса, /с",0.2,8.0,0.1],
	["climb_per_shot","Подъём ствола за выстрел, °",0.0,5.0,0.05],
	["climb_max","Подъём ствола: предел, °",0.0,20.0,0.5],
	["climb_recovery","Возврат ствола, /с",1.0,30.0,0.5],
	["aim_recoil_mult","Отдача с лазером, ×",0.0,1.0,0.05],
	["kick_back","Откат оружия, px",0.0,16.0,0.5],
	["cam_kick","Толчок камеры, px",0.0,20.0,0.5],
	["cam_kick_recovery","Возврат камеры, /с",4.0,60.0,1.0],
	["shot_trauma","Тряска за выстрел",0.0,0.6,0.01],
	["trauma_decay","Затухание тряски, /с",0.5,6.0,0.1],
	["shake_max","Тряска: максимум, px",0.0,30.0,0.5],
	["knockback","Отброс зомби, px/с",0.0,500.0,10.0],
	["headshot_knockback","Отброс при хедшоте, px/с",0.0,700.0,10.0],
	["hitstop_kill","Стоп-кадр: убийство, мс",0.0,200.0,5.0],
	["hitstop_headshot","Стоп-кадр: хедшот, мс",0.0,200.0,5.0],
	["hitstop_scale","Скорость в стоп-кадре",0.0,0.5,0.01],
	["hit_flash","Вспышка попадания, мс",0.0,200.0,5.0],
]

var rpm := 900.0
var hip_spread_min := 1.6
var hip_spread_max := 6.5
var bloom_per_shot := 0.09
var bloom_delay := 120.0
var bloom_recovery := 3.0
var climb_per_shot := 1.3
var climb_max := 6.0
var climb_recovery := 9.0
var aim_recoil_mult := 0.45
var kick_back := 6.0
var cam_kick := 5.0
var cam_kick_recovery := 22.0
var shot_trauma := 0.16
var trauma_decay := 2.6
var shake_max := 9.0
var knockback := 150.0
var headshot_knockback := 280.0
var hitstop_kill := 60.0
var hitstop_headshot := 35.0
var hitstop_scale := 0.05
var hit_flash := 60.0

var _defaults := {}

func _init() -> void:
	for param in PARAMS: _defaults[param[0]] = get(param[0])

func fire_interval() -> float:
	return 60.0/rpm

func reset() -> void:
	for key in _defaults: set(key,_defaults[key])

func save() -> Error:
	var config := ConfigFile.new()
	for param in PARAMS: config.set_value("feel",param[0],get(param[0]))
	return config.save(SAVE_PATH)

func load_saved() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK: return
	for param in PARAMS:
		set(param[0],float(config.get_value("feel",param[0],get(param[0]))))

func as_text() -> String:
	var lines := PackedStringArray()
	for param in PARAMS: lines.append("%s = %s" % [param[0],str(get(param[0]))])
	return "\n".join(lines)
