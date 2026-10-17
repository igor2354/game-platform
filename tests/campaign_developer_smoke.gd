extends "res://tests/developer_mode_smoke.gd"
## Run the complete existing workspace/profile suite against the campaign scene.
const CATALOG = preload("res://scripts/campaign/catalog.gd")

func _initialize() -> void:
	var temporary := OS.get_environment("TEMP") if OS.has_feature("windows") else "/private/tmp"
	directory = temporary.path_join("campaign-developer-%d" % OS.get_process_id())
	call_deferred("run")

func new_lab(saved := false) -> void:
	lab = load("res://scenes/campaign/prologue.tscn").instantiate()
	lab.load_user_settings = saved
	lab.get_node("World/Player").character_id = "sofia"
	lab.settings_path = directory+"/movement.cfg"
	lab.shooting_settings_path = directory+"/shooting.cfg"
	lab.camera_settings_path = directory+"/camera.cfg"
	lab.zombie_settings_path = directory+"/zombie.cfg"
	lab.ragdoll_settings_path = directory+"/ragdoll.cfg"
	root.add_child(lab)
	if not saved: CATALOG.equip(lab.player.weapon,"stg44")
	else: lab.player.weapon.equipped_weapon_id = "stg44"
	lab.shooting_overlay.defaults.apply_values(CATALOG.WEAPONS[0].values)
	lab.shooting_overlay._sync()
