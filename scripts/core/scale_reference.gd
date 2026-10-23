class_name CoreScaleReference
extends Node2D
## Opt-in polygon fixture. Artwork scale follows the user's collage, not the capsule.
const FOREST = preload("res://resources/campaign/prologue_forest_4k.png")
const ORIGIN := Vector2(-5600,760)
const ROAD_PIXEL := Vector2(1800,1658)
const ART_SCALE := CoreWorldUnits.REFERENCE_HEIGHT/CoreWorldUnits.COLLAGE_HEIGHT
var player: CoreMovementPlayer
var fixtures: Array[StaticBody2D] = []
var raised := false
var original_z := 0
var reference_font: Font

func _ready() -> void:
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	process_mode = Node.PROCESS_MODE_ALWAYS
	reference_font = ThemeDB.fallback_font.duplicate()
	if reference_font is FontFile: reference_font.oversampling = 4.0
	_fixture(Rect2(ORIGIN+Vector2(135,-CoreWorldUnits.units(.6)),Vector2.ONE*CoreWorldUnits.units(.6)))
	var door := Rect2(ORIGIN+Vector2(180,-CoreWorldUnits.units(2.1)),Vector2(CoreWorldUnits.units(.9),CoreWorldUnits.units(2.1)))
	# Jambs are a facade behind the walk plane; only the lintel tests head clearance.
	_fixture(Rect2(door.position-Vector2(3,3),Vector2(door.size.x+6,3)))
	set_enabled(false)

func _fixture(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position
	body.collision_layer = 0
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.size*.5
	body.add_child(shape)
	add_child(body)
	fixtures.append(body)

func set_enabled(enabled: bool) -> void:
	visible = enabled
	for body in fixtures: body.collision_layer = 1 if enabled else 0
	_update_player_depth()

func _process(_delta: float) -> void: _update_player_depth()
func _update_player_depth() -> void:
	if not is_instance_valid(player): return
	var inside := visible and absf(player.global_position.x-ORIGIN.x) < 260 and absf(player.global_position.y-ORIGIN.y) < 300
	if inside and not raised:
		original_z = player.z_index
		player.z_index = maxi(original_z,2)
		raised = true
	elif not inside and raised:
		player.z_index = original_z
		raised = false
func _exit_tree() -> void:
	if raised and is_instance_valid(player): player.z_index = original_z

func _draw() -> void:
	var rect := Rect2(ORIGIN-ROAD_PIXEL*ART_SCALE,FOREST.get_size()*ART_SCALE)
	draw_texture_rect(FOREST,rect,false)
	draw_line(ORIGIN+Vector2(-230,0),ORIGIN+Vector2(230,0),Color("aad8cb"),.6)
	var font := reference_font
	for i in range(-6,7):
		var x := i*.5*CoreWorldUnits.UNITS_PER_METER
		draw_line(ORIGIN+Vector2(x,0),ORIGIN+Vector2(x,3),Color("aad8cb"),.4)
		if i % 2 == 0: draw_string(font,ORIGIN+Vector2(x-15,9),"%.1f м / %.0f ед." % [i*.5,x],HORIZONTAL_ALIGNMENT_CENTER,30,4,Color("ffffff"))
	var box := Rect2(ORIGIN+Vector2(135,-CoreWorldUnits.units(.6)),Vector2.ONE*CoreWorldUnits.units(.6))
	draw_rect(box,Color("333e49"))
	draw_rect(box,Color("f2d88d"),false,.6)
	draw_string(font,box.position+Vector2(-5,-4),"Образец 0,6 м",HORIZONTAL_ALIGNMENT_LEFT,-1,5,Color("fff3cd"))
	var door := Rect2(ORIGIN+Vector2(180,-CoreWorldUnits.units(2.1)),Vector2(CoreWorldUnits.units(.9),CoreWorldUnits.units(2.1)))
	draw_rect(door,Color("aad8cb"),false,1)
	draw_string(font,door.position+Vector2(-18,-5),"Проём 0,9 × 2,1 м",HORIZONTAL_ALIGNMENT_LEFT,-1,5,Color("ffffff"))
	draw_string(font,ORIGIN+Vector2(-180,-167),"СВЕРКА МАСШТАБА · рабочие образцы, не утверждённый стандарт",HORIZONTAL_ALIGNMENT_LEFT,-1,6,Color("c9dfe7"))
