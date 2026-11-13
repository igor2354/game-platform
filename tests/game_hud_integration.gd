extends SceneTree
var checks:=0
var failures:=0
var directory:=OS.get_environment("TEMP").path_join("game-hud-%d" % OS.get_process_id())
func _initialize(): run.call_deferred()
func check(ok: bool,text: String):
 checks+=1
 if ok: print("PASS ",text)
 else:
  failures+=1
  push_error("FAIL "+text)
func frames(n:=3):
 for i in n: await process_frame
func key(code: int):
 var event:=InputEventKey.new()
 event.physical_keycode=code
 event.pressed=true
 root.push_input(event,true)
 await frames()
func run():
 root.gui_embed_subwindows=true
 DirAccess.make_dir_recursive_absolute(directory)
 var menu=load("res://scenes/frontend.tscn").instantiate()
 menu.load_user_settings=false
 menu.test_settings_directory=directory
 root.add_child(menu)
 await frames()
 var export_path:=directory.path_join("hud.json")
 for route in ["native_polygon","legacy_polygon","prologue","prologue_v2","terra","hub"]:
  menu.selected_level=route
  menu.launch(route not in ["native_polygon","legacy_polygon"],route=="legacy_polygon")
  await frames(4)
  var stage=menu.game
  var native: bool=stage is Node3D
  var hud=stage.game_hud
  var dev=stage.developer.developer_mode if native else stage.developer_mode
  var gun=stage.combat.gun if native else stage.player.weapon
  if native: stage.paused=true
  else: paused=true
  hud._process(0)
  check(hud.blocks.values().all(func(p): return p.size.y<=110),"compact block heights "+route)
  check(hud.blocks.size()==6 and hud.texts.size()==6,"six shared blocks "+route)
  check(not stage.camera_settings.hud_telemetry_enabled and hud.telemetry_nodes.all(func(n): return not n.visible),"telemetry off by default "+route)
  dev.toggle_debug()
  await frames()
  check(not stage.camera_settings.hud_telemetry_enabled and hud.telemetry_nodes.all(func(n): return not n.visible),"F1 does not enable telemetry "+route)
  await key(KEY_F12)
  check(stage.camera_settings.hud_telemetry_enabled and stage.player.debug_shape if not native else stage.camera_settings.hud_telemetry_enabled and stage.developer.debug_view.visible,"F12 independent telemetry "+route)
  await key(KEY_F12)
  dev.toggle_debug()
  stage.player.set_current_health(73.25)
  if native: stage.player.reserve=.375
  else: stage.player.sprint_reserve=.375
  gun.set("magazine" if native else "magazine_ammo",3)
  gun.set("reserve" if native else "reserve_ammo",17)
  hud._process(0)
  check(hud.last_data.health==73.25 and hud.last_data.max_health==stage.player.maximum_health(),"actual fractional HP "+route)
  check(hud.last_data.stamina==.375 and hud.last_data.stamina_seconds==.375*stage.player.tuning.sprint_duration,"actual stamina "+route)
  check(hud.last_data.magazine==3 and hud.last_data.reserve==17 and hud.last_data.total==20,"actual ammo and total "+route)
  check(hud.last_data.weapon_id==("stg44") and hud.last_data.weapon=="STG-44","active weapon name "+route)
  if native: check(hud.last_data.grenades==stage.player.grenades.count,"actual native grenades")
  else:
   stage.player.grenades.count=2
   hud._process(0)
   check(hud.last_data.grenades==2,"actual grenade inventory "+route)
  check(hud.last_data.gadgets==null and hud.texts.gadgets.text=="Не подключены","no invented gadgets "+route)
  if native: stage.paused=false
  else: paused=false
  await key(KEY_H)
  check(hud.editing and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"H opens movable HUD "+route)
  var before: Vector2=stage.player.position if not native else Vector2(stage.player.position.x,stage.player.position.y)
  Input.action_press("core_right")
  for i in 4: await physics_frame
  Input.action_release("core_right")
  check((stage.player.position if not native else Vector2(stage.player.position.x,stage.player.position.y )).x==before.x,"editing does not move player "+route)
  hud.move_block("health",Vector2(500,280))
  var x: float=stage.camera_settings.hud_health_x
  var y: float=stage.camera_settings.hud_health_y
  hud._process(0)
  check(x>0 and y>0 and hud.blocks.health.position.distance_to(Vector2(500,280))<2,"drag stores normalized position "+route)
  hud.selected="health"
  hud._sync_editor()
  hud.scale_number.value=1.3
  check(is_equal_approx(stage.camera_settings.hud_health_scale,1.3),"individual size "+route)
  hud.show_toggle.button_pressed=false
  await key(KEY_H)
  hud._process(0)
  check(not hud.editing and not hud.blocks.health.visible,"individual hide retained after editing "+route)
  await key(KEY_2)
  hud._process(0)
  check(hud.last_data.weapon_id=="m1911","HUD follows real pistol switch "+route)
  await key(KEY_1)
  hud._process(0)
  check(hud.last_data.weapon_id=="stg44" and hud.last_data.magazine==3 and hud.last_data.reserve==17,"HUD follows restored weapon ammo "+route)
  stage.camera_settings.offset_x=37
  stage.camera_settings.save_saved(stage.camera_settings_path)
  var movement_path: String=stage.settings_path
  var marker:=FileAccess.open(movement_path,FileAccess.WRITE)
  marker.store_string("untouched movement marker")
  marker.close()
  stage.camera_settings.offset_x=81
  hud.save_layout()
  var cfg:=ConfigFile.new()
  cfg.load(stage.camera_settings_path)
  check(is_equal_approx(cfg.get_value("camera","hud_health_x"),x) and cfg.get_value("camera","hud_health_visible")==false,"layout saved in existing profile "+route)
  check(cfg.get_value("camera","offset_x")==37 and FileAccess.get_file_as_string(movement_path)=="untouched movement marker","HUD save preserves unrelated settings "+route)
  var adapter=stage.developer if native else stage
  check(adapter.export_settings_file(export_path),"HUD JSON export "+route)
  stage.camera_settings.hud_health_x=.99
  check(adapter.import_settings_file(export_path) and is_equal_approx(stage.camera_settings.hud_health_x,x),"HUD JSON import "+route)
  hud.reset_layout()
  check(stage.camera_settings.offset_x==81 and not stage.camera_settings.hud_health_visible,"layout reset preserves other flags "+route)
  menu.return_to_menu()
  paused=false
  await frames()
 # Saved settings are loaded on a fresh launch, not only kept in memory.
 menu.load_user_settings=true
 menu.launch(false)
 await frames(4)
 check(not menu.game.camera_settings.hud_health_visible,"fresh launch loads saved HUD flags")
 var hud=menu.game.game_hud
 hud.move_block("ammo",Vector2(100000,100000))
 hud._process(0)
 check(hud.blocks.ammo.get_global_rect().end.x<=hud.get_viewport_rect().size.x+.1 and hud.blocks.ammo.get_global_rect().end.y<=hud.get_viewport_rect().size.y+.1,"drag clamps whole block to viewport")
 var exported_state=menu.game.developer._resources().camera.as_dictionary()
 check(menu.game.developer.export_settings_file(export_path),"fresh HUD export")
 var bad_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(export_path))
 bad_data.camera.hud_health_x="invalid"
 var bad_path:=directory.path_join("invalid-hud.json")
 var bad_file:=FileAccess.open(bad_path,FileAccess.WRITE)
 bad_file.store_string(JSON.stringify(bad_data))
 bad_file.close()
 check(not menu.game.developer.import_settings_file(bad_path) and menu.game.camera_settings.as_dictionary()==exported_state,"invalid HUD profile rejected atomically")
 hud.reset_layout()
 menu.game.camera_settings.hud_health_visible=true
 hud.set_editing(true)
 await frames(4)
 var start_point: Vector2=hud.blocks.health.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new()
 motion.position=start_point
 root.push_input(motion,true)
 var click:=InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT
 click.pressed=true
 click.position=start_point
 root.push_input(click,true)
 await frames()
 check(hud.dragging=="health","real GUI press starts drag")
 var old_position: Vector2=hud.blocks.health.position
 motion.position=start_point+Vector2(64,-40)
 motion.relative=Vector2(64,-40)
 root.push_input(motion,true)
 await frames()
 click.pressed=false
 click.position=motion.position
 root.push_input(click,true)
 await frames()
 check(hud.blocks.health.position.distance_to(old_position)>30 and hud.dragging=="","real GUI motion moves and releases block")
 hud.set_editing(false)
 if "--capture" in OS.get_cmdline_user_args():
  hud.reset_layout()
  menu.game.camera_settings.hud_health_visible=true
  menu.game.paused=true
  await frames(8)
  await RenderingServer.frame_post_draw
  var output=preload("res://tools/media_paths.gd").path("docs/core/game_hud_2026-11-13/default.png")
  root.get_texture().get_image().save_png(output)
  print("CAPTURE ",output)
  hud.set_editing(true)
  await frames(8)
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output.get_base_dir().path_join("editor.png"))
 print("GAME_HUD checks=",checks," failures=",failures)
 menu.return_to_menu()
 menu.queue_free()
 await frames()
 quit(int(failures>0))
