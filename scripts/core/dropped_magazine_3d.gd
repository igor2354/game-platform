extends RigidBody3D
# Small-object contact recovery in physics state; never chooses a resting edge.
var half_size := Vector3(.05,.015,.10)
var stable_time := 0.0
var ground_ray := PhysicsRayQueryParameters3D.new()
func _ready() -> void:
 ground_ray.collision_mask = 1|8
 ground_ray.exclude = [get_rid()]
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
 if freeze: return
 var center := state.transform.origin
 ground_ray.from = center+Vector3.UP*.3
 ground_ray.to = center-Vector3.UP*.4
 var hit := state.get_space_state().intersect_ray(ground_ray)
 if hit.is_empty():
  stable_time=0
  return
 var normal: Vector3 = hit.normal
 if normal.y<.2 or center.y<hit.position.y-.03: return
 var radius := absf(normal.dot(state.transform.basis.x))*half_size.x+absf(normal.dot(state.transform.basis.y))*half_size.y+absf(normal.dot(state.transform.basis.z))*half_size.z
 var gap: float = normal.dot(center-hit.position)-radius
 if gap>.006:
  stable_time=0
  return
 var flat_patch := false
 for i in 3:
  if absf(normal.dot(state.transform.basis[i]))>.998: flat_patch = true
 if gap<.001:
  var transform := state.transform
  transform.origin += normal*(.001-gap)
  state.transform = transform
  var speed := state.linear_velocity.dot(normal)
  if speed<0:
   var lever := Vector3.ZERO
   for i in 3:
    var axis: Vector3 = state.transform.basis[i]
    var projection := normal.dot(axis)
    if absf(projection)>.035: lever -= axis*signf(projection)*half_size[i]
   if flat_patch: lever = -normal*radius
   var contact_speed := (state.linear_velocity+state.angular_velocity.cross(lever)).dot(normal)
   var effective := state.inverse_mass+normal.dot((state.inverse_inertia_tensor*(lever.cross(normal))).cross(lever))
   if contact_speed<0 and effective>.0001:
    state.apply_impulse(normal*(-contact_speed*(1.04 if contact_speed<-.6 else 1.0)/effective),lever)
 state.linear_velocity *= exp(-state.step*3)
 state.angular_velocity *= exp(-state.step*(20 if flat_patch else 3))
 if state.linear_velocity.length()<.012 and state.angular_velocity.length()<.06: stable_time+=state.step
 else: stable_time=0
 if stable_time>.8:
  state.linear_velocity=Vector3.ZERO
  state.angular_velocity=Vector3.ZERO
  state.sleeping=true
