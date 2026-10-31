extends CoreConceptZombie
## Shared registered cutout mannequin for every map and target role.
## Replacement textures use the same transparent bounds as the original piece.
var part_textures: Dictionary = {}
const LIVE_ART = preload("res://scripts/core/mannequin_art.gd")
var mannequin_style := 0
var cached_clip := ""
var cached_phase := -1.0
var cached_pose: Dictionary = {}

func pose_scale() -> Vector2:
	# Width of the old collision capsule cannot squeeze the selected anatomy.
	return Vector2.ONE*body_size.y/64

func animated_part_rect(part: String,prone_pose: bool,motion := true) -> Rect2:
	var values := current_pose() if motion and prone_pose == is_prone() else LIVE_ART.pose("prone_idle" if prone_pose else "idle",0)
	return ART.rect_for(values,part,facing,pose_scale())

func ragdoll_recovery_pose(prone: bool) -> Dictionary:
	return _physical_pose(LIVE_ART.pose("prone_idle" if prone else "bind",0),prone)

func constrain_recovery_points(points: Dictionary,feet: Vector2) -> void:
	var proportions := pose_scale()
	var basis := Transform2D(Vector2(facing*proportions.x,0),Vector2(0,proportions.y),feet)
	var inverse := basis.affine_inverse()
	for side in ["left","right"]:
		var shoulder := basis*LIVE_ART.shoulder_point(inverse*points.neck,inverse*points.waist,side)
		points[side+"_hand"] += shoulder-points[side+"_shoulder"]
		points[side+"_shoulder"] = shoulder
		for limb in [["shoulder","elbow","hand",LIVE_ART.UPPER_ARM,LIVE_ART.FOREARM,1.0],["hip","knee","ankle",LIVE_ART.THIGH,LIVE_ART.SHIN,-1.0]]:
			var solved := ART.solve_limb(inverse*points[side+"_"+limb[0]],inverse*points[side+"_"+limb[2]],limb[3],limb[4],limb[5])
			points[side+"_"+limb[1]] = basis*solved[0]
			points[side+"_"+limb[2]] = basis*solved[1]

func _ready() -> void:
	super._ready()
	if stationary_target:
		knockdown_moves_in_subclass = false
		collision_mask = 0

func locomotion_animation_phase(clip: String) -> float:
	return LIVE_ART.phase_from_distance(walk_phase/TAU*48,clip,pose_scale().x*global_transform.x.length())

func _select_animation() -> String:
	var clip := super._select_animation()
	if stationary_target and clip in ["airborne","land","patrol","chase"]:
		return "prone_idle" if is_prone() else "idle"
	return clip

func current_pose() -> Dictionary:
	var clip := animation_name if preview_clip.is_empty() else preview_clip
	var phase := animation_phase
	if not preview_clip.is_empty():
		phase = float(preview_frame)/(16 if ART.CLIPS.has(clip) and ART.CLIPS[clip][1] else 15)
	if clip != cached_clip or phase != cached_phase or cached_pose.is_empty():
		cached_pose = LIVE_ART.pose(clip,phase)
		cached_clip = clip
		cached_phase = phase
	return cached_pose

func set_part_texture(part: String,texture: Texture2D) -> void:
	if part not in ART.ORDER: return
	if texture == null: part_textures.erase(part)
	else: part_textures[part] = texture
	queue_redraw()

func draw_live_piece(canvas: CanvasItem,key: String,transform: Transform2D,dimensions: Vector2,tint: Color) -> void:
	if not part_textures.has(key):
		LIVE_ART.draw_piece(canvas,key,transform,dimensions,tint,mannequin_style)
		return
	canvas.draw_set_transform_matrix(transform)
	# Optional replacement art also keeps its own aspect ratio.
	var size: Vector2 = part_textures[key].get_size()*(dimensions.y/part_textures[key].get_height())
	canvas.draw_texture_rect(part_textures[key],Rect2(-size*.5,size),false,tint)

func _draw_live_pose(canvas: CanvasItem,values: Dictionary,base: Transform2D,visible: Array,flash := "",dead := false) -> void:
	for key in ART.ORDER:
		var part: Dictionary = values.parts[key]
		if part.anatomy not in visible: continue
		var tint := Color(.75,.78,.8) if key.begins_with("left") else Color.WHITE
		if dead: tint *= Color(.75,.77,.79)
		if flash == part.anatomy: tint = Color(1.7,1.3,1.15)
		draw_live_piece(canvas,key,base*Transform2D(part.rotation,part.position),part.dimensions,tint)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_actor_body() -> void:
	var proportions := pose_scale()
	var base := Transform2D(Vector2(facing*proportions.x,0),Vector2(0,proportions.y),reaction_offset)
	_draw_live_pose(self,current_pose(),base,PARTS.filter(func(part): return has_part(part)),last_hit_part if hit_flash > 0 else "",health <= 0)

func _draw_detached() -> void:
	for piece in detached_parts:
		if not piece.has("concept_pose"): continue
		var proportions := pose_scale()
		var mirror := Transform2D(Vector2(piece.concept_facing*proportions.x,0),Vector2(0,proportions.y),Vector2.ZERO)
		var base := Transform2D(piece.rotation,to_local(piece.point))*Transform2D(0,-piece.concept_center)*mirror
		_draw_live_pose(self,piece.concept_pose,base,[piece.part])

func reset_target() -> void:
	animation_phase = 0
	super.reset_target()
