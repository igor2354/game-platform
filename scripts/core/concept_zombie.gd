class_name CoreConceptZombie
extends CoreZombie
## Separate illustrated actor; all combat and perception remain CoreZombie's.
const ART = preload("res://scripts/core/concept_zombie_art.gd")
var animation_name := "idle"
var animation_frame := 0
var animation_elapsed := 0.0
var visual_hit_left := 0.0
var visual_fall_left := 0.0
var visual_getup_left := 0.0
var visual_land_left := 0.0
var death_elapsed := 0.0
var death_was_prone := false
var was_grounded := false
# Capture/test tools may inspect the actual sixteen poses without changing AI.
var preview_clip := ""
var preview_frame := 0

func _ready() -> void:
	ART.prepare_regions()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	super._ready()

func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	var physical_before := blast_ragdoll != null and blast_ragdoll.active
	super._physics_process(delta)
	if test_frozen: return
	if physical_before and not blast_ragdoll.active:
		# The physical proxy already completed its sixteen-step rise. The
		# ordinary knockdown callback must not play a second rise from the floor.
		visual_getup_left = 0
		visual_fall_left = 0
	if blast_ragdoll.active:
		visual_fall_left = 0
		return
	visual_hit_left = maxf(0,visual_hit_left-delta)
	visual_fall_left = maxf(0,visual_fall_left-delta)
	visual_getup_left = maxf(0,visual_getup_left-delta)
	visual_land_left = maxf(0,visual_land_left-delta)
	if not grounded and is_on_floor() and was_grounded and not is_prone(): visual_land_left = .24
	was_grounded = was_grounded or is_on_floor()
	if health <= 0: death_elapsed += delta
	var next := _select_animation()
	if next != animation_name:
		animation_name = next
		animation_elapsed = 0
	animation_elapsed += delta
	var phase := animation_elapsed/float(ART.CLIPS[animation_name][0])
	var prone_prefix := "crawl_" if is_prone() else ""
	if animation_name == prone_prefix+"windup": phase = 1-state_left/maxf(.001,windup_duration)
	elif animation_name in [prone_prefix+"strike",prone_prefix+"recover"]:
		var strike_time := minf(.16,recovery_duration*.35)
		var elapsed := maxf(0,recovery_duration-state_left)
		phase = elapsed/strike_time if animation_name.ends_with("strike") else (elapsed-strike_time)/maxf(.001,recovery_duration-strike_time)
	elif animation_name == "shove": phase = 1-shove_left/maxf(.001,shove_duration)
	elif animation_name in ["patrol","chase","crawl"]: phase = walk_phase/TAU*(2.0 if animation_name == "patrol" else 1.2 if animation_name == "chase" else .9)
	elif animation_name in ["death","prone_death"]: phase = death_elapsed/float(ART.CLIPS[animation_name][0])
	elif animation_name == "fall": phase = 1-visual_fall_left/.42
	elif animation_name == "get_up": phase = 1-visual_getup_left/.65
	elif animation_name == "land": phase = 1-visual_land_left/.24
	elif animation_name in ["hurt","crawl_hurt"]: phase = 1-visual_hit_left/.28
	animation_frame = posmod(floori(phase*16),16) if ART.CLIPS[animation_name][1] else clampi(floori(phase*16),0,15)
	_sync_zones()
	queue_redraw()

func _select_animation() -> String:
	if health <= 0: return "prone_death" if death_was_prone else "death"
	if visual_fall_left > 0: return "fall"
	if visual_getup_left > 0: return "get_up"
	if shove_left > 0: return "shove"
	if visual_hit_left > 0: return "crawl_hurt" if is_prone() else "hurt"
	if is_stunned(): return "prone_stunned" if is_prone() else "stunned"
	var prefix := "crawl_" if is_prone() else ""
	if state == State.WINDUP: return prefix+"windup"
	if state == State.RECOVERY: return prefix+("strike" if recovery_duration-state_left < minf(.16,recovery_duration*.35) else "recover")
	if is_prone(): return "crawl" if absf(velocity.x) > 1 else "prone_idle"
	if not is_on_floor(): return "airborne"
	if visual_land_left > 0: return "land"
	if absf(velocity.x) > 1: return "chase" if state == State.CHASE else "patrol"
	return "idle"

func current_pose() -> Dictionary:
	return ART.pose(preview_clip if not preview_clip.is_empty() else animation_name,preview_frame if not preview_clip.is_empty() else animation_frame)

func animated_part_rect(part: String,prone_pose: bool,motion := true) -> Rect2:
	var values := current_pose() if motion and prone_pose == is_prone() else ART.pose("prone_idle" if prone_pose else "idle",0)
	return ART.rect_for(values,part,facing,body_size/Vector2(32,64))

func _draw_actor_body() -> void:
	var clip := preview_clip if not preview_clip.is_empty() else animation_name
	var frame := preview_frame if not preview_clip.is_empty() else animation_frame
	var proportions := body_size/Vector2(32,64)
	var base := Transform2D(Vector2(facing*proportions.x,0),Vector2(0,proportions.y),reaction_offset)
	var baked := ART.texture(clip)
	if missing_parts.is_empty() and hit_flash <= 0 and baked:
		draw_set_transform_matrix(base)
		var source := Rect2(Vector2(frame%4,frame/4)*ART.CELL,Vector2.ONE*ART.CELL)
		draw_texture_rect_region(baked,Rect2(-ART.ANCHOR/ART.BAKE_SCALE,Vector2.ONE*ART.CELL/ART.BAKE_SCALE),source,Color(.75,.77,.79) if health <= 0 else Color.WHITE)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		var visible := PARTS.filter(func(part): return has_part(part))
		ART.draw_pose(self,current_pose(),base,visible,last_hit_part if hit_flash > 0 else "",health <= 0)

func take_damage(amount: float,direction := Vector2.RIGHT) -> bool:
	var alive := health > 0
	var prone := is_prone()
	var hits := received_hits
	var killed := super.take_damage(amount,direction)
	if received_hits > hits and not test_frozen: visual_hit_left = .28
	if alive and health <= 0:
		death_elapsed = 0
		death_was_prone = prone
		animation_name = "prone_death" if prone else "death"
		animation_frame = 0
	return killed

func _on_health_changed(was_alive: bool) -> void:
	if was_alive and health <= 0:
		death_was_prone = is_prone()
		death_elapsed = 0
	if not was_alive and health > 0:
		visual_fall_left = 0
		visual_getup_left = 0
		visual_hit_left = 0
		animation_name = "prone_idle" if is_prone() else "idle"
		animation_frame = 0
	super._on_health_changed(was_alive)

func _on_knockdown_started() -> void:
	if not is_prone() or animation_name not in ["crawl","prone_idle","shove"]: visual_fall_left = .42
	super._on_knockdown_started()

func _on_knockdown_ended() -> void:
	super._on_knockdown_ended()
	visual_fall_left = 0
	if has_part("left_leg") and has_part("right_leg") and not blast_ragdoll.active: visual_getup_left = .65

func _sever_part(part: String,direction: Vector2) -> void:
	var values := current_pose()
	var rect := part_rect(part)
	var original_facing := facing
	var was_low := is_prone()
	super._sever_part(part,direction)
	var piece: Dictionary = detached_parts.back()
	piece["concept_pose"] = values
	piece["concept_center"] = rect.get_center()
	piece["concept_facing"] = original_facing
	if part.ends_with("leg") and not was_low: visual_fall_left = .42

func _draw_detached() -> void:
	for piece in detached_parts:
		if not piece.has("concept_pose"): continue
		var proportions := body_size/Vector2(32,64)
		var mirror := Transform2D(Vector2(piece.concept_facing*proportions.x,0),Vector2(0,proportions.y),Vector2.ZERO)
		var base := Transform2D(piece.rotation,to_local(piece.point))*Transform2D(0,-piece.concept_center)*mirror
		ART.draw_pose(self,piece.concept_pose,base,[piece.part])

func reset_target() -> void:
	visual_hit_left = 0
	visual_fall_left = 0
	visual_getup_left = 0
	visual_land_left = 0
	death_elapsed = 0
	death_was_prone = false
	animation_name = "idle"
	animation_frame = 0
	animation_elapsed = 0
	preview_clip = ""
	preview_frame = 0
	super.reset_target()

func ragdoll_pose() -> Dictionary:
	return _physical_pose(current_pose())

func ragdoll_recovery_pose(prone: bool) -> Dictionary:
	return _physical_pose(ART.pose("prone_idle" if prone else "idle",0),prone)

func ragdoll_recovery_phase(phase: float) -> float:
	return floorf(phase*15)/15

func constrain_recovery_points(points: Dictionary,feet: Vector2) -> void:
	var proportions := body_size/Vector2(32,64)
	var basis := Transform2D(Vector2(facing*proportions.x,0),Vector2(0,proportions.y),feet)
	var inverse := basis.affine_inverse()
	for side in ["left","right"]:
		var shoulder := basis*ART.shoulder_point(inverse*points.neck,inverse*points.waist,side)
		points[side+"_hand"] += shoulder-points[side+"_shoulder"]
		points[side+"_shoulder"] = shoulder
		for limb in [["shoulder","elbow","hand",12.0,1.0],["hip","knee","ankle",13.0,-1.0]]:
			var solved := ART.solve_limb(inverse*points[side+"_"+limb[0]],inverse*points[side+"_"+limb[2]],limb[3],limb[3],limb[4])
			points[side+"_"+limb[1]] = basis*solved[0]
			points[side+"_"+limb[2]] = basis*solved[1]

func _physical_pose(values: Dictionary,prone_override: Variant = null) -> Dictionary:
	var proportions := body_size/Vector2(32,64)
	var mirror := Transform2D(Vector2(facing*proportions.x,0),Vector2(0,proportions.y),reaction_offset)
	var basis := global_transform
	basis.origin = Vector2.ZERO
	var result := {"parts":{},"joints":{},"facing":facing,"prone":is_prone() if prone_override == null else bool(prone_override),"concept":true}
	for key in values.parts:
		var part: Dictionary = values.parts[key]
		var transform := basis*mirror*Transform2D(part.rotation,part.position)
		result.parts[key] = {"position":transform.origin,"rotation":Vector2.DOWN.angle_to(transform.y),"dimensions":part.dimensions*Vector2(transform.x.length(),transform.y.length())}
	for key in values.joints: result.joints[key] = basis*mirror*values.joints[key]
	result.anatomical_limits = {"neck":Vector2(-.95,.95),"waist":Vector2(-.7,.7)}
	for side in ["left","right"]:
		# Both visible sides share the same elbow/knee anatomy; mirroring the
		# entire actor reverses the signed range, not the near/far limb name.
		result.anatomical_limits[side+"_elbow"] = Vector2(deg_to_rad(-150),deg_to_rad(-2)) if facing > 0 else Vector2(deg_to_rad(2),deg_to_rad(150))
		result.anatomical_limits[side+"_knee"] = Vector2(deg_to_rad(2),deg_to_rad(150)) if facing > 0 else Vector2(deg_to_rad(-150),deg_to_rad(-2))
	result.pelvis_offset = -result.parts.pelvis.position.y
	return result

func create_ragdoll_skin() -> Node2D:
	return preload("res://scripts/core/concept_zombie_ragdoll_skin.gd").new()
