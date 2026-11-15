extends SceneTree
var failures := 0
var checks := 0
var stage
var directory := OS.get_environment("TEMP").path_join("developer3d-%d" % OS.get_process_id())
func _initialize(): run.call_deferred()
func check(value: bool,text: String):
 checks+=1
 if not value:
  failures+=1
  push_error("FAIL "+text)
 else: print("PASS ",text)
func snapshot(dev) -> Dictionary:
 var values := {}
 for key in dev._resources(): values[key]=dev._resources()[key].as_dictionary()
 return values
func run():
 root.size=Vector2i(1600,1000)
 root.gui_embed_subwindows=true
 DirAccess.make_dir_recursive_absolute(directory)
 stage=load("res://scenes/core/polygon_3d.tscn").instantiate()
 stage.load_user_settings=false
 for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]: stage.set(key,directory.path_join(key+".cfg"))
 root.add_child(stage)
 for i in 5: await process_frame
 stage.paused=true
 var dev=stage.developer
 var ui=dev.developer_mode
 check(not ui.enabled and not dev.debug_view.visible,"normal startup")
 ui.set_enabled(true)
 for i in 8:
  ui.show_overlay(i)
  await process_frame
  check(dev._ui_overlays()[i].panel.is_visible_in_tree(),"shared page %d" % i)
 check(stage.combat.overlay.rows.has("reload_duration") and stage.combat.overlay.rows.has("camera_kick"),"existing shooting and recoil pages retained")
 ui.show_overlay(5)
 stage.player.set_current_health(24)
 ui._sync_health()
 check(ui.health_number.value==24,"health readout")
 ui.invulnerable_toggle.button_pressed=true
 stage.player.take_damage(10)
 check(stage.player.health==24,"invulnerable player")
 ui.invulnerable_toggle.button_pressed=false
 stage.player.take_damage(10)
 check(stage.player.health==14,"damage restored")
 stage.player.tuning.max_health=180
 stage.player.set_current_health(180)
 check(stage.player.health==180,"live health ceiling")
 stage.player.set_current_health(0)
 stage.player.set_current_health(180)
 check(stage.player.collision_layer==2 and not stage.player.model.death_ragdoll.active,"revive player on place")
 ui.show_section(CoreDeveloperMode.Section.TESTING)
 var tools=ui.enemy_tools
 tools.freeze_toggle.button_pressed=true
 tools.invulnerable_toggle.button_pressed=true
 for enemy in dev.developer_enemies():
  enemy.take_projectile_hit(999,enemy.position,Vector3.RIGHT)
  check(enemy.health>0 and enemy.test_frozen,"enemy test controls "+str(enemy.name))
 tools.target_choice.select(1)
 tools._change_maximum(230)
 tools._change_health(57)
 check(dev.developer_enemies()[0].maximum_health()==230 and dev.developer_enemies()[0].health==57,"selected enemy HP")
 stage.combat.gun.magazine=0
 dev.developer_refill()
 check(stage.combat.gun.magazine==stage.combat.gun.tuning.magazine_capacity,"refill ammunition")
 ui.toggle_debug()
 await process_frame
 check(dev.debug_view.visible,"native diagnostic geometry")
 stage.player.tuning.run_speed=456
 stage.combat.gun.tuning.reload_duration=3.1
 stage.camera_settings.zoom=1.2
 stage.combat.zombie_settings.patrol_speed=110
 stage.ragdoll_settings.muscle_tension=.8
 var expected=snapshot(dev)
 ui.save_all()
 for overlay in dev._overlays(): check(FileAccess.file_exists(overlay.settings_path),"save profile "+overlay.settings_path.get_file())
 var json=directory.path_join("roundtrip.json")
 check(dev.export_settings_file(json),"JSON export")
 stage.player.tuning.run_speed=333
 ui.load_all()
 check(snapshot(dev)==expected,"load all preserves all sections")
 stage.player.tuning.run_speed=222
 check(dev.import_settings_file(json) and snapshot(dev)==expected,"JSON full roundtrip")
 var bad=FileAccess.open(directory.path_join("bad.json"),FileAccess.WRITE)
 bad.store_string('{"format":"dead-platform-settings","version":1,"movement":{},"shooting":false,"camera":{}}')
 bad.close()
 check(not dev.import_settings_file(directory.path_join("bad.json")) and snapshot(dev)==expected,"invalid JSON atomic rejection")
 for pause_state in [false,true]:
  stage.paused=pause_state
  dev._open_settings_dialog(true)
  check(stage.paused and dev.settings_dialog_open,"file dialog pauses")
  dev._close_settings_dialog()
  check(stage.paused==pause_state,"file dialog restores previous pause")
 var event=InputEventKey.new()
 event.physical_keycode=KEY_F3
 event.pressed=true
 dev.handle_key(event)
 check(ui.current_section==0 and ui.current_player_tab==0,"F3 routes shared page")
 ui.set_enabled(false)
 ui.toggle_debug()
 check(not ui.enabled and not dev.debug_view.visible,"close and independent F1")
 ui.set_enabled(false)
 event.physical_keycode=KEY_F2
 root.push_input(event,true)
 await process_frame
 check(ui.enabled,"actual F2 input opens workspace")
 event.physical_keycode=KEY_F4
 root.push_input(event,true)
 await process_frame
 check(ui.current_player_tab==1 and stage.combat.overlay.panel.is_visible_in_tree(),"actual F4 selects weapon settings")
 stage.combat.overlay.tabs.current_tab=stage.combat.overlay.groups.find("Магазин")
 for i in 3: await process_frame
 var field=stage.combat.overlay.rows.reload_duration.number.get_line_edit()
 field.grab_focus()
 await process_frame
 check(root.gui_get_focus_owner()==field,"numeric editor receives focus")
 dev.developer_enemies()[0].set_current_health(31)
 event.physical_keycode=KEY_F7
 root.push_input(event,true)
 await process_frame
 check(dev.developer_enemies()[0].health==31,"numeric editor blocks respawn shortcut")
 field.release_focus()
 root.push_input(event,true)
 await process_frame
 check(dev.developer_enemies()[0].health==230,"F7 restores enemies preserving session maximum")
 check(not stage.combat.overlay.rows.arm_durability.number.editable and not stage.camera_overlay.feature_toggles.map_enabled.disabled,"missing mechanics marked; working map switch retained")
 root.size=Vector2i(1366,768)
 ui.size=Vector2(1366,768)
 for index in 8:
  ui.show_overlay(index)
  if not ui.enabled: ui.set_enabled(true)
  for i in 3: await process_frame
  check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(ui.panel.get_global_rect()),"workspace fits 1366x768 page "+str(index)+" rect="+str(ui.panel.get_global_rect()))
 root.size=Vector2i(1600,1000)
 ui.size=Vector2(1600,1000)
 print("DEVELOPER_3D checks=",checks," failures=",failures)
 if "--capture" in OS.get_cmdline_user_args():
  ui.set_enabled(true)
  ui.show_section(CoreDeveloperMode.Section.TESTING)
  ui.status.text="Все пять профилей совместимы. Изменения применяются сразу."
  ui.size=ui.get_viewport_rect().size
  ui._layout()
  for i in 8: await process_frame
  await RenderingServer.frame_post_draw
  var image=root.get_texture().get_image()
  var logical=OS.get_environment("UBERSHRIKE_CAPTURE_PATH")
  if logical.is_empty(): logical="docs/core/developer_3d_2026-11-13/testing.png"
  var output=preload("res://tools/media_paths.gd").path(logical)
  image.save_png(output)
  print("CAPTURE ",output)
 stage.queue_free()
 await process_frame
 quit(int(failures>0))
