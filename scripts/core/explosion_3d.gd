extends Node3D
const U=100.97598
var stage: Node3D
var tuning: CoreExplosionSettings
var source: PhysicsBody3D
var instigator: Node
var affected={}
var elapsed=0.0
var visual: RefCounted
var canvas: Node2D
static func spawn(host: Node3D,point: Vector3,profile: CoreExplosionSettings,origin: PhysicsBody3D=null,attacker: Node=null):
 if host.paused or not profile.explosions_enabled: return null
 var blast=load("res://scripts/core/explosion_3d.gd").new()
 blast.stage=host
 blast.tuning=profile.snapshot()
 blast.source=origin
 blast.instigator=attacker
 host.add_child(blast)
 blast.global_position=point
 blast.detonate()
 return blast
func strength_at(distance: float):
 var inner=minf(tuning.explosion_full_damage_radius,tuning.explosion_radius)
 if distance>=tuning.explosion_radius: return 0.0
 if distance<=inner: return 1.0
 return pow(clampf((tuning.explosion_radius-distance)/maxf(.001,tuning.explosion_radius-inner),0,1),tuning.explosion_falloff)
func surface_point(body: PhysicsBody3D):
 var nearest=body.global_position
 var distance=INF
 for child in body.get_children():
  if not child is CollisionShape3D or child.disabled: continue
  var local=child.to_local(global_position)
  var point=local
  if child.shape is CapsuleShape3D:
   var axis=Vector3(0,clampf(local.y,-child.shape.height*.5+child.shape.radius,child.shape.height*.5-child.shape.radius),0)
   point=axis+(local-axis).limit_length(child.shape.radius)
  elif child.shape is SphereShape3D: point=local.limit_length(child.shape.radius)
  elif child.shape is BoxShape3D: point=local.clamp(-child.shape.size*.5,child.shape.size*.5)
  else: continue
  point=child.to_global(point)
  if point.distance_squared_to(global_position)<distance:
   nearest=point
   distance=point.distance_squared_to(global_position)
 return nearest
func detonate():
 add_to_group("core_explosions_3d")
 var sphere=SphereShape3D.new()
 sphere.radius=maxf(tuning.explosion_radius,tuning.explosion_shockwave_radius if tuning.explosion_shockwave_enabled else 0)/U
 var query=PhysicsShapeQueryParameters3D.new()
 query.shape=sphere
 query.transform=Transform3D(Basis.IDENTITY,global_position)
 query.collision_mask=2|4|8|16
 if is_instance_valid(source): query.exclude=[source.get_rid()]
 var seen={}
 var contacts=[]
 for hit in get_world_3d().direct_space_state.intersect_shape(query,2048):
  var physical=hit.collider
  var body=physical
  if physical is PhysicalBone3D:
   var parent=physical.get_parent()
   while parent and not parent is CharacterBody3D: parent=parent.get_parent()
   if parent: body=parent
  if not body is PhysicsBody3D or body==source or seen.has(body.get_instance_id()): continue
  seen[body.get_instance_id()]=true
  var point=surface_point(physical)
  var distance=point.distance_to(global_position)*U
  var main=strength_at(distance)
  var wave=clampf(1-distance/maxf(1,tuning.explosion_shockwave_radius),0,1) if tuning.explosion_shockwave_enabled else 0.0
  var outer=distance>=tuning.explosion_radius
  var character=body is CharacterBody3D and "health" in body
  if outer and (not character or wave<=0): continue
  var excluded: Array[RID]=[physical.get_rid(),body.get_rid()]
  if is_instance_valid(source): excluded.append(source.get_rid())
  var ray=PhysicsRayQueryParameters3D.create(global_position,point,1|8,excluded)
  ray.hit_from_inside=true
  if tuning.explosion_occlusion_enabled and not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
  contacts.append({"body":body,"point":point,"distance":distance,"main":main,"wave":wave,"outer":outer,"character":character})
 for contact in contacts:
  var body=contact.body
  var weight=maxf(contact.main,contact.wave) if contact.character else contact.main
  var direction=(body.global_position+Vector3.UP*(.8 if contact.character else 0)-global_position).normalized()
  if direction==Vector3.ZERO: direction=Vector3.UP
  var damage=tuning.explosion_damage*contact.main
  affected[body.get_instance_id()]=weight
  if contact.character:
   damage=maxf(damage,minf(tuning.explosion_shockwave_damage*contact.wave,maxf(0,body.health-1)))
   if contact.outer: damage=minf(damage,maxf(0,body.health-1))
   var player=body==stage.player
   if player and body.dash_left>0: continue
   var push=maxf(tuning.explosion_character_push*contact.main,tuning.explosion_shockwave_push*contact.wave)/U
   var speed=direction*push
   var before=body.health
   if player:
    if tuning.explosion_player_damage_enabled: body.take_damage(damage)
   else: body.take_projectile_hit(damage,contact.point,direction)
   var rag=tuning.explosion_ragdoll_enabled and ((player and not contact.outer) or contact.distance>=tuning.explosion_ragdoll_min_distance)
   if body.get("test_frozen")==true: rag=false
   if rag:
    speed+=Vector3.UP*(tuning.explosion_ragdoll_lift*weight/U)
    preload("res://scripts/core/blast_knockdown_3d.gd").start(body,speed,tuning.explosion_ragdoll_duration)
   else:
    body.velocity+=speed
    if "stun_left" in body: body.stun_left=maxf(body.stun_left,tuning.explosion_stun_duration*weight)
   if not player and before>body.health and is_instance_valid(instigator) and instigator==stage.player:
    stage.combat.gun.impact_resolved.emit({"position":contact.point,"collider":body,"normal":-direction},direction,damage,true,body.health<=0)
  elif body is RigidBody3D:
   body.apply_central_impulse(direction*minf(tuning.explosion_impulse*weight/U,body.mass*tuning.explosion_prop_speed_limit/U))
 if tuning.explosion_audio_enabled:
  var audio=AudioStreamPlayer3D.new()
  audio.stream=CoreCombatAudio.make_stream("explosion")
  audio.volume_db=tuning.explosion_volume
  add_child(audio)
  audio.play()
 if tuning.explosion_camera_enabled:
  var weight=clampf(1-stage.player.global_position.distance_to(global_position)/maxf(.01,tuning.explosion_shockwave_radius/U),0,1)
  stage.camera_shake=maxf(stage.camera_shake,tuning.explosion_camera_strength*weight/U)
 if tuning.explosion_visuals_enabled:
  visual=preload("res://scripts/core/grenade_blast_visual.gd").new()
  var rng=RandomNumberGenerator.new()
  rng.randomize()
  var contacts_visual=[]
  var ground=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position,global_position+Vector3.DOWN*.48,1|8))
  if not ground.is_empty(): contacts_visual.append({"point":Vector2(global_position.x,-ground.position.y)*U,"normal":Vector2(ground.normal.x,-ground.normal.y),"kind":3})
  visual.configure(Vector2(global_position.x,-global_position.y)*U,contacts_visual,stage.player.tuning,rng)
  var layer=CanvasLayer.new()
  layer.layer=3
  add_child(layer)
  if stage.player.tuning.grenade_sprites_enabled:
   canvas=BlastCanvas.new()
   canvas.blast=self
  else:
   canvas=CoreExplosion.new()
   canvas.tuning=tuning
  layer.add_child(canvas)
  canvas.set_process(false)
func _process(dt):
 if stage.paused:
  for child in get_children():
   if child is AudioStreamPlayer3D: child.stream_paused=true
  return
 for child in get_children():
  if child is AudioStreamPlayer3D: child.stream_paused=false
 elapsed+=dt
 if canvas:
  canvas.position=stage.camera.unproject_position(global_position)
  var unit=stage.camera.unproject_position(global_position+stage.camera.global_basis.x)-canvas.position
  canvas.scale=Vector2.ONE*unit.length()/U
  if canvas is CoreExplosion: canvas.elapsed=elapsed
  canvas.queue_redraw()
 if elapsed>maxf(1.05,visual.end_time() if visual else 0): queue_free()
class BlastCanvas extends Node2D:
 var blast: Node3D
 func _draw():
  blast.visual.draw_on(self,blast.elapsed)
