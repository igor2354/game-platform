extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var folder := preload("res://tools/media_paths.gd").path("docs/mannequin_candidates/Основа_стойки_2026-11-06/Равные_ноги_плавная_ходьба_2026-11-08")
	var packed: PackedScene=load(folder.path_join("EqualLegRig.scn"))
	var model: Node2D=packed.instantiate()
	model.transform=Transform2D.IDENTITY
	root.add_child(model)
	var scene := PackedScene.new()
	assert(scene.pack(model)==OK)
	assert(ResourceSaver.save(scene,"res://resources/core/user_standing/Standing.scn",ResourceSaver.FLAG_COMPRESS)==OK)
	for dependency in ResourceLoader.get_dependencies("res://resources/core/user_standing/Standing.scn"):
		assert(not str(dependency).contains("farleg.png"))
	print("EQUAL_LEG_MODEL_PROMOTED")
	quit()
