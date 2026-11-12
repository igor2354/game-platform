extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
 for i in n: await physics_frame
func check(value: bool,label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  print("FAIL ",label)
func run() -> void:
 var scene = load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings = false
 root.add_child(scene)
 scene.combat.set_process(false)
 scene.combat.set_physics_process(false)
 scene.combat.zombie_settings.movement_enabled = false
 scene.combat.zombie_settings.combat_enabled = false
 var gun = scene.combat.gun
 gun.input_driven = false
 var fx = scene.combat.effects
 var target = scene.combat.targets[0]
 await frames(8)
 for id in ["stg44","mp40","svt","m1911"]:
  fx.clear()
  target.reset()
  scene.combat.equip(id)
  gun.tuning.hip_spread = 0
  gun.tuning.hip_max_spread = 0
  gun.tuning.movement_spread_enabled = false
  gun.tuning.recoil_enabled = false
  gun.tuning.bullet_speed = 300
  scene.combat.aim_direction = Vector3.RIGHT
  var origin: Vector3 = target.global_position+Vector3(-1,1.1,0)
  scene.combat.pivot.position = origin-scene.combat.muzzle
  check(gun.fire(origin,Vector3.RIGHT),id+" shot")
  check(fx.flash.active,id+" approved flash")
  check(fx.tracers.size()==1,id+" flight tracer")
  check(fx.casings.size()==1,id+" casing")
  var casing = fx.casings[0]
  var size: Vector2 = preload("res://scripts/campaign/catalog.gd").casing_mm(id)*.001
  check(casing.size.is_equal_approx(size) and casing.collision_layer==0,id+" exact calibre / nonblocking")
  check(fx.smoke.portions.size()==1,id+" shot smoke")
  scene.combat.aim_direction = Vector3.UP
  await frames(5)
  check(fx.tracers.size()==1 and fx.tracers[0].helper.stage()==1,id+" sustained flight stage")
  await frames(10)
  check(fx.last_impact.get("direction",Vector3.ZERO).dot(Vector3.RIGHT)>.999,id+" impact ignores later aim")
  check(fx.last_impact.get("normal",Vector3.ZERO).dot(Vector3.LEFT)>.8,id+" normal from collider")
  check(target.health<100,id+" ballistic damage preserved")
  check(fx.bursts.size()>0,id+" original droplet polygons")
  check(fx.tracers.size()==1 and fx.tracers[0].helper.stage()==2,id+" stationary terminal stage")
  if not fx.tracers.is_empty():
   var point: Vector3 = fx.tracers[0].bullet.position
   check(point.distance_to(fx.last_impact.point)<.001,id+" decay at actual hit")
  await frames(10)
  check(fx.tracers.is_empty(),id+" decay expired")
  check(fx.trails.is_empty(),id+" casing smoke expired")
 # Geometry/material routing on all six old material identifiers.
 var surface := StaticBody3D.new()
 scene.add_child(surface)
 for kind in 6:
  surface.set_meta("terra_material",kind)
  fx.impact({"collider":surface,"position":Vector3(0,1,0),"normal":Vector3.RIGHT},Vector3.LEFT,1,false,false)
  check(fx.chips.back().data.kind==kind,"surface material "+str(kind))
  check(fx.chips.back().velocity.x>0,"outward normal "+str(kind))
 # A stale collision with a corpse is neither another live hit nor another kill.
 var reticle = scene.combat.reticle
 reticle.clear()
 fx.clear()
 fx.impact({"collider":target,"position":target.position,"normal":Vector3.LEFT},Vector3.RIGHT,10,false,false)
 reticle.on_impact({},Vector3.RIGHT,10,false,true)
 check(fx.bursts.is_empty() and reticle.kill_marker_left==0,"corpse does not produce blood / kill marker")
 reticle.on_impact({},Vector3.RIGHT,0,true,true)
 check(reticle.kill_marker_left==.32,"live kill marker timer")
 scene.combat.aim_direction = Vector3.RIGHT
 scene.combat.pivot.position = Vector3(-4,1,0)-scene.combat.muzzle
 fx.shot(Vector3(-4,1,0),Vector3.RIGHT)
 scene.combat.weapon_parts.drop(scene)
 await frames(4)
 scene.paused = true
 await frames(3)
 var casing = fx.casings[0]
 var held: Vector3 = casing.global_position
 var age: float = fx.smoke.portions[0].age
 await frames(8)
 check(held.distance_to(casing.global_position)<.0001,"pause physical casing")
 check(fx.smoke.portions[0].age==age,"pause smoke clock")
 scene.paused = false
 await frames(3)
 # Heat threshold and residual emission after the configured magazine load.
 fx.clear()
 scene.player.tuning.muzzle_residual_magazines = .5
 scene.combat.pivot.visible = true
 for i in gun.tuning.magazine_capacity: fx.smoke.shot(Vector3(-4,1,0),Vector3.RIGHT)
 check(fx.smoke.sustained[gun.weapon_id].smoking,"residual magazine threshold")
 fx.smoke.tick(.2)
 check(fx.smoke.portions.any(func(portion): return portion.residual),"heated barrel residual portion")
 scene.combat.cursor_active = true
 scene.combat.pivot.visible = true
 scene.combat.pivot.position = Vector3(-4,1,0)
 gun.tuning.aim_beam_enabled = true
 gun.tuning.hip_spread = 8
 gun.tuning.hip_max_spread = 8
 reticle._physics_process(1.0/60)
 check(reticle.beam_points.size()==97,"real spread beam samples")
 check(is_equal_approx(reticle.half_angle,deg_to_rad(gun.spread_degrees())),"beam ballistic half angle")
 var reset := InputEventKey.new()
 reset.pressed = true
 reset.physical_keycode = KEY_F8
 scene.combat._unhandled_key_input(reset)
 await frames(2)
 check(fx.casings.is_empty() and fx.trails.is_empty() and fx.chips.is_empty() and fx.bursts.is_empty() and fx.tracers.is_empty(),"F8 all effects")
 check(gun.projectiles.is_empty() and reticle.kill_marker_left==0 and fx.smoke.heat.is_empty(),"F8 bullets/markers/heat")
 print("SHOOTING_3D_EFFECTS checks=",checks," failures=",failures)
 scene.queue_free()
 await process_frame
 quit(int(failures>0))
