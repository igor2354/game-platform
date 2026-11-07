extends Node2D
const ART = preload("res://scripts/core/concept_zombie_art.gd")
var rig: Node2D
var zombie: CoreZombie
var pose: Dictionary
func _process(_delta: float) -> void:
	if not get_tree().paused: queue_redraw()
func visible_sections() -> Array:
	var order: Array = zombie.call("presentation_order") if zombie.has_method("presentation_order") else ART.ORDER
	return order.filter(func(key): return zombie.has_part(ART.anatomy(key)) and rig.parts[key].visible)
func connected_head_transform() -> Transform2D:
	var head: RigidBody2D = rig.parts.head
	var torso: RigidBody2D = rig.parts.torso
	var neck: Vector2 = pose.joints.neck
	var head_anchor: Vector2 = (Transform2D(pose.parts.head.rotation,pose.parts.head.position).affine_inverse()*neck)/pose.parts.head.dimensions
	var torso_anchor: Vector2 = (Transform2D(pose.parts.torso.rotation,pose.parts.torso.position).affine_inverse()*neck)/pose.parts.torso.dimensions
	var result := head.global_transform
	# Positional solver error under a blast must never draw a detached head.
	# Rotation still comes from the actual articulated physical head.
	result.origin = torso.to_global(torso_anchor*torso.dimensions)-result.basis_xform(head_anchor*head.dimensions)
	return result
func _draw() -> void:
	if not is_instance_valid(rig): return
	var mirror := Transform2D(Vector2(pose.facing,0),Vector2.DOWN,Vector2.ZERO)
	for key in visible_sections():
		var part: RigidBody2D = rig.parts[key]
		var transform := global_transform.affine_inverse()*part.global_transform*mirror
		if key == "head": transform = global_transform.affine_inverse()*connected_head_transform()*mirror
		var far_side := "right" if zombie.has_method("presentation_order") else "left"
		var far_color := Color(.8,.8,.8) if zombie.has_method("presentation_order") else Color(.75,.78,.8)
		var color := far_color if key.begins_with(far_side) else Color.WHITE
		if zombie.health <= 0: color *= Color(.75,.77,.79)
		if zombie.hit_flash > 0 and zombie.last_hit_part == ART.anatomy(key): color = Color(1.7,1.3,1.15)
		if zombie.has_method("draw_live_piece"):
			zombie.draw_live_piece(self,key,transform,part.dimensions,color)
		else:
			ART.draw_piece(self,key,transform,part.dimensions,color)
		if zombie.debug_zones: draw_rect(Rect2(-part.dimensions*.5,part.dimensions),Color("f0c96a"),false,.5)
	draw_set_transform_matrix(Transform2D.IDENTITY)
