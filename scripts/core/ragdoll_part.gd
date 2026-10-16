extends RigidBody2D

var mannequin: Node2D
var part_name := ""
var dimensions := Vector2(8,20)
var tint := Color("9bada2")
var round_head := false
var suspended_transform := Transform2D.IDENTITY
var skin_rendered := false

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if mannequin and not mannequin.simulation_enabled:
		# A state callback already queued before freezing must not restore the
		# previous simulation tick over the pose captured by the switch.
		state.transform = suspended_transform
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0

func receive_projectile_impulse(direction: Vector2,point: Vector2,damage: float) -> void:
	if not mannequin.simulation_enabled: return
	mannequin.activate()
	apply_impulse(direction.normalized()*clampf(damage*5,0,200),point-global_position)
	mannequin.impacts += 1

func _draw() -> void:
	if skin_rendered: return
	if round_head:
		draw_circle(Vector2.ZERO,dimensions.x*.5,tint)
		draw_arc(Vector2.ZERO,dimensions.x*.5,0,TAU,24,Color("263b3d"),1.5)
		draw_line(Vector2(-5,-1),Vector2(5,-1),Color("263b3d"),2)
		draw_line(Vector2(-3,4),Vector2(3,4),Color("263b3d"),1)
		return
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.border_color = Color("263b3d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(minf(dimensions.x,dimensions.y)*.35))
	draw_style_box(style,Rect2(-dimensions*.5,dimensions))
	if part_name == "torso":
		draw_line(Vector2(0,-9),Vector2(0,9),Color("c4d9c5"),2)
		draw_circle(Vector2.ZERO,3,Color("d9b76b"))
	elif part_name == "pelvis":
		draw_line(Vector2(-8,0),Vector2(8,0),Color("d9b76b"),3)
	elif not part_name.ends_with("foot"):
		draw_circle(Vector2(0,-dimensions.y*.5+3),2,Color("d9b76b"))
		draw_circle(Vector2(0,dimensions.y*.5-3),2,Color("d9b76b"))

func can_grab() -> bool:
	return mannequin != null and mannequin.simulation_enabled

func begin_grab() -> void:
	mannequin.activate()

func receive_explosion_impulse(impulse: Vector2,_point: Vector2) -> void:
	if not mannequin.simulation_enabled: return
	mannequin.activate()
	apply_central_impulse(impulse)
