class_name CoreRagdollSettings
extends CoreExplosionSettings
## Legacy physics-profile name retained for compatible CFG/JSON files.

const SAVE_PATH := "user://core_ragdoll.cfg"
static var SWITCHES: Array = [
	["simulation_enabled", "Физика манекена включена", "Манекен", "Выключено: манекен замирает в текущей позе и не реагирует на попадания. Повторное включение продолжает симуляцию."]
] + CoreExplosionSettings.BLAST_SWITCHES + [
	["hanging_enabled","Подвесные грузы включены","Подвесные грузы","Выключение замораживает только подвесные грузы и отключает обрыв. Повторное включение продолжает физику."],
	["hanging_impact_enabled","Урон и сбивание грузом","Подвесные грузы","Отключает урон и сбивание от упавшего груза. Падение и физические столкновения сохраняются."],
	["hanging_net_tear_enabled","Разрыв сетки при ударе","Подвесные грузы","При сильном ударе содержимое рассыпается, сетка рвётся и падает отдельными физическими участками. Изменение не собирает уже рассыпавшийся груз: используйте восстановление."]
]
@export var simulation_enabled := true

static var PARAMS: Array = [
	["muscle_tension","Напряжение конечностей",0.0,1.0,.05,"×","Манекен"],
	["muscle_stiffness","Жёсткость суставов",100.0,5000.0,100.0,"","Манекен"],
	["muscle_damping","Затухание раскачивания",0.0,20.0,.5,"/с","Манекен"]] + CoreExplosionSettings.BLAST_PARAMS + [
	["hanging_scale","Размер · после восстановления",.5,2.0,.05,"×","Подвесные грузы"],
	["hanging_rope_length","Длина троса · после восстановления",80.0,340.0,5.0,"px","Подвесные грузы"],
	["hanging_rope_health","Прочность троса",1.0,200.0,1.0,"HP","Подвесные грузы"],
	["hanging_mount_health","Прочность крепления",1.0,500.0,1.0,"HP","Подвесные грузы"],
	["hanging_base_mass","Масса эталонного груза",5.0,250.0,1.0,"кг","Подвесные грузы"],
	["hanging_damage_scale","Множитель урона от энергии",0.0,1.0,.001,"×","Подвесные грузы"],
	["hanging_size_influence","Влияние габаритов на урон",0.0,1.5,.05,"×","Подвесные грузы"],
	["hanging_wood_damage","Опасность дерева",0.0,3.0,.05,"×","Подвесные грузы"],
	["hanging_rubble_damage","Опасность строительного мусора",0.0,3.0,.05,"×","Подвесные грузы"],
	["hanging_metal_damage","Опасность металла",0.0,3.0,.05,"×","Подвесные грузы"],
	["hanging_min_speed","Минимальная скорость урона",30.0,500.0,5.0,"px/с","Подвесные грузы"],
	["hanging_max_damage","Предел урона за удар",0.0,1000.0,5.0,"HP","Подвесные грузы"],
	["hanging_knockdown_speed","Скорость сбивания с ног",100.0,1200.0,10.0,"px/с","Подвесные грузы"],
	["hanging_knockdown_duration","Время на земле",0.0,5.0,.05,"с","Подвесные грузы"],
	["hanging_hit_cooldown","Интервал ударов по одной цели",.2,3.0,.05,"с","Подвесные грузы"],
	["hanging_net_tear_speed","Порог разрыва сетки",80.0,1200.0,5.0,"px/с","Подвесные грузы"],
	["hanging_net_strength","Прочность и растяжение сетки",.1,3.0,.05,"×","Подвесные грузы"],
	["hanging_spill_scatter","Разлёт содержимого",0.0,1.5,.05,"×","Подвесные грузы"]
]

@export var muscle_tension := 1.0
@export var muscle_stiffness := 1000.0
@export var muscle_damping := 5.0
@export var hanging_enabled := true
@export var hanging_impact_enabled := true
@export var hanging_scale := 1.0
@export var hanging_rope_length := 170.0
@export var hanging_rope_health := 15.0
@export var hanging_mount_health := 25.0
@export var hanging_base_mass := 35.0
@export var hanging_damage_scale := .12
@export var hanging_size_influence := .5
@export var hanging_wood_damage := .65
@export var hanging_rubble_damage := 1.0
@export var hanging_metal_damage := 1.3
@export var hanging_min_speed := 100.0
@export var hanging_max_damage := 500.0
@export var hanging_knockdown_speed := 380.0
@export var hanging_knockdown_duration := 1.5
@export var hanging_hit_cooldown := .8
@export var hanging_net_tear_enabled := true
@export var hanging_net_tear_speed := 220.0
@export var hanging_net_strength := 1.0
@export var hanging_spill_scatter := .7

func as_dictionary() -> Dictionary:
	var values := {}
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
func set_parameter(key: String,value: float) -> void:
	if not is_finite(value): return
	for param in PARAMS:
		if param[0] == key:
			var snapped_value := clampf(snappedf(value,float(param[4])),float(param[2]),float(param[3]))
			# Keep slider decimals identical to their CFG/JSON representation.
			set(key,float(String.num(snapped_value,step_decimals(float(param[4])))))
			return
func save_saved(path := SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	for key in as_dictionary(): config.set_value("ragdoll",key,get(key))
	return config.save(path)
func load_saved(path := SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	var result := config.load(path)
	if result != OK: return result
	var values := {}
	for key in as_dictionary(): values[key] = config.get_value("ragdoll",key,get(key))
	for entry in SWITCHES: values[entry[0]] = config.get_value("ragdoll",entry[0],true)
	apply_values(values)
	return OK
func as_text() -> String:
	var lines := PackedStringArray()
	for key in as_dictionary(): lines.append("%s = %s" % [key,str(get(key))])
	return "\n".join(lines)
