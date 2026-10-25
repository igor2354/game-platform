extends SceneTree
const V2=preload("res://scripts/campaign/forest_prologue_v2.gd")
const ENCOUNTERS=preload("res://scripts/campaign/prologue_v2_encounters.gd")
var lab:CoreMovementLab
var hero:CoreMovementPlayer
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func frames(n:int) -> void:
	for i in n:await physics_frame;await process_frame
func check(ok:bool,label:String) -> void:
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;push_error("FAIL "+label)
func release() -> void:
	for key in ["core_fire","core_aim","core_left","core_right","core_jump","core_sprint"]:Input.action_release(key)
func run() -> void:
	lab=load("res://scenes/campaign/prologue_v2.tscn").instantiate();lab.load_user_settings=false
	var temp:=OS.get_environment("TEMP").path_join("v2-encounters-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(temp)
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:lab.set(key,temp.path_join(key+".cfg"))
	lab.get_node("World/Player").character_id="sofia";lab.get_node("World/Player").sofia_cel_variant=true
	root.add_child(lab);await frames(20);hero=lab.player
	preload("res://scripts/campaign/catalog.gd").equip(hero.weapon,"stg44");hero.weapon.tuning.sound_enabled=false
	var actors:=lab.level.campaign_enemies
	check(actors.size()==6,"six zombies satisfy the updated user minimum")
	check(actors.filter(func(a):return a.get_meta("blueprint_segment")=="10").size()==3 and actors.filter(func(a):return a.get_meta("blueprint_segment")=="11").size()==3,"three trench opponents and three bunker-floor contacts")
	for i in actors.size():
		var enemy:CoreZombie=actors[i];var record:Dictionary=ENCOUNTERS.PLACEMENTS[i]
		check(enemy.home.is_equal_approx(V2.point(record.x_m,record.height_m)),"authored position "+enemy.identifier)
		check(enemy.target==hero and enemy.tuning==lab.zombie_settings and enemy in lab.level.enemies,"shared AI, target and developer controls "+enemy.identifier)
		check(enemy.body_size.is_equal_approx(Vector2(80,180)) and is_equal_approx(enemy.body_size.x/enemy.body_size.y,32.0/72.0),"uniform soldier proportions at human world size "+enemy.identifier)
		check(enemy.is_on_floor() and absf(enemy.position.y-enemy.home.y)<2,"standing on actual physical floor "+enemy.identifier)
		check(enemy.health==enemy.maximum_health() and not enemy.test_frozen,"alive and active at level entry "+enemy.identifier)
	check(ENCOUNTERS.PLACEMENTS.all(func(r):return r.x_m>=338 and r.x_m<430),"safe introduction, parkour, rest and fatal chasm remain free of enemy spawns")
	await frames(120)
	for enemy in actors:
		if not enemy.is_on_floor() or enemy.health<=0 or absf(enemy.position.y-enemy.home.y)>=V2.UPM*.1:
			print("PATROL DETAIL ",enemy.identifier," position=",enemy.position," home=",enemy.home," floor=",enemy.is_on_floor()," hp=",enemy.health)
	check(actors.all(func(a):return a.is_on_floor() and a.health>0 and absf(a.position.y-a.home.y)<V2.UPM*.1),"patrols follow their local support, including the shallow trench-exit slope, without changing floors")
	hero.invulnerable=true;hero.reset_to(V2.point(354,-2));await frames(6)
	var second_heard:=actors[1].heard_noise_count
	var later_heard:=actors.slice(1).map(func(a):return a.heard_noise_count)
	lab._broadcast_noise(hero.position,1,"shot");await frames(2)
	var later_quiet:=true
	for i in later_heard.size():later_quiet=later_quiet and actors[i+1].heard_noise_count==later_heard[i]
	check(actors[0].heard_noise_count>0 and later_quiet,"first trench shot does not summon the later five contacts at default hearing")
	hero.weapon.aim_override=actors[0].aim_point_for_part("torso")
	Input.action_press("core_fire")
	for i in 160:
		await frames(1);hero.weapon.aim_override=actors[0].aim_point_for_part("torso")
		if actors[0].health<=0:break
	release()
	check(actors[0].health<=0 and actors[0].received_hits>0,"first opponent can be killed by the selected STG through real hit regions")
	check(actors[1].health==actors[1].maximum_health() and actors[1].heard_noise_count==second_heard,"later trench opponent remains separate from first fight")
	hero.reset_to(V2.point(368.0,-2));await frames(35)
	check(actors[1].state in [CoreZombie.State.CHASE,CoreZombie.State.WINDUP,CoreZombie.State.RECOVERY,CoreZombie.State.INVESTIGATE],"next trench opponent reacts during forward advance")
	var bunker:CoreZombie=actors[3]
	lab._respawn_enemies();await frames(2)
	check(actors.all(func(a):return a.health==a.maximum_health() and a.position.distance_to(a.home)<5),"F7 restores all six without adding waves")
	hero.invulnerable=false;hero.reset_to(V2.point(405.2,.3));hero.weapon.aim_override=V2.point(406,.8)
	bunker.facing=-1
	for i in 130:
		await frames(1)
		if hero.health<100:break
	check(bunker.attacks_started>0 and hero.health<100,"human-sized bunker opponent can hit Sofia at actual body contact")
	check(bunker.melee_reach()>bunker.tuning.attack_range,"campaign contact reach accounts for widened body")
	lab._recover();await frames(3)
	check(actors.size()==6 and actors.all(func(a):return a.health==a.maximum_health()) and hero.position.distance_to(lab.level.player_spawn())<2,"F8 restores all six and player start without duplicates")
	release();lab.queue_free();await frames(3)
	print("V2 ENCOUNTERS: %d/%d"%[checks-failures,checks]);quit(1 if failures else 0)
