extends CanvasLayer
var options: RefCounted
var label: Label
var remaining:=0.0
func _ready() -> void:
	layer=110;process_mode=Node.PROCESS_MODE_ALWAYS
	label=Label.new();label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_outline_color",Color.BLACK);label.add_theme_constant_override("outline_size",5)
	label.add_theme_font_size_override("font_size",18);add_child(label)
	get_viewport().size_changed.connect(_layout);options.changed.connect(refresh)
	_layout();refresh()
func _layout() -> void:
	label.position=Vector2(maxf(8,get_viewport().get_visible_rect().size.x*.5-45),8)
func refresh() -> void:
	visible=options.show_fps;set_process(visible)
	if visible:label.text="FPS: %.0f"%Engine.get_frames_per_second();remaining=0
func _process(delta: float) -> void:
	var huds := get_tree().get_nodes_in_group("runtime_game_hud")
	visible = options.show_fps and (huds.is_empty() or huds[0].settings.hud_telemetry_enabled)
	label.position.y = 48 if not huds.is_empty() else 8
	remaining-=delta
	if remaining<=0:label.text="FPS: %.0f"%Engine.get_frames_per_second();remaining=.25
