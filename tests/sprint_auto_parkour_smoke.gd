extends SceneTree
const FOREST = preload("res://scripts/campaign/forest_prologue_v2.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var fixtures: Node2D
var obstacle: Rect2
var checks := 0
var failures := 0
var seen := false
var hung := false
var exit_speed := 0.0
var kind := ""
var directory := ""
func _initialize() -> void:call_deferred("run")
func frames(n:int) -> void:
	for i in n:await physics_frame;await process_frame
func check(ok:bool,label:String) -> void:
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;push_error("FAIL "+label)
func release() -> void:
	for a in ["core_left","core_right","core_sprint","core_jump","core_crouch","core_up","core_down","core_aim","core_fire"]:Input.action_release(a)
func block(r:Rect2) -> void:
	var body:=StaticBody2D.new();body.collision_layer=1;body.collision_mask=0
	var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new();rectangle.size=r.size
	shape.shape=rectangle;shape.position=r.get_center();body.add_child(shape);fixtures.add_child(body)
func course(ratio:float,width:=40.0,factor:=2.85,face:=1.0,ceiling:=false) -> void:
	release();hero.reset_to(Vector2(65000,760))
	if fixtures:fixtures.queue_free();await frames(2)
	hero.request_body_scale(factor)
	fixtures=Node2D.new();lab.add_child(fixtures)
	block(Rect2(64000,760,8000,100))
	obstacle=Rect2(65700,760-64*factor*ratio,width*factor,64*factor*ratio)
	block(obstacle)
	if ceiling:block(Rect2(65400,obstacle.position.y-64*factor+50,1000,30))
	hero.reset_to(Vector2(65700-300*factor if face>0 else obstacle.end.x+300*factor,760))
	hero.weapon.aim_override=hero.position+Vector2(-face*1200,-80)
	hero.tuning.parkour_enabled=true;hero.tuning.sprint_auto_parkour_enabled=true
	hero.tuning.sprint_enabled=true;hero.tuning.sprint_duration=10
	hero.tuning.sprint_auto_min_height_ratio=.25;hero.tuning.sprint_auto_max_height_ratio=.75
	hero.tuning.sprint_auto_max_width=96;hero.tuning.sprint_auto_vault_time=.32
	seen=false;hung=false;exit_speed=0;kind=""
	await frames(8)
func drive(face:float,sprint:=true,ticks:=260) -> bool:
	Input.action_press("core_right" if face>0 else "core_left")
	if sprint:Input.action_press("core_sprint")
	var was_auto := false
	for i in ticks:
		await frames(1)
		if hero.parkour_active():
			seen=seen or hero.parkour.sprint_assist;was_auto=hero.parkour.sprint_assist
			kind=hero.parkour.kind
			hung=hung or hero.mode=="ledge_hang"
		elif was_auto:exit_speed=absf(hero.velocity.x);was_auto=false
		if (hero.position.x>obstacle.end.x+hero.world_radius()+5 if face>0 else hero.position.x<obstacle.position.x-hero.world_radius()-5) and hero.is_on_floor():return true
	return false
func run() -> void:
	directory=OS.get_environment("TEMP").path_join("sprint-auto-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(directory)
	lab=load("res://scenes/campaign/prologue_v2.tscn").instantiate();lab.load_user_settings=false
	for entry in [["settings_path","movement.cfg"],["shooting_settings_path","shooting.cfg"],["camera_settings_path","camera.cfg"],["zombie_settings_path","zombie.cfg"],["ragdoll_settings_path","ragdoll.cfg"]]:lab.set(entry[0],directory.path_join(entry[1]))
	lab.get_node("World/Player").character_id="sofia";lab.get_node("World/Player").sofia_cel_variant=true
	root.add_child(lab);await frames(10);hero=lab.player;CATALOG.equip(hero.weapon,"stg44");hero.weapon.tuning.sound_enabled=false
	check(lab.movement_overlay.feature_toggles.has("sprint_auto_parkour_enabled") and lab.movement_overlay.rows.has("sprint_auto_max_height_ratio"),"developer menu exposes independent toggle and numeric tuning")
	check(lab.level.forest.ladders.all(func(r):return is_equal_approx(r.size.x,51.3)),"all seventeen ver2 ladders use 2.85x reference width")
	var maximum_grip_error := 0.0
	for index in lab.level.forest.ladders.size():
		var r: Rect2 = lab.level.forest.ladders[index]
		for up in [true,false]:
			release();hero.reset_to(Vector2(r.get_center().x,r.end.y if up else r.position.y));await frames(1)
			Input.action_press("core_up" if up else "core_down")
			var target: float = r.position.y if up else r.end.y
			var reached := false
			for tick in ceili(r.size.y/hero.motion_value("climb_speed")*60)+120:
				await frames(1)
				if hero.climbing:
					for arm in [hero.body.near_arm,hero.body.far_arm]:maximum_grip_error=maxf(maximum_grip_error,arm.hand.distance_to(arm.requested_hand))
				if not hero.climbing and absf(hero.position.y-target)<2:reached=true;break
			release();check(reached,"wider ladder %02d full %s"%[index+1,"ascent" if up else "descent"])
			if not reached:print("LADDER DETAIL ",index+1," ",up," at=",hero.position," rect=",r," climbing=",hero.climbing)
	check(maximum_grip_error<.1,"wider ladder grips remain reachable with unchanged arm lengths")
	for face in [1.0,-1.0]:
		for ratio in [.25,.50,.75]:
			await course(ratio,40,2.85,face)
			var completed=await drive(face)
			check(completed and seen,"sprint alone crosses height %.2fH facing %s"%[ratio,face])
			check(not hung and not Input.is_action_pressed("core_jump"),"automatic traversal needs neither hang nor Space")
			check(exit_speed>100 and hero.collision_mask==hero.WORLD_MASK,"exit keeps forward momentum and full collision")
			release()
	for factor in [1.0,3.5]:
		await course(.55,40,factor)
		check(await drive(1) and seen,"anatomical thresholds follow size %.2fx"%factor);release()
	await course(.5,220)
	Input.action_press("core_right");Input.action_press("core_sprint")
	for tick in 220:
		await frames(1)
		if hero.parkour_active():seen=true;kind=hero.parkour.kind
		elif seen:break
	check(seen and kind=="mantle" and hero.is_on_floor() and hero.position.y<obstacle.position.y+1,"broad obstacle is climbed onto without waiting for Space")
	for negative in ["below_knee","above_chest","ordinary_run","disabled","ceiling","reload","ads","no_sprint"]:
		await course(.15 if negative=="below_knee" else .85 if negative=="above_chest" else .50,40,2.85,1,negative=="ceiling")
		if negative=="disabled":hero.tuning.sprint_auto_parkour_enabled=false
		if negative=="no_sprint":hero.tuning.sprint_enabled=false
		if negative=="reload":hero.weapon.magazine_ammo=1;hero.weapon.request_reload()
		if negative=="ads":Input.action_press("core_aim")
		await drive(1,negative!="ordinary_run",125)
		check(not seen,"automatic action rejected: "+negative);release();hero.weapon.cancel_reload()
	# C cancels a live automatic movement, retaining the existing collision-safe exit.
	await course(.5)
	Input.action_press("core_right");Input.action_press("core_sprint")
	for tick in 180:
		await frames(1)
		if hero.parkour_active():break
	Input.action_press("core_crouch");await frames(2)
	check(not hero.parkour_active() and hero.collision_mask==hero.WORLD_MASK,"C cancels auto-parkour without disabling collisions")
	await course(.5)
	Input.action_press("core_right");Input.action_press("core_sprint")
	for tick in 180:
		await frames(1)
		if hero.parkour_active():break
	var reserve := hero.sprint_reserve
	await frames(4)
	check(hero.sprint_reserve<reserve,"automatic traversal consumes sprint reserve")
	paused=true
	var position:=hero.position
	await frames(4)
	check(hero.position.is_equal_approx(position),"pause freezes automatic traversal")
	paused=false;hero.tuning.sprint_auto_parkour_enabled=false;await frames(2)
	check(not hero.parkour_active() and hero.tuning.sprint_auto_vault_time==.32,"disabling auto traversal cancels it without erasing parameters")
	# New values use existing profile persistence and legacy defaults.
	release();hero.reset_to(Vector2(65000,760));await frames(5)
	hero.tuning.sprint_auto_parkour_enabled=false;hero.tuning.sprint_auto_vault_time=.47
	check(hero.tuning.save_saved(lab.settings_path)==OK,"new toggle and numeric parameters save to isolated CFG")
	var loaded:=CoreMovementSettings.new();loaded.load_saved(lab.settings_path)
	check(not loaded.sprint_auto_parkour_enabled and is_equal_approx(loaded.sprint_auto_vault_time,.47),"CFG retains disabled state and its parameters")
	var legacy:=CoreMovementSettings.new();legacy.apply_values({"run_speed":180})
	check(legacy.sprint_auto_parkour_enabled and legacy.sprint_auto_max_height_ratio==.75,"legacy settings receive new defaults without losing old values")
	check(lab.export_settings_file(directory.path_join("auto.json")),"five-profile JSON exports with new movement fields")
	hero.tuning.sprint_auto_parkour_enabled=true;hero.tuning.sprint_auto_vault_time=.2
	check(lab.import_settings_file(directory.path_join("auto.json")) and not hero.tuning.sprint_auto_parkour_enabled and is_equal_approx(hero.tuning.sprint_auto_vault_time,.47),"JSON import restores auto settings and developer controls")
	lab.queue_free();await frames(3);print("SPRINT AUTO: %d/%d"%[checks-failures,checks]);quit(1 if failures else 0)
