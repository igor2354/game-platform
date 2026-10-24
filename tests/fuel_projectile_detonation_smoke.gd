extends SceneTree
var lab: CoreMovementLab
var fuel: CoreExplosiveBarrel
var checks := 0
var failures := 0
var directory := "/private/tmp/fuel-projectile-%d" % OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count := 4) -> void:
	for tick in count: await physics_frame; await process_frame
func reset_fuel() -> void:
	fuel.reset_barrel()
	fuel.freeze = true
func hit(amount := 1.0,damage_enabled := true) -> void:
	CoreProjectile.resolve_impact({"collider":fuel,"position":fuel.position},amount,Vector2.RIGHT,Callable(),Vector2.INF,damage_enabled,lab.player)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]: lab.set(key,directory.path_join(key+".cfg"))
	root.add_child(lab)
	await frames()
	var settings := lab.ragdoll_settings
	settings.explosion_audio_enabled = false
	settings.explosion_visuals_enabled = false
	settings.explosion_camera_enabled = false
	settings.explosion_damage = 0
	settings.explosion_shockwave_enabled = false
	settings.explosion_impulse = 0
	settings.explosion_radius = 40
	settings.explosion_sever_enabled = false
	fuel = load("res://scenes/core/fuel_barrel.tscn").instantiate()
	fuel.position = Vector2(10000,-300)
	fuel.tuning = settings
	lab.level.add_child(fuel)
	fuel.freeze = true
	check(settings.fuel_projectile_detonation_enabled and settings.fuel_projectile_detonation_hits == 2,"fuel bullets detonate by default on the second positive-damage hit")
	hit()
	check(fuel.projectile_hits == 1 and fuel.leaking and not fuel.armed,"first positive hit still starts the independent leak")
	fuel.grabbed_by = lab.player
	hit()
	check(fuel.armed and fuel.instigator == lab.player and fuel.grabbed_by == null,"second hit starts shared fuse, releases grab and preserves attacker attribution")
	var fuse := fuel.fuse_left
	paused = true
	await frames(12)
	check(fuel.armed and fuel.fuse_left == fuse and not fuel.destroyed,"pause freezes the existing barrel fuse")
	paused = false
	await frames(20)
	check(fuel.destroyed and fuel.debris.size() == 12,"fuel shot detonation creates the shared explosion and persistent debris")
	reset_fuel()
	settings.fuel_projectile_detonation_enabled = false
	hit(500)
	hit(500)
	await frames(12)
	check(fuel.health == 0 and fuel.leaking and not fuel.armed and not fuel.destroyed,"disabled option retains the old perforated fuel tank even at zero shell HP")
	check(fuel.ignite_from_fire(lab.player),"turning off bullet detonation preserves fire ignition")
	await frames(20)
	check(fuel.destroyed,"fire still detonates fuel while bullet option is off")
	reset_fuel()
	settings.fuel_projectile_detonation_enabled = true
	settings.fuel_projectile_detonation_hits = 4
	settings.barrel_leak_hits = 2
	for i in 3: hit(500)
	check(fuel.projectile_hits == 3 and fuel.leaking and not fuel.armed,"bullet threshold is independent of shell HP and leak threshold")
	hit()
	check(fuel.armed,"configurable fourth hit arms the fuel barrel")
	reset_fuel()
	settings.fuel_projectile_detonation_hits = 1
	settings.fuel_fire_enabled = false
	settings.fuel_leak_enabled = false
	hit()
	check(fuel.armed,"direct bullet detonation is independent of leak and fire switches")
	settings.fuel_projectile_detonation_enabled = false
	check(fuel.armed,"disabling the option never cancels an already-started fuse")
	reset_fuel()
	settings.fuel_projectile_detonation_enabled = true
	hit(25,false)
	for amount in [0.0,-1.0,NAN,INF]: fuel.take_projectile_damage(amount,lab.player)
	check(fuel.projectile_hits == 0 and not fuel.armed,"damage-disabled, zero, negative and invalid hits cannot count toward detonation")
	settings.barrels_enabled = false
	hit()
	check(fuel.projectile_hits == 0 and not fuel.armed,"barrel master switch blocks bullet detonation and hit counting")
	settings.barrels_enabled = true
	settings.explosions_enabled = false
	hit()
	check(fuel.projectile_hits == 1 and not fuel.armed,"explosion master switch blocks arming without breaking the shell damage path")
	settings.explosions_enabled = true
	hit()
	check(fuel.armed,"reenabled explosions can arm on the next accepted hit")
	reset_fuel()
	check(fuel.projectile_hits == 0 and not fuel.leaking and not fuel.armed and fuel.health == settings.barrel_health,"barrel restoration resets hit count, HP, leakage and fuse")
	settings.fuel_projectile_detonation_enabled = false
	fuel.take_explosion_hit(500,fuel.position,lab.player,true)
	check(fuel.armed,"disabled bullet option leaves chain detonation unchanged")
	reset_fuel()
	settings.explosion_chain_enabled = false
	fuel.take_explosion_hit(500,fuel.position,lab.player,true)
	check(not fuel.armed,"chain switch still independently blocks explosion-induced arming")
	settings.explosion_chain_enabled = true
	settings.fuel_projectile_detonation_enabled = true
	settings.fuel_projectile_detonation_hits = 1
	for kind in [CoreExplosiveBarrel.Contents.EMPTY,CoreExplosiveBarrel.Contents.INERT,CoreExplosiveBarrel.Contents.EXPLOSIVE]:
		var other: CoreExplosiveBarrel = load("res://scenes/core/explosive_barrel.tscn").instantiate()
		other.contents = kind
		other.position = fuel.position+Vector2(500,0)
		other.tuning = settings
		lab.level.add_child(other)
		other.freeze = true
		other.take_projectile_damage(1,lab.player)
		check(not other.armed and not other.destroyed,"new fuel threshold does not replace HP rules of other barrel type "+str(kind))
		other.take_projectile_damage(500,lab.player)
		check(other.armed if kind == CoreExplosiveBarrel.Contents.EXPLOSIVE else other.destroyed and not other.armed,"original destruction/detonation retained for other type "+str(kind))
		for piece in other.debris: piece.queue_free()
		other.queue_free()
	# Actual travelling projectile through the normal raycast pipeline.
	reset_fuel()
	settings.fuel_projectile_detonation_hits = 1
	var projectile := CoreProjectile.new()
	projectile.position = fuel.position-Vector2(100,0)
	projectile.direction = Vector2.RIGHT
	projectile.instigator = lab.player
	projectile.shooter = lab.player.get_rid()
	projectile.damage = 1
	lab.level.add_child(projectile)
	await frames(20)
	check(fuel.destroyed and fuel.instigator == lab.player,"a real moving projectile detonates a fuel barrel through the production collision path")
	var ui := lab.ragdoll_overlay
	ui.feature_toggles.fuel_projectile_detonation_enabled.button_pressed = false
	ui.rows.fuel_projectile_detonation_hits.number.value = 5
	check(not settings.fuel_projectile_detonation_enabled and settings.fuel_projectile_detonation_hits == 5,"developer toggle and numeric threshold change the live profile")
	paused = true
	ui.feature_toggles.fuel_projectile_detonation_enabled.button_pressed = true
	ui.rows.fuel_projectile_detonation_hits.slider.value = 7
	check(settings.fuel_projectile_detonation_enabled and settings.fuel_projectile_detonation_hits == 7,"both new controls remain adjustable on pause")
	ui.save_profile()
	var loaded := CoreRagdollSettings.new()
	check(loaded.load_saved(lab.ragdoll_settings_path) == OK and loaded.fuel_projectile_detonation_enabled and loaded.fuel_projectile_detonation_hits == 7,"camera-independent physics CFG roundtrips both new values")
	check(settings.snapshot().fuel_projectile_detonation_hits == 7,"shared explosion snapshots preserve the additional profile values")
	check(lab.export_settings_file(directory+"/profile.json"),"exports to isolated five-profile JSON")
	settings.fuel_projectile_detonation_enabled = false
	settings.fuel_projectile_detonation_hits = 19
	check(lab.import_settings_file(directory+"/profile.json") and settings.fuel_projectile_detonation_enabled and settings.fuel_projectile_detonation_hits == 7,"JSON restores the new switch and threshold")
	var old := ConfigFile.new()
	old.set_value("ragdoll","barrel_health",90)
	old.save(directory+"/old.cfg")
	loaded = CoreRagdollSettings.new()
	check(loaded.load_saved(directory+"/old.cfg") == OK and loaded.fuel_projectile_detonation_enabled and loaded.fuel_projectile_detonation_hits == 2 and loaded.barrel_health == 90,"old CFG gets the requested enabled default while retaining old values")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"/profile.json"))
	data.ragdoll.erase("fuel_projectile_detonation_enabled")
	data.ragdoll.erase("fuel_projectile_detonation_hits")
	var file := FileAccess.open(directory+"/old.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	check(lab.import_settings_file(directory+"/old.json") and settings.fuel_projectile_detonation_enabled and settings.fuel_projectile_detonation_hits == 2,"old JSON applies deliberate enabled defaults")
	settings.set_parameter("fuel_projectile_detonation_hits",100)
	check(settings.fuel_projectile_detonation_hits == 20,"threshold clamps at twenty hits")
	settings.set_parameter("fuel_projectile_detonation_hits",0)
	check(settings.fuel_projectile_detonation_hits == 1,"threshold clamps at one hit")
	paused = false
	for piece in fuel.debris: piece.queue_free()
	lab.queue_free()
	await frames()
	print("FUEL PROJECTILE DETONATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
