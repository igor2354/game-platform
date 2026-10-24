extends "res://tests/recoil_mouse_smoke.gd"
## Exercise the existing real-mouse/ADS/fire-mode matrix through the new renderer.
func _initialize() -> void:
	node_added.connect(_enable_stable)
	super._initialize()

func _enable_stable(node: Node) -> void:
	if not node is CoreMovementLab: return
	var temporary := "/private/tmp/stable-mouse-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(temporary)
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:
		node.set(key,temporary.path_join(key+".cfg"))
	node.ready.connect(func():
		node.camera_settings.stable_pixel_enabled = true
		node._camera_settings_changed())
