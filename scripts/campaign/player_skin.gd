extends Node2D
const ART = preload("res://scripts/campaign/art.gd")
var player: CoreMovementPlayer
var deform_figure: Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if player.character_id == "harry":
		deform_figure = preload("res://scripts/campaign/deform_figure.gd").new()
		deform_figure.name = "DeformFigure"
		deform_figure.player = player
		add_child(deform_figure)
	elif player.sofia_cel_variant and player.character_id == "sofia":
		deform_figure = preload("res://scripts/campaign/sofia_cel_figure.gd").new()
		deform_figure.name = "SofiaCelFigure"
		deform_figure.player = player
		add_child(deform_figure)

func _process(_delta: float) -> void:
	# Body pose coordinates already contain the facing mirror.
	scale.x = player.body.facing
	if is_instance_valid(deform_figure): deform_figure.update_pose(player.body.ragdoll_pose())
	queue_redraw()

func _draw() -> void:
	if player.uses_deformed_skin() or player.uses_painted_cels(): return
	var pose := player.body.ragdoll_pose()
	for key in ["left_thigh","left_shin","left_foot","right_thigh","right_shin","right_foot","pelvis","torso","head"]:
		var piece: Dictionary = pose.parts[key]
		ART.draw_piece(self,player.character_id,key,Transform2D(piece.rotation,piece.position),piece.dimensions,pose.facing,Color(.73,.76,.72) if key.begins_with("left") else Color.WHITE)
