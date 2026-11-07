extends SceneTree
const GEO = preload("res://scripts/campaign/hub_geometry.gd")
var checks := 0
var failures := 0
var lab
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if ok: print("PASS ",label)
	else: failures += 1; push_error("FAIL "+label)
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func run() -> void:
	lab = load("res://scenes/campaign/hub.tscn").instantiate()
	lab.load_user_settings = false
	var temp := OS.get_environment("TEMP").path_join("hub-smoke-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(temp)
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]: lab.set(key,temp.path_join(key+".cfg"))
	lab.get_node("World/Player").character_id = "sofia"
	lab.get_node("World/Player").sofia_cel_variant = true
	root.add_child(lab); await frames(20)
	var level = lab.level
	var geo = level.forest
	check(level.hub_mode,"hub mode enabled")
	check(level.player_spawn().is_equal_approx(GEO.point(49,0)),"blueprint entry spawn")
	check(level.ladders.is_empty() and level.side_ladders.is_empty(),"no automatic climbing zones")
	check(level.transition_doors.is_empty(),"no temporary floor teleport replacing future stairs")
	check(geo.stair_flights.size()==14,"fourteen blocking stair flights")
	check(geo.room_boxes.size()==13,"all blueprint rooms")
	check(level.enemies.is_empty() and level.campaign_enemies.is_empty(),"safe hub has no enemies")
	check(level.physics_crate==null and level.ragdoll_mannequin==null,"no polygon fixtures")
	check(level.map_landmarks().size()==14,"entry and rooms on existing map")
	check(is_equal_approx(lab.player.character_scale(),1.0),"reference Sofia scale")
	check(lab.player.is_on_floor(),"spawn rests on ground")
	lab.player.reset_to(GEO.point(26,0)); await frames(5)
	Input.action_press("core_up"); await frames(90); Input.action_release("core_up")
	check(not lab.player.climbing,"up alongside placeholder does not climb")
	check(absf(lab.player.position.y-GEO.point(26,0).y)<4,"no implicit vertical movement")
	lab.player.reset_to(GEO.point(29,0)); await frames(5)
	Input.action_press("core_left"); await frames(125); Input.action_release("core_left")
	check(lab.player.position.x<GEO.point(24,0).x,"ground door and inactive stairs allow walking")
	for h in [4.4,7.8,11.2]:
		lab.player.reset_to(GEO.point(54,h)); await frames(8)
		check(lab.player.is_on_floor(),"admin floor contact "+str(h))
		var query := PhysicsRayQueryParameters2D.create(GEO.point(71,h+1),GEO.point(74,h+1),1)
		check(not lab.player.get_world_2d().direct_space_state.intersect_ray(query).is_empty(),"upper right boundary "+str(h))
	lab._recover(); await frames(10)
	check(lab.player.is_on_floor(),"safe respawn without missing fixtures")
	var frontend = preload("res://scripts/campaign/frontend.gd").new()
	frontend.load_user_settings=false; root.add_child(frontend); await frames(3)
	frontend.show_page("levels"); await frames(3)
	check(frontend.buttons.has("hub"),"hub selectable in campaign menu")
	frontend.select_level("hub");check(frontend._mode_caption()=="ХАБ","hub selection caption")
	lab._teleport_player(CoreMovementLevel.ZOMBIE_TEST_SPAWN)
	check(level.campaign_bounds().has_point(lab.player.position),"polygon shortcuts cannot leave hub")
	lab.queue_free();await frames(3)
	frontend.test_settings_directory=temp
	frontend.launch(true);await frames(10)
	check(frontend.game.level.hub_mode,"campaign selection launches real hub scene")
	frontend.return_to_menu();await frames(3)
	check(not is_instance_valid(frontend.game),"hub returns to menu")
	frontend.queue_free();await frames(3)
	print("HUB CHECKS %d/%d"%[checks-failures,checks]);quit(1 if failures else 0)
