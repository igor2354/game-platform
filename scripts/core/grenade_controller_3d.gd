extends Node3D
const U=100.97598
var stage: Node3D
var player: CharacterBody3D
var tuning: CoreRagdollSettings
var held_grenade: RigidBody3D
var charging=false
var charge=0.0
var throw_progress=0.0
var count=5
var throws=0
var trigger_held=false
var needs_release=false
var trajectory=PackedVector3Array()
var trajectory_hit=false
var last_launch={}
var preview: Node2D
var preview_clock=0.0
func _ready():
 player=stage.player
 tuning=stage.ragdoll_settings
 refill()
 var layer=CanvasLayer.new()
 layer.layer=4
 add_child(layer)
 preview=Preview.new()
 preview.controller=self
 layer.add_child(preview)
func preparing(): return is_instance_valid(held_grenade) and not held_grenade.detonated
func busy(): return preparing() or throw_progress>0
func refill(): count=roundi(tuning.grenade_starting_count)
func reset_state():
 for grenade in get_tree().get_nodes_in_group("core_grenades_3d"):
  if grenade.controller==self: grenade.queue_free()
 for blast in get_tree().get_nodes_in_group("core_explosions_3d"):
  if blast.stage==stage: blast.queue_free()
 held_grenade=null
 charge=0
 charging=false
 throw_progress=0
 throws=0
 last_launch.clear()
 trajectory.clear()
 needs_release=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
 trigger_held=needs_release
 refill()
func blocked():
 return stage.paused or (is_instance_valid(stage.developer) and (stage.developer.developer_mode.enabled or stage.developer.blocks_mouse())) or (is_instance_valid(stage.game_hud) and stage.game_hud.editing)
func prepare():
 if blocked() or not tuning.grenades_enabled or busy() or count<=0 or player.health<=0 or player.climbing or player.parkour.active or player.dash_left>0 or player.slide_left>0 or player.model.death_ragdoll.active: return false
 var gun=stage.combat.gun
 gun.cancel_reload()
 gun.aiming=false
 gun.firing=false
 gun.queued_single_press=false
 for key in ["recoil_kick_offset","recoil_drift_offset","recoil_retarget_motion"]: gun.recoil.set(key,Vector2.ZERO)
 for key in ["recoil_back","recoil_angle","recoil_climb","recoil_horizontal"]: gun.recoil.set(key,0.0)
 var grenade=preload("res://scripts/core/grenade_3d.gd").new()
 grenade.tuning=tuning
 grenade.controller=self
 grenade.instigator=player
 stage.add_child(grenade)
 held_grenade=grenade
 grenade.global_position=launch_origin()
 count-=1
 charge=0
 charging=false
 trigger_held=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
 needs_release=trigger_held
 refresh_trajectory()
 return true
func holster():
 if not preparing() or held_grenade.fuse_started or blocked(): return false
 held_grenade.queue_free()
 held_grenade=null
 count+=1
 charge=0
 charging=false
 trajectory.clear()
 stage.combat.gun.trigger_needs_release=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
 stage.combat.gun.queued_single_press=false
 return true
func input_trigger(pressed: bool):
 if not preparing() or not tuning.grenades_enabled: return
 if pressed:
  if not needs_release:
   held_grenade.start_fuse()
   charging=true
   charge=0
 elif charging:
  charging=false
  throw_held()
 if not pressed: needs_release=false
 trigger_held=pressed
func cancel_charge():
 charging=false
 charge=0
 needs_release=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
 trigger_held=needs_release
func power(): return clampf(charge/maxf(.01,tuning.grenade_charge_time),0,1)
func launch_velocity():
 var direction=stage.combat.aim_direction.normalized()
 direction=direction.rotated(Vector3.BACK,signf(direction.x)*deg_to_rad(tuning.grenade_lob_angle)*absf(direction.x))
 return direction*lerpf(minf(tuning.grenade_min_speed,tuning.grenade_max_speed),maxf(tuning.grenade_min_speed,tuning.grenade_max_speed),power())/U
func hand_point():
 return player.global_position+Vector3(stage.combat.aim_facing*(.28-.10*power()),player.capsule.height*.74+.07*power(),0)
func launch_origin():
 var origin=hand_point()
 var chest=player.global_position+Vector3.UP*player.capsule.height*.6
 var query=PhysicsShapeQueryParameters3D.new()
 var shape=SphereShape3D.new()
 shape.radius=tuning.grenade_radius/U
 query.shape=shape
 query.transform=Transform3D(Basis.IDENTITY,chest)
 query.motion=origin-chest
 query.collision_mask=1|8
 query.exclude=[player.get_rid()]
 var fractions=get_world_3d().direct_space_state.cast_motion(query)
 return chest+query.motion*maxf(0,fractions[0]-.02) if fractions[0]<1 else origin
func throw_held(drop=false):
 if not preparing() or stage.paused: return false
 var grenade=held_grenade
 var point=launch_origin()
 var speed=player.velocity if drop else launch_velocity()
 last_launch={"point":point,"velocity":speed,"fuse":grenade.fuse_left,"gravity":tuning.grenade_gravity/U}
 grenade.launch(point,speed)
 held_grenade=null
 charge=0
 charging=false
 throws+=1
 throw_progress=0 if drop else .32
 trajectory.clear()
 stage.combat.gun.trigger_needs_release=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
 stage.combat.gun.queued_single_press=false
 return true
func on_grenade_finished(grenade):
 if grenade==held_grenade:
  held_grenade=null
  charging=false
  charge=0
  trajectory.clear()
  stage.combat.gun.trigger_needs_release=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
  stage.combat.gun.queued_single_press=false
func predict_path(point: Vector3,speed: Vector3,seconds: float):
 var points=PackedVector3Array([point])
 trajectory_hit=false
 var step=1.0/Engine.physics_ticks_per_second
 var query=PhysicsShapeQueryParameters3D.new()
 var shape=SphereShape3D.new()
 shape.radius=tuning.grenade_radius/U
 query.shape=shape
 query.collision_mask=1|2|4|8|16
 query.exclude=[player.get_rid()]
 if preparing(): query.exclude.append(held_grenade.get_rid())
 for index in mini(900,ceili(seconds/step)):
  query.transform=Transform3D(Basis.IDENTITY,point)
  query.motion=speed*step
  var fractions=get_world_3d().direct_space_state.cast_motion(query)
  point+=query.motion*fractions[0]
  points.append(point)
  speed+=Vector3.DOWN*(tuning.grenade_gravity/U)*step
  if fractions[0]<1:
   trajectory_hit=true
   break
 return points
func refresh_trajectory():
 trajectory.clear()
 if preparing() and tuning.grenade_trajectory_enabled: trajectory=predict_path(launch_origin(),launch_velocity(),maxf(0,held_grenade.fuse_left))
func _input(event):
 if stage.paused and event is InputEventMouseButton and preparing():
  cancel_charge()
  return
 if event is InputEventKey and event.physical_keycode==KEY_T and event.pressed and not event.echo and not blocked():
  if preparing(): holster()
  else: prepare()
  get_viewport().set_input_as_handled()
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and preparing() and not blocked():
  input_trigger(event.pressed)
  get_viewport().set_input_as_handled()
func _physics_process(dt):
 if stage.paused: return
 throw_progress=maxf(0,throw_progress-dt)
 if not preparing(): return
 if player.health<=0 or player.model.death_ragdoll.active:
  throw_held(true)
  return
 if blocked() or not tuning.grenades_enabled: cancel_charge()
 else:
  var pressed=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
  if pressed!=trigger_held: input_trigger(pressed)
  if charging: charge=minf(charge+dt,tuning.grenade_charge_time)
 if preparing(): held_grenade.global_position=launch_origin()
func _process(dt):
 if not stage.paused and preparing() and blocked(): cancel_charge()
 preview_clock+=dt
 if not stage.paused and preview_clock>=1.0/30:
  preview_clock=0
  refresh_trajectory()
 preview.queue_redraw()
class Preview extends Node2D:
 var controller: Node3D
 func _draw():
  var c=controller
  if not c.preparing(): return
  var color=Color("f0c96a")
  if c.held_grenade.fuse_started and c.held_grenade.fuse_left<=1: color=Color("ff7d62")
  var at=c.stage.camera.unproject_position(c.launch_origin())
  var label="ЛКМ — бросок"
  if c.held_grenade.fuse_started: label="%.1f с · %d%%" % [maxf(0,c.held_grenade.fuse_left),roundi(c.power()*100)]
  draw_string(ThemeDB.fallback_font,at+Vector2(-28,-27),label,HORIZONTAL_ALIGNMENT_LEFT,-1,16,color)
  for i in range(1,c.trajectory.size()):
   if i%5<3: draw_line(c.stage.camera.unproject_position(c.trajectory[i-1]),c.stage.camera.unproject_position(c.trajectory[i]),color,1.6,true)
  if c.trajectory.size()>1:
   var end=c.stage.camera.unproject_position(c.trajectory[-1])
   draw_arc(end,7,0,TAU,24,color,1.5,true)
   if not c.trajectory_hit: draw_circle(end,3,Color("ff7d62"))
