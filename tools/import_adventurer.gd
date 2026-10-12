extends SceneTree
# Imports rvros' "Animated Pixel Adventurer" (https://rvros.itch.io/animated-pixel-hero)
# as a frame-by-frame body for HybridBody: one strip per animation plus
# frames.json, in assets/thirdparty/rvros_adventurer/ (kept out of git: the
# pack's licence forbids redistributing it).
#   Godot --headless --path . -s res://tools/import_adventurer.gd -- "<path to Individual Sprites>"
#   Godot --headless --path . --import

const OUT_DIR := "res://assets/thirdparty/rvros_adventurer/"
# Our animation -> pack prefix, playback fps and the speed (rig units/s) at
# which the cycle plays at 1x. The pack has no walk, so walk reuses run.
const MAP := {
	"idle":{"prefix":"adventurer-idle","fps":6.0},
	"walk":{"prefix":"adventurer-run","fps":10.0,"speed":300.0},
	"run":{"prefix":"adventurer-run","fps":10.0,"speed":475.0},
	"roll":{"prefix":"adventurer-smrslt","fps":8.0},
	"climb":{"prefix":"adventurer-ladder-climb","fps":8.0,"speed":263.0},
}
# The greybox soldier is 220 rig units tall; the pixel hero is scaled to match.
const TARGET_HEIGHT := 220.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass the pack's 'Individual Sprites' folder after --")
		quit(1)
		return
	var source: String = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var meta := {"animations":{},"filter":"nearest"}
	var frame_size := Vector2i.ZERO
	for anim_name in MAP:
		var spec: Dictionary = MAP[anim_name]
		var frames: Array[Image] = []
		var i := 0
		while FileAccess.file_exists(source.path_join("%s-%02d.png" % [spec.prefix,i])):
			var image := Image.load_from_file(source.path_join("%s-%02d.png" % [spec.prefix,i]))
			image.convert(Image.FORMAT_RGBA8)
			frames.append(image)
			i += 1
		if frames.is_empty():
			push_error("No frames for "+spec.prefix)
			quit(1)
			return
		frame_size = frames[0].get_size()
		var strip := Image.create(frame_size.x*frames.size(),frame_size.y,false,Image.FORMAT_RGBA8)
		for f in frames.size(): strip.blit_rect(frames[f],Rect2i(Vector2i.ZERO,frame_size),Vector2i(frame_size.x*f,0))
		strip.save_png(ProjectSettings.globalize_path(OUT_DIR+anim_name+".png"))
		var entry := {"frames":frames.size(),"fps":spec.fps,"loop":anim_name != "roll","armed":false,"events":{}}
		if spec.has("speed"): entry.speed = spec.speed
		meta.animations[anim_name] = entry
		if anim_name == "idle":
			# Feet = bottom of the opaque pixels, centred on the body.
			var box := frames[0].get_used_rect()
			meta.pivot = [box.position.x+box.size.x*0.5,box.end.y]
			meta.scale = TARGET_HEIGHT/box.size.y
		print("imported ",anim_name,": ",frames.size()," frames")
	meta.frame_size = [frame_size.x,frame_size.y]
	var file := FileAccess.open(OUT_DIR+"frames.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(meta,"\t"))
	file.close()
	quit()
