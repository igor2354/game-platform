extends SceneTree
var failures:=0
func check(ok: bool,label: String):
 if not ok:
  failures+=1
  print("FAIL ",label)
func _initialize(): run.call_deferred()
func run():
 var menu=load("res://scenes/frontend.tscn").instantiate()
 menu.load_user_settings=false
 root.add_child(menu)
 await process_frame
 for legacy in [false,true]:
  menu.selected_weapon="mp40"
  menu.launch(false,legacy)
  for i in 8: await process_frame
  var game=menu.game
  var gun: Node=game.player.weapon if legacy else game.combat.gun
  var loadout: Node=game.find_child("*",false,false)
  if legacy:
   for child in game.get_children():
    if child.get_script()==preload("res://scripts/core/weapon_loadout.gd"): loadout=child
  else: loadout=game.combat.loadout
  var mag_key: String="magazine_ammo" if legacy else "magazine"
  var reserve_key: String="reserve_ammo" if legacy else "reserve"
  gun.set(mag_key,9)
  gun.set(reserve_key,40)
  loadout.switch_slot(2)
  check(loadout.active=="m1911","secondary both routes")
  check(gun.get(mag_key)==7,"first pistol load")
  gun.set(mag_key,3)
  gun.set(reserve_key,21)
  loadout.switch_slot(1)
  check(gun.get(mag_key)==9 and gun.get(reserve_key)==40,"primary ammo retained")
  loadout.switch_slot(2)
  check(gun.get(mag_key)==3 and gun.get(reserve_key)==21,"pistol ammo retained")
  if not legacy:
   check(game.combat.pistol_model.visible and not game.combat.barrel.visible,"real pistol model")
   check(game.combat.pistol_animator.has_animation("Fire"),"source animation")
   gun.cooldown=0
   check(gun.fire(game.combat.pivot.to_global(game.combat.muzzle),Vector3.RIGHT),"pistol fires")
   check(game.combat.pistol_animator.is_playing(),"Fire animation triggered")
   var bullet={"finished":false}
   gun.projectiles.append(bullet)
   loadout.switch_slot(1)
   check(gun.projectiles.has(bullet) and not bullet.finished,"bullets survive switch")
   game.paused=true
   loadout.switch_slot(2)
   check(loadout.active=="mp40","pause blocks switch")
   game.paused=false
  menu.return_to_menu()
  for i in 8: await process_frame
 for level in ["prologue","prologue_v2","terra","hub"]:
  menu.selected_weapon="stg44"
  menu.selected_level=level
  menu.launch(true)
  for i in 8: await process_frame
  var game=menu.game
  var inventory: Node
  for child in game.get_children():
   if child.get_script()==preload("res://scripts/core/weapon_loadout.gd"): inventory=child
  check(inventory!=null,"campaign inventory "+level)
  if inventory:
   inventory.switch_slot(2)
   check(game.player.weapon.equipped_weapon_id=="m1911","campaign secondary "+level)
   inventory.switch_slot(1)
   check(game.player.weapon.equipped_weapon_id=="stg44","campaign primary "+level)
  menu.return_to_menu()
  for i in 8: await process_frame
 print("WEAPON_LOADOUT failures=",failures)
 menu.queue_free()
 await process_frame
 quit(int(failures>0))
