extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
func _initialize() -> void:
	var source := ProjectSettings.globalize_path("res://../../../1_Персонажи/Для анимации/Кандидаты/Зомби_мужчина_01_Подготовка_2026-11-01/00_source_sheet.png")
	var image := Image.load_from_file(source)
	var crop := image.get_region(Rect2i(320,5,125,460))
	var path := MEDIA.path("docs/core/profile_rebuild_20261101/source_crop.png")
	crop.save_png(path)
	crop.resize(500,1840,Image.INTERPOLATE_NEAREST)
	crop.save_png(MEDIA.path("docs/core/profile_rebuild_20261101/source_zoom.png"))
	print(path)
	quit()
