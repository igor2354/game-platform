extends Node
## Three live menus wrap the existing gameplay scene without replacing its tools.
const CATALOG = preload("res://scripts/campaign/catalog.gd")
const ART = preload("res://scripts/campaign/art.gd")
const RUINS = preload("res://resources/campaign/ruins.png")
const MAIN = preload("res://resources/campaign/main_menu.webp")
const BASE := Vector2(1600,900)
@export var load_user_settings := true
var test_settings_directory := "" # Set before launch by profile-import tests only.
var selected_character := "harry"
var selected_weapon := "stg44"
var selected_mode := "campaign"
var selected_level := "prologue"
var page := "main"
var stage: Control
var layer: CanvasLayer
var game: CoreMovementLab
var buttons: Dictionary = {}
var menu_font: SystemFont
var busy := false
var game_bar: CanvasLayer

class Plate extends Button:
	func _draw() -> void:
		var color := Color("f33227") if button_pressed or is_hovered() else Color("a28b72")
		for corner in [Vector2(3,3),Vector2(size.x-3,3),Vector2(3,size.y-3),size-Vector2(3,3)]:
			var toward := Vector2(1 if corner.x < size.x/2 else -1,1 if corner.y < size.y/2 else -1)
			draw_line(corner+toward*Vector2(2,13),corner+toward*Vector2(13,2),color,1.5,true)
	func _process(_delta: float) -> void: queue_redraw()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_font = SystemFont.new()
	menu_font.font_names = PackedStringArray(["Georgia","Times New Roman","DejaVu Serif"])
	menu_font.allow_system_fallback = true
	layer = CanvasLayer.new()
	layer.layer = 70
	add_child(layer)
	stage = Control.new()
	stage.size = BASE
	layer.add_child(stage)
	get_viewport().size_changed.connect(_resize)
	_resize()
	show_page("main")

func _resize() -> void:
	stage.scale = get_viewport().get_visible_rect().size/BASE

func _style(selected := false,alpha := .92) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color(.13,.012,.008,alpha) if selected else Color(.025,.025,.022,alpha)
	result.border_color = Color("f23022") if selected else Color("968878")
	result.set_border_width_all(2)
	result.set_corner_radius_all(6)
	result.shadow_color = Color(.8,.025,0,.4) if selected else Color(0,0,0,.65)
	result.shadow_size = 7 if selected else 4
	result.content_margin_left = 14
	result.content_margin_right = 14
	return result

func _plate_style(selected: bool) -> StyleBoxTexture:
	var result := StyleBoxTexture.new()
	result.texture = ART.chrome(selected)
	result.content_margin_left = 24
	result.content_margin_right = 24
	result.content_margin_top = 6
	result.content_margin_bottom = 6
	return result

func _label(text: String,rect: Rect2,font_size: int,parent: Node = null,color := Color("e7dfd1"),wrap := false) -> Label:
	var label := Label.new()
	if wrap: label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font",menu_font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else stage).add_child(label)
	return label

func _picture(texture: Texture2D,rect: Rect2,parent: Node = null,mode := TextureRect.STRETCH_KEEP_ASPECT_CENTERED) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = mode
	picture.position = rect.position
	picture.size = rect.size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else stage).add_child(picture)
	return picture

func _panel(rect: Rect2,selected := false) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",_style(selected))
	stage.add_child(panel)
	return panel

func _button(id: String,text: String,rect: Rect2,action: Callable,selected := false) -> Button:
	var button := Plate.new()
	button.name = id
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_override("font",menu_font)
	button.add_theme_font_size_override("font_size",30)
	button.add_theme_color_override("font_color",Color("e7dfd1"))
	button.add_theme_color_override("font_hover_color",Color.WHITE)
	button.add_theme_stylebox_override("normal",_plate_style(selected))
	button.add_theme_stylebox_override("hover",_plate_style(true))
	button.add_theme_stylebox_override("pressed",_plate_style(true))
	button.add_theme_stylebox_override("focus",_style(true,.12))
	button.pressed.connect(action)
	stage.add_child(button)
	buttons[id] = button
	return button

func show_page(next: String) -> void:
	page = next
	buttons.clear()
	for child in stage.get_children():
		stage.remove_child(child)
		child.queue_free()
	stage.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if next == "main":
		_main_menu()
	else:
		_picture(RUINS,Rect2(Vector2.ZERO,BASE),null,TextureRect.STRETCH_SCALE)
		var shade := ColorRect.new()
		shade.color = Color(0,0,0,.18)
		shade.size = BASE
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(shade)
		if next == "levels": _levels()
		elif next == "characters": _characters()
		else: _weapons()

func _main_menu() -> void:
	_picture(MAIN,Rect2(Vector2.ZERO,BASE),null,TextureRect.STRETCH_SCALE)
	var definitions := [["campaign",Rect2(1148,147,389,79),func(): show_page("levels")],["polygon",Rect2(1152,250,381,77),func(): begin_selection(false)],["settings",Rect2(1152,350,381,76),func(): pass],["quit",Rect2(1159,448,374,74),func(): get_tree().quit()]]
	for definition in definitions:
		var button := _button(definition[0],"",definition[1],definition[2])
		button.tooltip_text = {"campaign":"Компания","polygon":"Полигон","settings":"Настройки — пока недоступно","quit":"Выход"}[definition[0]]
		button.disabled = definition[0] == "settings"
		button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		button.add_theme_stylebox_override("disabled",StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover",_style(true,.10))
		button.add_theme_stylebox_override("pressed",_style(true,.18))

func _title(text: String,width: float) -> void:
	var panel := _panel(Rect2(32,24,width,81),true)
	panel.add_theme_stylebox_override("panel",_plate_style(true))
	_label("✠  "+text,Rect2(53,32,width-30,65),43)

func _levels() -> void:
	_title("Выберите уровень",710)
	_label("КОМПАНИЯ",Rect2(1260,48,300,40),25)
	for index in 2:
		var id := "prologue" if index == 0 else "prologue_v2"
		var card := _button(id,"",Rect2(250,230+index*230,1100,180),func(): select_level(id),selected_level == id)
		_label("Пролог" if index == 0 else "Пролог ver2",Rect2(35,24,1000,58),40,card)
		_label("Первоначальный уровень" if index == 0 else "Новый лесной маршрут · геометрия без текстур",Rect2(38,100,1000,40),25,card,Color("bdb29e"))
	_button("back","‹  Назад",Rect2(40,820,220,58),func(): show_page("main"))

func select_level(id: String) -> void:
	if id not in ["prologue","prologue_v2"]: return
	selected_level = id
	begin_selection(true)

func _mode_caption() -> String:
	if selected_mode == "polygon": return "ПОЛИГОН"
	return "ПРОЛОГ VER2" if selected_level == "prologue_v2" else "ПРОЛОГ · I"

func _characters() -> void:
	_title("Выберите персонажа",710)
	_label(_mode_caption(),Rect2(1260,48,300,40),25)
	for index in 2:
		var character: Dictionary = CATALOG.CHARACTERS[index]
		var x := 200.0+index*650
		var portrait := _picture(ART.portrait(character.id),Rect2(x-100,98,650,720))
		portrait.modulate = Color.WHITE if selected_character == character.id else Color(.77,.77,.77)
		var selected: bool = selected_character == character.id
		var card := _button(character.id,"",Rect2(x-35,570,490,212),func(): select_character(character.id),selected)
		_label("✠  "+character.name,Rect2(22,22,446,44),36,card)
		_label(character.role,Rect2(61,70,410,28),17,card,Color("bdb29e"))
		for i in 3:
			var icon: String = ["⊕","Ⅲ","✚"][i]
			_label(icon,Rect2(60+i*140,99,70,43),34,card)
			_label(["ВЫЖИВАЕМОСТЬ","ОГНЕВАЯ МОЩЬ","ПОДДЕРЖКА"][i],Rect2(21+i*150,154,154,28),12,card,Color("bdb29e"))
	_button("back","‹  Назад",Rect2(40,820,220,58),func(): show_page("levels" if selected_mode == "campaign" else "main"))
	_button("choose","Выбрать  ›",Rect2(1310,820,250,58),func(): show_page("weapons"),true)

func select_character(id: String) -> void:
	if id not in ["harry","sofia"]: return
	selected_character = id
	show_page("characters")

func select_weapon(id: String) -> void:
	selected_weapon = CATALOG.WEAPONS[CATALOG.index_for(id)].id
	show_page("weapons")

func _weapons() -> void:
	_title("Настройка и выбор оружия",1000)
	_label(_mode_caption(),Rect2(1260,48,300,40),25)
	_picture(ART.portrait(selected_character),Rect2(-80,115,760,765))
	_panel(Rect2(610,119,950,685))
	_label("Выбор оружия",Rect2(640,125,880,57),38)
	for index in 4:
		var entry: Dictionary = CATALOG.WEAPONS[index]
		var card := _button(entry.id,"",Rect2(635+index*225,190,211,190),func(): select_weapon(entry.id),selected_weapon == entry.id)
		_picture(ART.weapon(index),Rect2(14,12,183,125),card)
		var caption := _label(entry.name,Rect2(10,126,191,36),27,card)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var selected := CATALOG.index_for(selected_weapon)
	var data: Dictionary = CATALOG.WEAPONS[selected]
	_panel(Rect2(630,395,910,194))
	_label(data.name,Rect2(648,399,280,45),34)
	_label(data.description,Rect2(650,449,240,108),18,null,Color("e7dfd1"),true)
	_picture(ART.weapon(selected),Rect2(912,425,335,134))
	var stat_names := ["Урон","Дальность","Точность","Контроль","Темп"]
	for index in 5:
		_label(stat_names[index],Rect2(1260,411+index*32,140,27),17)
		var bar := ColorRect.new()
		bar.position = Vector2(1390,423+index*32)
		bar.size = Vector2(125,7)
		bar.color = Color("25221f")
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(bar)
		var fill := ColorRect.new()
		fill.size = Vector2(125*data.stats[index],7)
		fill.color = Color("c5b2a0")
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(fill)
	_label("Настройка оружия",Rect2(650,596,830,48),34)
	# These are intentionally read-only; only weapon selection is enabled.
	var rows := ["Прицел                         Стандартный прицел","Точность                       Стандартная","Контроль отдачи           Стандартный","Скорость прицеливания   Стандартная","Боезапас                       Магазин (%d)" % int(data.values.magazine_capacity)]
	for index in rows.size():
		_label(rows[index],Rect2(657,651+index*26,850,27),19,null,Color("8c877e"))
	_button("back","‹  Назад",Rect2(40,820,220,58),func(): show_page("characters"))
	_button("apply","Применить  ›",Rect2(1270,820,290,58),func(): launch(selected_mode == "campaign"),true)

func begin_selection(campaign: bool) -> void:
	selected_mode = "campaign" if campaign else "polygon"
	show_page("characters")

func launch(campaign: bool) -> void:
	if busy or is_instance_valid(game): return
	busy = true
	stage.hide()
	var scene_path := "res://scenes/main.tscn"
	if campaign: scene_path = "res://scenes/campaign/prologue_v2.tscn" if selected_level == "prologue_v2" else "res://scenes/campaign/prologue.tscn"
	game = load(scene_path).instantiate()
	game.load_user_settings = load_user_settings
	if not test_settings_directory.is_empty():
		for entry in [["settings_path","movement.cfg"],["shooting_settings_path","shooting.cfg"],["camera_settings_path","camera.cfg"],["zombie_settings_path","zombie.cfg"],["ragdoll_settings_path","ragdoll.cfg"]]:
			game.set(entry[0],test_settings_directory.path_join(entry[1]))
	game.get_node("World/Player").character_id = selected_character
	game.get_node("World/Player").sofia_cel_variant = selected_character == "sofia"
	add_child(game)
	CATALOG.equip(game.player.weapon,selected_weapon)
	game.shooting_overlay.defaults.apply_values(CATALOG.WEAPONS[CATALOG.index_for(selected_weapon)].values)
	game.shooting_overlay._sync()
	game.suppress_mouse_until_release = true
	game_bar = CanvasLayer.new()
	game_bar.layer = 60
	game.add_child(game_bar)
	var back := Button.new()
	back.text = "В главное меню"
	back.position = Vector2(1060,16)
	back.size = Vector2(250,42)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(return_to_menu)
	game_bar.add_child(back)
	var character_name: String = "Гарри" if selected_character == "harry" else "София Шоль"
	_label((_mode_caption() if campaign else "ПОЛИГОН")+"   /   "+character_name+"   /   "+CATALOG.WEAPONS[CATALOG.index_for(selected_weapon)].name,Rect2(30,152,1200,43),25,game_bar)
	page = "game"
	busy = false

func return_to_menu() -> void:
	if busy or not is_instance_valid(game): return
	busy = true
	get_tree().paused = false
	Engine.time_scale = 1
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.queue_free()
	await get_tree().process_frame
	game = null
	get_viewport().canvas_transform = Transform2D.IDENTITY
	show_page("main")
	busy = false

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(game): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and page != "main":
			show_page("characters" if page == "weapons" else "levels" if page == "characters" and selected_mode == "campaign" else "main")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F11:
			var window := get_window()
			window.mode = Window.MODE_WINDOWED if window.mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN] else Window.MODE_EXCLUSIVE_FULLSCREEN
