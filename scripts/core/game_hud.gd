extends Control
## One live HUD and layout editor for native 3D and every shared 2D map.
const PARAMETERS = preload("res://scripts/core/hud_parameters.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
var stage: Node
var settings: CoreCameraSettings
var blocks: Dictionary = {}
var texts: Dictionary = {}
var bars: Dictionary = {}
var telemetry_nodes: Array[Control] = []
var toolbar: HBoxContainer
var editor: PanelContainer
var editing := false
var selected := "health"
var dragging := ""
var drag_offset := Vector2.ZERO
var telemetry_button: Button
var edit_button: Button
var choice: OptionButton
var x_number: SpinBox
var y_number: SpinBox
var scale_number: SpinBox
var show_toggle: CheckButton
var status: Label
var syncing := false
var last_data: Dictionary = {}
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 process_priority = 100
 add_to_group("runtime_game_hud")
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 settings = stage.camera_settings
 for i in PARAMETERS.IDS.size(): _block(PARAMETERS.IDS[i],PARAMETERS.TITLES[i])
 _build_toolbar()
 _build_editor()
 var hud_page=stage.camera_overlay.tabs.get_tab_control(stage.camera_overlay.groups.find("HUD")).get_child(0)
 var hud_actions:=HBoxContainer.new()
 hud_actions.add_child(_button("Переместить блоки · H",func(): set_editing(true)))
 hud_actions.add_child(_button("Сохранить HUD",save_layout))
 hud_page.add_child(hud_actions)
 hud_page.move_child(hud_actions,0)
 var dev = stage.developer.developer_mode if stage is Node3D else stage.developer_mode
 dev.telemetry_toggle.set_pressed_no_signal(settings.hud_telemetry_enabled)
 dev.telemetry_toggle.toggled.connect(set_telemetry_enabled)
 get_viewport().size_changed.connect(_layout)
 _collect_telemetry.call_deferred()
 _layout()
 _process(0)
func _style() -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color=Color("17232dec")
 style.border_color=Color("58717a")
 style.set_border_width_all(1)
 style.set_corner_radius_all(6)
 style.content_margin_left=12
 style.content_margin_right=12
 style.content_margin_top=7
 style.content_margin_bottom=7
 return style
func _button(title: String,callback: Callable) -> Button:
 var button:=Button.new()
 button.text=title
 button.focus_mode=Control.FOCUS_NONE
 button.pressed.connect(callback)
 return button
func _block(id: String,title: String) -> void:
 var panel:=PanelContainer.new()
 panel.custom_minimum_size=Vector2(250,76)
 panel.size=Vector2(250,76)
 if id=="ammo":
  panel.custom_minimum_size=Vector2(330,96)
  panel.size=Vector2(330,96)
 panel.add_theme_stylebox_override("panel",_style())
 panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel.gui_input.connect(_drag_input.bind(id))
 add_child(panel)
 var column:=VBoxContainer.new()
 column.mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel.add_child(column)
 var heading:=Label.new()
 heading.text=title.to_upper()
 heading.add_theme_font_size_override("font_size",12)
 heading.add_theme_color_override("font_color",Color("a6b9c2"))
 heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
 column.add_child(heading)
 var value:=Label.new()
 value.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 value.add_theme_font_size_override("font_size",18)
 value.mouse_filter=Control.MOUSE_FILTER_IGNORE
 column.add_child(value)
 texts[id]=value
 if id in ["health","stamina"]:
  var bar:=ProgressBar.new()
  bar.custom_minimum_size=Vector2(0,5)
  bar.max_value=1
  bar.show_percentage=false
  bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var background:=StyleBoxFlat.new()
  background.bg_color=Color("31424c")
  var fill:=StyleBoxFlat.new()
  fill.bg_color=Color("b76d63") if id=="health" else Color("b8bf8a")
  bar.add_theme_stylebox_override("background",background)
  bar.add_theme_stylebox_override("fill",fill)
  column.add_child(bar)
  bars[id]=bar
 blocks[id]=panel
func _build_toolbar() -> void:
 toolbar=HBoxContainer.new()
 toolbar.add_theme_constant_override("separation",8)
 add_child(toolbar)
 telemetry_button=_button("Телеметрия · F12",func(): set_telemetry_enabled(not settings.hud_telemetry_enabled))
 telemetry_button.toggle_mode=true
 toolbar.add_child(telemetry_button)
 edit_button=_button("Настроить HUD · H",func(): set_editing(not editing))
 toolbar.add_child(edit_button)
func _number(minimum: float,maximum: float,step: float,callback: Callable) -> SpinBox:
 var number:=SpinBox.new()
 number.min_value=minimum
 number.max_value=maximum
 number.step=step
 number.custom_minimum_size.x=100
 number.value_changed.connect(callback)
 number.get_line_edit().text_submitted.connect(func(_value): number.apply(); number.get_line_edit().release_focus())
 return number
func _build_editor() -> void:
 editor=PanelContainer.new()
 editor.add_theme_stylebox_override("panel",_style())
 add_child(editor)
 var column:=VBoxContainer.new()
 editor.add_child(column)
 var hint:=Label.new()
 hint.text="Перетаскивайте блоки мышью. X/Y — положение на экране; размер настраивается отдельно."
 column.add_child(hint)
 var row:=HBoxContainer.new()
 column.add_child(row)
 choice=OptionButton.new()
 for title in PARAMETERS.TITLES: choice.add_item(title)
 choice.item_selected.connect(func(index): _finish_editing(); selected=PARAMETERS.IDS[index]; _sync_editor())
 row.add_child(choice)
 x_number=_number(0,100,.1,func(v): _change("x",v/100))
 y_number=_number(0,100,.1,func(v): _change("y",v/100))
 scale_number=_number(.5,2,.05,func(v): _change("scale",v))
 x_number.prefix="X "
 y_number.prefix="Y "
 x_number.suffix="%"
 y_number.suffix="%"
 scale_number.prefix="× "
 for number in [x_number,y_number,scale_number]: row.add_child(number)
 show_toggle=CheckButton.new()
 show_toggle.text="Показывать"
 show_toggle.toggled.connect(func(value):
  if not syncing: settings.set("hud_"+selected+"_visible",value); _changed())
 row.add_child(show_toggle)
 var actions:=HBoxContainer.new()
 column.add_child(actions)
 actions.add_child(_button("Сохранить HUD",save_layout))
 actions.add_child(_button("Сбросить размещение",reset_layout))
 actions.add_child(_button("Готово · H",func(): set_editing(false)))
 status=Label.new()
 status.text="Изменения в памяти. Для записи в профиль нажмите «Сохранить HUD»."
 actions.add_child(status)
 editor.hide()
func _finish_editing() -> void:
 for number in [x_number,y_number,scale_number]:
  if number and number.get_line_edit().has_focus(): number.apply(); number.get_line_edit().release_focus()
func _change(suffix: String,value: float) -> void:
 if syncing: return
 settings.set_parameter("hud_"+selected+"_"+suffix,value)
 _changed()
func _changed() -> void:
 status.text="Не сохранено · нажмите «Сохранить HUD»"
 _layout()
 stage.camera_overlay._sync()
func _sync_editor() -> void:
 syncing=true
 choice.select(PARAMETERS.IDS.find(selected))
 x_number.set_value_no_signal(settings.get("hud_"+selected+"_x")*100)
 y_number.set_value_no_signal(settings.get("hud_"+selected+"_y")*100)
 scale_number.set_value_no_signal(settings.get("hud_"+selected+"_scale"))
 show_toggle.set_pressed_no_signal(settings.get("hud_"+selected+"_visible"))
 syncing=false
func set_editing(value: bool) -> void:
 _finish_editing()
 editing=value
 dragging=""
 if value:
  var dev = stage.developer.developer_mode if stage is Node3D else stage.developer_mode
  dev.set_enabled(false)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 _suppress_shot()
 editor.visible=value
 edit_button.text="Редактор HUD · H" if value else "Настроить HUD · H"
 _sync_editor()
 _layout()
func _suppress_shot() -> void:
 if stage is Node3D: stage.developer.developer_prepare()
 else: stage.suppress_mouse_until_release=true; stage.player.weapon.queued_single_press=false
func set_telemetry_enabled(value: bool) -> void:
 settings.hud_telemetry_enabled=value
 var dev = stage.developer.developer_mode if stage is Node3D else stage.developer_mode
 dev.telemetry_toggle.set_pressed_no_signal(value)
 _apply_telemetry()
 _suppress_shot()
func blocks_mouse_input(point: Vector2) -> bool:
 return editing or toolbar.get_global_rect().has_point(point)
func _drag_input(event: InputEvent,id: String) -> void:
 if not editing: return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:
   _finish_editing()
   selected=id
   dragging=id
   drag_offset=get_global_mouse_position()-blocks[id].position
   _sync_editor()
  else: dragging=""
  accept_event()
func move_block(id: String,point: Vector2) -> void:
 var panel: Control=blocks[id]
 var available: Vector2=(get_viewport_rect().size-panel.size*panel.scale).max(Vector2.ZERO)
 settings.set_parameter("hud_"+id+"_x",clampf(point.x/maxf(1,available.x),0,1))
 settings.set_parameter("hud_"+id+"_y",clampf(point.y/maxf(1,available.y),0,1))
 _changed()
 _sync_editor()
func _input(event: InputEvent) -> void:
 if editing and event is InputEventMouseMotion and dragging!="":
  move_block(dragging,event.position-drag_offset)
  get_viewport().set_input_as_handled()
 if event is InputEventMouseButton and not event.pressed: dragging=""
 if not event is InputEventKey or not event.pressed or event.echo: return
 if (stage.developer.settings_dialog_open if stage is Node3D else stage.settings_dialog_open): return
 var focus:=get_viewport().gui_get_focus_owner()
 if focus is LineEdit or focus is TextEdit:
  if editing and event.physical_keycode==KEY_ESCAPE:
   _finish_editing()
   get_viewport().set_input_as_handled()
  return
 if editing and event.physical_keycode in [KEY_F2,KEY_F3,KEY_F4,KEY_F5,KEY_F6,KEY_F10]:
  set_editing(false)
 if event.physical_keycode==KEY_F12:
  set_telemetry_enabled(not settings.hud_telemetry_enabled)
  get_viewport().set_input_as_handled()
 elif event.physical_keycode==KEY_H or (editing and event.physical_keycode==KEY_ESCAPE):
  set_editing(not editing)
  get_viewport().set_input_as_handled()
func _collect_telemetry() -> void:
 if stage is Node3D: telemetry_nodes.assign([stage.hud,stage.combat.readout])
 else:
  for child in stage.hud.get_parent().get_children():
   if child is Label and child!=stage.interaction_hint: telemetry_nodes.append(child)
  telemetry_nodes.append(stage.ammo_progress)
 for child in get_tree().get_nodes_in_group("gameplay_telemetry"):
  if stage.is_ancestor_of(child) and child is Control: telemetry_nodes.append(child)
 _apply_telemetry()
func _apply_telemetry() -> void:
 var enabled: bool=settings.hud_telemetry_enabled
 var dev = stage.developer.developer_mode if stage is Node3D else stage.developer_mode
 dev.telemetry_toggle.set_pressed_no_signal(enabled)
 telemetry_button.set_pressed_no_signal(enabled)
 if stage is Node3D:
  for enemy in stage.combat.targets+stage.combat.enemies: enemy.label.visible=enabled
 else:
  for enemy in stage.level.enemies:
   if enemy.has_method("set_telemetry_enabled"): enemy.set_telemetry_enabled(enabled)
 for node in telemetry_nodes:
  if is_instance_valid(node):
   if stage is Node2D and node==stage.ammo_progress: node.visible=enabled and stage.player.weapon.reloading
   else: node.visible=enabled
func read_data() -> Dictionary:
 var native:=stage is Node3D
 var player=stage.player
 var gun=stage.combat.gun if native else player.weapon
 var id: String=gun.weapon_id if native else gun.equipped_weapon_id
 var mag: int=gun.magazine if native else gun.magazine_ammo
 var reserve: int=gun.reserve if native else gun.reserve_ammo
 var capacity: int=gun.tuning.magazine_capacity if native else gun.capacity()
 var fraction: float=player.reserve if native else player.sprint_reserve
 var grenades: Variant=null
 var held:=false
 if "grenades" in player and is_instance_valid(player.grenades):
  grenades=player.grenades.count
  held=player.grenades.preparing()
 var gadgets: Variant=stage.get_hud_gadgets() if stage.has_method("get_hud_gadgets") else null
 return {"health":player.health,"max_health":player.maximum_health(),"stamina":fraction,"stamina_seconds":fraction*player.tuning.sprint_duration,"stamina_duration":player.tuning.sprint_duration,"stamina_enabled":player.tuning.sprint_enabled,"weapon_id":id,"weapon":CATALOG.WEAPONS[CATALOG.index_for(id)].name if id!="" else "Нет оружия","magazine":mag,"capacity":capacity,"reserve":reserve,"total":mag+reserve,"reloading":gun.reload_left>0 if native else gun.reloading,"grenades":grenades,"held_grenade":held,"gadgets":gadgets}
func _process(_dt: float) -> void:
 last_data=read_data()
 var d:=last_data
 texts.health.text=String.num(d.health,3)+" / "+String.num(d.max_health,3)+" HP"
 bars.health.value=clampf(d.health/maxf(1,d.max_health),0,1)
 texts.stamina.text=("%.1f%% · %s / %s с" % [d.stamina*100,String.num(d.stamina_seconds,3),String.num(d.stamina_duration,3)]) if d.stamina_enabled else "Спринт отключён"
 bars.stamina.value=d.stamina
 texts.weapon.text=d.weapon
 texts.ammo.text="В магазине %d / %d\nЗапас %d · Всего %d%s" % [d.magazine,d.capacity,d.reserve,d.total," · R…" if d.reloading else ""]
 texts.grenades.text="Не подключены" if d.grenades==null else str(d.grenades)+(" + 1 в руке" if d.held_grenade else "")
 texts.gadgets.text="Не подключены" if d.gadgets==null else str(d.gadgets)
 _layout()
 _apply_telemetry()
func _layout() -> void:
 if not toolbar: return
 var viewport:=get_viewport_rect().size
 toolbar.position=Vector2(maxf(8,(viewport.x-toolbar.size.x)*.5),12)
 editor.position=Vector2(maxf(8,(viewport.x-editor.size.x)*.5),62)
 for id in blocks:
  var panel: Control=blocks[id]
  # Wrapped labels can report a transient tall minimum before receiving width.
  panel.size=Vector2(330,96) if id=="ammo" else Vector2(250,76)
  var factor: float=settings.get("hud_"+id+"_scale")
  factor=minf(factor,minf(viewport.x/maxf(1,panel.size.x),viewport.y/maxf(1,panel.size.y)))
  panel.scale=Vector2.ONE*factor
  var available: Vector2=(viewport-panel.size*factor).max(Vector2.ZERO)
  panel.position=available*Vector2(settings.get("hud_"+id+"_x"),settings.get("hud_"+id+"_y"))
  panel.visible=editing or (settings.hud_enabled and settings.get("hud_"+id+"_visible"))
  panel.modulate.a=1.0 if editing else settings.hud_opacity
  panel.mouse_filter=Control.MOUSE_FILTER_STOP if editing else Control.MOUSE_FILTER_IGNORE
func save_layout() -> void:
 _finish_editing()
 var config:=ConfigFile.new()
 var result:=config.load(stage.camera_settings_path)
 if result not in [OK,ERR_FILE_NOT_FOUND]:
  status.text="Ошибка чтения профиля (%d), файл не изменён" % result
  return
 if result==ERR_FILE_NOT_FOUND:
  for key in settings.as_dictionary(): config.set_value("camera",key,settings.get(key))
 for entry in PARAMETERS.PARAMS+PARAMETERS.SWITCHES: config.set_value("camera",entry[0],settings.get(entry[0]))
 result=config.save(stage.camera_settings_path)
 status.text="HUD сохранён в профиль камеры" if result==OK else "Не удалось сохранить HUD (%d)" % result
 if result==OK:
  for entry in PARAMETERS.PARAMS+PARAMETERS.SWITCHES: stage.camera_overlay.saved_values[entry[0]]=settings.get(entry[0])
func reset_layout() -> void:
 var defaults:=CoreCameraSettings.new()
 for entry in PARAMETERS.PARAMS:
  if entry[0]!="hud_opacity": settings.set(entry[0],defaults.get(entry[0]))
 _sync_editor()
 _changed()
