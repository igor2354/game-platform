class_name CoreEnemyTools
extends VBoxContainer
## Session-only controls; never stored in balance profiles or JSON.
var lab: Node
var freeze_toggle: CheckButton
var invulnerable_toggle: CheckButton
var target_choice: OptionButton
var health_number: SpinBox
var health_slider: HSlider
var maximum_number: SpinBox
var maximum_slider: HSlider
var heal_button: Button
var readout: Label
var syncing := false
var selected_index := 0

func _ready() -> void:
	add_theme_constant_override("separation",8)
	add_child(lab.movement_overlay._label("ПРОТИВНИКИ ПОЛИГОНА",19))
	freeze_toggle = _toggle("Остановить всех противников",func(value: bool):
		lab.developer_mode._prepare_action()
		for enemy in _enemies(): enemy.set_test_frozen(value)
		sync())
	freeze_toggle.tooltip_text = "Замораживает движение, атаки, таймеры и анимации врагов. Игрок и пули продолжают работать."
	invulnerable_toggle = _toggle("Бессмертие всех противников",func(value: bool):
		lab.developer_mode._prepare_action()
		for enemy in _enemies(): enemy.set_invulnerable(value)
		_release_players()
		sync())
	invulnerable_toggle.tooltip_text = "HP не уменьшаются от урона. Попадания и отстрел конечностей остаются. Включение оживляет погибших на месте."
	target_choice = OptionButton.new()
	target_choice.focus_mode = Control.FOCUS_NONE
	target_choice.add_item("HP: все противники")
	for enemy in _enemies():
		target_choice.add_item(("Зомби " if enemy.is_zombie else "Мишень ")+str(_enemies().find(enemy)+1) if lab.has_method("developer_enemies") else ("Зомби " if enemy is CoreZombie else "Мишень ")+enemy.identifier)
	target_choice.item_selected.connect(func(index: int):
		# Commit an unfinished HP edit to its original targets before switching.
		target_choice.select(selected_index)
		lab.developer_mode._prepare_action()
		target_choice.select(index)
		selected_index = index
		sync())
	add_child(target_choice)
	var current := _number_row("Текущие HP",0,100,.01,_change_health)
	health_number = current.number
	health_slider = current.slider
	var maximum := _number_row("Максимальные HP",1,1000,1,_change_maximum)
	maximum_number = maximum.number
	maximum_slider = maximum.slider
	readout = lab.movement_overlay._label("",14)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(readout)
	heal_button = lab.movement_overlay._button("Восстановить HP выбранных противников",func():
		lab.developer_mode._prepare_action()
		for enemy in targets(): enemy.set_current_health(enemy.maximum_health())
		_release_players()
		sync())
	add_child(heal_button)
	sync()

func _toggle(text: String,callback: Callable) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(callback)
	add_child(toggle)
	return toggle

func _number_row(text: String,minimum: float,maximum: float,step: float,callback: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	var label: Label = lab.movement_overlay._label(text,16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var number := SpinBox.new()
	number.min_value = minimum
	number.max_value = maximum
	number.step = step
	number.suffix = "HP"
	number.custom_minimum_size.x = 150
	number.value_changed.connect(callback)
	number.get_line_edit().text_submitted.connect(func(_text: String): finish_editing())
	row.add_child(number)
	add_child(row)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(callback)
	add_child(slider)
	return {"number":number,"slider":slider}

func targets() -> Array[Node]:
	var result: Array[Node] = []
	for i in _enemies().size():
		var enemy: Node = _enemies()[i]
		if is_instance_valid(enemy) and (target_choice.selected == 0 or target_choice.selected == i+1): result.append(enemy)
	return result

func _editing(number: SpinBox) -> bool:
	return number != null and get_viewport().gui_get_focus_owner() == number.get_line_edit()

func blocks_keyboard_input() -> bool:
	return _editing(health_number) or _editing(maximum_number)

func finish_editing() -> void:
	for number in [health_number,maximum_number]:
		if _editing(number):
			number.apply()
			number.get_line_edit().release_focus()

func _change_health(value: float) -> void:
	if syncing: return
	lab.suppress_mouse_until_release = true
	for enemy in targets(): enemy.set_current_health(value)
	_release_players()
	sync()

func _change_maximum(value: float) -> void:
	if syncing: return
	lab.suppress_mouse_until_release = true
	for enemy in targets(): enemy.set_maximum_health(value)
	sync()

func sync() -> void:
	if not health_number: return
	var selected := targets()
	if selected.is_empty(): return
	syncing = true
	freeze_toggle.set_pressed_no_signal(_enemies().all(func(enemy): return enemy.test_frozen))
	invulnerable_toggle.set_pressed_no_signal(_enemies().all(func(enemy): return enemy.invulnerable))
	var low_health := INF
	var high_health := 0.0
	var low_maximum := INF
	var high_maximum := 0.0
	for enemy in selected:
		low_health = minf(low_health,enemy.health)
		high_health = maxf(high_health,enemy.health)
		low_maximum = minf(low_maximum,enemy.maximum_health())
		high_maximum = maxf(high_maximum,enemy.maximum_health())
	health_slider.max_value = low_maximum
	health_slider.set_value_no_signal(low_health)
	maximum_slider.set_value_no_signal(low_maximum)
	if not _editing(health_number):
		health_number.max_value = low_maximum
		health_number.set_value_no_signal(low_health)
	if not _editing(maximum_number): maximum_number.set_value_no_signal(low_maximum)
	readout.text = "Выбрано: %d · HP: %.2f–%.2f · Максимум: %.0f–%.0f\nПри разных HP показан минимум. Правка применяется ко всем выбранным.\nЛечение сохраняет конечности; F7 восстанавливает врагов полностью.\nОстановка, бессмертие и HP действуют до конца текущего запуска." % [selected.size(),low_health,high_health,low_maximum,high_maximum]
	syncing = false

func _enemies() -> Array:
	return lab.developer_enemies() if lab.has_method("developer_enemies") else lab.level.enemies

func _release_players() -> void:
	if lab.has_method("developer_enemies"):
		for enemy in _enemies(): enemy.release_overlapping_players()
	else: lab.player.allow_exit_overlapping_enemies()
