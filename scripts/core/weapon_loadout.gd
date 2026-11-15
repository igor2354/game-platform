extends Node
# Shared two-slot loadout; gameplay controllers retain ownership of shots/reloads.
var gun: Node
var equip_weapon: Callable
var blocked: Callable
var primary := "stg44"
var secondary := "m1911"
var active := ""
var states := {}
func configure(controller: Node,equipper: Callable,selected: String,blocker: Callable,secondary_id := "m1911") -> void:
 gun=controller
 equip_weapon=equipper
 blocked=blocker
 secondary=secondary_id
 primary=selected
 active=selected
 states.clear()
func switch_slot(slot: int) -> void:
 if get_tree().paused or (blocked.is_valid() and blocked.call()): return
 var wanted := primary if slot==1 else secondary
 if wanted==active: return
 var native := "weapon_id" in gun
 var mag_key := "magazine" if native else "magazine_ammo"
 var reserve_key := "reserve" if native else "reserve_ammo"
 gun.cancel_reload()
 var values := {}
 for key in preload("res://scripts/campaign/catalog.gd").WEAPONS[preload("res://scripts/campaign/catalog.gd").index_for(active)].values:
  values[key]=gun.tuning.get(key)
 states[active]={"mag":gun.get(mag_key),"reserve":gun.get(reserve_key),"cooldown":gun.cooldown,"values":values}
 equip_weapon.call(wanted)
 if states.has(wanted):
  gun.tuning.apply_values(states[wanted].values)
  gun.set(mag_key,states[wanted].mag)
  gun.set(reserve_key,states[wanted].reserve)
  gun.cooldown=states[wanted].cooldown
 active=wanted
func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 var focus := get_viewport().gui_get_focus_owner()
 if focus is LineEdit or focus is TextEdit: return
 if event.physical_keycode in [KEY_1,KEY_KP_1]: switch_slot(1)
 elif event.physical_keycode in [KEY_2,KEY_KP_2]: switch_slot(2)
