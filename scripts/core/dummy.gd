class_name CoreEnemyDummy
extends CharacterBody2D

@export var body_size := Vector2(32,64)
@export var identifier := "01"
const MAX_HEALTH := 100.0
const HIT_LAYER := 16
const PARTS := ["head","torso","left_arm","right_arm","left_leg","right_leg"]
const LIMBS := ["left_arm","right_arm","left_leg","right_leg"]
const PART_NAMES := {"head":"ГОЛОВА","torso":"КОРПУС","left_arm":"ЛЕВАЯ РУКА","right_arm":"ПРАВАЯ РУКА","left_leg":"ЛЕВАЯ НОГА","right_leg":"ПРАВАЯ НОГА"}
signal posture_changed

var damage_tuning: CoreShootingSettings = CoreShootingSettings.new()
var health := MAX_HEALTH
var hit_flash := 0.0
var received_hits := 0
var reaction_offset := Vector2.ZERO
var death_progress := 0.0
var hit_side := 1.0
var last_hit_part := ""
var last_hit_damage := 0.0
var last_hit_severed := false
var hit_notice_left := 0.0
var limb_damage: Dictionary = {}
var missing_parts: Array[String] = []
var hit_zones: Dictionary = {}
var detached_parts: Array[Dictionary] = []
var body_shape: CollisionShape2D
var debug_zones := false
var idle_clock := 0.0

func has_part(part: String) -> bool:
	return part in PARTS and part not in missing_parts

func is_prone() -> bool:
	return "left_leg" in missing_parts and "right_leg" in missing_parts

func limb_max_health(part: String) -> float:
	return damage_tuning.arm_durability if part.ends_with("arm") else damage_tuning.leg_durability

func limb_health(part: String) -> float:
	return 0.0 if not has_part(part) else maxf(0,limb_max_health(part)-float(limb_damage.get(part,0.0)))

func damage_multiplier(part: String) -> float:
	if part == "head": return damage_tuning.head_damage_multiplier
	if part.ends_with("arm"): return damage_tuning.arm_damage_multiplier
	if part.ends_with("leg"): return damage_tuning.leg_damage_multiplier
	return damage_tuning.torso_damage_multiplier

func part_rect(part: String) -> Rect2:
	var standing := {
		"head":Rect2(-7,-64,14,14),"torso":Rect2(-9,-50,18,26),
		"left_arm":Rect2(-16,-39,7,20),"right_arm":Rect2(9,-39,7,20),
		"left_leg":Rect2(-10,-24,8,24),"right_leg":Rect2(2,-24,8,24)}
	var prone := {
		"head":Rect2(5,-24,14,14),"torso":Rect2(-22,-20,26,15),
		"left_arm":Rect2(-3,-6,32,5),"right_arm":Rect2(-3,-14,34,6)}
	var rect: Rect2 = prone.get(part,Rect2()) if is_prone() else standing.get(part,Rect2())
	var proportions := body_size/Vector2(32,64)
	return Rect2(rect.position*proportions,rect.size*proportions)

func aim_point_for_part(part: String) -> Vector2:
	var rect := part_rect(part)
	var point := rect.get_center()
	# An upper-chest point is exposed above the arms from either side.
	if part == "torso" and not is_prone(): point.y = rect.position.y+rect.size.y*.23
	return to_global(point+reaction_offset)

func take_projectile_hit(amount: float,part: String,direction := Vector2.RIGHT) -> bool:
	if health <= 0 or not has_part(part) or not is_finite(amount) or amount <= 0: return false
	last_hit_part = part
	last_hit_damage = amount*damage_multiplier(part)
	last_hit_severed = false
	if part in LIMBS:
		limb_damage[part] = float(limb_damage.get(part,0.0))+amount
		if limb_health(part) <= 0:
			_sever_part(part,direction)
			last_hit_severed = true
	hit_notice_left = .85
	return take_damage(last_hit_damage,direction)

func take_damage(amount: float,direction := Vector2.RIGHT) -> bool:
	# Generic damage (explosions/test reset) bypasses the location multiplier.
	if health <= 0 or not is_finite(amount) or amount < 0: return false
	health = maxf(0,health-amount)
	received_hits += 1
	hit_flash = .12
	hit_side = 1 if direction.x >= 0 else -1
	reaction_offset = (reaction_offset+direction*3).limit_length(5)
	if health <= 0: collision_layer = 0
	_sync_zones()
	queue_redraw()
	return health <= 0

func _sever_part(part: String,direction: Vector2) -> void:
	var rect := part_rect(part)
	detached_parts.append({"part":part,"point":to_global(rect.get_center()+reaction_offset),"size":rect.size,"velocity":direction*100+Vector2(0,-95),"rotation":0.0,"spin":direction.x*5,"life":12.0,"settled":false})
	missing_parts.append(part)
	if part.ends_with("leg") and is_prone():
		_update_body_shape()
		posture_changed.emit()

func reset_target() -> void:
	health = MAX_HEALTH
	received_hits = 0
	hit_flash = 0
	reaction_offset = Vector2.ZERO
	death_progress = 0
	last_hit_part = ""
	last_hit_damage = 0
	last_hit_severed = false
	hit_notice_left = 0
	limb_damage.clear()
	missing_parts.clear()
	detached_parts.clear()
	collision_layer = 4
	_update_body_shape()
	_sync_zones()
	queue_redraw()

func _physics_process(delta: float) -> void:
	idle_clock += delta
	hit_flash = maxf(0,hit_flash-delta)
	hit_notice_left = maxf(0,hit_notice_left-delta)
	reaction_offset *= exp(-22*delta)
	if health <= 0: death_progress = minf(1,death_progress+delta/.20)
	for piece in detached_parts: _tick_detached_part(piece,delta)
	detached_parts = detached_parts.filter(func(piece: Dictionary) -> bool: return piece.life > 0)
	_sync_zones()
	queue_redraw()

func _tick_detached_part(piece: Dictionary,delta: float) -> void:
	piece.life -= delta
	if piece.settled: return
	piece.velocity += Vector2(0,950*delta)
	var next: Vector2 = piece.point+piece.velocity*delta
	var query := PhysicsRayQueryParameters2D.create(piece.point,next,1|8)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		piece.point = next
		piece.rotation += piece.spin*delta
	else:
		piece.velocity = (piece.velocity as Vector2).bounce(hit.normal)*.22
		piece.point = hit.position+hit.normal*minf(piece.size.x,piece.size.y)*.5
		piece.rotation = PI*.5 if piece.size.y > piece.size.x else 0.0
		if piece.velocity.length() < 55: piece.settled = true

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	body_shape = CollisionShape2D.new()
	body_shape.shape = RectangleShape2D.new()
	add_child(body_shape)
	_update_body_shape()
	for part in PARTS:
		var zone := Area2D.new()
		zone.name = part
		zone.set_meta("body_part",part)
		zone.collision_mask = 0
		zone.monitoring = false
		zone.monitorable = false
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		zone.add_child(shape)
		add_child(zone)
		hit_zones[part] = zone
	_sync_zones()

func _update_body_shape() -> void:
	if not body_shape: return
	var rect := Rect2(-28,-24,62,24) if is_prone() else Rect2(-16,-64,32,64)
	var proportions := body_size/Vector2(32,64)
	body_shape.position = rect.get_center()*proportions
	(body_shape.shape as RectangleShape2D).size = rect.size*proportions

func _sync_zones() -> void:
	for part in hit_zones:
		var zone: Area2D = hit_zones[part]
		var enabled := health > 0 and has_part(part)
		zone.collision_layer = HIT_LAYER if enabled else 0
		if not enabled: continue
		var rect := part_rect(part)
		var shape := zone.get_child(0) as CollisionShape2D
		shape.position = rect.get_center()+reaction_offset
		(shape.shape as RectangleShape2D).size = rect.size

func _part_color(part: String) -> Color:
	if part == "head": return Color("aeb7a0")
	if part.ends_with("leg"): return Color("515e58")
	return Color("857e58") if identifier == "02" else Color("6e8270")

func _draw_part(part: String,rect: Rect2,color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.darkened(.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	draw_style_box(style,rect)
	if part == "head":
		draw_rect(Rect2(rect.position,Vector2(rect.size.x,rect.size.y*.33)),Color("3c5049"))
		draw_line(rect.position+rect.size*Vector2(.22,.48),rect.position+rect.size*Vector2(.8,.48),Color("252e2d"),2)
	elif part == "torso":
		draw_line(Vector2(rect.get_center().x,rect.position.y+3),Vector2(rect.get_center().x,rect.end.y-3),color.lightened(.18),1)
		draw_line(Vector2(rect.position.x,rect.end.y-5),Vector2(rect.end.x,rect.end.y-5),Color("4e4840"),3)
		var chest := rect.position+rect.size*Vector2(.27,.33)+Vector2(0,sin(idle_clock*2.5)*.4)
		draw_rect(Rect2(chest,rect.size*Vector2(.22,.22)),Color("92876b"))
	else:
		var end_rect := Rect2(rect.position+Vector2(0,rect.size.y*.76),Vector2(rect.size.x,rect.size.y*.24))
		if rect.size.x > rect.size.y: end_rect = Rect2(rect.position+Vector2(rect.size.x*.84,0),Vector2(rect.size.x*.16,rect.size.y))
		draw_rect(end_rect,Color("333e3a"))
		if part.ends_with("arm"):
			draw_line(rect.position+rect.size*Vector2(0,.5),rect.position+rect.size*Vector2(1,.5),color.lightened(.22),1)

func _draw() -> void:
	var fall_rotation := hit_side*PI*.5*death_progress if not is_prone() else 0.0
	var fall_offset := Vector2(0,body_size.x*.5*death_progress) if not is_prone() else Vector2.ZERO
	draw_set_transform(reaction_offset-fall_offset,fall_rotation)
	for part in ["left_leg","right_leg","torso","left_arm","right_arm","head"]:
		if not has_part(part): continue
		var color := _part_color(part)
		if health <= 0: color = Color("52606b")
		elif hit_flash > 0 and last_hit_part == part: color = Color("ffcfb6")
		_draw_part(part,part_rect(part),color)
	draw_set_transform(Vector2.ZERO)
	for piece in detached_parts:
		draw_set_transform(to_local(piece.point),piece.rotation)
		_draw_part(piece.part,Rect2(-piece.size*.5,piece.size),_part_color(piece.part))
	draw_set_transform(Vector2.ZERO)
	if debug_zones and health > 0:
		for part in PARTS:
			if has_part(part): draw_rect(Rect2(part_rect(part).position+reaction_offset,part_rect(part).size),Color("f0c96a"),false,1)
	var top := -body_size.y if not is_prone() else -34*body_size.y/64
	if health > 0:
		draw_rect(Rect2(-20,top-7,40,4),Color("273742"))
		draw_rect(Rect2(-20,top-7,40*health/MAX_HEALTH,4),Color("81c6a7"))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(-32,top-14),"%s · %.0f HP" % [identifier,health],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("d0c8b7"))
	if hit_notice_left > 0 and last_hit_part != "":
		var text: String = PART_NAMES[last_hit_part]+(" · ОТРЫВ" if last_hit_severed else " −%.1f" % last_hit_damage)
		draw_string(font,Vector2(-45,top-30),text,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("ffa88b"))
