extends Node2D
## The physical proxy keeps collision bodies, but appearance is one painted frame.
const ART = preload("res://scripts/core/concept_zombie_art.gd")
const FRAMES = preload("res://scripts/core/concept_zombie_frames.gd")
var rig: Node2D
var zombie: CoreZombie
var pose: Dictionary
var sprite: Sprite2D
var elapsed := 0.0
var display_clip := "fall"
var display_frame := 0
func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.name = "WholePhysicalFrame"
	add_child(sprite)
	_update_frame()
func _physics_process(delta: float) -> void:
	if zombie.test_frozen: return
	elapsed += delta
	_update_frame()
func _process(_delta: float) -> void:
	if not get_tree().paused: _update_frame()
func visible_sections() -> Array:
	# Compatibility for physical hit ownership; these are never drawn separately.
	return ART.ORDER.filter(func(key): return zombie.has_part(ART.anatomy(key)) and rig.parts[key].visible)
func _update_frame() -> void:
	if not is_instance_valid(rig) or not is_instance_valid(sprite): return
	var controller: CoreCharacterRagdoll = zombie.blast_ragdoll
	var proportions := zombie.body_size/Vector2(32,64)
	var progress := clampf(elapsed/.42,0,1)
	display_clip = "death" if zombie.health <= 0 else "fall"
	display_frame = clampi(floori(progress*16),0,15)
	var angle := wrapf(rig.parts.torso.rotation-pose.parts.torso.rotation,-PI,PI)*(1-progress)
	var origin: Vector2 = rig.parts.pelvis.global_position
	var pelvis: Vector2 = ART.pose(display_clip,display_frame).parts.pelvis.position*Vector2(pose.facing*proportions.x,proportions.y)
	origin -= pelvis.rotated(angle)
	if controller.recovering:
		progress = zombie.call("ragdoll_recovery_phase",clampf(controller.recovery_elapsed/controller.recovery_duration,0,1))
		display_clip = "prone_idle" if controller.recovery_target.prone else "get_up"
		display_frame = clampi(roundi(progress*15),0,15)
		angle = 0
		origin = controller.recovery_feet
	FRAMES.update_sprite(sprite,display_clip,display_frame,zombie.missing_parts,zombie.last_hit_part if zombie.hit_flash > 0 else "",zombie.health <= 0)
	sprite.global_transform = Transform2D(angle,Vector2(pose.facing*proportions.x,proportions.y)/FRAMES.SCALE,0,origin)
func health_anchor() -> Vector2:
	var head := FRAMES.rect_for(display_clip,display_frame,"head")
	return sprite.to_global(Vector2(head.get_center().x,head.position.y)*FRAMES.SCALE)
func connected_head_transform() -> Transform2D:
	# Diagnostic joint transform retained for physical-neck checks. The visible
	# head is part of the complete frame and cannot separate from its artwork.
	var head: RigidBody2D = rig.parts.head
	var torso: RigidBody2D = rig.parts.torso
	var neck: Vector2 = pose.joints.neck
	var head_anchor: Vector2 = (Transform2D(pose.parts.head.rotation,pose.parts.head.position).affine_inverse()*neck)/pose.parts.head.dimensions
	var torso_anchor: Vector2 = (Transform2D(pose.parts.torso.rotation,pose.parts.torso.position).affine_inverse()*neck)/pose.parts.torso.dimensions
	var result := head.global_transform
	result.origin = torso.to_global(torso_anchor*torso.dimensions)-result.basis_xform(head_anchor*head.dimensions)
	return result
