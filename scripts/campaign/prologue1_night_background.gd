extends Node2D
## World-anchored distant scene; camera/player movement never relocates its art.
const ART = preload("res://resources/campaign/prologue1_night_background.png")
const CLEAN_ART = preload("res://resources/campaign/prologue1_night_clean.png")
const CONTINUATION_ART = preload("res://resources/campaign/prologue1_night_continuation.png")
const CONTINUATION_CLEAN_ART = preload("res://resources/campaign/prologue1_night_continuation_clean.png")
const EFFECT = preload("res://shaders/prologue1_night_background.gdshader")
const EFFECTS := ["wind","clouds","smoke","fire","water"]
# Fixed art calibration matching the accepted opening composition. These are
# reference values, not the current camera/viewport or the player's position.
const REFERENCE_VIEW := Vector2(1600,900)
const REFERENCE_ZOOM := .7
const REFERENCE_CAMERA_Y := -185.0
var route: Node2D
var lab: CoreMovementLab
var picture: Sprite2D
var effect_material: ShaderMaterial
var elapsed := 0.0
var opacity := 0.0
var continuation_picture: Sprite2D
var continuation_material: ShaderMaterial

func set_continuation_art(source: Texture2D,clean: Texture2D) -> bool:
	# Candidate textures can be supplied by the external preview tool. No file
	# lookup or automatic admission of unapproved media into the game/export.
	if source == null or clean == null or source.get_width()/float(source.get_height()) <= ART.get_width()/float(ART.get_height()): return false
	if not continuation_picture:
		continuation_picture = Sprite2D.new()
		continuation_picture.name = "SecondScreenPanorama"
		continuation_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		continuation_picture.z_index = -1
		add_child(continuation_picture)
		continuation_material = ShaderMaterial.new()
		continuation_material.shader = EFFECT
		continuation_picture.material = continuation_material
	continuation_picture.texture = source
	continuation_material.set_shader_parameter("clean_background",clean)
	var extent := (source.get_width()/float(source.get_height()))/(ART.get_width()/float(ART.get_height()))
	continuation_material.set_shader_parameter("source_extent_x",extent)
	# The shared overlap is spatial, not a time-based crossfade between scenes.
	effect_material.set_shader_parameter("right_fade_start",.94)
	_place_in_world()
	return true

func _place_in_world() -> void:
	if not picture or not route: return
	var view_size := REFERENCE_VIEW/REFERENCE_ZOOM
	var ratio := maxf(view_size.x/ART.get_width(),view_size.y/ART.get_height())*1.16
	picture.scale = Vector2.ONE*ratio
	picture.position = route.ORIGIN+Vector2(view_size.x*.5,-CoreMovementPlayer.HEIGHT*.5+REFERENCE_CAMERA_Y/REFERENCE_ZOOM+.08*view_size.y)
	if is_instance_valid(continuation_picture):
		var texture: Texture2D = continuation_picture.texture
		continuation_picture.scale = Vector2.ONE*ratio*ART.get_height()/float(texture.get_height())
		var extra_width := texture.get_width()*continuation_picture.scale.x-ART.get_width()*ratio
		continuation_picture.position = picture.position+Vector2(extra_width*.5,0)

func _ready() -> void:
	name = "NightForestBackground"
	process_mode = Node.PROCESS_MODE_ALWAYS
	picture = Sprite2D.new()
	picture.name = "DistantForest"
	picture.texture = ART
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	effect_material = ShaderMaterial.new()
	effect_material.shader = EFFECT
	effect_material.set_shader_parameter("clean_background",CLEAN_ART)
	picture.material = effect_material
	add_child(picture)
	set_continuation_art(CONTINUATION_ART,CONTINUATION_CLEAN_ART)
	call_deferred("_bind_lab")

func _bind_lab() -> void:
	var parent := get_parent()
	while parent:
		if parent is CoreMovementLab:
			lab = parent
			return
		parent = parent.get_parent()

func _process(delta: float) -> void:
	if not is_instance_valid(lab) or lab.camera_settings == null: return
	if not get_tree().paused: elapsed += delta
	update_background()

func update_background() -> void:
	var s := lab.camera_settings
	var x := (lab.player.global_position.x-float(route.ORIGIN.x))/float(route.UPM)
	var extended := is_instance_valid(continuation_picture)
	opacity = smoothstep(-6.0,-2.0,x)*(1.0-smoothstep(34.0,40.0,x) if extended else 1.0-smoothstep(16.0,22.0,x))
	visible = s.p1_night_enabled and opacity > .001
	for paint in [effect_material,continuation_material] if extended else [effect_material]:
		paint.set_shader_parameter("animation_time",elapsed)
		paint.set_shader_parameter("opacity",opacity)
		for key in EFFECTS:
			paint.set_shader_parameter(key+"_strength",s.get("p1_night_"+key+"_strength") if s.get("p1_night_"+key+"_enabled") else 0.0)
			paint.set_shader_parameter(key+"_speed",s.get("p1_night_"+key+"_speed"))
