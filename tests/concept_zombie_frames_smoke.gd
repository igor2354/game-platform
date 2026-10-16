extends SceneTree
const FRAMES = preload("res://scripts/core/concept_zombie_frames.gd")
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
	for index in count:
		await physics_frame
		await process_frame
func run() -> void:
	FRAMES.prepare()
	check(FRAMES.metadata.size() == 22,"all 22 gameplay states have complete painted frame data")
	for clip in FRAMES.CLIPS:
		var image := FRAMES.texture(clip).get_image()
		var mask := FRAMES.mask(clip).get_image()
		var unique := {}
		var valid := image.get_size() == Vector2i(1024,1024) and mask.get_size() == image.get_size()
		for frame in 16:
			var origin := Vector2i(frame%4,frame/4)*256
			var cell := image.get_region(Rect2i(origin,Vector2i(256,256)))
			var used := cell.get_used_rect()
			valid = valid and used.has_area() and used.position.x >= 1 and used.end.x < 256 and used.end.y == 224
			unique[hash(cell.get_data())] = true
			for part in FRAMES.PARTS:
				var a := FRAMES.rect_for(clip,frame,part,1)
				var b := FRAMES.rect_for(clip,frame,part,-1)
				valid = valid and a.has_area() and a.size.is_equal_approx(b.size) and is_equal_approx(a.position.x,-b.end.x)
			# Every nontransparent sampled sprite pixel has exactly one damage
			# owner, and transparent padding does not acquire visible artwork.
			for y in range(0,256,3):
				for x in range(0,256,3):
					if cell.get_pixel(x,y).a <= .05: continue
					var id := roundi(mask.get_pixelv(origin+Vector2i(x,y)).r*255)
					valid = valid and id in range(1,7)
		check(valid and unique.size() == 16,"16 distinct whole frames, ground alignment, masks and mirrored hit boxes: "+clip)
	var idle_mask := FRAMES.mask("idle").get_image()
	var sleeves_match := true
	# Inspected opaque points on the painted near forearm/hand, far sleeve
	# and central chest. Prevent an arm being labelled as shirt or trouser.
	for sample in [[Vector2i(114,125),4],[Vector2i(112,141),4],[Vector2i(111,152),4],[Vector2i(162,137),3],[Vector2i(135,115),2]]:
		sleeves_match = sleeves_match and roundi(idle_mask.get_pixelv(sample[0]).r*255) == sample[1]
	check(sleeves_match,"painted forearms and hands belong to their own damage masks instead of torso/legs")
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.weapon.tuning.sound_enabled = false
	var zombie: CoreConceptZombie = lab.level.concept_zombie
	zombie.set_test_frozen(true)
	await frames(3)
	check(zombie.body_sprite is Sprite2D and zombie.body_sprite.hframes == 4 and zombie.body_sprite.texture.resource_path.contains("/frames/") and zombie.body_sprite.show_behind_parent,"normal appearance is one complete-frame Sprite2D behind F1 hit-zone overlays")
	zombie.hit_flash = .1
	zombie.last_hit_part = "torso"
	zombie.queue_redraw()
	await frames(2)
	check(zombie.body_sprite.material.get_shader_parameter("flash_part") == 2 and zombie.body_sprite.texture == FRAMES.texture("idle"),"a hit flashes the whole-frame shader without returning to the cutout renderer")
	zombie._sever_part("right_arm",Vector2.RIGHT)
	await frames(2)
	var hidden: Vector4 = zombie.body_sprite.material.get_shader_parameter("hidden_a")
	check(hidden.w == 1 and zombie.detached_sprites.size() == 1 and zombie.detached_sprites[0].texture == FRAMES.texture("idle"),"severed limb is masked from and cropped out of the same complete painted frame")
	zombie.reset_target()
	await frames(3)
	check(zombie.detached_sprites.is_empty() and zombie.body_sprite.material.get_shader_parameter("hidden_a") == Vector4.ZERO,"revival restores the complete frame and removes detached fragments")
	zombie.set_test_frozen(false)
	zombie.tuning.apply_values({"movement_enabled":false,"combat_enabled":false,"vision_enabled":false,"hearing_enabled":false})
	zombie.blast_ragdoll.start(Vector2(80,-50),.4,.12)
	await frames(3)
	check(not zombie.body_sprite.visible and zombie.blast_ragdoll.zombie_skin.sprite.texture.resource_path.contains("/frames/"),"blast uses one complete falling character frame while physics bodies stay active")
	lab.queue_free()
	await frames(4)
	print("WHOLE FRAMES: %d/%d passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
