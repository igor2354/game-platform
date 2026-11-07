extends Node2D
## Cosmetic child of a projectile. After impact it detaches for a stationary
## fade; it never moves a projectile, casts rays, applies damage or emits sound.
const SHEETS := {
	"stg44":{"texture":preload("res://resources/effects/assault_tracer.png"),"prefix":"assault_tracer",
		"regions":[[Rect2(190,215,136,19),Rect2(451,213,305,22),Rect2(1028,215,124,18)],[Rect2(188,617,138,21),Rect2(435,613,321,28),Rect2(1028,617,124,20)],[Rect2(174,1018,153,23),Rect2(421,1015,335,28),Rect2(1022,1018,130,22)]],
		"heads":[[Vector2(326,224),Vector2(756,223),Vector2(1152,224)],[Vector2(326,626),Vector2(756,626),Vector2(1152,627)],[Vector2(327,1029),Vector2(756,1029),Vector2(1152,1029)]]},
	"mp40":{"texture":preload("res://resources/effects/smg_tracer.png"),"prefix":"smg_tracer",
		"regions":[[Rect2(180,208,130,18),Rect2(493,207,248,20),Rect2(1040,208,100,17)],[Rect2(162,618,149,18),Rect2(471,615,271,25),Rect2(1036,618,105,18)],[Rect2(144,1026,167,22),Rect2(455,1022,288,30),Rect2(988,1027,153,20)]],
		"heads":[[Vector2(310,216),Vector2(741,216),Vector2(1140,216)],[Vector2(311,627),Vector2(742,627),Vector2(1141,627)],[Vector2(311,1036),Vector2(743,1036),Vector2(1141,1036)]]},
	"svt":{"texture":preload("res://resources/effects/rifle_tracer.png"),"prefix":"rifle_tracer",
		"regions":[[Rect2(216,239,111,17),Rect2(487,237,284,20),Rect2(1048,239,126,17)],[Rect2(206,615,122,18),Rect2(401,613,374,23),Rect2(1036,617,140,17)],[Rect2(195,996,133,22),Rect2(409,993,367,25),Rect2(1032,996,144,20)]],
		"heads":[[Vector2(327,247),Vector2(771,247),Vector2(1174,247)],[Vector2(328,624),Vector2(775,624),Vector2(1176,625)],[Vector2(328,1006),Vector2(776,1006),Vector2(1176,1006)]]},
	"m1911":{"texture":preload("res://resources/effects/pistol_tracer.png"),"prefix":"pistol_tracer",
		"regions":[[Rect2(225,223,98,16),Rect2(496,222,256,19),Rect2(1046,223,94,15)],[Rect2(207,618,117,18),Rect2(460,616,292,22),Rect2(1022,618,118,17)],[Rect2(204,1011,120,20),Rect2(477,1009,275,23),Rect2(1006,1010,133,21)]],
		"heads":[[Vector2(323,231),Vector2(752,231),Vector2(1140,230)],[Vector2(324,626),Vector2(752,626),Vector2(1140,626)],[Vector2(324,1021),Vector2(752,1021),Vector2(1139,1020)]]},
}

const MAX_RESIDUALS := 96
var weapon_id := ""
var settings: CoreShootingSettings
var rows := PackedInt32Array()
var flight_direction := Vector2.RIGHT
var flight_distance := 0.0
var age := 0.0
var ignition := .02
var decay := .04
var fade_age := 0.0
var fading := false

static func supports(id: String) -> bool: return SHEETS.has(id)
static func prefix(id: String) -> String: return str(SHEETS[id].prefix)
static func enabled(tuning: CoreShootingSettings,id: String) -> bool:
	return tuning != null and supports(id) and bool(tuning.get(prefix(id)+"_enabled"))

func configure(id: String,tuning: CoreShootingSettings,seed_value: int,direction: Vector2) -> void:
	weapon_id=id
	settings=tuning
	flight_direction=direction
	var random := RandomNumberGenerator.new()
	random.seed=seed_value
	for phase in 3: rows.append(random.randi_range(0,2))
	ignition=float(settings.get(prefix(id)+"_ignition"))
	decay=float(settings.get(prefix(id)+"_decay"))

func stage() -> int: return 2 if fading else 0 if age<ignition else 1
func frame() -> Vector2i: return Vector2i(rows[stage()],stage())

func finish(point: Vector2,distance: float,direction: Vector2) -> void:
	flight_distance=distance
	flight_direction=direction
	if not enabled(settings,weapon_id) or distance<=.001:
		queue_free()
		return
	reparent(get_parent().get_parent())
	global_position=point
	fading=true
	fade_age=0
	add_to_group("core_tracer_residuals")
	var previous := get_tree().get_nodes_in_group("core_tracer_residuals").filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())
	if previous.size()>MAX_RESIDUALS: previous[0].queue_free()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	if fading:
		fade_age+=delta
		if fade_age>=decay or not enabled(settings,weapon_id):
			queue_free()
			return
	else:
		age+=delta
	queue_redraw()

func geometry() -> Dictionary:
	if not enabled(settings,weapon_id) or flight_distance<=.001: return {}
	var key := prefix(weapon_id)
	var current := frame()
	var region: Rect2=SHEETS[weapon_id].regions[current.x][current.y]
	var head: Vector2=SHEETS[weapon_id].heads[current.x][current.y]
	var scale_x: float=CoreWorldUnits.units(float(settings.get(key+"_length")))/330.0
	var scale_y: float=CoreWorldUnits.units(float(settings.get(key+"_width")))/24.0
	var destination := Rect2((region.position-head)*Vector2(scale_x,scale_y),region.size*Vector2(scale_x,scale_y))
	# The head is at the actual projectile position. Crop the tail to the
	# travelled segment and source UVs together; do not squash a long trace.
	var left := maxf(destination.position.x,-flight_distance)
	var right := minf(destination.end.x,0.0)
	if right<=left: return {}
	region.position.x+=(left-destination.position.x)/scale_x
	region.size.x=(right-left)/scale_x
	destination.position.x=left
	destination.size.x=right-left
	var alpha: float=float(settings.get(key+"_opacity"))
	if fading: alpha*=clampf(1.0-fade_age/decay,0,1)
	else: alpha*=clampf(age/ignition,0,1)
	return {"texture":SHEETS[weapon_id].texture,"source":region,"destination":destination,"opacity":alpha}

func _draw() -> void:
	var data := geometry()
	if data.is_empty(): return
	draw_set_transform_matrix(Transform2D(flight_direction,Vector2(-flight_direction.y,flight_direction.x),Vector2.ZERO))
	draw_texture_rect_region(data.texture,data.destination,data.source,Color(1,1,1,data.opacity))
	draw_set_transform_matrix(Transform2D.IDENTITY)
