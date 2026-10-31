extends RefCounted
signal changed
var settings_path := "user://display.cfg"
var resolution := Vector2i.ZERO # Native/automatic; keeps existing rendering by default.
var fullscreen := true
var hip_sensitivity := 1.0
var ads_sensitivity := 1.0

var tree: SceneTree
static func access(scene_tree: SceneTree,read_saved := true):
	var instance = scene_tree.root.get_meta("ubershrike_display_options") if scene_tree.root.has_meta("ubershrike_display_options") else null
	if instance == null:
		instance = load("res://scripts/ui/display_options.gd").new()
		instance.tree = scene_tree
		scene_tree.root.set_meta("ubershrike_display_options",instance)
		if read_saved and DisplayServer.get_name() != "headless" and instance.load_saved() == OK: instance.apply_window()
	return instance

func load_saved() -> Error:
	var config := ConfigFile.new()
	var result := config.load(settings_path)
	if result != OK: return result
	var width = config.get_value("display","width",0)
	var height = config.get_value("display","height",0)
	var full = config.get_value("display","fullscreen",true)
	var hip = config.get_value("input","hip_sensitivity",1.0)
	var ads = config.get_value("input","ads_sensitivity",1.0)
	if not width is int or not height is int or not full is bool: return ERR_INVALID_DATA
	if not valid_size(Vector2i(width,height)): return ERR_INVALID_DATA
	if not (hip is float or hip is int) or not (ads is float or ads is int): return ERR_INVALID_DATA
	if not valid_sensitivity(hip) or not valid_sensitivity(ads): return ERR_INVALID_DATA
	resolution = Vector2i(width,height)
	fullscreen = full
	hip_sensitivity = hip
	ads_sensitivity = ads
	return OK

func valid_size(value: Vector2i) -> bool:
	return value == Vector2i.ZERO or (value.x >= 960 and value.y >= 540 and value.x <= 7680 and value.y <= 4320)

func select(value: Vector2i,full: bool) -> Error:
	return apply_preferences(value,full,hip_sensitivity,ads_sensitivity)

func valid_sensitivity(value: float) -> bool:
	return is_finite(value) and value >= .1 and value <= 3.0

func aim_sensitivity(aiming: bool) -> float:
	return ads_sensitivity if aiming else hip_sensitivity

func apply_preferences(value: Vector2i,full: bool,hip: float,ads: float) -> Error:
	if not valid_size(value) or not valid_sensitivity(hip) or not valid_sensitivity(ads): return ERR_INVALID_PARAMETER
	resolution = value
	fullscreen = full
	hip_sensitivity = hip
	ads_sensitivity = ads
	apply_window()
	var config := ConfigFile.new()
	config.set_value("display","width",resolution.x)
	config.set_value("display","height",resolution.y)
	config.set_value("display","fullscreen",fullscreen)
	config.set_value("input","hip_sensitivity",hip_sensitivity)
	config.set_value("input","ads_sensitivity",ads_sensitivity)
	return config.save(settings_path)

func apply_window() -> void:
	if DisplayServer.get_name() != "headless":
		var window := tree.root
		window.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
		if not fullscreen:
			var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
			var requested := resolution if resolution != Vector2i.ZERO else Vector2i(1280,720)
			window.size = requested.min((usable.size-Vector2i(24,64)).max(Vector2i(960,540)))
			window.position = usable.position+(usable.size-window.size)/2
	changed.emit()

func render_limit() -> Vector2i:
	return resolution

func toggle_fullscreen() -> void:
	fullscreen = tree.root.mode not in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN]
	apply_window() # F11 is temporary; persistence is explicit via Apply in settings.
