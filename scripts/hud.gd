class_name StationHUD
extends Control
const PAPER := Color("e3dfcc")
const MUTED := Color("91a2a5")
const GOLD := Color("cbb27c")
var game: Node2D
var font: SystemFont
var mono: SystemFont
var buttons: Array[Dictionary] = []
var hover := Vector2.ZERO

func _ready() -> void:
	size = Vector2(1440,900)
	mouse_filter = Control.MOUSE_FILTER_PASS
	font = SystemFont.new()
	font.font_names = PackedStringArray(["DIN Condensed","Arial Narrow","Noto Sans"])
	font.font_weight = 600
	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo","Consolas","monospace"])

func _process(_delta: float) -> void:
	hover = get_local_mouse_position()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for button in buttons:
			if button.rect.has_point(event.position):
				button.callback.call()
				accept_event()
				return

func text(at: Vector2, content: String, height := 20, color := PAPER, use_mono := false) -> void:
	draw_string(mono if use_mono else font,at,content,HORIZONTAL_ALIGNMENT_LEFT,-1,height,color)

func line(a: Vector2, b: Vector2, alpha := 0.3) -> void:
	draw_line(a,b,Color(0.74,0.77,0.7,alpha),1,true)

func panel(rect: Rect2, alpha := 0.8) -> void:
	draw_rect(rect,Color(0.025,0.046,0.058,alpha))
	draw_rect(rect,Color(0.61,0.63,0.56,0.25),false,1)

func button(rect: Rect2, label: String, callback: Callable, primary := false) -> void:
	var inside := rect.has_point(hover)
	var color := Color("cbb27c") if primary else Color("25373c")
	if inside: color = color.lightened(0.16)
	draw_rect(rect,color)
	draw_rect(rect,Color("d3c69e") if primary else Color("798782"),false,1)
	text(rect.position+Vector2(22,rect.size.y*0.5+8),label,25,Color("18252a") if primary else PAPER)
	text(rect.position+Vector2(rect.size.x-45,rect.size.y*0.5+6),"→",24,Color("18252a") if primary else GOLD)
	buttons.append({"rect":rect,"callback":callback})

func _draw() -> void:
	buttons.clear()
	if game.state == "title":
		_draw_title()
		return
	_draw_game_hud()
	if game.state == "playing":
		_draw_crosshair()
		_draw_interaction()
	else:
		_draw_modal()

func _draw_title() -> void:
	# Restrained editorial typography over the live station, not a separate mockup.
	for i in 45:
		draw_rect(Rect2(i*20,0,20,900),Color(0.02,0.035,0.043,maxf(0,0.88-i*0.019)))
	text(Vector2(88,91),"ВОСТОЧНЫЙ ФРОНТ  /  1945",18,GOLD,true)
	line(Vector2(88,112),Vector2(460,112),0.4)
	text(Vector2(88,251),"НОЧНАЯ СМЕНА",19,MUTED,true)
	text(Vector2(82,342),"МЁРТВЫЙ",96)
	text(Vector2(82,440),"ПЕРРОН",96)
	text(Vector2(88,490),"Последний поезд ушёл. Мёртвые остались.",25,Color("bec7bf"))
	text(Vector2(88,526),"Доберитесь до радиорубки и вызовите эвакуацию.",20,MUTED)
	button(Rect2(88,574,367,64),"НАЧАТЬ ОПЕРАЦИЮ",game.start_game,true)
	text(Vector2(88,665),"ENTER — начать",14,MUTED,true)
	line(Vector2(88,712),Vector2(455,712),0.3)
	text(Vector2(88,753),"A / D",17,GOLD,true)
	text(Vector2(200,753),"Движение",20)
	text(Vector2(88,787),"W / S",17,GOLD,true)
	text(Vector2(200,787),"Лестницы",20)
	text(Vector2(88,821),"ПРОБЕЛ",17,GOLD,true)
	text(Vector2(200,821),"Прыжок · Shift — перекат",20)
	text(Vector2(485,753),"ЛКМ",17,GOLD,true)
	text(Vector2(575,753),"Стрельба",20)
	text(Vector2(485,787),"ПКМ",17,GOLD,true)
	text(Vector2(575,787),"Лазер · точность · медленный шаг",20)
	text(Vector2(485,821),"R / E",17,GOLD,true)
	text(Vector2(575,821),"Перезарядка / взаимодействие",20)
	text(Vector2(1120,58),"01 / ВОКЗАЛ",19,GOLD,true)
	text(Vector2(1090,85),"02:41  •  НОЧЬ  •  ДОЖДЬ",18,MUTED)
	text(Vector2(1122,854),"GODOT 4  /  GDSCRIPT",13,MUTED,true)

func _draw_game_hud() -> void:
	# Health upper left, mission upper right, weapon lower right.
	panel(Rect2(36,32,295,98),0.64)
	text(Vector2(56,60),"РЯДОВОЙ / 07",16,MUTED,true)
	text(Vector2(56,94),"ЗДОРОВЬЕ",22)
	text(Vector2(261,94),str(game.player.health),24,GOLD)
	draw_rect(Rect2(56,108,253,5),Color("263a40"))
	draw_rect(Rect2(56,108,253*game.player.health/100.0,5),Color("b58a70"))
	for x in range(1,10): draw_line(Vector2(56+x*25.3,108),Vector2(56+x*25.3,113),Color("15272e"),2)
	text(Vector2(599,56),"МЁРТВЫЙ ПЕРРОН",25)
	text(Vector2(638,82),"1945 / 02:41",14,MUTED,true)
	line(Vector2(374,106),Vector2(1066,106),0.2)
	text(Vector2(1100,54),"02 / ЭВАКУАЦИЯ" if game.radio_active else "01 / УСТАНОВИТЬ СВЯЗЬ",17,GOLD,true)
	text(Vector2(1100,85),"ВОСТОЧНЫЙ ВЫХОД →" if game.radio_active else "РАДИОРУБКА ↑",25)
	_draw_map()
	text(Vector2(44,782),"ВОСТОЧНЫЙ ВОКЗАЛ",21)
	var tier_name: String = ["НИЖНИЙ ПЕРРОН","СЛУЖЕБНЫЕ МОСТКИ","ВЕРХНЯЯ ГАЛЕРЕЯ"][game.level.tier(game.player.position.y)]
	text(Vector2(44,806),tier_name,13,MUTED,true)
	line(Vector2(44,830),Vector2(677,830),0.24)
	text(Vector2(44,860),"A D  шаг   W S  лестница   SPACE  прыжок   SHIFT  перекат   R  магазин   E  связь",14,Color("b6c2bd"))
	text(Vector2(44,881),"S + SPACE  спуститься   ESC  пауза   F2  эффекты   M  звук",12,MUTED)
	panel(Rect2(1146,730,252,132),0.75)
	text(Vector2(1168,757),"ППШ–41",22)
	text(Vector2(1168,807),"%02d" % game.player.ammo,48)
	text(Vector2(1235,804),"/ %03d" % game.player.reserve,25,MUTED,true)
	var status := "ЛАЗЕР / ТОЧНЫЙ ОГОНЬ" if game.player.aiming else "СТРЕЛЬБА С РАЗБРОСОМ"
	if game.player.climbing: status = "ЛЕСТНИЦА / ОРУЖИЕ УБРАНО"
	if game.player.reload_left > 0:
		status = "ПЕРЕЗАРЯДКА"
		draw_rect(Rect2(1168,823,208*(1-game.player.reload_left/Soldier.RELOAD_TIME),2),GOLD)
	text(Vector2(1168,845),status,12,GOLD,true)
	if game.toast_left > 0:
		var width := font.get_string_size(game.toast,HORIZONTAL_ALIGNMENT_LEFT,-1,21).x+52
		panel(Rect2((1440-width)/2,139,width,49),0.86)
		text(Vector2((1440-width)/2+26,171),game.toast,21,GOLD)
	text(Vector2(1134,888),"%02d:%02d  /  %02d УСТРАНЕНО" % [int(game.mission_time)/60,int(game.mission_time)%60,game.kills],12,MUTED,true)

func _draw_map() -> void:
	var origin := Vector2(1106,132)
	var scale_x := 0.064
	for span in game.level.spans:
		var y: float = (span.position.y-520)*0.105
		draw_line(origin+Vector2(span.position.x*scale_x,y),origin+Vector2(span.end.x*scale_x,y),Color("647d83"),2)
	for ladder in game.level.ladders:
		draw_line(origin+Vector2(ladder.get_center().x*scale_x,(ladder.position.y+20-520)*0.105),origin+Vector2(ladder.get_center().x*scale_x,(ladder.end.y-520)*0.105),Color("657363"),1)
	var pos: Vector2 = game.player.position
	draw_circle(origin+Vector2(pos.x*scale_x,(pos.y-520)*0.105-3),3,PAPER)
	var target: Vector2 = game.level.exit_point if game.radio_active else game.level.radio
	var p := origin+Vector2(target.x*scale_x,(target.y-520)*0.105-5)
	draw_colored_polygon(PackedVector2Array([p+Vector2(0,-4),p+Vector2(4,0),p+Vector2(0,4),p+Vector2(-4,0)]),GOLD)

func _draw_crosshair() -> void:
	# The crosshair sits where the barrel points at mouse distance, so it rides
	# the muzzle rise and settles back; the gap shows the real spread cone.
	var player: Soldier = game.player
	var dist := (player.get_global_mouse_position()-player.gun_origin()).length()
	var at := get_viewport().get_canvas_transform()*(player.gun_origin()+player.barrel_direction()*dist)
	var gap := 5.0 if player.aiming else clampf(dist*tan(player.current_spread()),4,70)+3
	var col := Color("dce5d8") if not player.aiming else Color("efb58e")
	if player.reload_left > 0: col = MUTED
	for dir in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		draw_line(at+dir*gap,at+dir*(gap+7),Color(0.02,0.03,0.04,0.8),3,true)
		draw_line(at+dir*gap,at+dir*(gap+7),col,1,true)
	draw_circle(at,1.3,col)
	if game.hit_marker > 0:
		var marker_col := GOLD
		var inner := 5.0
		var outer := 10.0
		var width := 2.0
		if game.hit_kind == "head":
			marker_col = Color("ff8a4c")
			inner = 6.0
			outer = 13.0
			width = 2.5
		elif game.hit_kind == "kill":
			# Kill marker blooms outward as it fades.
			var grow: float = (1-game.hit_marker/0.26)*6
			marker_col = Color("e8432a")
			inner = 7.0+grow
			outer = 16.0+grow
			width = 3.0
		for dir in [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
			var d: Vector2 = dir.normalized()
			draw_line(at+d*inner,at+d*outer,Color(0.02,0.03,0.04,0.7),width+2,true)
			draw_line(at+d*inner,at+d*outer,marker_col,width,true)

func _draw_interaction() -> void:
	if not game.radio_active and game.player.position.distance_to(game.level.radio) < 95:
		panel(Rect2(535,651,370,54),0.9)
		text(Vector2(558,686),"[ E ]  ВЫЗВАТЬ ЭВАКУАЦИЮ",24,GOLD)

func _draw_modal() -> void:
	draw_rect(Rect2(0,0,1440,900),Color(0.015,0.025,0.033,0.65))
	panel(Rect2(455,220,530,470),0.95)
	line(Vector2(491,249),Vector2(949,249),0.4)
	if game.state == "paused":
		text(Vector2(491,294),"ОПЕРАЦИЯ ПРИОСТАНОВЛЕНА",18,GOLD,true)
		text(Vector2(488,360),"ПАУЗА",60)
		text(Vector2(491,402),"Лазер: точный огонь ценой скорости.",23,MUTED)
		text(Vector2(491,434),"S + ПРОБЕЛ: спрыгнуть на нижний ярус.",20,MUTED)
		button(Rect2(491,481,458,59),"ПРОДОЛЖИТЬ",game.resume,true)
		button(Rect2(491,553,458,55),"НАЧАТЬ ЗАНОВО",game.restart)
		text(Vector2(491,650),"ESC / ENTER — продолжить",15,MUTED,true)
	elif game.state == "dead":
		text(Vector2(491,294),"СВЯЗЬ ПРЕРВАНА",18,GOLD,true)
		text(Vector2(488,360),"ВЫ ПОГИБЛИ",56)
		text(Vector2(491,408),"Вокзал всё ещё ждёт своего последнего бойца.",22,MUTED)
		button(Rect2(491,469,458,59),"ВЕРНУТЬСЯ К УКРЫТИЮ",game.continue_checkpoint,true)
		button(Rect2(491,541,458,55),"НОВАЯ ОПЕРАЦИЯ",game.restart)
		text(Vector2(491,650),"ENTER — новая операция",15,MUTED,true)
	else:
		text(Vector2(491,294),"РАДИОГРАММА ПРИНЯТА",18,GOLD,true)
		text(Vector2(488,360),"ВЫ ПРОРВАЛИСЬ",53)
		text(Vector2(491,408),"Эвакуация прибыла. Перрон остался позади.",22,MUTED)
		text(Vector2(491,451),"ВРЕМЯ  %02d:%02d    УСТРАНЕНО  %d" % [int(game.mission_time)/60,int(game.mission_time)%60,game.kills],17,GOLD,true)
		button(Rect2(491,502,458,59),"ПОВТОРИТЬ ОПЕРАЦИЮ",game.restart,true)
		text(Vector2(491,650),"ENTER — сыграть снова",15,MUTED,true)
