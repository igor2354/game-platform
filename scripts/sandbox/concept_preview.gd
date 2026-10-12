extends Node2D
# Artist preview for the complete concept body and the PPSh interactions.
var figures: Array[ConceptBody] = []
var paused := false
var multiplier := 1.0
var direction := 1.0
var preview_state := "run"
var reload_demo := false
var fire_demo := false
var aim_demo := false
var clock_time := 0.0
var font: SystemFont

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("142029"))
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Arial", "Noto Sans"])
	for i in 3:
		var holder := Node2D.new()
		holder.position = [Vector2(300,690),Vector2(850,690),Vector2(1220,740)][i]
		holder.scale = Vector2.ONE*(1.8 if i < 2 else Soldier.BODY_SCALE)
		add_child(holder)
		var figure := ConceptBody.new()
		holder.add_child(figure)
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
		KEY_W: preview_state = "walk"
		KEY_B: preview_state = "run"
		KEY_Q: preview_state = "roll"
		KEY_L: preview_state = "climb"
		KEY_J: preview_state = "air"
		KEY_I: preview_state = "idle"
		KEY_R: reload_demo = not reload_demo
		KEY_T: fire_demo = not fire_demo
		KEY_A: aim_demo = not aim_demo
	clock_time = 0
	for f in figures: f.restart("idle" if f == figures[0] else preview_state)
	queue_redraw()

func _process(delta: float) -> void:
	if not paused: clock_time += delta*multiplier
	for i in figures.size():
		var f := figures[i]
		f.face(direction)
		var anim := "idle" if i == 0 else preview_state
		var velocity := Vector2.ZERO
		if anim in ["walk","run"]: velocity.x = direction*float(f.meta.animations[anim].speed)
		elif anim == "climb": velocity.y = -float(f.meta.animations.climb.speed)
		f.drive(anim,velocity)
		if not paused:
			f.advance(delta*multiplier)
			if anim == "roll" and f.time >= float(f.meta.animations.roll.duration): f.restart("roll")
		var p := fmod(clock_time,2.2)
		var reload_progress := p/Soldier.RELOAD_TIME if reload_demo and p < Soldier.RELOAD_TIME else -1.0
		var angle := .7*sin(clock_time*1.8) if aim_demo else 0.0
		var shot_phase := fmod(clock_time,60.0/900.0)
		var flash := .045-shot_phase if fire_demo and not reload_demo else 0.0
		var recoil := 4*(1-shot_phase/(60.0/900.0)) if fire_demo and not reload_demo else 0.0
		f.update_combat(Vector2(15,-140)-Vector2.from_angle(angle)*recoil,Vector2.from_angle(angle),reload_progress,flash)

func label(at: Vector2, value: String, size := 20, color := Color("dfdfcc")) -> void:
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw() -> void:
	label(Vector2(55,65),"КОНЦЕПТ → 3D → 2D / ППШ-41",32)
	label(Vector2(55,100),"Тело — кадры из 3D · руки — текстуры той же модели с IK · магазин и затвор отдельно",19,Color("91a5aa"))
	for x in [40,570,1100]: draw_rect(Rect2(x,150,500 if x < 1100 else 300,620),Color("1b2a33"))
	label(Vector2(70,195),"СТОЙКА / ОРУЖИЕ",22)
	label(Vector2(600,195),{"idle":"СТОЙКА","walk":"ХОДЬБА","run":"БЕГ","roll":"ПЕРЕКАТ","climb":"ЛЕСТНИЦА","air":"ПРЫЖОК"}[preview_state],22)
	label(Vector2(1130,195),"В ИГРЕ",22)
	label(Vector2(1130,230),"Рост около 130 px",16,Color("91a5aa"))
	for i in 3:
		var x: float = [40.0,570.0,1100.0][i]
		var y := 690.0 if i < 2 else 740.0
		draw_line(Vector2(x+15,y),Vector2(x+(485 if i < 2 else 285),y),Color("667b7c"),1)
	label(Vector2(55,810),"W — шаг · B — бег · Q — перекат · L — лестница · J — прыжок · I — стойка",19)
	label(Vector2(55,840),"R — перезарядка · T — стрельба · A — прицел · F — разворот · SPACE — пауза",19)
	label(Vector2(55,875),"1 / 2 / 3 — скорость 0,5× / 1× / 2×",18,Color("91a5aa"))
