extends SceneTree
## Registration-only review: originals stay unchanged; no runtime connection.
const MEDIA = preload("res://tools/media_paths.gd")
var destination: String
class Sheet extends Node2D:
	var source: Texture2D
	var kit: Texture2D
	var legs: Texture2D
	func piece(texture: Texture2D,region: Rect2,a: Vector2,b: Vector2,target_a: Vector2,target_b: Vector2) -> void:
		var amount := target_a.distance_to(target_b)/a.distance_to(b)
		var angle := (target_b-target_a).angle()-(b-a).angle()
		var basis := Transform2D(angle,Vector2.ZERO).scaled(Vector2.ONE*amount)
		basis.origin = target_a-basis.basis_xform(a)
		var display := Transform2D(Vector2(1.5,0),Vector2(0,1.5),Vector2(540,115))
		draw_set_transform_matrix(display*basis)
		draw_texture_rect_region(texture,region,region)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_string(font,Vector2(40,45),"01 · Контроль сборки без деформации деталей",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color.WHITE)
		draw_string(font,Vector2(40,85),"Выбранный профиль",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
		draw_string(font,Vector2(800,85),"Сборка: сохранены формы PNG",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
		draw_texture_rect_region(source,Rect2(65,115,300,711),Rect2(315,0,200,474))
		# Each attachment uses ONE scale for both axes; no squeezing to fit bones.
		piece(legs,Rect2(730,30,440,850),Vector2(925,130),Vector2(1010,805),Vector2(381,244),Vector2(384,339))
		piece(kit,Rect2(100,610,170,285),Vector2(175,640),Vector2(185,860),Vector2(384,339),Vector2(380,425))
		piece(kit,Rect2(350,650,320,235),Vector2(430,725),Vector2(430,860),Vector2(380,425),Vector2(380,450))
		piece(kit,Rect2(70,315,210,290),Vector2(150,355),Vector2(175,565),Vector2(374,100),Vector2(374,170))
		piece(kit,Rect2(400,315,215,290),Vector2(455,345),Vector2(550,560),Vector2(374,170),Vector2(397,229))
		piece(kit,Rect2(725,330,190,270),Vector2(805,365),Vector2(815,570),Vector2(397,229),Vector2(399,267))
		piece(legs,Rect2(200,30,470,850),Vector2(385,130),Vector2(515,805),Vector2(385,244),Vector2(388,339))
		piece(kit,Rect2(730,915,170,305),Vector2(810,950),Vector2(800,1180),Vector2(388,339),Vector2(383,425))
		piece(kit,Rect2(350,650,320,235),Vector2(430,725),Vector2(430,860),Vector2(383,425),Vector2(383,450))
		piece(kit,Rect2(980,60,290,250),Vector2(1120,100),Vector2(1120,250),Vector2(386,203),Vector2(385,244))
		piece(kit,Rect2(690,0,205,315),Vector2(785,40),Vector2(790,280),Vector2(388,76),Vector2(386,203))
		piece(kit,Rect2(70,0,270,320),Vector2(200,40),Vector2(225,290),Vector2(398,15),Vector2(388,88))
		piece(kit,Rect2(700,610,205,290),Vector2(820,650),Vector2(775,865),Vector2(378,100),Vector2(378,170))
		piece(kit,Rect2(1030,610,185,290),Vector2(1130,650),Vector2(1110,865),Vector2(378,170),Vector2(401,229))
		piece(kit,Rect2(70,915,220,300),Vector2(160,950),Vector2(170,1170),Vector2(401,229),Vector2(403,267))
		draw_string(font,Vector2(40,865),"Рабочая разметка суставов. Это проверка совместимости, не готовый игровой риг.",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("ffc878"))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1400,900)
	root.content_scale_size = Vector2i(1400,900)
	RenderingServer.set_default_clear_color(Color("23313a"))
	var folder := ProjectSettings.globalize_path("res://../../../1_Персонажи/Для анимации/Кандидаты/Зомби_мужчина_01_Подготовка_2026-11-01/")
	var sheet := Sheet.new()
	sheet.source = ImageTexture.create_from_image(Image.load_from_file(folder+"00_source_sheet.png"))
	sheet.kit = ImageTexture.create_from_image(Image.load_from_file(folder+"02_costume_layers_candidate.png"))
	sheet.legs = ImageTexture.create_from_image(Image.load_from_file(folder+"03_thighs_addendum_v1.png"))
	root.add_child(sheet)
	await process_frame
	await RenderingServer.frame_post_draw
	destination = MEDIA.path("docs/core/mannequin_assembly_20261101/registration_review.png")
	var result := root.get_texture().get_image().save_png(destination)
	print("REGISTRATION REVIEW ",result," ",destination)
	quit(result)
