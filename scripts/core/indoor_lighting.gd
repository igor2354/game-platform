class_name CoreIndoorLighting
extends Node2D
## A reusable local lighting zone. No global CanvasModulate or outdoor darkening.
const BOUNDS := Rect2(6020,528,920,232)
const TEST_SPAWN := Vector2(6120,760)
const ENEMY_HOME := Vector2(6660,760)
const SOLIDS: Array[Rect2] = [Rect2(6000,508,960,20),Rect2(6000,528,20,128),Rect2(6940,528,20,232)]
const DARKNESS = preload("res://shaders/core_indoor_darkness.gdshader")
var tuning: CoreZombieSettings
var lamp: CoreBreakableLamp
var shade: ColorRect
var observers: Array[Node2D] = []

func _ready() -> void:
	add_to_group("indoor_lighting")
	z_index = 0
	if not tuning: tuning = CoreZombieSettings.new()
	lamp = CoreBreakableLamp.new()
	lamp.name = "BreakableWallLamp"
	lamp.tuning = tuning
	lamp.position = Vector2(6460,566)
	lamp.z_index = 22
	lamp.light_changed.connect(refresh)
	add_child(lamp)
	shade = ColorRect.new()
	shade.name = "LocalDarkness"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.position = BOUNDS.position
	shade.size = BOUNDS.size
	shade.z_index = 20
	var material := ShaderMaterial.new()
	material.shader = DARKNESS
	shade.material = material
	add_child(shade)
	refresh()

func contains_point(point: Vector2) -> bool:
	return BOUNDS.has_point(to_local(point))

func light_level(point: Vector2) -> float:
	if not tuning.lighting_enabled: return 1.0
	var energy := 0.0
	if is_instance_valid(lamp) and not lamp.broken:
		var distance := to_local(point).distance_to(lamp.position)
		energy = tuning.lamp_intensity*(1.0-smoothstep(tuning.lamp_radius*.65,tuning.lamp_radius,distance))
	return clampf(tuning.indoor_ambient+energy,0,1)

static func vision_factors(actor: Node2D) -> Vector2:
	# Per observer: all existing detection/retention calls and the F1 cone share
	# the same light sample. Hearing, physical contact and damage memory are independent.
	var point := actor.global_position-Vector2(0,32)
	for zone in actor.get_tree().get_nodes_in_group("indoor_lighting"):
		if not zone.tuning.lighting_enabled or not zone.contains_point(point): continue
		var light: float = zone.light_level(point)
		return Vector2(lerpf(zone.tuning.dark_vision_range,1,light),lerpf(zone.tuning.dark_vision_angle,1,light))
	return Vector2.ONE

func apply_tuning(value: CoreZombieSettings) -> void:
	tuning = value
	lamp.tuning = value
	lamp.apply_tuning()

func refresh() -> void:
	if is_instance_valid(shade):
		shade.visible = tuning.lighting_enabled
		var material: ShaderMaterial = shade.material
		material.set_shader_parameter("room_size",BOUNDS.size)
		material.set_shader_parameter("lamp_position",lamp.position-BOUNDS.position)
		material.set_shader_parameter("radius",tuning.lamp_radius)
		material.set_shader_parameter("energy",0.0 if lamp.broken else tuning.lamp_intensity)
		material.set_shader_parameter("ambient",tuning.indoor_ambient)
	# Frozen test enemies do not repaint every tick; their F1 sector still
	# needs to respond immediately when a lamp is shot or repaired.
	for observer in observers:
		if is_instance_valid(observer): observer.queue_redraw()
	queue_redraw()

func _draw() -> void:
	draw_rect(BOUNDS,Color("414c50"))
	for y in range(548,760,38):
		draw_line(Vector2(6020,y),Vector2(6940,y),Color("364044"),2)
	for x in range(6050,6940,76):
		draw_line(Vector2(x,528),Vector2(x,760),Color("394449"),1)
	draw_rect(Rect2(6800,553,94,50),Color("29363d"))
	for y in range(561,600,8): draw_line(Vector2(6810,y),Vector2(6884,y),Color("67777b"),3)
	draw_line(Vector2(6460,528),Vector2(6460,548),Color("19272d"),4)
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(6030,465),"12 · ОСВЕЩЕНИЕ · КОМНАТА С ПАТРУЛЁМ",HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("d7be83"))
	draw_string(font,Vector2(6030,495),"Разбейте лампу · F1 — конус зрения · F6 → Освещение",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("a4b4ba"))
	if is_instance_valid(lamp):
		var text := "ЛАМПА РАЗБИТА · СЛУХ СОХРАНЁН" if lamp.broken else "ЛАМПА · %.0f HP" % lamp.health
		if not tuning.lighting_enabled: text += " · ВЛИЯНИЕ СВЕТА ВЫКЛ."
		draw_string(font,Vector2(6030,435),text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("c1cbd0"))
