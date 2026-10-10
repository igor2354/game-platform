extends Node2D
# Sandbox for the greybox rig: a floor, a low tunnel to roll under and a ladder
# to an upper landing. Open scenes/sandbox/rig_sandbox.tscn and press F6.
# A/D walk · Shift run · Space roll · W/S ladder · 1–5 one animation in place · 0 back

const FLOOR_Y := 800.0
const LANDING_Y := 480.0
const LADDER_X := 1560.0
const RUNG := 32.0
const TUNNEL := Rect2(760,560,260,110)
const LANDING := Rect2(1440,LANDING_Y,760,24)
const PREVIEWS := {KEY_1:"idle",KEY_2:"walk",KEY_3:"run",KEY_4:"roll",KEY_5:"climb"}

var player: GreyboxController
var camera: Camera2D
var hud: Label
var steps := 0

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.13,0.15,0.16))
	_solid(Rect2(-400,FLOOR_Y,3000,200),false)
	_solid(TUNNEL,false)
	_solid(LANDING,true)
	player = GreyboxController.new()
	player.position = Vector2(300,FLOOR_Y)
	player.ladders.append(Rect2(LADDER_X-24,LANDING_Y,48,FLOOR_Y-LANDING_Y))
	add_child(player)
	player.rig.anim_event.connect(_on_anim_event)
	camera = Camera2D.new()
	camera.position = Vector2(720,560)
	add_child(camera)
	camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24,20)
	hud.add_theme_font_size_override("font_size",18)
	layer.add_child(hud)

func _on_anim_event(event: String) -> void:
	if event == "footstep": steps += 1

func _solid(rect: Rect2, one_way: bool) -> void:
	var body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	collision.shape = box
	collision.position = rect.get_center()
	collision.one_way_collision = one_way
	body.add_child(collision)
	add_child(body)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo: return
	if event.physical_keycode in PREVIEWS:
		player.preview = PREVIEWS[event.physical_keycode]
	elif event.physical_keycode == KEY_0:
		player.preview = ""
		player.rolling = 0

func _process(_delta: float) -> void:
	camera.position.x = lerpf(camera.position.x,clampf(player.position.x,720,1500),0.12)
	var mode := "просмотр: "+player.preview if player.preview != "" else "управление"
	hud.text = "%s\nсостояние: %s   скорость анимации: ×%.2f\nнеуязвимость: %s   шагов: %d\n\nA/D шаг · Shift бег · Пробел перекат · W/S лестница\n1–5 анимация на месте · 0 управление" % [mode,player.rig.state,player.rig.tree.get("parameters/TimeScale/scale"),"да" if player.invulnerable() else "нет",steps]
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-400,FLOOR_Y,3000,200),Color(0.24,0.27,0.27))
	draw_rect(TUNNEL,Color(0.3,0.33,0.34))
	draw_rect(LANDING,Color(0.27,0.3,0.3))
	# Ladder: rails and rungs every 32 px, the spacing the climb cycle assumes.
	for x in [LADDER_X-22,LADDER_X+22]:
		draw_line(Vector2(x,LANDING_Y-40),Vector2(x,FLOOR_Y),Color(0.55,0.45,0.32),5)
	var y := FLOOR_Y-RUNG
	while y > LANDING_Y-40:
		draw_line(Vector2(LADDER_X-22,y),Vector2(LADDER_X+22,y),Color(0.55,0.45,0.32),4)
		y -= RUNG
	draw_string(ThemeDB.fallback_font,Vector2(TUNNEL.position.x+12,TUNNEL.end.y+28),"проход 130 — только перекатом",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(0.7,0.74,0.72))
