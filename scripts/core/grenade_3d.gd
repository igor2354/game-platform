extends RigidBody3D
const U=100.97598
var tuning: CoreRagdollSettings
var controller: Node3D
var instigator: CharacterBody3D
var held=true
var fuse_started=false
var fuse_left=4.0
var detonated=false
var flight_age=0.0
var age=0.0
var disabled=false
var previous_velocity=Vector3.ZERO
var saved_velocity=Vector3.ZERO
var saved_spin=Vector3.ZERO
var hit_times={}
var pending_hits={}
var collider: CollisionShape3D
var mesh: SphereMesh
var last_parameters=Vector4(INF,INF,INF,INF)
var material: PhysicsMaterial
func _ready():
 add_to_group("core_grenades_3d")
 custom_integrator=true
 continuous_cd=true
 contact_monitor=true
 max_contacts_reported=12
 linear_damp=0
 angular_damp=0
 collision_layer=0
 collision_mask=1|2|4|8|16
 collider=CollisionShape3D.new()
 collider.shape=SphereShape3D.new()
 add_child(collider)
 material=PhysicsMaterial.new()
 physics_material_override=material
 var visual=MeshInstance3D.new()
 mesh=SphereMesh.new()
 mesh.radius=tuning.grenade_radius/U
 mesh.height=mesh.radius*2
 visual.mesh=mesh
 var mat=StandardMaterial3D.new()
 mat.albedo_color=Color("687451")
 visual.material_override=mat
 add_child(visual)
 fuse_left=tuning.grenade_fuse
 freeze=true
 apply_tuning()
func start_fuse():
 if not detonated: fuse_started=true
func apply_tuning():
 var values=Vector4(tuning.grenade_mass,tuning.grenade_radius,tuning.grenade_bounce,tuning.grenade_friction)
 if values!=last_parameters:
  mass=values.x
  collider.shape.radius=values.y/U
  mesh.radius=values.y/U
  mesh.height=mesh.radius*2
  material.bounce=values.z
  material.friction=values.w
  last_parameters=values
 var paused=controller.stage.paused or not tuning.grenades_enabled
 if paused!=disabled:
  disabled=paused
  if disabled:
   saved_velocity=linear_velocity
   saved_spin=angular_velocity
   freeze=true
  else:
   freeze=held
   linear_velocity=saved_velocity
   angular_velocity=saved_spin
   sleeping=false
func launch(point: Vector3,speed: Vector3):
 held=false
 global_position=point
 freeze=disabled
 collision_layer=256
 linear_velocity=speed
 previous_velocity=speed
 angular_velocity=Vector3(0,0,tuning.grenade_spin*signf(speed.x))
 if is_instance_valid(instigator): add_collision_exception_with(instigator)
 reset_physics_interpolation()
func _integrate_forces(state: PhysicsDirectBodyState3D):
 if held or disabled: return
 var incoming=previous_velocity if previous_velocity.length()>state.linear_velocity.length() else state.linear_velocity
 for i in state.get_contact_count():
  var other=state.get_contact_collider_object(i)
  if not is_instance_valid(other): continue
  if other is PhysicalBone3D:
   var parent=other.get_parent()
   while parent and not parent is CharacterBody3D: parent=parent.get_parent()
   if parent: other=parent
  var other_velocity=other.velocity if other is CharacterBody3D else Vector3.ZERO
  var normal=state.transform.basis*state.get_contact_local_normal(i)
  var speed=maxf(0,-(incoming-other_velocity).dot(normal))*U
  if other==instigator and flight_age<.2: continue
  if not tuning.grenade_impact_enabled or speed<tuning.grenade_impact_min_speed: continue
  if not other.has_method("take_projectile_hit") and other!=instigator: continue
  var id=other.get_instance_id()
  if not pending_hits.has(id) or speed>pending_hits[id].speed: pending_hits[id]={"speed":speed,"direction":incoming.normalized()}
 state.linear_velocity+=Vector3.DOWN*(tuning.grenade_gravity/U)*state.step
 previous_velocity=state.linear_velocity
func _physics_process(dt):
 apply_tuning()
 if disabled or detonated: return
 age+=dt
 if not held: flight_age+=dt
 if fuse_started and tuning.explosions_enabled: fuse_left-=dt
 if not held and flight_age>=.2 and is_instance_valid(instigator): remove_collision_exception_with(instigator)
 for id in pending_hits:
  var other=instance_from_id(id)
  if not is_instance_valid(other) or age-float(hit_times.get(id,-10))<.4: continue
  hit_times[id]=age
  var event=pending_hits[id]
  var damage=minf(tuning.grenade_impact_max_damage,(event.speed-tuning.grenade_impact_min_speed)*tuning.grenade_impact_damage_scale*mass/.45)
  if other.has_method("take_projectile_hit"): other.take_projectile_hit(damage,global_position,event.direction)
  else: other.take_damage(damage)
 pending_hits.clear()
 if fuse_started and fuse_left<=0: explode()
func explode():
 if detonated or not tuning.grenades_enabled or not tuning.explosions_enabled: return
 detonated=true
 var profile=tuning.snapshot()
 profile.explosion_radius=tuning.grenade_blast_radius
 profile.explosion_full_damage_radius=minf(profile.explosion_full_damage_radius,profile.explosion_radius)
 profile.explosion_damage=tuning.grenade_blast_damage
 profile.explosion_impulse=tuning.grenade_blast_impulse
 profile.explosion_shockwave_radius=tuning.grenade_shockwave_radius
 controller.on_grenade_finished(self)
 preload("res://scripts/core/explosion_3d.gd").spawn(controller.stage,global_position,profile,self,instigator)
 queue_free()
