extends SceneTree
var lab: CoreMovementLab
var gun: CoreShootingController
var checks := 0
var failures := 0
var shots: Array[Dictionary] = []
var shot_audio_finished := false
var profile := "/private/tmp/combat-feel-%d.cfg" % OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func release_inputs() -> void:
	Input.action_release("core_fire")
	Input.action_release("core_aim")
func reset_at(point: Vector2) -> void:
	release_inputs()
	lab._recover()
	lab.player.reset_to(point)
	shots.clear()
	await frames(8)
func record(origin: Vector2,direction: Vector2,aimed: bool,_spread: float) -> void:
	shots.append({"back":gun.recoil_back,"angle":gun.recoil_angle,"aimed":aimed,"error":absf((gun.aim_point-origin).normalized().cross(direction))})
func single_shot() -> void:
	Input.action_press("core_fire")
	await frames(2)
	Input.action_release("core_fire")
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	lab.shooting_settings_path = profile
	root.add_child(lab)
	gun = lab.player.weapon
	gun.shot_audio.finished.connect(func() -> void: shot_audio_finished = true)
	gun.aim_override = Vector2(1000,400)
	gun.tuning.set_fire_mode(CoreShootingSettings.FireMode.SINGLE)
	gun.shot_fired.connect(record)
	await frames(8)
	await single_shot()
	check(gun.shots_fired == 1 and gun.recoil_back > 0 and gun.recoil_angle > 0,"a real shot kicks the weapon backwards and lifts its barrel")
	check(gun.effects.any(func(effect: Dictionary) -> bool: return effect.get("kind","") == "casing"),"shots eject visible casings")
	# Audio runs in wall-clock time. A short shot can finish before two physics
	# ticks on a busy runner; natural completion also proves it was played.
	await process_frame
	await process_frame
	# Physics may run twice before an idle frame; the camera applies its
	# impulse in _process, so observe it after an actual process update.
	check(lab.camera.offset.length() > 0 and lab.camera_kick.length() > 0,"a shot drives directional camera motion")
	check((gun.shot_audio.playing or shot_audio_finished) and gun.shot_audio.volume_db == gun.tuning.shot_volume,"shot sound plays at the configured volume")
	var hip_back: float = shots[0].back
	var hip_angle: float = shots[0].angle
	await frames(65)
	check(gun.recoil_back < .001 and gun.recoil_angle < .001 and lab.camera.offset.length() < .01,"weapon and camera settle smoothly after firing stops")
	check(gun.effects.is_empty(),"temporary casings and impacts expire")
	await reset_at(Vector2(160,760))
	Input.action_press("core_aim")
	await single_shot()
	check(shots[0].aimed and shots[0].error < .00001,"visual recoil preserves ADS bullet accuracy")
	check(absf(shots[0].back-hip_back*.55) < .001 and absf(shots[0].angle-hip_angle*.55) < .001,"aiming reduces visual recoil")
	paused = true
	var state := [gun.recoil_back,gun.recoil_angle,lab.camera.offset,lab.camera_kick,lab.camera_shake]
	await frames(8)
	check(state == [gun.recoil_back,gun.recoil_angle,lab.camera.offset,lab.camera_kick,lab.camera_shake],"pause freezes camera and weapon feedback")
	paused = false
	await reset_at(Vector2(2250,760))
	var target := lab.level.enemies[0]
	gun.aim_override = target.aim_point_for_part("torso")
	gun.tuning.sway_radius = 0
	Input.action_press("core_aim")
	await single_shot()
	await frames(6)
	check(target.health == 75 and gun.hit_sounds_played == 1 and gun.kill_sounds_played == 0,"a nonlethal projectile produces only the enemy hit sound")
	check(target.reaction_offset.length() > 0 and target.position == Vector2(2460,760),"impact animates the target without moving its collision body")
	check(gun.hit_marker_left > 0 and gun.kill_marker_left == 0,"a nonlethal hit displays the ordinary hit marker")
	check(gun.hit_audio.volume_db == gun.tuning.hit_volume,"hit sound uses its separate volume setting")
	await reset_at(Vector2(2250,760))
	Input.action_press("core_aim")
	gun.tuning.damage = 100
	await single_shot()
	await frames(6)
	check(target.health == 0 and gun.kills == 1 and gun.kill_sounds_played == 1 and gun.hit_sounds_played == 0,"a lethal projectile produces one kill cue without doubling the hit sound")
	check(gun.kill_marker_left > 0 and gun.effects.any(func(effect: Dictionary) -> bool: return effect.get("killed",false)),"kills show their own marker and stronger impact burst")
	check(target.death_progress > 0 and target.collision_layer == 0,"the defeated target visibly falls and disables collision")
	check(gun.kill_audio.volume_db == gun.tuning.kill_volume,"kill cue uses its separate volume setting")
	await frames(16)
	check(target.death_progress == 1 and gun.kills == 1,"the death animation settles without awarding another kill")
	await reset_at(Vector2(620,760))
	gun.aim_override = Vector2(900,724)
	Input.action_press("core_aim")
	await single_shot()
	check(gun.hit_sounds_played == 0 and gun.kill_sounds_played == 0,"wall impacts never play enemy hit or kill cues")
	var shot_stream := gun.shot_audio.stream as AudioStreamWAV
	var hit_stream := gun.hit_audio.stream as AudioStreamWAV
	var kill_stream := gun.kill_audio.stream as AudioStreamWAV
	check(shot_stream.data != hit_stream.data and hit_stream.data != kill_stream.data and kill_stream.data.size() > hit_stream.data.size(),"shot, hit and kill sounds have distinct waveforms and durations")
	await reset_at(Vector2(160,760))
	gun.aim_override = Vector2(1000,400)
	gun.tuning.set_fire_mode(CoreShootingSettings.FireMode.AUTO)
	Input.action_press("core_fire")
	var bounded := true
	for i in 100:
		await physics_frame
		bounded = bounded and gun.recoil_back <= 12 and gun.recoil_angle <= deg_to_rad(12)+.001 and lab.camera_kick.length() <= 12.01 and lab.camera_shake <= 5 and lab.camera.offset.length() < 20
	check(bounded and gun.shots_fired > 20,"sustained fire keeps camera shake and recoil bounded")
	paused = true
	var overlay := lab.shooting_overlay
	overlay.toggle()
	check(overlay.tabs.get_tab_count() == 6 and overlay.rows.has("kill_volume") and overlay.rows.has("camera_shake"),"F4 exposes recoil, sound and damage tabs")
	overlay.tabs.current_tab = 3
	overlay.rows.recoil_back.slider.value = 7
	overlay.rows.camera_kick.slider.value = 4
	overlay.tabs.current_tab = 4
	overlay.rows.hit_volume.slider.value = -22
	overlay.save_profile()
	var loaded := CoreShootingSettings.new()
	check(loaded.load_saved(profile) == OK and loaded.recoil_back == 7 and loaded.camera_kick == 4 and loaded.hit_volume == -22,"feedback parameters can be changed on pause and saved")
	check((load("res://resources/core/shooting.tres") as CoreShootingSettings).recoil_back == 5,"feedback tuning leaves source defaults unchanged")
	overlay.reset_profile()
	check(gun.tuning.recoil_back == 5 and gun.tuning.hit_volume == -13,"Reset restores feedback defaults")
	overlay.toggle()
	paused = false
	await reset_at(Vector2(160,760))
	check(gun.kills == 0 and gun.kill_marker_left == 0 and gun.recoil_back == 0 and gun.effects.is_empty() and lab.camera.offset == Vector2.ZERO and not gun.hit_audio.playing and not gun.kill_audio.playing,"R clears recoil, camera feedback, sounds, death state and temporary effects")
	gun.tuning.recoil_back = 0
	gun.tuning.recoil_angle = 0
	gun.tuning.camera_kick = 0
	gun.tuning.camera_shake = 0
	await single_shot()
	check(gun.shots_fired == 1 and gun.recoil_back == 0 and gun.recoil_angle == 0 and lab.camera.offset == Vector2.ZERO,"zero feedback settings disable recoil and shake while shooting still works")
	release_inputs()
	gun.shot_audio.stop()
	gun.hit_audio.stop()
	gun.kill_audio.stop()
	# Let the audio mixer release its final playback before quitting the test.
	await create_timer(.12).timeout
	lab.queue_free()
	await process_frame
	DirAccess.remove_absolute(profile)
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
