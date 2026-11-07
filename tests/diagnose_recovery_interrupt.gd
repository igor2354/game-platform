extends SceneTree
## Regression for the live debugger error: interruption before the first recovery tick.
var failures:=0
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var app=preload("res://scripts/campaign/frontend.gd").new();app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("recovery-diagnosis-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory);root.add_child(app)
	for character in ["sofia","harry"]:
		app.selected_character=character;app.selected_level="terra";app.launch(true)
		for frame in 5:await physics_frame;await process_frame
		var hero=app.game.player;var r=hero.blast_ragdoll
		for phase in [0.0,.2,.5]:
			r.start(Vector2.ZERO,2,.12);r._begin_recovery(hero.global_position)
			check(r.recovery_points.has("neck") and r.recovery_points.size()==r.recovery_source.points.size(),character+" complete points published before first recovery tick")
			if phase>0:r._tick_recovery(phase)
			var neck: Vector2=r.recovery_points.neck
			r.start(Vector2(-240,-310),2,.12)
			check(not r.recovering and not r.recovery_finished and r.rig.simulation_enabled,character+" repeated blast resumes physical simulation")
			check(r.rig.joints[0].global_position.distance_to(neck)<.001 and r.rig.joints.all(func(j):return not j.node_a.is_empty() and not j.node_b.is_empty()),character+" interruption keeps current joint anchors and all connections")
			r.cancel();for frame in 2:await physics_frame;await process_frame
		await app.return_to_menu()
	print("RECOVERY INTERRUPT ",checks," checks / ",failures," failures")
	app.queue_free();for frame in 4:await process_frame
	quit(1 if failures else 0)
