extends CanvasLayer
signal resume_requested
signal restart_requested
signal menu_requested
var screen: Control
var settings: Control
var resume_button: Button
var settings_button: Button

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 370
	box.add_theme_constant_override("separation",16)
	center.add_child(box)
	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",36)
	box.add_child(title)
	resume_button = _button(box,"Продолжить",func(): resume_requested.emit())
	settings_button = _button(box,"Настройки",func(): settings.open())
	_button(box,"Начать заново · F8",func(): restart_requested.emit())
	_button(box,"В главное меню",func(): menu_requested.emit())
	settings = preload("res://scripts/ui/display_panel.gd").new()
	screen.add_child(settings)
	settings.closed.connect(func(): settings_button.grab_focus())
	screen.hide()

func _button(box: VBoxContainer,text: String,action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 50
	button.add_theme_font_size_override("font_size",23)
	button.pressed.connect(action)
	box.add_child(button)
	return button

func open() -> void:
	screen.show()
	resume_button.grab_focus()

func close() -> void:
	settings.hide()
	screen.hide()
