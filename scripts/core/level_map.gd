class_name CoreLevelMap
extends Control

signal close_requested

const CAMPAIGN_SECTION_WIDTH := 600.0

var level: CoreMovementLevel
var player: CoreMovementPlayer
var camera: Camera2D
var explored_sections: Dictionary = {}
var close_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_button = Button.new()
	close_button.text = "Закрыть · M / Esc"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size",18)
	close_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close_button.offset_left = -230
	close_button.offset_right = -42
	close_button.offset_top = 36
	close_button.offset_bottom = 80
	close_button.pressed.connect(func(): close_requested.emit())
	add_child(close_button)
	queue_redraw()

func _process(_delta: float) -> void:
	if not level or not player: return
	if level.prologue_mode:
		var player_position := level.to_local(player.global_position)
		var section := _section_at(player_position.x)
		if not explored_sections.has(section): explored_sections[section] = true
	if visible: queue_redraw()

func _draw() -> void:
	if not level: return
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.015,0.025,0.032,.94))
	var frame := Rect2(Vector2(28,24),size-Vector2(56,48))
	draw_rect(frame,Color("101a20"),true)
	draw_rect(frame,Color("52616a"),false,2)
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(58,72),"КАРТА УРОВНЯ",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("e0d8c4"))
	var subline := "Схема бокового профиля · герой, геометрия, лестницы и проходы"
	if level.prologue_mode: subline += " · неизведанные участки открываются по мере движения"
	else: subline += " · вся тестовая геометрия, штриховые линии соединяют пары дверей E"
	draw_string(font,Vector2(60,103),subline,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("9babb1"))
	var plot := Rect2(Vector2(62,142),Vector2(size.x-124,maxf(240,size.y-330)))
	_draw_grid(plot)
	_draw_level_geometry(plot)
	_draw_connections(plot)
	_draw_landmarks(plot,font)
	_draw_player_and_camera(plot)
	draw_string(font,Vector2(60,size.y-156),"Условная схема: высота увеличена для читаемости. Динамические позиции врагов и секреты не показываются.",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("9babb1"))
	_draw_legend(font)

func _draw_grid(plot: Rect2) -> void:
	var bounds := _world_x_bounds()
	var x_step := 1000.0
	var first_x := ceilf(bounds.x/x_step)*x_step
	for world_x in range(int(first_x),int(bounds.y)+1,int(x_step)):
		var point := _map_point(Vector2(world_x,_world_y_bounds().x),plot)
		draw_line(Vector2(point.x,plot.position.y),Vector2(point.x,plot.end.y),Color(.28,.36,.4,.24),1)
		draw_string(ThemeDB.fallback_font,Vector2(point.x+4,plot.end.y-8),str(world_x),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(.60,.68,.70,.72))
	draw_rect(plot,Color("718087"),false,1)

func _draw_level_geometry(plot: Rect2) -> void:
	var terrain_color := Color("bdc4b4")
	var platform_color := Color("9aab9f")
	for rect in level.floors:
		_draw_horizontal(rect.position.x,rect.end.x,rect.position.y,plot,terrain_color,5)
	var boundary_color := Color("9c7570") if level.prologue_mode else Color("64747a")
	for world_x in [_world_x_bounds().x,_world_x_bounds().y]:
		draw_line(_map_point(Vector2(world_x,_world_y_bounds().x),plot),_map_point(Vector2(world_x,_world_y_bounds().y),plot),boundary_color,2)
	for rect in level.platforms:
		_draw_horizontal(rect.position.x,rect.end.x,rect.position.y,plot,platform_color,4)
	for rect in level.obstacles:
		if _is_revealed(rect.get_center().x):
			var top_left := _map_point(rect.position,plot)
			var bottom_right := _map_point(rect.end,plot)
			draw_rect(Rect2(top_left,bottom_right-top_left),Color("9b7652"),true)
	for rect in level.ladders:
		if not _is_revealed(rect.get_center().x): continue
		var center_x := rect.get_center().x
		var top := _map_point(Vector2(center_x,rect.position.y),plot)
		var bottom := _map_point(Vector2(center_x,rect.end.y),plot)
		draw_line(top,bottom,Color("94b6b3"),3)
		var rung_count := maxi(2,int(rect.size.y/60.0))
		for rung in rung_count:
			var y := lerpf(top.y,bottom.y,float(rung+1)/float(rung_count+1))
			draw_line(Vector2(top.x-5,y),Vector2(top.x+5,y),Color("94b6b3"),2)
	_draw_top_edges(PackedVector2Array(CoreMovementLevel.BARREL_RAMP),plot,Color("c28e58"))
	for polygon in level.slopes:
		_draw_top_edges(polygon,plot,Color("c28e58"))
	_draw_horizontal(CoreMovementLevel.HANGING_BEAM.position.x,CoreMovementLevel.HANGING_BEAM.end.x,CoreMovementLevel.HANGING_BEAM.position.y,plot,Color("778d91"),3)

func _draw_horizontal(x0: float,x1: float,y: float,plot: Rect2,color: Color,width: float) -> void:
	var minimum := _world_x_bounds().x
	var maximum := _world_x_bounds().y
	x0 = maxf(x0,minimum)
	x1 = minf(x1,maximum)
	if x1 <= x0: return
	if not level.prologue_mode:
		var start := _map_point(Vector2(x0,y),plot)
		var finish := _map_point(Vector2(x1,y),plot)
		draw_line(start,finish,color,width)
		return
	var cursor := x0
	while cursor < x1:
		var section := _section_at(cursor)
		var section_end := minf(x1,minimum+(section+1)*CAMPAIGN_SECTION_WIDTH)
		if explored_sections.has(section):
			draw_line(_map_point(Vector2(cursor,y),plot),_map_point(Vector2(section_end,y),plot),color,width)
		cursor = section_end

func _draw_top_edges(points: PackedVector2Array,plot: Rect2,color: Color) -> void:
	if points.size()<2: return
	for index in range(points.size()-1):
		var first: Vector2 = points[index]
		var second: Vector2 = points[index+1]
		var bounds := _world_x_bounds()
		if maxf(first.x,second.x)<bounds.x or minf(first.x,second.x)>bounds.y: continue
		if not _is_revealed((first.x+second.x)*.5): continue
		draw_line(_map_point(first,plot),_map_point(second,plot),color,4)

func _draw_connections(plot: Rect2) -> void:
	if level.prologue_mode: return
	for door in level.transition_doors:
		if not is_instance_valid(door): continue
		var start := _map_point(door.position,plot)
		var destination := _map_point(door.destination_position,plot)
		draw_dashed_line(start,destination,Color("d0a465",.75),2,8)
		draw_circle(start,7,Color("e5c27d"))
		draw_circle(destination,5,Color("8eb4b1"))
		draw_string(ThemeDB.fallback_font,start+Vector2(9,-8),"E",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ffe4aa"))

func _draw_landmarks(plot: Rect2,font: Font) -> void:
	for landmark in level.map_landmarks():
		var point: Vector2 = landmark.position
		if not level.prologue_mode and not _is_revealed(point.x) and landmark.kind != "start": continue
		var screen := _map_point(point,plot)
		var color := Color("81c6a7") if landmark.kind == "start" else Color("d3b47c")
		if landmark.kind == "edge": color = Color("9c7570")
		draw_circle(screen,11,Color("101a20"))
		draw_circle(screen,8,color)
		var id_position := screen+Vector2(-10,5)
		if landmark.kind == "start": id_position = screen+Vector2(10,-14)
		draw_string(font,id_position,landmark.id,HORIZONTAL_ALIGNMENT_CENTER,24,10,Color("12191b"))
		if landmark.kind == "edge":
			draw_line(screen-Vector2(0,28),screen+Vector2(0,28),color,2)

func _draw_player_and_camera(plot: Rect2) -> void:
	if not player: return
	var player_position := level.to_local(player.global_position)
	if camera:
		var viewport_size := get_viewport_rect().size
		var zoom := maxf(.01,camera.zoom.x)
		var camera_center := level.to_local(camera.get_screen_center_position())
		var half_width := viewport_size.x/(2.0*zoom)
		var left := maxf(_world_x_bounds().x,camera_center.x-half_width)
		var right := minf(_world_x_bounds().y,camera_center.x+half_width)
		if right > left:
			var p0 := _map_point(Vector2(left,_world_y_bounds().x),plot)
			var p1 := _map_point(Vector2(right,_world_y_bounds().y),plot)
			draw_rect(Rect2(Vector2(p0.x,plot.position.y),Vector2(p1.x-p0.x,plot.size.y)),Color("81c6a7",.08),true)
			draw_line(Vector2(p0.x,plot.position.y),Vector2(p0.x,plot.end.y),Color("81c6a7",.7),1)
			draw_line(Vector2(p1.x,plot.position.y),Vector2(p1.x,plot.end.y),Color("81c6a7",.7),1)
	if not level.prologue_mode or _is_revealed(player_position.x):
		var marker := _map_point(player_position,plot)
		draw_circle(marker,13,Color("101a20"))
		draw_circle(marker,9,Color("e5e6d8"))
		draw_circle(marker,4,Color("7fd0a9"))

func _draw_legend(font: Font) -> void:
	var y := size.y-132
	if level.prologue_mode:
		draw_circle(Vector2(70,y-5),7,Color("7fd0a9"))
		draw_string(font,Vector2(86,y),"Игрок",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("d6ddd7"))
		draw_line(Vector2(205,y-5),Vector2(245,y-5),Color("81c6a7",.7),2)
		draw_string(font,Vector2(253,y),"Текущий обзор камеры",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("d6ddd7"))
		draw_line(Vector2(500,y-5),Vector2(540,y-5),Color("bdc4b4"),4)
		draw_string(font,Vector2(548,y),"Пройденный участок",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("d6ddd7"))
		draw_string(font,Vector2(930,y),"Участок раскрытия: %.0f игровых единиц" % CAMPAIGN_SECTION_WIDTH,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("9babb1"))
	else:
		var landmarks := level.map_landmarks()
		for index in landmarks.size():
			var column := index%3
			var row := floori(float(index)/3.0)
			var x := 66+column*480
			var row_y := y+row*23
			var landmark: Dictionary = landmarks[index]
			draw_string(font,Vector2(x,row_y),landmark.id,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("d3b47c"))
			draw_string(font,Vector2(x+40,row_y),landmark.label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("d6ddd7"))

func _world_x_bounds() -> Vector2:
	if level.prologue_mode: return Vector2(CoreMovementLevel.PROLOGUE_FLOOR.position.x,CoreMovementLevel.PROLOGUE_FLOOR.end.x)
	return Vector2(CoreMovementLevel.LEFT_BOUND,CoreMovementLevel.WIDTH)

func _world_y_bounds() -> Vector2:
	if level.prologue_mode: return Vector2(610,890)
	return Vector2(180,1120)

func _map_point(point: Vector2,plot: Rect2) -> Vector2:
	var x_bounds := _world_x_bounds()
	var y_bounds := _world_y_bounds()
	return Vector2(
		plot.position.x+clampf((point.x-x_bounds.x)/maxf(1,x_bounds.y-x_bounds.x),0,1)*plot.size.x,
		plot.position.y+clampf((point.y-y_bounds.x)/maxf(1,y_bounds.y-y_bounds.x),0,1)*plot.size.y
	)

func _section_at(world_x: float) -> int:
	return floori((world_x-_world_x_bounds().x)/CAMPAIGN_SECTION_WIDTH)

func _is_revealed(world_x: float) -> bool:
	return not level.prologue_mode or explored_sections.has(_section_at(world_x))
