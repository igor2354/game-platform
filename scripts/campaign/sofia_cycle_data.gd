extends RefCounted
const WALK = preload("res://resources/campaign/sofia_walk_v4.png")
const RUN = preload("res://resources/campaign/sofia_run_v4.png")
const CROUCH = preload("res://resources/campaign/sofia_crouch_walk_v4.png")
const DOWN = preload("res://resources/campaign/sofia_down_aim_v4.png")
const clips = preload("res://resources/campaign/sofia_v4_landmarks.gd").CLIPS

static func texture(clip: String) -> Texture2D:
	return WALK if clip == "walk" else RUN if clip == "run" else CROUCH if clip == "crouch_walk" else DOWN

static func frame_count(clip: String) -> int:
	return clips[clip].frames.size()

static func source(clip: String,index: int) -> Dictionary:
	var data: Dictionary = clips[clip]
	var frame: Dictionary = data.frames[index]
	var ratio := texture(clip).get_size()/Vector2(data["size"][0],data["size"][1])
	var result := {"root":Vector2(frame.root[0],frame.root[1])*ratio,"scale":frame.scale/ratio.x,
		"box":Rect2(Vector2(frame.box[0],frame.box[1])*ratio,Vector2(frame.box[2],frame.box[3])*ratio)}
	for i in data["keys"].size():
		var point: Array = frame.points[i]
		result[data["keys"][i]] = Vector2(point[0],point[1])*ratio
	if clip == "down":
		# This drawing turns the torso toward the camera: the far socket is
		# across the chest, rather than 1.3 units behind the near socket.
		var column := index % 4
		result.right_shoulder = result.shoulder
		result.left_shoulder = Vector2(column*384+260,158+8*index)*ratio if index < 4 else Vector2(column*384+279,755)*ratio
	return result
