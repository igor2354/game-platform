extends SceneTree
const LIVE = preload("res://scripts/core/live_zombie.gd")
const ART = preload("res://scripts/core/concept_zombie_art.gd")
var checks := 0
var failures := 0
var lab: CoreMovementLab
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	var folder := "user://live_zombie_test_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:
		lab.set(key,folder+key+".cfg")
	root.add_child(lab)
	lab.player.weapon.tuning.sound_enabled = false
	lab.ragdoll_settings.explosion_audio_enabled = false
	await frames(5)
	check(lab.moon_forest == null,"polygon has no forest background")
	var patrols := [lab.level.zombie,lab.level.concept_zombie,lab.level.indoor_zombie]
	for actor in patrols:
		check(actor.get_script() == LIVE,"all three patrols use live cutouts")
		check(actor.target == lab.player and actor.tuning == lab.zombie_settings,"shared AI and settings")
	var actor = lab.level.concept_zombie
	actor.set_test_frozen(true)
	var saved_size: Vector2 = actor.body_size
	var saved_walk: float = actor.walk_phase
	for clip in ["patrol","chase","crawl"]:
		actor.walk_phase = TAU
		actor.body_size = Vector2(32,64)
		var small: float = actor.locomotion_animation_phase(clip)
		actor.body_size = Vector2(96,192)
		check(absf(actor.locomotion_animation_phase(clip)*3-small) < .0001,"gait distance follows actor scale: "+clip)
	actor.body_size = saved_size
	actor.walk_phase = saved_walk
	actor.body_size = Vector2(19,192)
	check(actor.pose_scale().is_equal_approx(Vector2(3,3)),"collision width cannot squeeze the authored anatomy")
	actor.body_size = saved_size
	var textures = preload("res://scripts/core/mannequin_textures.gd")
	textures.prepare()
	for key in textures.REGIONS:
		var registered: Transform2D = textures.registration(key,Vector2.ZERO,Vector2(3,17))
		check(absf(registered.x.length()-registered.y.length()) < .00001 and absf(registered.x.dot(registered.y)) < .00001,"sprite registration has no stretch or shear: "+key)
		check(absf(registered.x.length()-.15) < .00001,"all parts share one source-pixel scale: "+key)
	for clip in ["patrol","chase"]:
		var stride := 6.0 if clip == "patrol" else 10.0
		var displacement := 2.0*stride*(saved_size.y/64)*.1/.62
		actor.walk_phase = displacement/48*TAU
		check(absf(actor.locomotion_animation_phase(clip)-.1) < .0001,"planted foot cycle matches world travel: "+clip)
		var pose0: Dictionary = actor.LIVE_ART.pose(clip,0)
		var pose1: Dictionary = actor.LIVE_ART.pose(clip,.1)
		check(absf(pose0.joints.right_ankle.x-pose1.joints.right_ankle.x-2*stride*.1/.62) < .001,"IK preserves actual planted ankle travel: "+clip)
	actor.walk_phase = saved_walk
	var staged = preload("res://scripts/core/mannequin_art.gd")
	for clip in staged.STAGED:
		var valid := true
		for sample in 65:
			var pose: Dictionary = staged.pose(clip,float(sample)/64)
			for side in ["left","right"]:
				for limb in ["upper_arm","forearm","thigh","shin"]:
					var length: float = pose.parts[side+"_"+limb].dimensions.y
					valid = valid and absf(length-({"upper_arm":10.2396288995,"forearm":16.3713163796,"thigh":13.3575821165,"shin":13.4440507289}[limb])) < .001
		check(valid,"staged motions preserve limb lengths across 65 phases: "+clip)
	var contact: Dictionary = staged.pose("windup",1)
	var strike: Dictionary = staged.pose("strike",0)
	check(contact.parts.right_forearm.position.distance_to(strike.parts.right_forearm.position) < .001 and absf(contact.parts.right_forearm.rotation-strike.parts.right_forearm.rotation) < .001,"staged attack contact is continuous")
	actor.preview_clip = "sit"
	actor.preview_frame = 8
	check(actor.current_pose().parts.size() == 13,"animal seated pose available for preview")
	actor.preview_clip = ""
	for clip in ART.CLIPS:
		actor.animation_name = clip
		actor.animation_phase = .371
		var pose: Dictionary = actor.current_pose()
		check(pose.parts.size() == 13 and pose.joints.has("neck"),"continuous anatomy "+clip)
		for facing in [-1.0,1.0]:
			actor.facing = facing
			actor._sync_zones()
			check(actor.part_rect("head").has_area() and actor.ragdoll_pose().parts.size() == 13,"hit zones and physics "+clip)
	actor.animation_name = "patrol"
	actor.animation_phase = .371
	var a: Vector2 = actor.current_pose().parts.right_foot.position
	actor.animation_phase = .372
	check(a.distance_to(actor.current_pose().parts.right_foot.position) > .0001,"pose changes within a baked frame")
	var replacement := ImageTexture.create_from_image(Image.create(8,8,false,Image.FORMAT_RGBA8))
	actor.set_part_texture("head",replacement)
	check(actor.part_textures.head == replacement,"replacement texture can be assigned")
	actor.queue_redraw()
	await frames(2)
	actor.set_part_texture("head",null)
	check(actor.part_textures.is_empty(),"original texture restored")
	actor.reset_target()
	actor.set_test_frozen(false)
	actor.blast_ragdoll.start(Vector2(150,-80),.45,.12)
	await frames(5)
	check(actor.blast_ragdoll.active,"live actor enters physical fall")
	await frames(240)
	check(not actor.blast_ragdoll.active,"physical fall returns control")
	# Capture a real rendered polygon frame when run with a window.
	if DisplayServer.get_name() != "headless":
		lab.camera_settings.scale_reference_enabled = true
		lab._camera_settings_changed()
		lab.player.reset_to(Vector2(-6070,760))
		lab.player.set_invulnerable(true)
		actor.reset_target()
		actor.set_test_frozen(true)
		actor.animation_name = "patrol"
		actor.animation_phase = .37
		actor.queue_redraw()
		lab.camera_settings.apply_values({"camera_enabled":true,"zoom":2.0,"offset_x":140,"offset_y":-90,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
		lab._update_camera(true)
		await frames(8)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(preload("res://tools/media_paths.gd").path("docs/core/profile_rebuild_20261101/polygon.png"))
		actor.set_test_frozen(false)
		actor.reset_target()
		actor._sever_part("right_arm",Vector2.LEFT)
		actor.take_damage(100,Vector2.RIGHT)
		await frames(60)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(preload("res://tools/media_paths.gd").path("docs/core/profile_rebuild_20261101/corpse_detached.png"))
		actor.detached_parts.clear()
		actor.queue_redraw()
		await frames(2)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(preload("res://tools/media_paths.gd").path("docs/core/profile_rebuild_20261101/corpse_without_detached.png"))
	lab.queue_free()
	await frames(3)
	print("LIVE ZOMBIE: %d/%d passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
