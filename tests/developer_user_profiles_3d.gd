extends SceneTree
var failures:=0
var checks:=0
func _initialize(): run.call_deferred()
func check(ok: bool,text: String):
 checks+=1
 if ok: print("PASS ",text)
 else:
  failures+=1
  push_error("FAIL "+text)
func snapshot(game) -> Dictionary:
 var data: Dictionary={}
 for key in game.developer._resources(): data[key]=game.developer._resources()[key].as_dictionary()
 return data
func run():
 var args:=OS.get_cmdline_user_args()
 if args.is_empty(): push_error("Need copied profile source directory"); quit(1); return
 var source:=args[0]
 var directory:=OS.get_environment("TEMP").path_join("user-profile-validation-%d" % OS.get_process_id())
 DirAccess.make_dir_recursive_absolute(directory)
 var names:=["movement","shooting","camera","zombie","ragdoll"]
 var hashes: Dictionary={}
 for key in names:
  var path:=source.path_join("core_"+key+".cfg")
  hashes[key]=FileAccess.get_sha256(path)
  check(DirAccess.copy_absolute(path,directory.path_join(key+".cfg"))==OK,"copy "+key)
 var expected: Dictionary={}
 for key in names:
  var resource=load("res://resources/core/"+key+".tres").duplicate(true) if key!="ragdoll" else CoreRagdollSettings.new()
  resource.load_saved(directory.path_join(key+".cfg"))
  expected[key]=resource.as_dictionary()
 var menu=load("res://scenes/frontend.tscn").instantiate()
 menu.load_user_settings=true
 menu.test_settings_directory=directory
 root.add_child(menu)
 for id in ["stg44","mp40","m1911","svt"]:
  menu.selected_weapon=id
  menu.launch(false)
  for i in 3: await process_frame
  var game=menu.game
  game.paused=true
  var actual=snapshot(game)
  var catalogue=preload("res://scripts/campaign/catalog.gd")
  var weapon_values: Dictionary=catalogue.WEAPONS[catalogue.index_for(id)].values
  for key in names:
   var wanted: Dictionary=expected[key].duplicate(true)
   if key=="shooting": wanted.merge(weapon_values,true)
   check(actual[key]==wanted,"startup uses copied "+key+" for "+id)
  game.developer.developer_mode.set_enabled(true)
  var saved=snapshot(game)
  var json:=directory.path_join("copied-profile.json")
  check(game.developer.export_settings_file(json),"export copied profile")
  game.combat.gun.tuning.aim_mouse_sensitivity=.75
  check(game.developer.import_settings_file(json) and snapshot(game)==saved,"import restores copy")
  for key in names: check(FileAccess.get_sha256(source.path_join("core_"+key+".cfg"))==hashes[key],"source untouched "+key)
  # Restore the original copies before selecting a different catalogue weapon.
  menu.return_to_menu()
  for i in 3: await process_frame
  for key in names: DirAccess.copy_absolute(source.path_join("core_"+key+".cfg"),directory.path_join(key+".cfg"))
 print("DEVELOPER_USER_PROFILES checks=",checks," failures=",failures)
 menu.queue_free()
 await process_frame
 quit(int(failures>0))
