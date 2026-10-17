extends RigidBody2D
## Held at the trigger hand, with its own contacts instead of a torso-painted gun.
const CATALOG = preload("res://scripts/campaign/catalog.gd")
var player: CoreMovementPlayer
var rig: Node2D
var source: Dictionary
var weapon_facing := 1.0
var wrist_angle := 0.0
var controller: Node2D
func _ready() -> void:
	var data: Dictionary = CATALOG.WEAPONS[CATALOG.index_for(player.weapon.equipped_weapon_id)]
	mass = 1.0 if data.id == "m1911" else 3.0
	gravity_scale = 1
	linear_damp = .6
	angular_damp = 1.5
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	collision_layer = 128
	collision_mask = 1|8|128
	position = source.breech
	rotation = source.direction.angle()
	weapon_facing = player.body.facing
	wrist_angle = rotation-rig.parts.right_forearm.rotation
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(data.length*(1-data.grip),2.2)
	shape.shape = rectangle
	shape.position = Vector2(rectangle.size.x*.5,0)
	add_child(shape)
	add_collision_exception_with(player)
	# Forearm/palm share the contact grip; the rest of the body blocks the gun.
	add_collision_exception_with(rig.parts.right_forearm)
	add_collision_exception_with(rig.parts.right_upper_arm)
	add_collision_exception_with(rig.parts.left_forearm)
	var pin := PinJoint2D.new()
	pin.position = CATALOG.rear_grip(data)*Vector2(1,weapon_facing)
	pin.disable_collision = true
	add_child(pin)
	pin.node_a = pin.get_path_to(self)
	pin.node_b = pin.get_path_to(rig.parts.right_forearm)
	linear_velocity = rig.parts.right_forearm.linear_velocity
	angular_velocity = rig.parts.right_forearm.angular_velocity
	controller = player.blast_ragdoll

func _physics_process(_delta: float) -> void:
	var held: bool = controller.recovering or controller.recovery_finished or controller.frozen
	freeze = held
	if held:
		var data: Dictionary = CATALOG.WEAPONS[CATALOG.index_for(player.weapon.equipped_weapon_id)]
		var forearm: RigidBody2D = rig.parts.right_forearm
		global_rotation = forearm.global_rotation+wrist_angle
		global_position = forearm.to_global(Vector2(0,forearm.dimensions.y*.5))-global_transform.basis_xform(CATALOG.rear_grip(data)*Vector2(1,weapon_facing))
func _draw() -> void:
	CATALOG.draw_weapon(self,player.weapon.equipped_weapon_id,Vector2.ZERO,Vector2.RIGHT,Vector2(0,weapon_facing))
