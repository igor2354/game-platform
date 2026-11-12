extends SceneTree
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
 for i in n: await physics_frame
func run() -> void:
 var scene = load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings = false
 root.add_child(scene)
 scene.set_process(false)
 scene.combat.set_process(false)
 var player = scene.player
 var enemy = scene.combat.enemies[0]
 enemy.set_physics_process(false)
 enemy.position = Vector3(2,0,0)
 player.reset()
 player.position = Vector3(0,.01,0)
 await frames(8)
 var failures := 0
 Input.action_press("core_right")
 await frames(55)
 Input.action_release("core_right")
 if player.position.x>1.32: failures += 1
 Input.action_press("core_dash")
 Input.action_press("core_right")
 await frames(12)
 Input.action_release("core_dash")
 Input.action_release("core_right")
 if player.position.x<2 or enemy.stun_left<=0 or enemy.health!=100: failures += 1
 await frames(25)
 if enemy in player.get_collision_exceptions(): failures += 1
 player.contacts.slide_hits.clear()
 enemy.reset()
 player.contacts.slide_impact(enemy,player.value("slide_knockdown_min_speed")+.1)
 if enemy.health!=100-player.tuning.slide_damage or not enemy.is_prone() or not enemy in player.get_collision_exceptions(): failures += 1
 player.contacts.slide_impact(enemy,player.value("slide_knockdown_min_speed")+.1)
 if enemy.health!=100-player.tuning.slide_damage: failures += 1
 player.contacts.slide_hits.clear()
 enemy.reset()
 player.contacts.slide_impact(enemy,0)
 if enemy.health!=100 or enemy.is_prone(): failures += 1
 enemy.tuning.stun_enabled = false
 enemy.stun_left = 0
 if enemy.apply_dash_stun() or enemy.stun_left>0: failures += 1
 enemy.tuning.stun_enabled = true
 enemy.apply_dash_stun()
 enemy.tick_disability(enemy.tuning.dash_stun_duration+.01)
 if enemy.stun_left>0: failures += 1
 enemy.reset()
 enemy.position = Vector3(2,0,0)
 player.reset()
 player.position = Vector3(0,.01,0)
 await frames(8)
 player.ground_speed = 12
 player.velocity.x = 12
 Input.action_press("core_right")
 Input.action_press("core_sprint")
 Input.action_press("core_crouch")
 await frames(35)
 Input.action_release("core_right")
 Input.action_release("core_sprint")
 Input.action_release("core_crouch")
 print("SLIDE SWEEP hp=",enemy.health," prone=",enemy.is_prone()," x=",player.position.x)
 if enemy.health!=100-player.tuning.slide_damage or not enemy.is_prone() or player.position.x<2.5: failures += 1
 player.contacts.slide_hits.clear()
 enemy.reset()
 var chance: float = player.tuning.slide_knockdown_chance
 player.tuning.slide_knockdown_chance = 0
 player.contacts.slide_impact(enemy,100)
 if enemy.is_prone(): failures += 1
 player.tuning.slide_knockdown_chance = chance
 player.contacts.slide_hits.clear()
 enemy.health = 5
 player.contacts.slide_impact(enemy,100)
 if enemy.health>0 or enemy not in player.get_collision_exceptions(): failures += 1
 player.reset()
 if not player.contacts.exceptions.is_empty() or player.collision_mask!=13: failures += 1
 player.position = Vector3(4.5,.01,0)
 await frames(8)
 Input.action_press("core_right")
 Input.action_press("core_dash")
 await frames(12)
 Input.action_release("core_right")
 Input.action_release("core_dash")
 if player.position.x>5.2 or player.dash_left>0: failures += 1
 player.set_physics_process(false)
 enemy.reset()
 enemy.position = Vector3(1,0,0)
 player.position = Vector3(1,0,0)
 await frames(2)
 player.contacts.dash_begin()
 player.contacts.dash_end()
 if enemy not in player.get_collision_exceptions(): failures += 1
 player.position.x = 3
 player.contacts.refresh()
 if enemy in player.get_collision_exceptions(): failures += 1
 print("DASH_SLIDE_3D failures=",failures)
 scene.queue_free()
 await process_frame
 quit(int(failures>0))
