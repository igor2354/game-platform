extends SceneTree
const FRONT = preload("res://scripts/campaign/frontend.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
var checks := 0
var failures := 0
var directory := OS.get_environment("TEMP").path_join("aim-beam-%d" % OS.get_process_id())
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else: failures += 1; push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func block(lab: Node,rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)
	lab.add_child(body)
	return body
func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	for mode in ["polygon","prologue","prologue_v2"]:
		for character in ["sofia","harry"]:
			var app := FRONT.new()
			app.load_user_settings = false
			app.test_settings_directory = directory.path_join(mode+character)
			DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
			app.selected_character = character
			app.selected_level = mode
			root.add_child(app)
			app.launch(mode != "polygon")
			await frames(6)
			var lab: CoreMovementLab = app.game
			var hero := lab.player
			var gun := hero.weapon
			var beam = gun.aim_beam
			block(lab,Rect2(7700,760,1800,80))
			var wall := block(lab,Rect2(8550,0,30,760))
			hero.reset_to(Vector2(8100,760))
			gun.aim_override = Vector2(9100,650)
			gun.tuning.sound_enabled = false
			await frames(8)
			for data in CATALOG.WEAPONS:
				CATALOG.equip(gun,data.id)
				# Exercise sustained bursts even for guns whose normal preset is single-shot.
				gun.tuning.set_fire_mode(CoreShootingSettings.FireMode.AUTO)
				await frames(3)
				check(beam.ready_to_draw and beam.points.size() == 97 and beam.rays_last_tick == 98,mode+character+data.id+" bounded cone is available")
				check(is_equal_approx(beam.half_angle,deg_to_rad(gun.spread_degrees())),"cone exactly matches ballistic half angle")
				check(beam.points[48].x <= 8550.1 and Array(beam.points).all(func(p): return p.x <= 8550.1),"wall blocks centre and entire cone")
				Input.action_press("core_aim")
				await frames(10)
				check(beam.half_angle == 0 and beam.points.size() == 1 and beam.rays_last_tick == 2,"zero-spread ADS uses only an exact line")
				var before: Vector2 = beam.end-beam.origin
				await frames(10)
				check(not before.normalized().is_equal_approx((beam.end-beam.origin).normalized()),"sway changes direction without adding width")
				check((beam.end-beam.origin).normalized().dot(gun.aim_direction) > .99999,"line follows actual shot direction")
				gun.tuning.recoil_enabled = false
				gun.tuning.damage_enabled = false
				var hip_before := gun.bloom
				var shots_before := gun.shots_fired
				Input.action_press("core_fire")
				await frames(40)
				check(gun.shots_fired > shots_before+1 and gun.ads_bloom > 0,"real ADS burst accumulates spread")
				check(beam.half_angle > 0 and is_equal_approx(beam.half_angle,deg_to_rad(gun.spread_degrees())),"firing ADS widens beam to current ballistic spread")
				check(gun.last_shot_spread > 0 and gun.last_shot_spread <= gun.tuning.ads_max_spread,"actual ADS bullets use growing bounded spread")
				var ads_before := gun.ads_bloom
				gun.tuning.aim_beam_enabled = false
				gun.rng.seed = 2354
				gun._fire()
				var ads_classic_direction := gun.last_shot_direction
				gun.ads_bloom = ads_before
				gun.tuning.aim_beam_enabled = true
				gun.rng.seed = 2354
				gun._fire()
				check(ads_classic_direction.is_equal_approx(gun.last_shot_direction),"both ADS display modes fire identically with nonzero spread")
				check(is_equal_approx(gun.bloom,hip_before),"ADS spread does not add to hip bloom")
				gun.tuning.ads_max_spread = gun.tuning.ads_spread+gun.tuning.ads_spread_per_shot
				await frames(20)
				check(gun.spread_degrees() <= gun.tuning.ads_max_spread+.0001,"ADS cap applies during continuing burst")
				gun.tuning.ads_spread_enabled = false
				await frames(2)
				check(gun.spread_degrees() == 0 and beam.half_angle == 0 and gun.tuning.ads_spread_per_shot == .35,"independent switch restores precise ADS without erasing parameters")
				gun.tuning.ads_spread_enabled = true
				gun.tuning.ads_max_spread = 4
				await frames(8)
				Input.action_release("core_fire")
				await frames(45)
				check(gun.ads_bloom == 0 and beam.half_angle == 0,"release restores accuracy and narrows ADS beam back to line")
				gun.tuning.movement_spread_ads_multiplier = 1
				gun.movement_spread = 4
				beam._physics_process(0)
				check(is_equal_approx(beam.half_angle,deg_to_rad(4)),"ADS respects enabled real movement spread")
				gun.tuning.movement_spread_ads_multiplier = 0
				Input.action_release("core_aim")
				await frames(2)
				var bloom_before := gun.bloom
				gun.tuning.recoil_enabled = false
				gun.tuning.damage_enabled = false
				gun.tuning.magazine_enabled = false
				gun.tuning.aim_beam_enabled = false
				gun.rng.seed = 1234
				gun._fire()
				var classic_direction := gun.last_shot_direction
				gun.bloom = bloom_before
				gun.tuning.aim_beam_enabled = true
				gun.rng.seed = 1234
				gun._fire()
				check(classic_direction.is_equal_approx(gun.last_shot_direction),"switching display does not change seeded shot trajectory")
			var random_before := gun.rng.state
			var ammo_before := gun.magazine_ammo
			var samples := []
			for i in 100:
				beam._physics_process(0)
				samples.append(beam.update_usec)
			check(gun.rng.state == random_before and gun.magazine_ammo == ammo_before,"indicator consumes neither ballistic RNG nor ammo")
			samples.sort()
			print("BEAM CPU USEC ",mode,"/",character," median=",samples[50]," p95=",samples[95])
			gun.tuning.aim_beam_enabled = false
			beam._physics_process(0)
			check(not beam.ready_to_draw and beam.rays_last_tick == 0,"classic display disables all beam queries")
			gun.tuning.aim_beam_enabled = true
			lab.developer_mode.set_enabled(true)
			await frames(3)
			check(not beam.ready_to_draw,"developer UI restores ordinary pointer and hides beam")
			lab.developer_mode.set_enabled(false)
			await frames(3)
			check(beam.ready_to_draw,"closing UI restores selected beam")
			lab.level_map.visible = true
			await frames(2)
			check(not beam.ready_to_draw,"map hides beam")
			lab.level_map.visible = false
			await frames(2)
			check(beam.ready_to_draw,"map closing restores beam")
			gun.tuning.beam_hip_opacity = .12
			gun.tuning.beam_edge_softness = .7
			gun.tuning.ads_spread_per_shot = .7
			check(lab.export_settings_file(directory.path_join("beam.json")),"export settings")
			gun.tuning.aim_beam_enabled = false
			gun.tuning.ads_spread_per_shot = 0
			check(lab.import_settings_file(directory.path_join("beam.json")) and gun.tuning.aim_beam_enabled and is_equal_approx(gun.tuning.beam_edge_softness,.7) and is_equal_approx(gun.tuning.ads_spread_per_shot,.7),"JSON round trip preserves display, ADS spread and appearance with five isolated profiles")
			var old := CoreShootingSettings.new()
			check(old.load_saved(lab.shooting_settings_path) == OK and old.aim_beam_enabled and is_equal_approx(old.beam_hip_opacity,.12),"CFG round trip preserves beam")
			wall.queue_free()
			await frames(2)
			check(beam.end.x > 8550,"removed obstacle no longer clips beam")
			check(lab.shooting_overlay.feature_toggles.has("aim_beam_enabled") and lab.shooting_overlay.rows.has("beam_edge_softness"),"full developer controls exist in every game mode")
			await app.return_to_menu()
			app.queue_free()
			await frames(2)
	print("AIM BEAM: %d/%d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
