extends Node
## Bruitages et musique, repris de la v2. Un son absent est silencieux ; le
## mode smoke charge les flux mais ne les joue pas (sous le pilote audio muet,
## les lectures ne se terminent jamais et s'empilent jusqu'à la sortie).

const SFX_DIR := "res://assets/sfx/"
const MUSIC_DIR := "res://assets/music/"
const VOICE_COUNT := 14

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _cache: Dictionary = {}
var _current_track := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICE_COUNT:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -9.0
	add_child(_music)

func _load(dir: String, key: String) -> AudioStream:
	if _cache.has(key):
		return _cache[key]
	var stream: AudioStream = null
	for ext in [".ogg", ".wav", ".mp3"]:
		var path: String = dir + key + ext
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_cache[key] = stream
	return stream

func sfx(sound: String, volume_db := 0.0, pitch_variation := 0.08) -> void:
	var stream := _load(SFX_DIR, sound)
	if stream == null or GameState.smoke_test:
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICE_COUNT
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.play()

func play_music(track: String) -> void:
	if _current_track == track:
		return
	var stream := _load(MUSIC_DIR, track)
	_current_track = track
	if stream == null or GameState.smoke_test:
		_music.stop()
		return
	_music.stream = stream
	_music.play()

func stop_music() -> void:
	_current_track = ""
	_music.stop()
