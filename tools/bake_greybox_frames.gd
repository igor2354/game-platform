extends SceneTree
# Bakes the greybox rig into frame-by-frame sheets for the hybrid body:
# assets/greybox_frames/<anim>.png (one horizontal strip per animation) and
# frames.json (frame count, fps, loop, per-frame shoulder anchor, events).
# Needs a renderer, so run it with a window, then re-import:
#   Godot --path . -s res://tools/bake_greybox_frames.gd
#   Godot --headless --path . --import
#
# Armed animations are baked without arms: in game the arms are a separate
# layer that holds the weapon and follows the aim. Roll and climb keep them.

const OUT_DIR := "res://assets/greybox_frames/"
const FRAME := Vector2i(224,320)
# Feet (the rig origin) sit here in every frame.
const PIVOT := Vector2(112,300)
const FPS := 12.0
const ANIMS := ["idle","walk","run","roll","climb"]
const ARMED := ["idle","walk","run"]
const ARM_BONES := ["arm_upper_l","arm_lower_l","hand_l","arm_upper_r","arm_lower_r","hand_r"]

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var view := SubViewport.new()
	view.size = FRAME
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var rig: HumanoidRig = load("res://scenes/characters/humanoid_greybox.tscn").instantiate()
	rig.position = PIVOT
	view.add_child(rig)
	await process_frame
	rig.tree.active = false
	var player: AnimationPlayer = rig.get_node("AnimationPlayer")
	var torso: Bone2D = rig.bones.torso
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var meta := {"frame_size":[FRAME.x,FRAME.y],"pivot":[PIVOT.x,PIVOT.y],"animations":{}}
	for anim_name in ANIMS:
		var anim := player.get_animation(anim_name)
		var count := maxi(1,roundi(anim.length*FPS))
		for bone in ARM_BONES: rig.bones[bone].get_node("art").visible = anim_name not in ARMED
		var sheet := Image.create(FRAME.x*count,FRAME.y,false,Image.FORMAT_RGBA8)
		var anchors := []
		player.play(anim_name)
		for i in count:
			player.seek(anim.length*i/count,true)
			player.pause()
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var image := view.get_texture().get_image()
			image.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(image,Rect2i(Vector2i.ZERO,FRAME),Vector2i(FRAME.x*i,0))
			# Torso in rig space: where the separate arms attach on this frame.
			var xf := rig.global_transform.affine_inverse()*torso.global_transform
			anchors.append([snappedf(xf.origin.x,0.01),snappedf(xf.origin.y,0.01),snappedf(xf.get_rotation(),0.0001)])
		sheet.save_png(ProjectSettings.globalize_path(OUT_DIR+anim_name+".png"))
		meta.animations[anim_name] = {"frames":count,"fps":count/anim.length,"loop":anim.loop_mode != Animation.LOOP_NONE,"armed":anim_name in ARMED,"torso":anchors,"events":_events(anim,count)}
		print("baked ",anim_name,": ",count," frames")
	var file := FileAccess.open(OUT_DIR+"frames.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(meta,"\t"))
	file.close()
	quit()

# Method-track events mapped to the frame they land on.
func _events(anim: Animation, count: int) -> Dictionary:
	var events := {}
	for track in anim.get_track_count():
		if anim.track_get_type(track) != Animation.TYPE_METHOD: continue
		for key in anim.track_get_key_count(track):
			var method_call: Dictionary = anim.track_get_key_value(track,key)
			var frame := roundi(anim.track_get_key_time(track,key)/anim.length*count)%count
			var event: String = method_call.args[0]
			if not events.has(event): events[event] = []
			events[event].append(frame)
	return events
