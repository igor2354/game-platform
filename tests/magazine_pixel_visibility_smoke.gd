extends SceneTree
## Real empty shot/R, then GPU readback: a physical body alone is insufficient.
var checks := 0
var failures := 0
var app
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
 for i in n: await physics_frame; await process_frame
func check(ok: bool,label: String) -> void:
 checks += 1
 print("PASS " if ok else "FAIL ",label)
 if not ok: failures += 1
func magazine_pixels(lab: CoreMovementLab,drop: RigidBody2D) -> bool:
 await frames(3)
 RenderingServer.force_draw(false)
 var image := root.get_texture().get_image()
 var center: Vector2 = lab.aim_cursor._canvas_projection()*drop.global_position
 center *= Vector2(image.get_size())/root.get_visible_rect().size
 var area := Rect2i(Vector2i(center)-Vector2i(55,55),Vector2i(110,110)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
 if not area.has_area(): return false
 var shown := image.get_region(area).get_data()
 drop.hide()
 await frames(3)
 RenderingServer.force_draw(false)
 var hidden := root.get_texture().get_image().get_region(area).get_data()
 drop.show()
 return shown != hidden
func run() -> void:
 app = preload("res://scripts/campaign/frontend.gd").new()
 app.load_user_settings = false
 app.test_settings_directory = "/private/tmp/magazine-pixels-%d" % OS.get_process_id()
 DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
 root.add_child(app)
 var cases := [[false,"prologue","mp40","world"],[true,"prologue","mp40","world"],[true,"prologue_v2","mp40","world"],[true,"hub","mp40","world"],[true,"terra","mp40","world"],[false,"prologue","mp40","native"],[false,"prologue","mp40","stable"],[false,"prologue","stg44","world"],[false,"prologue","m1911","world"],[false,"prologue","svt","world"],[false,"prologue","mp40","limited"]]
 for entry in cases:
  app.selected_level = entry[1]
  app.selected_weapon = entry[2]
  app.launch(entry[0])
  await frames(12)
  var lab: CoreMovementLab = app.game
  var gun := lab.player.weapon
  var tag := str(entry)
  var ui := CanvasLayer.new()
  ui.layer = 80
  lab.add_child(ui)
  var marker := Node2D.new()
  marker.top_level = true
  marker.position = Vector2(100,220)
  marker.draw.connect(func(): marker.draw_rect(Rect2(0,0,9,9),Color.MAGENTA))
  ui.add_child(marker)
  lab.display_options.resolution = Vector2i(960,540) if entry[3] == "limited" else Vector2i.ZERO
  lab.camera_settings.world_pixel_enabled = entry[3] == "world"
  lab.camera_settings.stable_pixel_enabled = entry[3] == "stable"
  lab._camera_settings_changed()
  gun.aim_override = lab.player.position+Vector2(500,-40)
  gun.aim_cursor.focus_override = true
  gun.aim_cursor.sync_context()
  gun.tuning.sound_enabled = false
  gun.tuning.reload_duration = 1.0
  gun.magazine_ammo = 1
  gun.reserve_ammo = 200
  gun._update_aim()
  gun._fire()
  check(gun.magazine_ammo == 0,tag+" final shot consumes the last round")
  var event := InputEventAction.new()
  event.action = "core_reload";event.pressed = true
  root.push_input(event,true)
  await frames(30)
  var drops := gun.get_children().filter(func(c): return c.has_meta("dropped_magazine"))
  check(gun.reloading and gun.empty_magazine_detached and drops.size() == 1,tag+" R creates exactly one physical magazine")
  if drops.size() == 1:
   var drop := drops[0] as RigidBody2D
   paused = true
   # Isolate the loose item's pixels from the character's possible occlusion.
   lab.player.visuals.hide()
   var position := drop.global_position
   await frames(3)
   RenderingServer.force_draw(false)
   var presented := root.get_texture().get_image()
   var ui_pixel := Vector2(104,224)*Vector2(presented.get_size())/root.get_visible_rect().size
   check(presented.get_pixelv(Vector2i(ui_pixel)).is_equal_approx(Color.MAGENTA) and lab.telemetry.get_viewport() == root,tag+" top-level UI remains on the native canvas")
   check(await magazine_pixels(lab,drop),tag+" released magazine contributes pixels to the presented world")
   lab.display_options.resolution = Vector2i.ZERO
   for enabled in [false,true]:
    lab.camera_settings.world_pixel_enabled = enabled
    lab.camera_settings.stable_pixel_enabled = false
    lab._camera_settings_changed()
    check(await magazine_pixels(lab,drop),tag+" existing drop remains visible after world-grid toggle "+str(enabled))
    check(drop.global_position.is_equal_approx(position),tag+" rendering switch does not move physical body")
   lab.player.visuals.show()
   paused = false
   gun.cancel_reload()
   check(gun.request_reload(),tag+" interrupted reload restarts")
   await frames(160)
   check(gun.get_children().filter(func(c): return c.has_meta("dropped_magazine")).size() == 1 and drop.sleeping,tag+" retry cannot duplicate the magazine and it settles on the floor")
  await app.return_to_menu()
  await frames(2)
 app.queue_free()
 await frames(2)
 print("MAGAZINE PIXELS: %d/%d; failures=%d" % [checks-failures,checks,failures])
 quit(int(failures > 0))
