class_name CourtAudio
extends Node

var effects = AudioStreamPlayer.new()
var music = AudioStreamPlayer.new()
var muted = false
var music_enabled = true
var sounds = {}
var score: AudioStreamWAV

func _exit_tree() -> void:
	effects.stop()
	music.stop()
	effects.stream = null
	music.stream = null
	score = null
	sounds.clear()

func _ready() -> void:
	add_child(effects)
	add_child(music)
	effects.volume_db = -18
	music.volume_db = -32
	for spec in [["select",392,0.055],["move",262,0.10],["capture",523,0.18],["reveal",659,0.32],["error",147,0.08],["purchase",784,0.18]]:
		sounds[spec[0]] = _tone(spec[1],spec[2])
	score = _score()
	music.stream = score
	if music_enabled:
		music.play()

func play_sound(id: String) -> void:
	if muted:
		return
	effects.stream = sounds.get(id,sounds.select)
	effects.play()

func configure(sound_on: bool, music_on: bool) -> void:
	muted = not sound_on
	music_enabled = music_on
	if not sound_on:
		effects.stop()
		effects.stream=null
	if not music_on:
		music.stop()
		music.stream=null
	elif not music.playing:
		music.stream=score
		music.play()

func _tone(hz: float, seconds: float) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data = PackedByteArray()
	var count = int(seconds*22050)
	data.resize(count*2)
	for i in range(count):
		var t = float(i)/22050
		var envelope = minf(t*200,1)*pow(1-float(i)/count,2)
		data.encode_s16(i*2,int((sin(TAU*hz*t)+0.15*sin(TAU*hz*2*t))*envelope*16000))
	stream.data = data
	return stream

func _score() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data = PackedByteArray()
	var count = 22050*8
	data.resize(count*2)
	var notes = [196.0,246.94,293.66,392.0,329.63,293.66,246.94,220.0]
	for i in range(count):
		var t = float(i)/22050
		var note = notes[int(t)%8]
		var beat = fmod(t,1.0)
		var envelope = minf(beat*14,1)*pow(1-beat,2)
		var wave = sin(TAU*note*t)*envelope*0.45+sin(TAU*98*t)*0.08
		data.encode_s16(i*2,int(wave*18000))
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream
