extends SceneTree
var physics_ms: Array[float] = []
var render_cpu_ms: Array[float] = []
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var scene = load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings = false
 root.add_child(scene)
 scene.combat.set_process(false)
 scene.combat.set_physics_process(false)
 scene.combat.zombie_settings.movement_enabled = false
 scene.combat.zombie_settings.combat_enabled = false
 scene.player.position = Vector3(-5,0,0)
 scene.set_process(false)
 scene.camera.position = Vector3(-3.5,1.2,9)
 scene.camera.look_at(Vector3(-3.5,1.2,0))
 scene.camera.size = 3
 var gun = scene.combat.gun
 gun.input_driven = false
 gun.tuning.magazine_enabled = false
 gun.tuning.sound_enabled = false
 gun.tuning.recoil_enabled = false
 gun.tuning.damage_enabled = false
 gun.tuning.hip_spread = 0
 gun.tuning.hip_max_spread = 0
 gun.tuning.rounds_per_minute = 600
 var target = scene.combat.targets[0]
 target.position = Vector3(-1.8,0,0)
 scene.combat.pivot.position = Vector3(-4.1,1.16,0)-scene.combat.muzzle
 for i in 120: await process_frame
 var baseline_physics: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
 var baseline_render: float = Performance.get_monitor(Performance.TIME_PROCESS)*1000
 var shots := 0
 for i in 360:
  await physics_frame
  if i%6==0:
   gun.cooldown = 0
   if gun.fire(Vector3(-4.1,1.16,0),Vector3.RIGHT): shots += 1
  await process_frame
  physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
  render_cpu_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
 var physics_total := 0.0
 var render_total := 0.0
 for value in physics_ms: physics_total += value
 for value in render_cpu_ms: render_total += value
 physics_ms.sort()
 render_cpu_ms.sort()
 var fx = scene.combat.effects
 var sleeping := 0
 for body in fx.casings:
  if is_instance_valid(body) and body.sleeping: sleeping += 1
 print("FX_BENCH shots=",shots," cases=",fx.casings.size()," sleeping=",sleeping," baseline_physics_ms=",baseline_physics," baseline_process_ms=",baseline_render," physics_mean_ms=",physics_total/physics_ms.size()," physics_p95_ms=",physics_ms[int(physics_ms.size()*.95)]," process_mean_ms=",render_total/render_cpu_ms.size()," process_p95_ms=",render_cpu_ms[int(render_cpu_ms.size()*.95)])
 scene.queue_free()
 await process_frame
 quit()
