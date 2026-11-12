extends SceneTree
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
 for i in n: await physics_frame
func run() -> void:
 var scene = load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings = false
 root.add_child(scene)
 await frames(8)
 var failures := 0
 scene.player.take_damage(1000)
 var player_rig = scene.player.model.death_ragdoll
 var enemy = scene.combat.enemies[0]
 enemy.take_projectile_hit(1000,enemy.position,Vector3.RIGHT)
 var dummy = scene.combat.targets[0]
 dummy.take_projectile_hit(1000,dummy.position,Vector3.RIGHT)
 await frames(4)
 var enemy_rig = enemy.get_node("ZombieVisual").ragdoll
 var start: Vector3 = player_rig.bodies[0].global_position
 if not player_rig.active or not enemy_rig.active or not dummy.get_node("ZombieVisual").ragdoll.active: failures += 1
 scene.paused = true
 await frames(3)
 var held: Vector3 = player_rig.bodies[0].global_position
 await frames(12)
 if held.distance_to(player_rig.bodies[0].global_position)>.001: failures += 1
 scene.paused = false
 await frames(180)
 if player_rig.bodies[0].global_position.distance_to(start)<.05: failures += 1
 for ragdoll in [player_rig,enemy_rig]:
  for body in ragdoll.bodies:
   if not body.global_transform.is_finite() or body.global_position.y < -1: failures += 1
 scene.player.reset()
 enemy.reset()
 dummy.reset()
 await frames(5)
 if player_rig.active or enemy_rig.active or scene.player.health<=0 or enemy.health<=0: failures += 1
 scene.player.take_damage(1000)
 enemy.take_projectile_hit(1000,enemy.position,Vector3.LEFT)
 await frames(12)
 if not player_rig.active or not enemy_rig.active: failures += 1
 scene.player.reset()
 enemy.reset()
 await frames(4)
 print("DEATH_RAGDOLL_3D failures=",failures," player_bodies=",player_rig.bodies.size()," enemy_bodies=",enemy_rig.bodies.size())
 scene.queue_free()
 await process_frame
 quit(int(failures>0))
