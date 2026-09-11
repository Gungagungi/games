extends Node
## Bruitages (`assets/sfx/<clé>.ogg`) et musiques (`assets/music/<clé>.*`).
## Un fichier absent rend l'appel silencieux, sans erreur.

const SFX_DIR := "res://assets/sfx/"
const MUSIC_DIR := "res://assets/music/"
const VOICE_COUNT := 12

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _current_track := ""
var _cache := {}

func _ready() -> void:
	for i in VOICE_COUNT:
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -10.0
	add_child(_music)
	apply_mute()

func _load(dir: String, key: String) -> AudioStream:
	var id := dir + key
	if _cache.has(id):
		return _cache[id]
	var stream: AudioStream = null
	for ext in [".ogg", ".wav", ".mp3"]:
		if ResourceLoader.exists(dir + key + ext):
			stream = load(dir + key + ext)
			break
	_cache[id] = stream
	return stream

## Le mode smoke charge sans jouer : sous le pilote audio muet du headless, les
## lectures ne se terminent jamais et s'empilent jusqu'à la sortie.
func sfx(key: String, pitch := 1.0, variation := 0.08) -> void:
	var stream := _load(SFX_DIR, key)
	if stream == null or Game.smoke_test:
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICE_COUNT
	p.stream = stream
	p.pitch_scale = pitch * (1.0 + randf_range(-variation, variation))
	p.play()

func play_music(track: String) -> void:
	if _current_track == track:
		return
	_current_track = track
	var stream := _load(MUSIC_DIR, track)
	if stream == null or Game.smoke_test:
		_music.stop()
		return
	_enable_loop(stream)
	_music.stream = stream
	_music.play()

func stop_music() -> void:
	_current_track = ""
	_music.stop()

## Boucle posée à l'exécution plutôt que dans les `.import`, qui n'existent
## qu'après un premier import.
func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)

func toggle_mute() -> void:
	Save.muted = not Save.muted
	Save.write()
	apply_mute()

func apply_mute() -> void:
	AudioServer.set_bus_mute(0, Save.muted)
