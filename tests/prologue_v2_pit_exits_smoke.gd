extends SceneTree
## Recover from failed jumps, rather than testing only the ideal upper route.
const FOREST = preload("res://scripts/campaign/forest_prologue_v2.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var failures := 0
var checks := 0
func _initialize() -> void:call_deferred("run")
func frames(n:int) -> void:
	for i in n:await physics_frame;await process_frame
func check(ok:bool,label:String) -> void:
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;push_error("FAIL "+label)
func release() -> void:
	for a in ["core_left","core_right","core_up","core_down","core_jump"]:Input.action_release(a)
func place(x:float,h:float) -> void:
	release();hero.reset_to(FOREST.point(x,h));hero.weapon.aim_override=hero.position+Vector2(700,-100)
	await frames(12)
func escape_right(target:float) -> bool:
	Input.action_press("core_right");Input.action_press("core_jump")
	for tick in 240:
		await frames(1)
		if hero.mode=="ledge_hang":
			Input.action_release("core_jump");await frames(2);Input.action_press("core_jump")
		if hero.position.x>FOREST.point(target,0).x and hero.is_on_floor():release();return true
	release();print("ESCAPE STOP ",hero.position," ",hero.mode);return false
func run() -> void:
	lab=load("res://scenes/campaign/prologue_v2.tscn").instantiate();lab.load_user_settings=false
	var directory=OS.get_environment("TEMP").path_join("pit-exits-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	for entry in [["settings_path","movement.cfg"],["shooting_settings_path","shooting.cfg"],["camera_settings_path","camera.cfg"],["zombie_settings_path","zombie.cfg"],["ragdoll_settings_path","ragdoll.cfg"]]:lab.set(entry[0],directory.path_join(entry[1]))
	lab.get_node("World/Player").character_id="sofia";lab.get_node("World/Player").sofia_cel_variant=true
	root.add_child(lab);await frames(10);hero=lab.player
	CATALOG.equip(hero.weapon,"stg44");hero.weapon.tuning.sound_enabled=false
	var respawns=lab.respawns
	# Drop into the narrow root pit from its left ledge, as in the first screenshot.
	await place(58+24.7,2.2);await frames(70)
	check(hero.is_on_floor() and hero.position.y>FOREST.point(0,1).y,"root pit fall reaches a living floor")
	var root_exit:Rect2=lab.level.forest.features.root_pit_exit_ladder
	await place((root_exit.get_center().x-FOREST.ORIGIN.x)/FOREST.UPM,0)
	Input.action_press("core_up")
	for i in 300:
		await frames(1)
		if hero.is_on_floor() and not hero.climbing and not hero.ladder_exit.is_finite() and absf(hero.position.y-root_exit.position.y)<3:break
	release();check(hero.is_on_floor() and absf(hero.position.y-root_exit.position.y)<3,"planned ladder escapes root pit forward with current jump")
	# Walk from the existing ladder through the bottom of the ravine.
	await place(24+10,-4.8)
	Input.action_press("core_right")
	var crossed := false
	for tick in 480:
		await frames(1)
		if hero.position.x>FOREST.point(24+21.9,0).x:crossed=true;break
	release();check(crossed,"standing Sofia crosses beneath ravine island towards forward exit")
	if crossed:
		Input.action_press("core_up")
		for tick in 260:
			await frames(1)
			if not hero.climbing and not hero.ladder_exit.is_finite() and hero.is_on_floor() and hero.position.y<FOREST.point(0,-2.3).y:break
		release();await frames(4)
		check(hero.is_on_floor() and hero.position.y<FOREST.point(0,-2.3).y,"forward ladder emerges onto the ravine right ledge")
		Input.action_press("core_right");await frames(100);release()
		check(hero.position.x>FOREST.point(24+24,0).x,"ravine forward exit rejoins the ascending main trail")
	check(hero.health>0 and lab.respawns==respawns,"both recoveries require no death, F8 or teleport out")
	lab.queue_free();await frames(3)
	print("PIT EXITS: %d/%d"%[checks-failures,checks]);quit(1 if failures else 0)
