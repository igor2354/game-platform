extends Node
var gun: Node
var tuning: CoreShootingSettings:
 get: return gun.tuning
var equipped_weapon_id: String:
 get: return gun.weapon_id
var cosmetic_rng := RandomNumberGenerator.new()
var shot_sound_weapon_id := ""
var procedural_shot: AudioStream
var procedural_empty: AudioStream
var shot_audio: AudioStreamPlayer
var magazine_empty_audio: AudioStreamPlayer
var reload_audio: AudioStreamPlayer
var hit_audio: AudioStreamPlayer
var kill_audio: AudioStreamPlayer
var reload_sounds := {}
var empty_sounds_played := 0
var last_shot_sound_profile := {}
var voices := {}
func _ready() -> void:
 cosmetic_rng.randomize()
 for kind in ["shot","magazine_empty","reload_out","reload_in","reload_bolt","dry","hit","kill"]:
  var audio := AudioStreamPlayer.new()
  audio.stream = CoreCombatAudio.make_stream(kind)
  audio.max_polyphony = 6 if kind=="shot" else 3
  add_child(audio)
  voices[kind] = audio
  if kind.begins_with("reload") or kind=="dry": reload_sounds[kind] = audio.stream
 shot_audio = voices.shot
 magazine_empty_audio = voices.magazine_empty
 reload_audio = voices.reload_out
 hit_audio = voices.hit
 kill_audio = voices.kill
 procedural_shot = shot_audio.stream
 procedural_empty = magazine_empty_audio.stream
func capacity() -> int: return clampi(tuning.magazine_capacity,1,150)
func impact(killed: bool) -> void:
 if not tuning.sound_enabled: return
 var audio: AudioStreamPlayer = kill_audio if killed else hit_audio
 audio.volume_db = tuning.kill_volume if killed else tuning.hit_volume
 audio.pitch_scale = cosmetic_rng.randf_range(.97,1.03) if killed else cosmetic_rng.randf_range(.92,1.08)
 audio.play()
func dry() -> void:
 if not tuning.sound_enabled: return
 voices.dry.volume_db = tuning.reload_volume
 voices.dry.play()
const STG_SHOTS := [
 preload("res://resources/audio/weapons/stg_01.wav"),
 preload("res://resources/audio/weapons/stg_02.wav"),
 preload("res://resources/audio/weapons/stg_03.wav"),
 preload("res://resources/audio/weapons/stg_04.wav"),
 preload("res://resources/audio/weapons/stg_05.wav"),
 preload("res://resources/audio/weapons/stg_06.wav"),
 preload("res://resources/audio/weapons/stg_07.wav"),
 preload("res://resources/audio/weapons/stg_08.wav"),
]
const MP40_SHOT = preload("res://resources/audio/weapons/mp40.wav")
const PISTOL_SHOT = preload("res://resources/audio/weapons/m1911.wav")
const STG_LAST = preload("res://resources/audio/weapons/stg_last.wav")
const STG_RELOAD := {
 "reload_out": preload("res://resources/audio/weapons/stg_reload_out.wav"),
 "reload_in": preload("res://resources/audio/weapons/stg_reload_in.wav"),
 "reload_bolt": preload("res://resources/audio/weapons/stg_reload_bolt.wav"),
}
func shot_sound_profile(rounds_before: int) -> Dictionary:
 if not tuning.magazine_enabled: return {"low":false,"pitch":1.0,"last":false}
 var threshold := tuning.low_ammo_threshold
 var fraction := float(rounds_before)/capacity()
 var low := rounds_before > 0 and threshold > 0 and fraction <= threshold
 var pitch := 1.0
 if low:
  # A noticeable change at the threshold, rising to its target on the
  # last round. Reserve ammunition never affects this magazine warning.
  var progress := clampf((threshold-fraction)/maxf(.0001,threshold-1.0/capacity()),0,1)
  pitch = lerpf(1,tuning.low_ammo_pitch,.25+.75*progress)
 return {"low":low,"pitch":pitch,"last":rounds_before == 1}

func _update_shot_stream() -> void:
 if shot_sound_weapon_id == equipped_weapon_id:
  return
 shot_sound_weapon_id = equipped_weapon_id
 var samples: Array
 match equipped_weapon_id:
  "stg44": samples = STG_SHOTS
  "mp40": samples = [MP40_SHOT]
  "m1911": samples = [PISTOL_SHOT]
  _:
   shot_audio.stream = procedural_shot
   return
 var stream := AudioStreamRandomizer.new()
 stream.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
 stream.random_volume_offset_db = .75
 for sample in samples:
  stream.add_stream(-1, sample)
 shot_audio.stream = stream

func _play_shot_sound(rounds_before: int) -> void:
 last_shot_sound_profile = shot_sound_profile(rounds_before)
 if not tuning.sound_enabled: return
 shot_audio.volume_db = tuning.shot_volume
 shot_audio.pitch_scale = last_shot_sound_profile.pitch*cosmetic_rng.randf_range(.98 if last_shot_sound_profile.low else .96,1.02 if last_shot_sound_profile.low else 1.04)
 _update_shot_stream()
 var last_accent: bool = last_shot_sound_profile.last and tuning.last_shot_accent > 0
 var stg_final := last_accent and equipped_weapon_id == "stg44"
 if not stg_final:
  shot_audio.play()
 if last_accent and equipped_weapon_id != "mp40":
  var accent_stream: AudioStream = STG_LAST if stg_final else procedural_empty
  if magazine_empty_audio.stream != accent_stream:
   magazine_empty_audio.stream = accent_stream
  magazine_empty_audio.volume_db = tuning.shot_volume+linear_to_db(tuning.last_shot_accent)
  magazine_empty_audio.play()
  empty_sounds_played += 1
func _play_reload_sound(kind: String) -> void:
 if not tuning.sound_enabled: return
 reload_audio.stream = STG_RELOAD.get(kind, reload_sounds[kind]) if equipped_weapon_id == "stg44" else reload_sounds[kind]
 reload_audio.volume_db = tuning.reload_volume
 reload_audio.play()
