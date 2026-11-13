extends SceneTree
var failures=0
var checks=0
func _initialize(): run.call_deferred()
func check(ok,label):
 checks+=1
 if ok: print("PASS ",label)
 else: failures+=1; push_error("FAIL "+label)
func frames(n):
 for i in n: await physics_frame
func click(pressed):
 var e=InputEventMouseButton.new()
 e.button_index=MOUSE_BUTTON_LEFT
 e.pressed=pressed
 e.position=Vector2(700,400)
 Input.parse_input_event(e)
func run():
 var stage=load("res://scenes/core/polygon_3d.tscn").instantiate()
 stage.load_user_settings=false
 root.add_child(stage)
 await frames(8)
 var player=stage.player
 var c=player.grenades
 var tuning=stage.ragdoll_settings
 tuning.explosion_audio_enabled=false
 stage.combat.gun.tuning.sound_enabled=false
 for enemy in stage.combat.enemies: enemy.set_test_frozen(true)
 check(c.count==5,"same starting inventory")
 check(c.prepare(),"prepare grenade")
 var grenade=c.held_grenade
 check(not grenade.fuse_started and c.count==4,"T reserves grenade without lighting fuse")
 await frames(65)
 check(is_equal_approx(grenade.fuse_left,tuning.grenade_fuse),"ready grenade waits indefinitely")
 check(stage.game_hud.read_data().grenades==4 and stage.game_hud.read_data().held_grenade,"HUD reads live stock and held grenade")
 check(c.holster() and c.count==5,"unlit grenade returns to stock")
 await frames(2)
 check(c.prepare(),"prepare again")
 grenade=c.held_grenade
 click(true)
 await frames(15)
 check(grenade.fuse_started and c.charging,"press starts fuse and charge")
 var fuse=grenade.fuse_left
 check(not c.holster(),"burning fuse cannot be holstered")
 check(c.power()>0 and c.power()<1,"charge increases gradually")
 var shots=stage.combat.gun.shots_fired
 await frames(8)
 check(stage.combat.gun.shots_fired==shots,"grenade input does not fire weapon")
 stage.paused=true
 var before=grenade.fuse_left
 var charge=c.charge
 await frames(12)
 check(is_equal_approx(before,grenade.fuse_left) and is_equal_approx(charge,c.charge),"pause freezes fuse and charge")
 click(false)
 await frames(1)
 stage.paused=false
 click(false)
 await frames(2)
 check(c.preparing(),"menu release does not become a throw")
 click(true)
 await frames(5)
 click(false)
 await frames(2)
 check(not c.preparing() and c.throws==1,"release throws exactly once")
 check(grenade.fuse_left<fuse and grenade.fuse_left>0,"throw preserves remaining fuse")
 check(grenade.continuous_cd,"continuous collision detection")
 var actual=grenade.linear_velocity.length()*c.U
 check(actual>=tuning.grenade_min_speed*.8 and actual<tuning.grenade_max_speed,"charged throw uses shared speed range")
 var stored=grenade.global_position
 tuning.grenades_enabled=false
 await frames(5)
 before=grenade.fuse_left
 stored=grenade.global_position
 await frames(8)
 check(grenade.global_position.distance_to(stored)<.001 and is_equal_approx(before,grenade.fuse_left),"mechanic toggle freezes body and fuse")
 tuning.grenades_enabled=true
 await frames(3)
 check(grenade.fuse_left<before,"reenabling resumes fuse")
 c.reset_state()
 await frames(3)
 check(c.count==5 and get_nodes_in_group("core_grenades_3d").is_empty(),"reset restores stock and removes active grenades")
 # Server ballistic path, before any bounce, against the same integration convention.
 c.prepare()
 grenade=c.held_grenade
 var origin=Vector3(2,5,0)
 var velocity=Vector3(3,3,0)
 var path=c.predict_path(origin,velocity,.3)
 grenade.launch(origin,velocity)
 c.held_grenade=null
 await frames(10)
 var error=INF
 for point in path: error=minf(error,point.distance_to(grenade.global_position))
 check(error<.15,"predicted arc matches physical flight before contact")
 c.reset_state()
 await frames(2)
 # Death drops an armed grenade without resetting its fuse.
 c.prepare()
 grenade=c.held_grenade
 grenade.start_fuse()
 grenade.fuse_left=2
 player.take_damage(1000)
 await frames(3)
 check(not grenade.held and not c.preparing() and grenade.fuse_left<2,"death drops live grenade")
 stage.developer._recover()
 await frames(3)
 # No-sever native geometry; damage and wave parity use the shared profile.
 var target=stage.combat.targets[0]
 target.position=Vector3(8,1,0)
 target.invulnerable=false
 target.health=100
 target.set_test_frozen(true)
 player.position=Vector3(-5,2,0)
 var profile=tuning.snapshot()
 profile.explosion_ragdoll_enabled=false
 profile.explosion_radius=100
 profile.explosion_full_damage_radius=40
 profile.explosion_damage=120
 profile.explosion_shockwave_radius=400
 profile.explosion_shockwave_damage=100
 await frames(2)
 var blast=preload("res://scripts/core/explosion_3d.gd").spawn(stage,target.position+Vector3(-2,.9,0),profile)
 check(target.health>=1 and target.health<100,"outer wave hurts but cannot kill")
 check(blast.affected.has(target.get_instance_id()),"blast tracks affected target")
 target.health=100
 var wall=StaticBody3D.new()
 var shape=CollisionShape3D.new()
 var box=BoxShape3D.new()
 box.size=Vector3(.2,3,3)
 shape.shape=box
 wall.add_child(shape)
 stage.add_child(wall)
 wall.position=target.position+Vector3(-1,1,0)
 await frames(2)
 blast=preload("res://scripts/core/explosion_3d.gd").spawn(stage,target.position+Vector3(-2,.9,0),profile)
 check(target.health==100,"solid cover blocks blast")
 wall.queue_free()
 await frames(2)
 target.health=100
 profile.explosion_ragdoll_enabled=true
 profile.explosion_ragdoll_min_distance=0
 target.set_test_frozen(false)
 profile.explosion_damage=0
 profile.explosion_shockwave_damage=0
 blast=preload("res://scripts/core/explosion_3d.gd").spawn(stage,target.position+Vector3(-.5,.8,0),profile)
 check(target.has_node("BlastRecovery") and target.get_node("ZombieVisual").ragdoll.active,"survivor enters real ragdoll")
 await frames(2)
 check(target.get_node("ZombieVisual").ragdoll.active,"living visual does not cancel blast ragdoll")
 stage.developer._recover()
 await frames(3)
 c.prepare()
 grenade=c.held_grenade
 grenade.start_fuse()
 grenade.fuse_left=.01
 await frames(4)
 check(not is_instance_valid(grenade) and not c.preparing(),"fuse explodes in hand")
 check(not get_nodes_in_group("core_explosions_3d").is_empty(),"detonation creates native blast and shared visual")
 stage.developer._recover()
 await frames(4)
 player.position=Vector3(3,.02,0)
 player.invulnerable=true
 await frames(3)
 profile.explosion_ragdoll_min_distance=0
 profile.explosion_ragdoll_duration=.3
 preload("res://scripts/core/explosion_3d.gd").spawn(stage,player.position+Vector3(.4,.5,0),profile)
 check(player.has_node("BlastRecovery") and player.model.death_ragdoll.active,"invulnerability still permits physical knockdown")
 await frames(600)
 check(player.health>0 and not player.model.death_ragdoll.active and not player.has_node("BlastRecovery"),"survivor recovers only after settling on clear ground")
 print("GRENADES_3D checks=",checks," failures=",failures)
 stage.queue_free()
 await process_frame
 quit(int(failures>0))
