extends SceneTree
var lab: CoreMovementLab
var gun: CoreShootingController
var checks := 0
var failures := 0
var shots: Array[Dictionary] = []
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
func record(_origin: Vector2,_direction: Vector2,aimed: bool,_spread: float) -> void:
	shots.append({"rounds":gun.magazine_ammo,"low":gun.last_shot_sound_profile.low,"factor":gun.last_shot_sound_profile.pitch,"pitch":gun.shot_audio.pitch_scale,"last":gun.last_shot_sound_profile.last,"aimed":aimed})
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	gun = lab.player.weapon
	gun.aim_override = Vector2(1000,724)
	gun.shot_fired.connect(record)
	await frames(8)
	check(gun.tuning.low_ammo_threshold == .30 and gun.tuning.low_ammo_pitch == 1.30 and gun.tuning.last_shot_accent == 1,"default warning begins at 30 percent and ends at a distinct higher tone")
	check(not gun.shot_sound_profile(22).low and gun.shot_sound_profile(21).low,"PPSh warning starts at 21 rounds, below 30 percent of its 71-round capacity")
	gun.tuning.apply_values({"magazine_capacity":100,"starting_reserve":0})
	lab.player.reset_to(Vector2(160,760))
	Input.action_press("core_fire")
	await frames(400)
	Input.action_release("core_fire")
	check(shots.size() == 100 and gun.shots_fired == 100 and gun.magazine_ammo == 0,"a real automatic magazine still fires exactly 100 rounds")
	check(shots.slice(0,70).all(func(shot): return not shot.low and shot.factor == 1 and shot.pitch >= .96 and shot.pitch <= 1.04),"the first 70 shots preserve the original sound and pitch variation")
	check(shots.slice(70).all(func(shot): return shot.low and shot.factor > 1 and shot.pitch > 1.04),"all final 30 shots have an audible tonal shift beyond ordinary pitch jitter")
	var increasing := true
	for i in range(71,100): increasing = increasing and shots[i].factor >= shots[i-1].factor
	check(increasing and is_equal_approx(shots[-1].factor,1.30),"warning intensity increases towards the last round")
	check(shots.filter(func(shot): return shot.last).size() == 1 and gun.empty_sounds_played == 1 and shots[-1].rounds == 0,"exactly the last real bullet produces the empty-magazine accent")
	var ordinary := gun.shot_audio.stream as AudioStreamWAV
	var accent := gun.magazine_empty_audio.stream as AudioStreamWAV
	check(accent.data != ordinary.data and accent.get_length() > ordinary.get_length(),"the last bullet layers its own metallic tail instead of replacing the gunshot")
	check(gun.magazine_empty_audio.volume_db == gun.tuning.shot_volume,"last accent respects the common shot volume")
	await frames(2)
	Input.action_press("core_fire")
	await frames(12)
	Input.action_release("core_fire")
	check(gun.empty_sounds_played == 1 and gun.shots_fired == 100 and gun.dry_clicks == 1,"an empty trigger only gives the dry click without replaying the last-bullet cue")
	gun.reserve_ammo = 999
	check(gun.shot_sound_profile(15).low and gun.shot_sound_profile(100).pitch == 1,"reserve size cannot hide a low magazine or warn on a full one")
	gun.tuning.apply_values({"low_ammo_threshold":.15})
	check(not gun.shot_sound_profile(16).low and gun.shot_sound_profile(15).low,"the configurable threshold can narrow the warning to 15 percent")
	gun.tuning.apply_values({"low_ammo_threshold":0})
	check(not gun.shot_sound_profile(1).low and gun.shot_sound_profile(1).pitch == 1 and gun.shot_sound_profile(1).last,"threshold zero disables tonal changes while retaining the independent last-shot cue")
	gun.tuning.apply_values({"low_ammo_threshold":.30,"low_ammo_pitch":.8})
	check(gun.shot_sound_profile(15).pitch < 1 and is_equal_approx(gun.shot_sound_profile(1).pitch,.8),"a lower-pitched warning is also supported")
	gun.tuning.apply_values({"low_ammo_pitch":1.30,"last_shot_accent":0,"magazine_capacity":1})
	lab.player.reset_to(Vector2(160,760))
	shots.clear()
	gun.tuning.set_fire_mode(1)
	Input.action_press("core_aim")
	Input.action_press("core_fire")
	await frames(10)
	Input.action_release("core_fire")
	Input.action_release("core_aim")
	check(shots.size() == 1 and shots[0].last and shots[0].aimed and not shots[0].low and gun.empty_sounds_played == 0,"one-round magazines, aimed single fire and a disabled last accent remain valid")
	gun.tuning.apply_values({"magazine_capacity":10,"last_shot_accent":.5,"reload_duration":.5,"starting_reserve":30})
	lab.player.reset_to(Vector2(160,760))
	gun.magazine_ammo = 1
	Input.action_press("core_fire")
	await frames(3)
	Input.action_release("core_fire")
	check(gun.empty_sounds_played == 1 and is_equal_approx(gun.magazine_empty_audio.volume_db,gun.tuning.shot_volume+linear_to_db(.5)),"accent intensity scales its volume without changing ammunition")
	gun.request_reload()
	await frames(40)
	Input.action_press("core_fire")
	await frames(3)
	Input.action_release("core_fire")
	check(not gun.last_shot_sound_profile.low and gun.last_shot_sound_profile.pitch == 1 and gun.empty_sounds_played == 1,"a reloaded full magazine restores the normal gunshot tone")
	gun.magazine_ammo = 1
	await frames(10)
	Input.action_press("core_fire")
	await frames(3)
	Input.action_release("core_fire")
	check(gun.empty_sounds_played == 2,"a later emptied magazine receives one new accent")
	paused = true
	var count := gun.empty_sounds_played
	await frames(20)
	check(gun.empty_sounds_played == count,"pause cannot replay a terminal shot cue")
	paused = false
	var path := "/private/tmp/ammo-audio-%d.cfg" % OS.get_process_id()
	gun.tuning.save_saved(path)
	var loaded := CoreShootingSettings.new()
	check(loaded.load_saved(path) == OK and loaded.low_ammo_threshold == .30 and loaded.low_ammo_pitch == 1.30 and loaded.last_shot_accent == .5,"sound feedback parameters survive a shooting-profile roundtrip")
	var legacy := ConfigFile.new()
	legacy.set_value("shooting","damage",30)
	legacy.save(path)
	loaded = CoreShootingSettings.new()
	check(loaded.load_saved(path) == OK and loaded.low_ammo_threshold == .30 and loaded.last_shot_accent == 1,"old profiles receive the new default sound feedback")
	DirAccess.remove_absolute(path)
	check(lab.shooting_overlay.rows.has("low_ammo_threshold") and lab.shooting_overlay.rows.has("low_ammo_pitch") and lab.shooting_overlay.rows.has("last_shot_accent"),"F4 exposes all three sound feedback controls")
	lab._recover()
	check(gun.empty_sounds_played == 0 and not gun.magazine_empty_audio.playing and gun.last_shot_sound_profile.pitch == 1,"level reset clears the accent and its sound diagnostics")
	for audio_player in [gun.shot_audio,gun.hit_audio,gun.kill_audio,gun.reload_audio,gun.magazine_empty_audio]: audio_player.stop()
	lab.queue_free()
	await process_frame
	await create_timer(.12).timeout
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
