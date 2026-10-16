extends SceneTree
const RATE := 22050
func _initialize() -> void: call_deferred("capture")
func samples(stream: AudioStreamWAV) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for i in stream.data.size()/2:
		var value := int(stream.data[i*2])|(int(stream.data[i*2+1])<<8)
		if value >= 32768: value -= 65536
		result.append(float(value)/32768)
	return result
func mix_sound(mix: PackedFloat32Array,sound: PackedFloat32Array,start: float,pitch: float,gain: float) -> void:
	var offset := roundi(start*RATE)
	for i in ceili(sound.size()/pitch):
		var source := i*pitch
		var index := floori(source)
		if index >= sound.size()-1 or offset+i >= mix.size(): break
		mix[offset+i] += lerpf(sound[index],sound[index+1],source-index)*gain
func capture() -> void:
	var gun := CoreShootingController.new()
	gun.tuning.magazine_capacity = 100
	var shot := samples(CoreCombatAudio.make_stream("shot"))
	var accent := samples(CoreCombatAudio.make_stream("magazine_empty"))
	var mix := PackedFloat32Array()
	mix.resize(RATE*3)
	# First five normal shots; then 30%, 20%, 15%, 5%, last round.
	for i in 5: mix_sound(mix,shot,.2+i*.12,1,1)
	var amounts := [30,20,15,5,1]
	for i in amounts.size():
		var profile := gun.shot_sound_profile(amounts[i])
		mix_sound(mix,shot,1.4+i*.12,profile.pitch,1)
		if profile.last: mix_sound(mix,accent,1.4+i*.12,1,gun.tuning.last_shot_accent)
	var peak := .001
	for value in mix: peak = maxf(peak,absf(value))
	var data := PackedByteArray()
	data.resize(mix.size()*2)
	for i in mix.size():
		var value := roundi(mix[i]*.8/peak*32767)
		data[i*2] = value&255
		data[i*2+1] = (value>>8)&255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	var error := stream.save_to_wav("res://docs/core/ammo_sound_comparison.wav")
	gun.free()
	if error != OK: push_error("Could not save sound comparison")
	print("CAPTURE: five normal shots, then low ammo and last round")
	quit(0 if error == OK else 1)
