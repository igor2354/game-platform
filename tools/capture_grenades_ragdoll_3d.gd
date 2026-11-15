extends SceneTree
const MEDIA=preload("res://tools/media_paths.gd")
func _initialize(): run.call_deferred()
func frames(n):
 for i in n: await physics_frame
func capture(name):
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(MEDIA.path("docs/core/grenades_ragdoll_2026-11-14/"+name+".png"))
func run():
 var stage=load("res://scenes/core/polygon_3d.tscn").instantiate()
 stage.load_user_settings=false
 root.add_child(stage)
 await frames(8)
 for enemy in stage.combat.enemies: enemy.set_test_frozen(true)
 stage.camera_settings.camera_enabled=false
 stage.camera.position=Vector3(3,1.4,5)
 stage.camera.look_at(Vector3(3,1.0,0))
 stage.camera.size=4
 stage.player.position=Vector3(3,.02,0)
 stage.combat.aim_direction=Vector3(1,.2,0).normalized()
 stage.player.grenades.prepare()
 await frames(18)
 await capture("grenade_ready")
 stage.player.grenades.holster()
 var profile=stage.ragdoll_settings.snapshot()
 profile.explosion_damage=0
 profile.explosion_shockwave_damage=0
 profile.explosion_ragdoll_enabled=false
 preload("res://scripts/core/explosion_3d.gd").spawn(stage,Vector3(4.0,.3,0),profile)
 await frames(8)
 await capture("grenade_blast")
 stage.player.take_damage(1000)
 await frames(150)
 await capture("player_ragdoll")
 var r=stage.player.model.death_ragdoll
 print("RAGDOLL_POSITIONS")
 for b in r.bodies: print(b.bone_name," ",b.global_position)
 stage.queue_free()
 await process_frame
 quit()
