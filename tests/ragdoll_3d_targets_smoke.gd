extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
 for i in n: await physics_frame
func shot(scene: Node,suffix: String) -> void:
 if not "--capture" in OS.get_cmdline_user_args(): return
 await RenderingServer.frame_post_draw
 var path := preload("res://tools/media_paths.gd").path("docs/core/ragdoll_3d_2026-11-12/"+suffix+".png")
 root.get_texture().get_image().save_png(path)
 print("CAPTURE ",path)
func run() -> void:
 var scene = load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings = false
 var temp := OS.get_environment("TEMP").replace("\\","/")+"/ubershrike_ragdoll_3d_test"
 DirAccess.make_dir_recursive_absolute(temp)
 for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]: scene.set(key,temp+"/"+key+".cfg")
 root.add_child(scene)
 scene.combat.zombie_settings.movement_enabled = false
 scene.combat.zombie_settings.combat_enabled = false
 await frames(12)
 scene.ragdoll_settings.muscle_stiffness = 2300
 scene.ragdoll_settings.muscle_damping = 8
 scene.ragdoll_overlay.save_profile()
 var restored := CoreRagdollSettings.new()
 restored.load_saved(scene.ragdoll_settings_path)
 if restored.muscle_stiffness!=2300 or restored.muscle_damping!=8: failures += 1
 scene.ragdoll_overlay.reset_profile()
 if scene.ragdoll_settings.muscle_stiffness!=1000: failures += 1
 scene.set_process(false)
 for layer in scene.find_children("*","CanvasLayer",true,false): layer.hide()
 scene.combat.pivot.hide()
 scene.camera.position = Vector3(26.5,2,12)
 scene.camera.look_at(Vector3(26.5,1,0))
 scene.camera.size = 5.0
 await frames(8)
 await shot(scene,"standing")
 var original_player: Vector3 = scene.player.position
 var sample_target = scene.combat.targets[0]
 var sample_rag = sample_target.get_node("ZombieVisual").ragdoll
 var previous_spin := Vector3.ZERO
 for side in [-1.0,1.0]:
  scene.player.position.x = sample_target.position.x+side*10
  sample_rag.rng.seed = 111
  sample_rag.start(Vector3.ZERO,Vector3.RIGHT,sample_target.position+Vector3.UP)
  var spin: Vector3 = sample_rag.bodies[0].angular_velocity
  if side>0 and spin!=previous_spin: failures += 1
  if sample_rag.pending_impulse!=Vector3.RIGHT: failures += 1
  previous_spin = spin
  sample_rag.stop()
 var positive := Vector3.ZERO
 var negative := Vector3.ZERO
 for seed_value in 48:
  sample_rag.rng.seed = seed_value+1
  sample_rag.start()
  var spin: Vector3 = sample_rag.bodies[0].angular_velocity
  for axis in 3:
   if spin[axis]>0: positive[axis] += 1
   else: negative[axis] += 1
  sample_rag.stop()
 for axis in 3:
  if positive[axis]<8 or negative[axis]<8: failures += 1
 scene.player.position = original_player
 await frames(3)
 for target in scene.combat.targets:
  if target.body_visual.visible or not target.has_node("ZombieVisual"): failures += 1
  if target.get_node("ZombieVisual").ragdoll.bodies.size()!=14: failures += 1
 # Opposite impacts at the same height, independent of where the player stands.
 for i in scene.combat.targets.size():
  var target = scene.combat.targets[i]
  target.take_projectile_hit(200,target.global_position+Vector3.UP*1.4,Vector3.RIGHT if i%2==0 else Vector3.LEFT)
 await frames(1)
 await frames(19)
 await shot(scene,"falling")
 var rag = scene.combat.targets[0].get_node("ZombieVisual").ragdoll
 scene.ragdoll_settings.simulation_enabled = false
 await frames(3)
 var held: Vector3 = rag.bodies[0].global_position
 await frames(12)
 if held.distance_to(rag.bodies[0].global_position)>.001: failures += 1
 scene.ragdoll_settings.simulation_enabled = true
 await frames(100)
 await shot(scene,"fallen")
 for target in scene.combat.targets:
  for body in target.get_node("ZombieVisual").ragdoll.bodies:
   if not body.global_transform.is_finite():
    failures += 1
    print("NONFINITE ",body.bone_name)
   elif body.global_position.y<-.25 and absf(body.global_position.z)<1.0:
    failures += 1
    print("FLOOR PENETRATION ",body.bone_name," ",body.global_position)
  target.reset()
 await frames(5)
 for target in scene.combat.targets:
  if target.health!=100 or target.get_node("ZombieVisual").ragdoll.active: failures += 1
 print("RAGDOLL_3D_TARGETS failures=",failures," targets=",scene.combat.targets.size()," profile/freeze/reset checked")
 scene.queue_free()
 await process_frame
 quit(int(failures>0))
