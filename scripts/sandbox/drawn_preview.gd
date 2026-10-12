extends Node2D
var figures: Array[DrawnBody] = []
var paused := false
var multiplier := 1.0
var direction := 1.0
var clock_time := 0.0
var reload_demo := false
var aim_demo := false
var font: SystemFont
const STATES := ["walk","dash","climb"]

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("142029"))
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Arial","Noto Sans"])
	for i in 3:
		var holder := Node2D.new()
		holder.position = Vector2(260+i*470,670)
		holder.scale = Vector2.ONE*1.65
		add_child(holder)
		var figure := DrawnBody.new()
		holder.add_child(figure)
		figure.restart(STATES[i])
		figures.append(figure)
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_SPACE: paused = not paused
		KEY_F: direction *= -1
		KEY_1: multiplier = .5
		KEY_2: multiplier = 1
		KEY_3: multiplier = 2
		KEY_R: reload_demo = not reload_demo
		KEY_A: aim_demo = not aim_demo
	queue_redraw()

func _process(delta: float) -> void:
	if paused: return
	clock_time += delta*multiplier
	for i in figures.size():
		var f := figures[i]
		f.face(direction)
		var anim: String = STATES[i]
		if anim == "dash" and f.time > Soldier.DASH_TIME+.55: f.restart("dash")
		var velocity := Vector2.ZERO
		if anim == "walk": velocity.x = direction*float(f.meta.animations.walk.speed)
		elif anim == "climb": velocity.y = -float(f.meta.animations.climb.speed)
		f.drive(anim,velocity)
		f.advance(delta*multiplier)
		var p := fmod(clock_time,2.2)
		var progress := p/Soldier.RELOAD_TIME if reload_demo and p < Soldier.RELOAD_TIME else -1.0
		var angle := .5*sin(clock_time*1.8) if aim_demo else 0.0
		f.update_combat(Vector2(15,-140),Vector2.from_angle(angle),progress,0)

func label(at: Vector2,value: String,size := 20,color := Color("dfdfcc")) -> void:
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw() -> void:
	label(Vector2(40,62),"РИСОВАННЫЙ СОЛДАТ / ГИБРИД",32)
	label(Vector2(40,100),"Шаг и ткань — рисунки · руки следуют оружию · снаряжение двигается с запаздыванием",19,Color("91a5aa"))
	for i in 3:
		var x := 25+i*470
		draw_rect(Rect2(x,145,450,590),Color("1b2a33"))
		label(Vector2(x+24,191),["ХОДЬБА / ППШ","РЫВОК","ЛЕСТНИЦА"][i],23)
		draw_line(Vector2(x+15,670),Vector2(x+435,670),Color("627b7b"))
	label(Vector2(40,790),"SPACE — пауза · F — разворот · 1 / 2 / 3 — скорость 0,5× / 1× / 2×",20)
	label(Vector2(40,828),"A — движение прицела · R — перезарядка ППШ",20)
	label(Vector2(40,870),"В игре новый вариант выбран сразу · F4 — сравнение с предыдущими персонажами",18,Color("91a5aa"))
