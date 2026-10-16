class_name CoreExplosionSettings
extends Resource
## Shared blast profile; barrels, grenades and planted charges use this type.
static var BLAST_SWITCHES: Array = [
	["explosions_enabled","Взрывы включены","Взрывы","Общий переключатель взрывов. Запалы бочек и гранат ждут повторного включения."],
	["explosion_occlusion_enabled","Укрытия защищают от взрыва","Взрывы","Стены, платформы и целые предметы закрывают ударную волну. Щепки не защищают."],
	["explosion_player_damage_enabled","Взрыв наносит урон игроку","Взрывы","Выключение сохраняет отбрасывание игрока и урон другим целям."],
	["explosion_visuals_enabled","Эффекты взрыва включены","Взрывы","Вспышка, ударная волна и дым; механика урона работает независимо."],
	["explosion_audio_enabled","Звук взрыва включён","Взрывы","Звук для игрока. Слух зомби реагирует на взрыв независимо от этой настройки."],
	["explosion_camera_enabled","Тряска камеры от взрыва","Взрывы","Сила тряски уменьшается с расстоянием до игрока."],
	["barrels_enabled","Механики бочек включены","Бочки","Физика и G остаются доступны. Выключение останавливает урон по бочкам, утечки и детонацию."],
	["explosion_chain_enabled","Цепная детонация бочек","Бочки","Ударная волна может запустить запал взрывной или топливной бочки."],
	["fuel_leak_enabled","Утечка топлива включена","Бочки","Пробитые бочки оставляют постоянные лужи и след. Выключение сохраняет уже разлитое топливо."],
	["fuel_fire_enabled","Горение топлива включено","Бочки","Выключение приостанавливает огонь, распространение и урон, сохраняя топливо."],
	["barrel_impact_enabled","Урон и сбивание бочкой","Бочки","Скорость столкновения определяет урон; быстрое столкновение сбивает персонажей с ног."]] + preload("res://scripts/core/grenade_settings.gd").SWITCHES
static var BLAST_PARAMS: Array = [
	["explosion_radius","Радиус взрыва",40.0,800.0,5.0,"px","Взрывы"],
	["explosion_full_damage_radius","Радиус полного урона",0.0,200.0,5.0,"px","Взрывы"],
	["explosion_damage","Урон у центра",0.0,500.0,5.0,"HP","Взрывы"],
	["explosion_falloff","Ослабление с расстоянием",.25,4.0,.05,"×","Взрывы"],
	["explosion_impulse","Импульс по физическим телам",0.0,5000.0,50.0,"Н·с","Взрывы"],
	["explosion_prop_speed_limit","Предел прибавки скорости тел",50.0,1500.0,10.0,"px/с","Взрывы"],
	["explosion_character_push","Отбрасывание персонажей",0.0,1000.0,10.0,"px/с","Взрывы"],
	["explosion_stun_duration","Ошеломление у центра",0.0,6.0,.05,"с","Взрывы"],
	["explosion_volume","Громкость взрыва",-40.0,6.0,1.0,"dB","Взрывы"],
	["explosion_camera_strength","Сила тряски камеры",0.0,30.0,.5,"px","Взрывы"],
	["barrel_health","Прочность бочки",1.0,500.0,1.0,"HP","Бочки"],
	["barrel_fuse","Задержка детонации",0.0,2.0,.01,"с","Бочки"],
	["barrel_leak_hits","Попаданий до утечки",1.0,2.0,1.0,"","Бочки"],
	["fuel_capacity","Запас топлива · 0 без ограничения",0.0,2000.0,10.0,"ед.","Бочки"],
	["fuel_leak_rate","Скорость утечки",.5,30.0,.5,"ед./с","Бочки"],
	["fuel_pool_radius","Максимальная полуширина лужи",12.0,160.0,2.0,"px","Бочки"],
	["fuel_spread_speed","Скорость распространения огня",10.0,500.0,5.0,"px/с","Бочки"],
	["fuel_burn_duration","Горение участка топлива",1.0,60.0,.5,"с","Бочки"],
	["fuel_fire_damage","Урон огня",0.0,100.0,1.0,"HP/с","Бочки"],
	["fuel_fire_height","Высота зоны огня",12.0,80.0,2.0,"px","Бочки"],
	["barrel_tip_duration","Время укладки бочки",.2,2.0,.05,"с","Бочки"],
	["barrel_roll_speed","Скорость перекатывания на G",20.0,300.0,5.0,"px/с","Бочки"],
	["barrel_impact_min_speed","Минимальная скорость урона",20.0,400.0,5.0,"px/с","Бочки"],
	["barrel_impact_damage_scale","Урон на единицу скорости",0.0,.5,.01,"×","Бочки"],
	["barrel_knockdown_speed","Скорость сбивания с ног",50.0,800.0,10.0,"px/с","Бочки"],
	["barrel_knockdown_duration","Время на земле от бочки",.1,5.0,.1,"с","Бочки"],
	["barrel_impact_cooldown","Интервал ударов по одной цели",.2,3.0,.05,"с","Бочки"]] + preload("res://scripts/core/grenade_settings.gd").PARAMS
@export var explosions_enabled := true
@export var explosion_occlusion_enabled := true
@export var explosion_player_damage_enabled := true
@export var explosion_visuals_enabled := true
@export var explosion_audio_enabled := true
@export var explosion_camera_enabled := true
@export var barrels_enabled := true
@export var explosion_chain_enabled := true
@export var explosion_radius := 240.0
@export var explosion_full_damage_radius := 40.0
@export var explosion_damage := 120.0
@export var explosion_falloff := 1.2
@export var explosion_impulse := 1200.0
@export var explosion_prop_speed_limit := 500.0
@export var explosion_character_push := 360.0
@export var explosion_stun_duration := 1.2
@export var explosion_volume := -8.0
@export var explosion_camera_strength := 10.0
@export var barrel_health := 50.0
@export var barrel_fuse := .15
@export var fuel_leak_enabled := true
@export var fuel_fire_enabled := true
@export var barrel_impact_enabled := true
@export var barrel_leak_hits := 1.0
@export var fuel_capacity := 0.0
@export var fuel_leak_rate := 4.0
@export var fuel_pool_radius := 60.0
@export var fuel_spread_speed := 85.0
@export var fuel_burn_duration := 14.0
@export var fuel_fire_damage := 15.0
@export var fuel_fire_height := 30.0
@export var barrel_tip_duration := .55
@export var barrel_roll_speed := 120.0
@export var barrel_impact_min_speed := 90.0
@export var barrel_impact_damage_scale := .08
@export var barrel_knockdown_speed := 220.0
@export var barrel_knockdown_duration := 1.5
@export var barrel_impact_cooldown := .75

func as_dictionary() -> Dictionary:
	var values := {}
	for entry in BLAST_SWITCHES+BLAST_PARAMS: values[entry[0]] = get(entry[0])
	return values
func apply_values(values: Dictionary) -> void:
	for entry in BLAST_SWITCHES:
		if values.get(entry[0]) is bool: set(entry[0],values[entry[0]])
	for param in BLAST_PARAMS:
		var value = values.get(param[0],get(param[0]))
		if (value is float or value is int) and is_finite(float(value)):
			set(param[0],clampf(float(value),param[2],param[3]))
func snapshot() -> CoreExplosionSettings:
	var result := CoreExplosionSettings.new()
	result.apply_values(as_dictionary())
	return result

@export var grenades_enabled := true
@export var grenade_trajectory_enabled := true
@export var grenade_impact_enabled := true
@export var grenade_starting_count := 5.0
@export var grenade_fuse := 4.0
@export var grenade_min_speed := 180.0
@export var grenade_max_speed := 1100.0
@export var grenade_charge_time := 1.2
@export var grenade_lob_angle := 20.0
@export var grenade_move_multiplier := .85
@export var grenade_gravity := 980.0
@export var grenade_bounce := .55
@export var grenade_friction := .45
@export var grenade_mass := .45
@export var grenade_radius := 5.0
@export var grenade_spin := 12.0
@export var grenade_blast_radius := 220.0
@export var grenade_blast_damage := 120.0
@export var grenade_blast_impulse := 1200.0
@export var grenade_shockwave_radius := 380.0
@export var grenade_impact_min_speed := 350.0
@export var grenade_impact_damage_scale := .025
@export var grenade_impact_max_damage := 40.0
@export var explosion_shockwave_enabled := true
@export var explosion_shockwave_radius := 420.0
@export var explosion_shockwave_damage := 25.0
@export var explosion_shockwave_push := 420.0
@export var explosion_ragdoll_enabled := true
@export var explosion_ragdoll_min_distance := 80.0
@export var explosion_ragdoll_duration := 2.0
@export var explosion_ragdoll_lift := 160.0
@export var explosion_ragdoll_tension := .12
@export var explosion_sever_enabled := true
@export var explosion_sever_chance := .45
@export var explosion_sever_min_damage := 10.0
