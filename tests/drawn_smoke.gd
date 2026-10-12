extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func check_equipment_motion() -> void:
	var simulations: Array[DrawnBody] = []
	var peaks := {}
	for fps in [30,60,120]:
		var body := DrawnBody.new()
		root.add_child(body)
		body.drive("walk",Vector2(208,0))
		var peak := {"carbine":0.0,"bedroll":0.0,"satchel":0.0,"canteen":0.0}
		var mounted := true
		for i in fps*2:
			body.advance(1.0/fps)
			var attachment := body.equipment_attachment()-body.reference_shoulder
			for name in body.equipment:
				var sprite: Sprite2D = body.equipment[name]
				var angle := sprite.rotation-(-1.08 if name == "carbine" else 0.0)
				peak[name] = maxf(peak[name],absf(angle))
				var displacement: Vector2 = sprite.position-DrawnBody.GEAR_REST[name]-attachment
				mounted = mounted and absf(displacement.x) < .001 and absf(displacement.y) < 1.2
		if fps == 60:
			check(mounted,"equipment pivots stay attached instead of floating around the body")
			peaks = peak
		body.drive("idle",Vector2.ZERO)
		for i in int(fps/5): body.advance(1.0/fps)
		simulations.append(body)
	check(peaks.canteen > peaks.satchel and peaks.satchel > peaks.carbine*2 and peaks.bedroll < .024,"hanging equipment swings more freely than the secured rifle and bedroll")
	var consistent := true
	for body in simulations:
		for name in body.equipment:
			consistent = consistent and body.equipment[name].position.distance_to(simulations[1].equipment[name].position) < .25
			consistent = consistent and absf(body.equipment[name].rotation-simulations[1].equipment[name].rotation) < .008
	check(consistent,"acceleration and settling remain consistent at 30, 60 and 120 FPS")
	var body := simulations[1]
	var frozen_angle: float = body.equipment.canteen.rotation
	var frozen_velocity: float = body.equipment_angle_velocity.canteen
	body.advance(0)
	check(body.equipment.canteen.rotation == frozen_angle and body.equipment_angle_velocity.canteen == frozen_velocity,"pause preserves the pendulum angle and momentum")
	for i in 240: body.advance(1.0/60)
	check(absf(body.equipment.canteen.rotation) < .001 and absf(body.equipment.satchel.rotation) < .001,"hanging equipment damps out after stopping")
	body.drive("walk",Vector2(475,0))
	for i in 30: body.advance(1.0/60)
	body.drive("walk",Vector2(-475,0))
	var bounded := true
	for i in 60:
		body.advance(1.0/60)
		for name in body.equipment:
			var rest := -1.08 if name == "carbine" else 0.0
			bounded = bounded and absf(body.equipment[name].rotation-rest) <= float(DrawnBody.GEAR_MOTION[name].limit)+.001
	check(bounded,"abrupt reversals keep gear within its strap travel")
	for simulation in simulations: simulation.queue_free()
func run() -> void:
	var game: DeadPlatformGame = load("res://scenes/archive/station_demo.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.feel.reset()
	var hero: Soldier = game.player
	hero.set_process(false)
	hero.set_physics_process(false)
	var body: DrawnBody = hero.rig
	check(hero.body_mode == "drawn" and body != null,"painted hybrid is selected at startup")
	if "--packed" in OS.get_cmdline_user_args():
		check(not FileAccess.file_exists("res://source_art/soldier_high_detail/soldier_high_detail.glb") and not FileAccess.file_exists("res://scenes/sandbox/drawn_preview.tscn"),"artistic 3D source and editor preview are excluded from the game pack")
	check("concept" in hero.body_modes() and "rig" in hero.body_modes(),"previous characters remain selectable")
	check(body.meta.animations.walk.frames == 12 and body.meta.animations.dash.frames == 4 and body.meta.animations.climb.frames == 4,"complete twelve-pose walk, retained dash and alternating climb drawings are present")
	var art: Image = body.sprites.walk.texture.get_image()
	check(art.get_pixel(0,0).a == 0 and art.get_size() == Vector2i(3840,320),"frame strip preserves genuine RGBA transparency")
	check(art.get_region(Rect2i(0,0,320,320)).get_data() != art.get_region(Rect2i(640,0,320,320)).get_data(),"walk uses distinct leg and coat drawings")
	body.drive("walk",Vector2(208,0))
	body.advance(.11)
	check(body.frame == 1 and body.arms.visible and body.equipment_root.visible,"walking advances drawn frames with separate arms and equipment")
	body.face(-1)
	body.drive("walk",Vector2(208,0))
	body.advance(.1)
	check(body.speed < 0 and body.frame == 0,"backpedalling reverses the painted cycle")
	body.face(1)
	body.restart("walk")
	body.drive("walk",Vector2(208,0))
	body.advance(.48)
	var gait_phase := body.time/float(body.meta.animations.walk.duration)
	var supporting_pose := body.frame
	body.drive("run",Vector2(475,0))
	check(is_equal_approx(body.time/float(body.meta.animations.run.duration),gait_phase) and body.frame == supporting_pose,"releasing aim preserves the supporting leg and stride phase")
	body.drive("walk",Vector2(208,0))
	check(is_equal_approx(body.time/float(body.meta.animations.walk.duration),gait_phase) and body.frame == supporting_pose,"aiming again changes cadence without restarting the gait")
	body.drive("idle",Vector2.ZERO)
	var grips_ok := true
	for angle in [-1.2,-.6,0,.6,1.2]:
		body.update_combat(Vector2(15,-140),Vector2.from_angle(angle),-1,0)
		for side in ["near","far"]:
			var grip: Vector2 = body.near_target if side == "near" else body.far_target
			grips_ok = grips_ok and body.hand_positions[side].distance_to(body.weapon_origin+grip.rotated(body.weapon_angle)) < .2
	check(grips_ok,"both painted gloves maintain contact across aim angles")
	body.update_combat(Vector2(10,-140),Vector2.RIGHT,.32,.04)
	check(body.magazine_position.y > body.vector(body.meta.weapon.magazine).y+12 and body.flash > 0,"reload and recoil drive the painted drum, gun and hands")
	check(body.hand_positions.far.distance_to(body.weapon_origin+body.magazine_position.rotated(body.weapon_angle)) < .2,"painted support hand follows the removed magazine")
	body.drive("walk",Vector2(208,0))
	var start_angle: float = body.equipment.satchel.rotation
	for i in 60: body.advance(1.0/60)
	check(absf(body.equipment.satchel.rotation-start_angle) > .005,"satchel moves independently while walking")
	body.drive("idle",Vector2.ZERO)
	var moving: Vector2 = body.equipment.satchel.position
	body.advance(.05)
	check(body.equipment.satchel.position.distance_to(moving) > .01,"equipment retains inertia after stopping")
	var frozen: Vector2 = body.equipment.satchel.position
	body.advance(0)
	check(body.equipment.satchel.position == frozen,"pausing freezes secondary equipment motion")
	for i in 240: body.advance(1.0/60)
	check(body.equipment.satchel.position.distance_to(DrawnBody.GEAR_REST.satchel) < 4,"equipment settles near its attachment after movement")
	body.drive("dash",Vector2.ZERO)
	body.advance(.2)
	check(body.frame == 2 and not body.arms.visible and not body.equipment_root.visible,"dash uses complete painted lunge poses, without duplicated arms or equipment")
	body.advance(1)
	check(body.frame == 3,"short dash ends in its recovery pose")
	body.drive("climb",Vector2(0,-263))
	body.advance(.22)
	check(body.frame == 1 and not body.weapon_layer.visible,"climbing uses the complete slung-weapon drawing")
	body.drive("climb",Vector2.ZERO)
	var stopped := body.frame
	body.advance(.5)
	check(body.frame == stopped,"ladder animation freezes with the player")
	body.drive("climb",Vector2(0,263))
	body.advance(.2)
	check(body.speed < 0 and body.frame == 0,"descent reverses climbing hand/foot changes")
	# Real movement/input and collision/invulnerability, not just animation calls.
	for enemy in game.enemies: enemy.queue_free()
	game.enemies.clear()
	game.start_game()
	hero.set_process(true)
	hero.set_physics_process(true)
	hero.position = Vector2(300,1120)
	hero.velocity = Vector2.ZERO
	await frames(8)
	Input.warp_mouse(game.get_viewport().get_canvas_transform()*Vector2(800,1036))
	var dash_start := hero.position.x
	Input.action_press("right")
	Input.action_press("roll")
	await frames(6)
	Input.action_release("roll")
	Input.action_release("right")
	check(body.state == "dash" and hero.capsule.height == Soldier.DASH_HEIGHT and hero.evade_label() == "рывок","Shift starts a real forward dash with its own collision height")
	hero.invulnerable = 0
	var hp := hero.health
	hero.take_damage(17)
	check(hero.health == hp,"dash protects the player within its short invulnerability window")
	await frames(20)
	check(hero.rolling <= 0 and hero.position.x > dash_start+150 and hero.capsule.height == Soldier.STAND_HEIGHT,"dash covers ground then restores standing within 0.34 seconds")
	check(body.arms.visible and body.equipment_root.visible,"after dash the hands and movable equipment return")
	hero.invulnerable = 0
	hero.take_damage(17)
	check(hero.health == hp-17,"dash protection expires instead of leaking into normal movement")
	hero.position = Vector2(530,1120)
	hero.velocity = Vector2.ZERO
	await frames(6)
	Input.action_press("up")
	await frames(12)
	check(hero.climbing and body.state == "climb","W selects the painted ladder animation through the actual controller")
	await frames(110)
	Input.action_release("up")
	await frames(4)
	check(not hero.climbing and absf(hero.position.y-820) < 3,"painted climber dismounts onto the platform")
	hero.ammo = 5
	hero.reserve = 50
	Input.action_press("reload")
	await frames(2)
	Input.action_release("reload")
	await frames(28)
	check(body.reload_fraction > .15 and body.reload_fraction < .5,"R synchronises the hybrid reload to gameplay time")
	await frames(85)
	check(hero.ammo == Soldier.MAGAZINE and hero.reserve == 31,"hybrid reload conserves finite ammunition")
	check(body.muzzle_global().distance_to(hero.muzzle()) < .2,"painted muzzle agrees with the gameplay projectile origin")
	Input.action_press("shoot")
	await frames(2)
	Input.action_release("shoot")
	await process_frame
	check(hero.ammo == Soldier.MAGAZINE-1 and body.flash > 0,"actual shooting consumes ammunition and flashes the held painted PPSh")
	hero.set_process(false)
	hero.set_physics_process(false)
	hero.set_body_mode("rig")
	check(hero.rig is HumanoidRig and hero.evade_label() == "перекат","retained greybox still uses the original roll")
	check_equipment_motion()
	game.ambient.stop()
	game.ambient.stream = null
	await create_timer(.2).timeout
	game.queue_free()
	await create_timer(.2).timeout
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
