extends RigidBody3D
const SOURCE = preload("res://scripts/core/weapon_casing.gd")
const GEO = preload("res://scripts/core/fx_geometry_3d.gd")
var effects: Node3D
var weapon_id := "stg44"
var age := 0.0
var launch_height := 0.0
var rest_variant := 0
var smoke_variant := 0
var visual: MeshInstance3D
var size := Vector2.ZERO
var rested := false
var previous_velocity := Vector3.ZERO
var support: Node3D
var kind := 3
var last_contact := -1.0
var quiet_time := 0.0
var ground_ray := PhysicsRayQueryParameters3D.new()
var stable_time := 0.0
var last_normal := Vector3.ZERO
var last_contact_point := Vector3.ZERO
func prepare(host: Node3D,id: String,point: Vector3,axis: Vector3) -> void:
 effects = host
 weapon_id = id
 size = preload("res://scripts/campaign/catalog.gd").casing_mm(id)*.001
 mass = {"stg44":.005,"mp40":.004,"svt":.01,"m1911":.005}.get(id,.005)
 collision_layer = 0
 collision_mask = 1|8
 gravity_scale = 750.0/100.97598/float(ProjectSettings.get_setting("physics/3d/default_gravity",9.8))
 continuous_cd = true
 linear_damp = .2
 angular_damp = 1.5
 contact_monitor = true
 max_contacts_reported = 4
 physics_material_override = PhysicsMaterial.new()
 physics_material_override.bounce = SOURCE.BOUNCE[3]
 physics_material_override.friction = SOURCE.DRAG[3]/220.0
 var collider := CollisionShape3D.new()
 var shape := CapsuleShape3D.new()
 shape.radius = size.y*.5
 shape.margin = .0005
 shape.height = size.x
 collider.shape = shape
 collider.rotation.z = PI/2
 add_child(collider)
 ground_ray.collision_mask = 1|8
 host.add_child(self)
 ground_ray.exclude = [get_rid()]
 global_position = point
 launch_height = point.y
 var art: Array = SOURCE.ART[id]
 visual = GEO.atlas(self,art[0],Rect2(art[1].position*art[0].get_size()/art[2],art[1].size*art[0].get_size()/art[2]),size)
 rest_variant = host.rng.randi_range(0,3)
 smoke_variant = host.rng.randi_range(0,5)
 # Preserve the old backwards/upward mechanical launch, with symmetric depth.
 linear_velocity = host.combat.stage.player.velocity-axis*host.rng.randf_range(38,85)/100.97598+Vector3.UP*host.rng.randf_range(78,142)/100.97598+Vector3.BACK*host.rng.randf_range(-.35,.35)
 angular_velocity = Vector3(host.rng.randf_range(-8,8),host.rng.randf_range(-8,8),host.rng.randf_range(-22,22))
 previous_velocity = linear_velocity
 sleeping_state_changed.connect(on_sleep)
func on_sleep() -> void:
 if sleeping and not rested and rest_variant>0:
  rested = true
  visual.queue_free()
  var art: Array = SOURCE.REST_ART[weapon_id]
  var factor: Vector2 = art[0].get_size()/Vector2(2172,724)
  var crop: Rect2 = art[rest_variant]
  visual = GEO.atlas(self,art[0],Rect2(crop.position*factor,crop.size*factor),size*Vector2(.9 if rest_variant>1 else 1.0,1))
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
 if not is_instance_valid(effects): return
 age += state.step
 if state.transform.origin.y<launch_height-6000.0/100.97598:
  queue_free()
  return
 if state.get_contact_count()>0:
  var object = state.get_contact_collider_object(0)
  var normal: Vector3 = state.get_contact_local_normal(0)
  var point: Vector3 = state.get_contact_local_position(0)
  last_normal = normal
  last_contact_point = point
  var material_kind: int = effects.surface_material(object,point,normal)
  if material_kind>=0:
   if kind!=material_kind:
    kind = material_kind
    physics_material_override.bounce = SOURCE.BOUNCE[kind]
    physics_material_override.friction = clampf(SOURCE.DRAG[kind]/220.0,.05,1)
   var incoming := previous_velocity.dot(normal)
   # Gravity/contact chatter is not a new audible impact.
   if incoming<-.22 and age-last_contact>.12:
    var tangent := previous_velocity-normal*incoming
    state.linear_velocity = tangent*(.36 if kind<2 else .67)+normal*(-incoming)*SOURCE.BOUNCE[kind]
    effects.casing_contact(self,kind,point)
    last_contact = age
   if object is Node3D:
    support = object
    effects.register_support(self,support)
   var stable_slope := sqrt(1-pow(float(SOURCE.ROLL_SLOPE[kind]),2))
   if normal.y>stable_slope and state.linear_velocity.length()<.18:
    state.angular_velocity *= exp(-state.step*12)
   if normal.y>stable_slope and state.linear_velocity.length()<.18 and state.angular_velocity.length()<1.0:
    quiet_time += state.step
    if quiet_time>=.2:
     state.linear_velocity = Vector3.ZERO
     state.angular_velocity = Vector3.ZERO
     state.sleeping = true
   else: quiet_time = 0
 settle_contact(state)
 previous_velocity = state.linear_velocity

func settle_contact(state: PhysicsDirectBodyState3D) -> void:
 var center := state.transform.origin
 ground_ray.from = center+Vector3.UP*.05
 ground_ray.to = center-Vector3.UP*.08
 var hit := state.get_space_state().intersect_ray(ground_ray)
 if hit.is_empty():
  stable_time=0
  return
 var normal: Vector3 = hit.normal
 if normal.y<.8 or center.y<hit.position.y-.02: return
 var radius := size.y*.5+absf(normal.dot(state.transform.basis.x))*maxf(0,(size.x-size.y)*.5)
 var gap: float = normal.dot(center-hit.position)-radius
 if gap>.004 or state.linear_velocity.length()>.3:
  stable_time=0
  return
 if gap<.0005:
  var pose := state.transform
  pose.origin += normal*(.0005-gap)
  state.transform=pose
 # Only remove residual contact energy after actual flight/bounces.
 var speed := state.linear_velocity.dot(normal)
 if absf(speed)<.18: state.linear_velocity-=normal*speed
 state.linear_velocity*=exp(-state.step*8)
 state.angular_velocity*=exp(-state.step*18)
 stable_time+=state.step
 if stable_time>.5 and state.linear_velocity.length()<.03 and state.angular_velocity.length()<.2:
  state.linear_velocity=Vector3.ZERO
  state.angular_velocity=Vector3.ZERO
  state.sleeping=true
