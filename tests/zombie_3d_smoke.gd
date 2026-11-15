extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var scene = load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings = false
 root.add_child(scene)
 scene.player.set_physics_process(false)
 scene.set_process(false)
 scene.combat.set_process(false)
 var enemy = scene.combat.enemies[0]
 var failures := 0
 scene.player.position = enemy.position+Vector3(-.9,0,0)
 enemy.facing = -1
 for i in 5: await physics_frame
 print("VISION ",enemy.sees_player()," enemy=",enemy.position," player=",scene.player.position," face=",enemy.facing)
 if not enemy.sees_player(): failures += 1
 for i in 80: await physics_frame
 print("ATTACK hp=",scene.player.health," state=",enemy.state," windup=",enemy.attack_left)
 if scene.player.health>=100: failures += 1
 enemy.take_projectile_hit(200,enemy.position,Vector3.RIGHT)
 if enemy.health>0 or enemy.collision_layer!=0: failures += 1
 enemy.reset()
 if enemy.health!=100 or enemy.memory!=0: failures += 1
 enemy.hear(enemy.position,1)
 if enemy.memory<=0: failures += 1
 print("ENEMY_3D_IN_GAME failures=",failures)
 scene.queue_free()
 await process_frame
 quit(int(failures>0))
