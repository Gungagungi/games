extends Node
## Lecture des SFX et de la musique. Tant que `assets/sfx` et `assets/music` sont
## vides, les appels sont silencieux : le jeu tourne, le son se branche en déposant
## les fichiers attendus (voir assets/MANIFEST.md).

const SFX_DIR := "res://assets/sfx/"
const MUSIC_DIR := "res://assets/music/"
const VOICE_COUNT := 12

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _music: AudioStreamPlayer
var _current_track: String = ""
var _cache: Dictionary = {}

func _ready() -> void:
	for i in VOICE_COUNT:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.volume_db = -8.0
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
	_cache[key] = stream
	return stream

## Le mode smoke charge les sons mais ne les joue pas.
##
## Il tourne sous le pilote audio muet : les lectures qu'on y lance ne se
## terminent jamais et s'empilent, jusqu'à un « resources still in use at
## exit » qui masquerait une vraie erreur dans `check.sh`. Le flux est quand
## même chargé, pour que le cache et la résolution d'extension restent
## éprouvés ; c'est en revanche l'import de `scripts/build.sh` qui refuse un
## fichier illisible, pas la partie smoke.
func _silent() -> bool:
	return GameState.smoke_test

func sfx(sound: String, pitch_variation: float = 0.08) -> void:
	var stream := _load(SFX_DIR, sound)
	if stream == null or _silent():
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICE_COUNT
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.play()

func play_music(track: String) -> void:
	if _current_track == track:
		return
	var stream := _load(MUSIC_DIR, track)
	_current_track = track
	if stream == null or _silent():
		_music.stop()
		return
	_music.stream = stream
	_music.play()

func stop_music() -> void:
	_current_track = ""
	_music.stop()
