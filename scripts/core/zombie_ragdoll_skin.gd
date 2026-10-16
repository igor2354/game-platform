extends Node2D
## The existing zombie artwork is split over its real physical bones.
const APPEARANCE = preload("res://scripts/core/enemy_appearance.gd")
var rig: Node2D
var zombie: CoreZombie
var pose: Dictionary

static func capture_pose(actor: CoreZombie,rects: Dictionary = {}) -> Dictionary:
	rects = rects.duplicate()
	var prone := actor.is_prone() if rects.is_empty() else not actor.has_part("left_leg") or not actor.has_part("right_leg")
	if rects.is_empty():
		for anatomy in CoreEnemyDummy.PARTS: rects[anatomy] = actor.part_rect(anatomy)
	var basis := actor.global_transform
	basis.origin = basis.x*actor.reaction_offset.x+basis.y*actor.reaction_offset.y
	var result := {"parts":{},"joints":{},"sections":{},"basis":basis,"facing":actor.facing,"prone":prone,"clock":actor.idle_clock}
	var torso: Rect2 = rects.torso
	_add_piece(result,"torso","torso",torso,Vector2.DOWN if not prone else Vector2(-actor.facing,0),true)
	var pelvis: Vector2 = Vector2(torso.get_center().x,torso.end.y) if not prone else Vector2(torso.position.x if actor.facing > 0 else torso.end.x,torso.get_center().y)
	var pelvis_rect := Rect2(pelvis-Vector2(8,2),Vector2(16,4)) if not prone else Rect2(pelvis-Vector2(2,6),Vector2(4,12))
	_add_piece(result,"pelvis","torso",pelvis_rect,Vector2.DOWN if not prone else Vector2(actor.facing,0),false)
	result.joints.waist = basis*pelvis
	var head: Rect2 = rects.head
	_add_piece(result,"head","head",head,Vector2.DOWN,true)
	result.joints.neck = basis*(head.get_center()+Vector2(0,head.size.y*.5) if not prone else head.get_center()-Vector2(actor.facing*head.size.x*.5,0))
	for side in ["left","right"]:
		for limb in ["arm","leg"]:
			var anatomy: String = side+"_"+limb
			var rect: Rect2 = rects[anatomy]
			var direction := Vector2.DOWN if not prone else Vector2(actor.facing if limb == "arm" else -actor.facing,0)
			var start := rect.get_center()-direction*(rect.size.y if not prone else rect.size.x)*.5
			var length: float = rect.size.y if not prone else rect.size.x
			var width: float = rect.size.x if not prone else rect.size.y
			var upper_length: float = length*.52
			var lower_length: float = length-upper_length-(minf(4,length*.2) if limb == "leg" else 0.0)
			var knee: Vector2 = start+direction*upper_length
			var ankle: Vector2 = knee+direction*lower_length
			var upper: String = side+("_upper_arm" if limb == "arm" else "_thigh")
			var lower: String = side+("_forearm" if limb == "arm" else "_shin")
			_add_piece(result,upper,anatomy,_segment_rect(start,knee,width),direction,false)
			_add_piece(result,lower,anatomy,_segment_rect(knee,ankle,width),direction,limb == "arm")
			result.joints[side+("_shoulder" if limb == "arm" else "_hip")] = basis*start
			result.joints[side+("_elbow" if limb == "arm" else "_knee")] = basis*knee
			if limb == "leg":
				_add_piece(result,side+"_foot",anatomy,_segment_rect(ankle,start+direction*length,width),direction,true)
				result.joints[side+"_ankle"] = basis*ankle
	result.pelvis_offset = -(basis*pelvis).y
	return result

static func _segment_rect(a: Vector2,b: Vector2,width: float) -> Rect2:
	var size := Vector2(width,a.distance_to(b)) if absf(b.y-a.y) > absf(b.x-a.x) else Vector2(a.distance_to(b),width)
	return Rect2((a+b)*.5-size*.5,size)

static func _add_piece(result: Dictionary,key: String,anatomy: String,rect: Rect2,direction: Vector2,detail: bool) -> void:
	var horizontal := absf(direction.x) > .5
	var dimensions := Vector2(rect.size.y,rect.size.x) if horizontal else rect.size
	var rotation: float = result.basis.get_rotation()+Vector2.DOWN.angle_to(direction)
	var initial := Transform2D(rotation,result.basis*rect.get_center())
	result.parts[key] = {"position":initial.origin,"rotation":rotation,"dimensions":dimensions}
	result.sections[key] = {"anatomy":anatomy,"rect":rect,"initial":initial,"detail":detail}

func _process(_delta: float) -> void:
	if not get_tree().paused: queue_redraw()

func visible_sections() -> Array:
	var result: Array = []
	for key in ["left_thigh","left_shin","left_foot","right_thigh","right_shin","right_foot","pelvis","torso","left_upper_arm","left_forearm","right_upper_arm","right_forearm","head"]:
		if zombie.has_part(pose.sections[key].anatomy) and rig.parts[key].visible: result.append(key)
	return result

func _draw() -> void:
	if not is_instance_valid(rig): return
	for key in visible_sections():
		var section: Dictionary = pose.sections[key]
		var bone: RigidBody2D = rig.parts[key]
		var ratio: Vector2 = bone.dimensions/pose.parts[key].dimensions
		var stretch := Transform2D(Vector2(ratio.x,0),Vector2(0,ratio.y),Vector2.ZERO)
		draw_set_transform_matrix(global_transform.affine_inverse()*bone.global_transform*stretch*section.initial.affine_inverse()*pose.basis)
		var color: Color = zombie._part_color(section.anatomy)
		if zombie.hit_flash > 0 and zombie.last_hit_part == section.anatomy: color = Color("ffcfb6")
		if key == "pelvis": draw_rect(section.rect,color)
		else: APPEARANCE.draw_part(self,section.anatomy,section.rect,color,pose.clock,true,pose.facing,section.detail)
		if zombie.debug_zones and zombie.health > 0: draw_rect(section.rect,Color("f0c96a"),false,1)
	draw_set_transform_matrix(Transform2D.IDENTITY)
