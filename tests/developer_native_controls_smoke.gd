extends SceneTree
var checks:=0
var failures:=0
func _initialize(): run.call_deferred()
func check(ok: bool,text: String):
 checks+=1
 if not ok:
  failures+=1
  push_error("FAIL "+text)
func run():
 var directory:=OS.get_environment("TEMP").path_join("native-controls-%d" % OS.get_process_id())
 DirAccess.make_dir_recursive_absolute(directory)
 var stage=load("res://scenes/core/polygon_3d.tscn").instantiate()
 stage.load_user_settings=false
 for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]: stage.set(key,directory.path_join(key+".cfg"))
 root.add_child(stage)
 for i in 3: await process_frame
 stage.paused=true
 var dev=stage.developer
 dev.developer_mode.set_enabled(true)
 var numeric:=0
 var switches:=0
 for index in 8:
  dev.developer_mode.show_overlay(index)
  var overlay=dev._ui_overlays()[index]
  for page in overlay.tabs.get_tab_count():
   overlay.tabs.current_tab=page
   await process_frame
   check(overlay.panel.is_visible_in_tree(),"visible page "+str(index)+"/"+str(page))
  for key in overlay.rows:
   var row: Dictionary=overlay.rows[key]
   if not row.number.editable: continue
   var before: Dictionary=overlay.settings.as_dictionary()
   var requested: float=float(overlay.settings.get(key))+(row.number.custom_arrow_step if row.number.custom_arrow_step>0 else row.number.step)
   if requested>row.number.max_value: requested=float(overlay.settings.get(key))-row.number.step
   row.number.value=requested
   var actual: float=float(overlay.settings.get(key))
   check(is_equal_approx(actual,row.number.value) and is_equal_approx(actual,row.slider.value),"live numeric "+key+" resource="+str(actual)+" number="+str(row.number.value)+" slider="+str(row.slider.value))
   check(overlay.settings==dev._ui_overlays()[index].settings,"same resource "+key)
   numeric+=1
   overlay.settings.apply_values(before)
   overlay._sync()
  var toggles: Dictionary=overlay.zombie_toggles if overlay.settings is CoreZombieSettings else overlay.feature_toggles
  for key in toggles:
   if toggles[key].disabled: continue
   var before: Dictionary=overlay.settings.as_dictionary()
   toggles[key].button_pressed=not bool(overlay.settings.get(key))
   check(bool(overlay.settings.get(key))==toggles[key].button_pressed,"live switch "+key)
   switches+=1
   overlay.settings.apply_values(before)
   overlay._sync()
  overlay.settings_changed.emit()
 dev.developer_mode.show_overlay(0)
 var old_speed: float=stage.player.tuning.run_speed
 stage.player.tuning.run_enabled=false
 dev._settings_changed()
 stage.paused=false
 stage.combat.zombie_settings.movement_enabled=false
 stage.combat.zombie_settings.combat_enabled=false
 Input.action_press("core_right")
 for i in 30: await physics_frame
 check(absf(stage.player.velocity.x)<.01,"run switch stops actual movement")
 stage.player.tuning.run_enabled=true
 stage.player.tuning.run_speed=400
 stage.player.tuning.acceleration_smoothing=0
 stage.player.tuning.acceleration=10000
 for i in 60: await physics_frame
 check(absf(stage.player.velocity.x)>1,"movement works while workspace open")
 Input.action_release("core_right")
 stage.player.tuning.run_speed=old_speed
 stage.paused=true
 var hp: float=stage.player.health
 stage.player.tuning.health_enabled=false
 stage.player.take_damage(10)
 check(stage.player.health==hp,"health switch blocks actual damage")
 stage.player.tuning.health_enabled=true
 stage.player.take_damage(10)
 check(stage.player.health==hp-10,"health switch restores actual damage")
 stage.player.contacts.dash_begin()
 stage.player.dash_left=.2
 stage.player.tuning.dash_enabled=false
 dev._settings_changed()
 check(stage.player.dash_left==0,"disable active dash immediately")
 stage.player.slide_left=.2
 stage.player.tuning.slide_enabled=false
 dev._settings_changed()
 check(stage.player.slide_left==0,"disable active slide immediately")
 stage.player.climbing=true
 stage.player.tuning.ladder_enabled=false
 dev._settings_changed()
 check(not stage.player.climbing,"disable active ladder immediately")
 dev.developer_mode.set_enabled(false)
 print("NATIVE_CONTROLS checks=",checks," failures=",failures," numeric=",numeric," switches=",switches)
 stage.queue_free()
 await process_frame
 quit(int(failures>0))
