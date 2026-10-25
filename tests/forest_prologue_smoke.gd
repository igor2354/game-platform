extends SceneTree
## Real-input traversal and alternate paths. Every profile path is isolated before _ready.
const FOREST = preload("res://scripts/campaign/forest_prologue.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
const ACTIONS := ["core_left","core_right","core_up","core_down","core_crouch","core_jump"]
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var checks := 0
var failures := 0
var traversal_ticks := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func release_inputs() -> void:
	for action in ACTIONS: Input.action_release(action)

func settle(point: Vector2) -> void:
	release_inputs()
	hero.reset_to(point)
	hero.weapon.aim_override = point+Vector2(500,-32)
	await frames(8)

func drive_to(target_x: float,posture := "route",allow_jump := true) -> bool:
	release_inputs()
	var direction := signf(target_x-hero.position.x)
	if is_zero_approx(direction): return true
	var action := "core_right" if direction > 0 else "core_left"
	var jump_left := 0
	var limit := ceili(absf(target_x-hero.position.x)/80.0*60)+240
	var recoveries := lab.respawns
	Input.action_press(action)
	for i in limit:
		hero.weapon.aim_override = hero.position+Vector2(direction*500,-32)
		var in_tunnel := hero.position.x > FOREST.point(60,0).x and hero.position.x < FOREST.point(70,0).x
		var crouch := posture == "crouch" or (posture == "route" and in_tunnel)
		if crouch: Input.action_press("core_crouch")
		else: Input.action_release("core_crouch")
		if allow_jump and hero.parkour.active and hero.parkour.stage == "ledge_hang":
			# The agreed parkour input requires release + a fresh press to climb.
			if Input.is_action_pressed("core_jump"): Input.action_release("core_jump")
			else: Input.action_press("core_jump")
			jump_left = 0
		elif jump_left > 0:
			jump_left -= 1
			if jump_left == 0: Input.action_release("core_jump")
		elif allow_jump and not crouch and hero.is_on_floor() and hero.is_on_wall():
			Input.action_press("core_jump")
			jump_left = 40
		await frames(1)
		traversal_ticks += 1
		if lab.respawns != recoveries:
			print("Unexpected recovery near ",hero.position," while driving to ",target_x)
			release_inputs()
			return false
		if direction*(hero.position.x-target_x) >= -3:
			release_inputs()
			await frames(14)
			return true
	print("Traversal stuck at ",hero.position," target ",target_x," floor ",hero.is_on_floor()," wall ",hero.is_on_wall()," posture ",hero.mode)
	release_inputs()
	return false

func climb(rect: Rect2,up: bool) -> bool:
	release_inputs()
	var action := "core_up" if up else "core_down"
	var destination := rect.position.y if up else rect.end.y
	Input.action_press(action)
	for i in ceili(rect.size.y/hero.tuning.climb_speed*60)+90:
		await frames(1)
		if absf(hero.position.y-destination) < 2 and not hero.climbing:
			release_inputs()
			await frames(8)
			return hero.is_on_floor() and absf(hero.position.y-destination) < 3
	release_inputs()
	print("Climb failed at ",hero.position," destination ",destination)
	return false

func run() -> void:
	root.size = Vector2i(1600,900)
	lab = load("res://scenes/campaign/prologue.tscn").instantiate()
	lab.load_user_settings = false
	var directory := OS.get_environment("TEMP").path_join("forest-prologue-%d" % OS.get_process_id())
	for entry in [["settings_path","movement.cfg"],["shooting_settings_path","shooting.cfg"],["camera_settings_path","camera.cfg"],["zombie_settings_path","zombie.cfg"],["ragdoll_settings_path","ragdoll.cfg"]]:
		lab.set(entry[0],directory.path_join(entry[1]))
	lab.get_node("World/Player").character_id = "sofia"
	lab.get_node("World/Player").sofia_cel_variant = true
	root.add_child(lab)
	hero = lab.player
	CATALOG.equip(hero.weapon,"stg44")
	hero.weapon.tuning.sound_enabled = false
	hero.weapon.aim_override = hero.position+Vector2(500,-32)
	# Test the previously read user speeds without loading/writing real profiles.
	hero.tuning.run_speed = 240
	hero.tuning.slow_walk_speed = 80
	hero.tuning.climb_speed = 180
	hero.tuning.crouch_speed_multiplier = .45
	await frames(8)
	var forest := lab.level.forest
	check(forest != null and forest.sections.size() == 12 and forest.surfaces.size() == 12,"campaign contains all twelve forest sections")
	check(lab.level.right_bound() == 33120 and FOREST.WIDTH == 21120,"forest retains the approved total width of 330H")
	check(hero.is_on_floor() and hero.position.is_equal_approx(lab.level.PROLOGUE_START),"Sofia spawns safely on forest terrain")
	check(hero.uses_painted_cels() and hero.weapon.equipped_weapon_id == "stg44","existing painted Sofia and chosen weapon remain connected")
	check(forest.environment.panels.size() == 12,"all twelve approved environment panels are installed")
	var fitted_roads := true
	var valid_triangles := true
	check(forest.environment.buildings.size() == 3 and forest.environment.buildings.all(func(item): return item.texture.get_image().detect_alpha() != Image.ALPHA_NONE),"three buildings have independent transparent layers")
	for panel in forest.environment.panels+forest.environment.buildings:
		var arrays: Array = panel.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var index: int = forest.environment.panels.find(panel)
		if index >= 0:
			var rows: int = (forest.environment.FEATURES.get(index,[]).size()+2)*8+1
			for col in vertices.size()/rows:
				var ground_vertex := vertices[col*rows+rows-9]
				var expected: Vector2 = forest.ground_point((ground_vertex.x-FOREST.ORIGIN.x)/FOREST.H)
				fitted_roads = fitted_roads and absf(expected.y-ground_vertex.y) < .002
		for j in range(0,indices.size(),3):
			var a := Vector2(vertices[indices[j]].x,vertices[indices[j]].y)
			var b := Vector2(vertices[indices[j+1]].x,vertices[indices[j+1]].y)
			var c := Vector2(vertices[indices[j+2]].x,vertices[indices[j+2]].y)
			valid_triangles = valid_triangles and a.is_finite() and b.is_finite() and c.is_finite() and (b-a).cross(c-a) > .001
	check(fitted_roads,"every rendered road column is fitted to the actual collision surface")
	check(valid_triangles,"environment meshes have no folded, empty or non-finite triangles")
	check(absf(CoreWorldUnits.meters(forest.ground_point(222).y-forest.features.cabin_left_lintel.end.y)-2.1) < .001,"cabin door has a real 2.1 m clearance")
	check(absf(CoreWorldUnits.meters(forest.ground_point(281).y-forest.features.bunker_left_lintel.end.y)-2.1) < .001,"bunker door has a real 2.1 m clearance")
	check(absf(CoreWorldUnits.meters(forest.ground_point(225).y-forest.features.cabin_roof.end.y)-2.5) < .001,"cabin ceiling has a human-scale 2.5 m clearance")
	check(absf(CoreWorldUnits.meters(forest.ground_point(285).y-forest.features.bunker_roof.end.y)-2.4) < .001,"bunker ceiling has a human-scale 2.4 m clearance")
	var rail_sizes_ok := true
	for pair in [["forest_bridge_rail","forest_bridge"],["stone_bridge_rail","stone_bridge"],["tower_rail","tower_deck"],["cabin_rail","cabin_roof"],["bunker_rail","bunker_roof"]]:
		rail_sizes_ok = rail_sizes_ok and absf(CoreWorldUnits.meters(forest.features[pair[1]].position.y-forest.environment.landmark_y(pair[0]))-1.1) < .001
	check(rail_sizes_ok,"all five railing anchors are 1.1 m above their walking surface")
	check(absf(CoreWorldUnits.meters(forest.ground_point(225).y-forest.environment.landmark_y("cabin_table"))-.75) < .001 and absf(CoreWorldUnits.meters(forest.ground_point(285).y-forest.environment.landmark_y("bunker_table"))-.75) < .001,"both tabletop anchors are 0.75 m above their floor")
	check(hero.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(CoreWorldUnits.REFERENCE_HEIGHT,63.42),"human artwork reference and player scale remain unchanged")
	for i in range(1,forest.surfaces.size()):
		check(forest.surfaces[i-1][-1].is_equal_approx(forest.surfaces[i][0]),"continuous terrain seam %02d" % i)
	check(lab.level.floors.size() == 2 and lab.level.slopes.size() == 14,"old flat prologue floor is absent; polygon test geometry remains")
	check(forest.ladders.size() == 6 and lab.level.transition_doors.is_empty(),"tower, roof and two lower paths have ladders; no polygon doors appear in campaign")
	var above_fall_limit := true
	for surface in forest.surfaces:
		for p in surface: above_fall_limit = above_fall_limit and p.y < CoreMovementLevel.FALL_LIMIT-100
	check(above_fall_limit,"all traversable terrain stays safely above the existing fall-recovery limit")
	check(not lab.level_map._is_revealed(FOREST.point(300,0).x),"unvisited forest sections start hidden on the map")
	var route_start := traversal_ticks
	for section in forest.sections:
		var target := FOREST.point(section.start_H+section.width_H-1,0).x
		var completed := await drive_to(target)
		check(completed and hero.is_on_floor(),"continuous input traversal reaches section "+section.id+" / "+section.label)
		if not completed: break
	check(hero.position.x > FOREST.point(329,0).x-12 and lab.respawns == 0,"entire main route is traversable without recovery or teleports")
	print("MAIN ROUTE INPUT SIMULATION: ",traversal_ticks-route_start," physics ticks; not a human playthrough time")
	lab._recover()
	check(hero.position.is_equal_approx(lab.level.PROLOGUE_START) and hero.weapon.equipped_weapon_id == "stg44","F8 returns to the same prologue start and retains the loadout")
	var root_rect: Rect2 = forest.features.root
	await settle(Vector2(root_rect.position.x-45,760))
	Input.action_press("core_right")
	await frames(70)
	release_inputs()
	check(hero.position.x < root_rect.position.x and hero.is_on_wall(),"standing player cannot pass through the low root")
	check(await drive_to(root_rect.end.x+70,"crouch",false),"crouching passes completely under the root")
	await settle(Vector2(root_rect.position.x-45,760))
	check(await drive_to(root_rect.get_center().x,"standing") and absf(hero.position.y-root_rect.position.y) < 3,"jumping provides the upper root route")
	var tower: Rect2 = forest.features.tower_ladder
	await settle(Vector2(tower.get_center().x,tower.end.y))
	check(await climb(tower,true),"tower ladder reaches the observation deck")
	check(await climb(tower,false),"the same tower ladder returns to the forest trail")
	for pair in [["bridge_down_ladder","bridge_up_ladder"],["stone_down_ladder","stone_up_ladder"]]:
		var down: Rect2 = forest.features[pair[0]]
		var up: Rect2 = forest.features[pair[1]]
		await settle(Vector2(down.get_center().x,down.position.y))
		check(await climb(down,false),"descend into lower route: "+pair[0])
		check(await drive_to(up.get_center().x,"standing",false),"walk across the lower route: "+pair[0])
		check(await climb(up,true),"return to the upper route: "+pair[1])
	await settle(FOREST.point(221,2))
	check(await drive_to(FOREST.point(235,0).x,"standing",false),"cabin doorways and interior are walkable without changing Sofia")
	await settle(FOREST.point(280,3))
	check(await drive_to(FOREST.point(290,0).x,"standing",false),"bunker doorways and interior are walkable")
	var roof: Rect2 = forest.features.bunker_ladder
	# Align with the existing ladder's capture tolerance after normal braking.
	await settle(Vector2(roof.get_center().x,roof.end.y))
	check(await climb(roof,true),"bunker roof is accessible by ladder")
	check(await climb(roof,false),"bunker ladder permits a safe descent")
	await settle(FOREST.point(38,-3))
	hero.blast_ragdoll.start(Vector2(40,-30),.2,.12)
	await frames(100)
	check(not hero.blast_ragdoll.active and hero.position.y < CoreMovementLevel.FALL_LIMIT and hero.uses_painted_cels(),"existing ragdoll recovers on the ravine floor")
	lab._recover()
	await frames(5)
	var map := lab.level_map
	check(map._world_x_bounds() == Vector2(12000,33120) and map._world_y_bounds() == Vector2(80,1080),"level map uses forest bounds including the tower and ravine")
	check(lab.level.map_landmarks().size() == 14 and map._is_revealed(FOREST.point(300,0).x),"map has twelve section landmarks and retains exploration across F8")
	lab._toggle_level_map()
	check(paused and map.visible,"map opens and pauses the campaign")
	lab._toggle_level_map()
	check(not paused and not map.visible,"closing map restores campaign simulation")
	lab._teleport_zombie()
	check(hero.position.is_equal_approx(CoreMovementLevel.ZOMBIE_TEST_SPAWN),"F9 still reaches the original developer test area")
	lab._recover()
	check(hero.position.is_equal_approx(lab.level.PROLOGUE_START),"F8 returns from the developer area to the forest")
	lab.queue_free()
	await frames(4)
	print("FOREST PROLOGUE: %d/%d passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
