extends Node2D
## The hero's clothing and equipment follow the same physical bones as the
## collision shapes. No mannequin artwork or duplicate standing sprite is drawn.
const INK := Color("25323b")
const NEAR := Color("829fae")
const FAR := Color("4c6678")
const BOOT := Color("34434d")
var rig: Node2D
var player: CoreMovementPlayer
var facing := 1.0
var deform_figure: Node2D
var painted_head_stage := 0
var painted_cel_pose: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if player.character_id == "harry":
		deform_figure = preload("res://scripts/campaign/deform_figure.gd").new()
		deform_figure.name = "DeformFigure"
		deform_figure.player = player
		deform_figure.physical = true
		deform_figure.head_stage = painted_head_stage
		add_child(deform_figure)
		_update_deform_pose()
	elif player.sofia_cel_variant and player.character_id == "sofia":
		deform_figure = preload("res://scripts/campaign/sofia_drawn_figure.gd").new()
		deform_figure.name = "SofiaCelFigure"
		deform_figure.player = player
		deform_figure.physical = true
		deform_figure.source_pose = painted_cel_pose
		add_child(deform_figure)
		_update_deform_pose()

func _update_deform_pose() -> void:
	if not is_instance_valid(deform_figure): return
	var parts := {}
	for key in rig.parts:
		var body: RigidBody2D = rig.parts[key]
		var pose := global_transform.affine_inverse()*body.global_transform
		parts[key] = {"position":pose.origin,"rotation":pose.get_rotation(),"dimensions":body.dimensions/scale.x}
	deform_figure.update_pose({"parts":parts,"facing":facing})

func _process(_delta: float) -> void:
	_update_deform_pose()
	queue_redraw()

func _part(key: String,mirror := false) -> Vector2:
	var body: RigidBody2D = rig.parts[key]
	var pose := global_transform.affine_inverse()*body.global_transform
	pose = Transform2D(pose.get_rotation(),pose.origin)
	if mirror: pose = pose*Transform2D(Vector2(facing,0),Vector2(0,1),Vector2.ZERO)
	draw_set_transform_matrix(pose)
	return body.dimensions/scale.x

func _polygon(points: Array,color: Color) -> void:
	var path := PackedVector2Array(points)
	draw_colored_polygon(path,color)
	path.append(path[0])
	draw_polyline(path,INK,.8,true)

func _ellipse(center: Vector2,radius: Vector2,color: Color) -> void:
	var points: Array = []
	for index in 24: points.append(center+Vector2(cos(index*TAU/24),sin(index*TAU/24))*radius)
	_polygon(points,color)

func _limb(key: String,color: Color,end_ratio := .78) -> void:
	var size := _part(key)
	var top := Vector2(0,-size.y*.5)
	var bottom := Vector2(0,size.y*.5)
	var w := size.x*.5
	_polygon([top+Vector2(-w,0),top+Vector2(w,0),bottom+Vector2(w*end_ratio,0),bottom-Vector2(w*end_ratio,0)],color)
	draw_circle(bottom,size.x*.5*end_ratio,color)
	if key.ends_with("forearm"):
		draw_circle(bottom,2.1,Color("c3b79e"))

func _boot(key: String) -> void:
	var size := _part(key,true)
	var w := size.x*.5
	var h := size.y*.5
	_polygon([Vector2(-w,-h),Vector2(w*.25,-h),Vector2(w,h*.15),Vector2(w,h),Vector2(-w,h)],BOOT)
	draw_line(Vector2(-w+1,h-.5),Vector2(w-1,h-.5),Color("adc0c6"),.5,true)

func _torso() -> void:
	var size := _part("torso",true)
	var w := size.x*.5
	var h := size.y*.5
	# The same compact backpack, jacket and chest panel as the baked body.
	_polygon([Vector2(-w+1,-h+2),Vector2(-w-5,-h+4),Vector2(-w-5,h-1),Vector2(-w+1,h)],FAR)
	_polygon([Vector2(-w,-h),Vector2(w,-h+1),Vector2(w,h+2),Vector2(-w,h+2)],NEAR)
	_polygon([Vector2(-2,-h+1),Vector2(3,-h+2),Vector2(4,h-2),Vector2(-1,h-2)],Color("667e8b"))
	draw_line(Vector2(-w+1,-h+2),Vector2(w-1,h-1),Color("34434d"),1.8,true)
	# A neck keeps the helmet attached visually as the head bends.
	draw_line(Vector2(1,-h+2),Vector2(1,-h-2),Color("b0a58f"),4,true)

func _pelvis() -> void:
	var size := _part("pelvis",true)
	var w := size.x*.5
	var h := size.y*.5
	_polygon([Vector2(-w,-h),Vector2(w,-h),Vector2(w,h),Vector2(-w,h)],NEAR)
	draw_line(Vector2(-w,-h+1),Vector2(w,-h+1),BOOT,2,true)
	_polygon([Vector2(-w-1,-h),Vector2(-w+4,-h),Vector2(-w+4,h+1),Vector2(-w-1,h+1)],Color("95a3a0"))

func _head() -> void:
	_part("head",true)
	_polygon([Vector2(-4,-4),Vector2(4,-4),Vector2(5,-1),Vector2(7,1),Vector2(4,2),Vector2(3,6),Vector2(-3,5)],Color("c3b79e"))
	_ellipse(Vector2(-2,1),Vector2(1.2,1.7),Color("9b927f"))
	draw_line(Vector2(3,-1),Vector2(4.5,-1),INK,.75,true)
	_ellipse(Vector2(0,-3),Vector2(6,4.8),INK)
	_ellipse(Vector2(0,-3.3),Vector2(5.2,4),Color("768d91"))
	_polygon([Vector2(-6,-3),Vector2(6.5,-3),Vector2(6.5,-1.2),Vector2(-6,-1.2)],Color("516974"))

func _draw_campaign_weapon() -> void:
	if rig.has_node("HeldWeapon"): return
	var torso: RigidBody2D = rig.parts.torso
	var local := global_transform.affine_inverse()*torso.global_transform
	player.weapon.draw_rifle(self,local*Vector2(-facing*3,4),local.basis_xform(Vector2.UP),local.basis_xform(Vector2.RIGHT*facing))

func _draw() -> void:
	if not is_instance_valid(rig): return
	if player.uses_deformed_skin() or player.uses_painted_cels():
		_draw_campaign_weapon()
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	if not player.character_id.is_empty():
		var art = preload("res://scripts/campaign/art.gd")
		for key in ["left_upper_arm","left_forearm","left_thigh","left_shin","left_foot","right_thigh","right_shin","right_foot","pelvis","torso","head","right_upper_arm","right_forearm"]:
			var part: RigidBody2D = rig.parts[key]
			var local_pose := global_transform.affine_inverse()*part.global_transform
			art.draw_piece(self,player.character_id,key,Transform2D(local_pose.get_rotation(),local_pose.origin),part.dimensions/scale.x,facing,Color(.73,.76,.72) if key.begins_with("left") else Color.WHITE)
		_part("torso")
		_draw_campaign_weapon()
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	# Back to front: slung rifle, far limbs, legs, clothing, helmet, near arm.
	_part("torso")
	# Keep the sling close to the spine, inside the body's contact width;
	# a diagonal rifle would visibly poke through the floor when lying down.
	player.weapon.draw_rifle(self,Vector2(-facing*3,4),Vector2.UP,Vector2.RIGHT*facing)
	_limb("left_upper_arm",FAR)
	_limb("left_forearm",FAR,.65)
	for side in ["left","right"]:
		var color := FAR if side == "left" else NEAR
		_limb(side+"_thigh",color)
		_limb(side+"_shin",color)
		_boot(side+"_foot")
	_torso()
	_pelvis()
	_head()
	_limb("right_upper_arm",NEAR)
	_limb("right_forearm",NEAR,.65)
	draw_set_transform_matrix(Transform2D.IDENTITY)
