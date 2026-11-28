extends Node
## Son du jeu (chargé automatiquement sous le nom « Son ») : musique en deux
## pistes synchronisées, ambiances, bruitages, volumes réglables.
##
## La musique suit la restauration : la piste de base joue toujours, la piste
## d'éclosion (mélodie, cordes aiguës) monte à mesure que la zone revit.

const DIR := "res://assets/audio/"
const SETTINGS_PATH := "user://reglages.cfg"

var _music: AudioStreamPlayer
var _music_sync: AudioStreamSynchronized
var _amb_dry: AudioStreamPlayer
var _amb_life: AudioStreamPlayer
var _bloom := 0.0
var _bloom_target := 0.0
var _cache := {}
var _started := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["Musique", "Effets"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")
	set_volume("Musique", _load("volume_musique", 0.8), false)
	set_volume("Effets", _load("volume_effets", 0.8), false)

## Lance la musique et les ambiances (une seule fois ; sans effet en mode sans écran).
func start() -> void:
	if _started or DisplayServer.get_name() == "headless":
		return
	_started = true
	_music_sync = AudioStreamSynchronized.new()
	_music_sync.stream_count = 2
	_music_sync.set_sync_stream(0, _loop(load(DIR + "musique_base.ogg")))
	_music_sync.set_sync_stream(1, _loop(load(DIR + "musique_eclosion.ogg")))
	_music_sync.set_sync_stream_volume(1, -60.0)
	_music = _player(_music_sync, "Musique", 0.0)
	_amb_dry = _player(_loop(load(DIR + "ambiance_vent.ogg")), "Effets", -14.0)
	_amb_life = _player(_loop(load(DIR + "ambiance_vie.ogg")), "Effets", -60.0)

func _loop(s: AudioStream) -> AudioStream:
	if s is AudioStreamOggVorbis:
		s.loop = true
	return s

func _player(stream: AudioStream, bus: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = db
	add_child(p)
	p.play()
	return p

## t = 0 : zone flétrie ; t = 1 : zone restaurée. « instant » saute le fondu.
func set_bloom(t: float, instant: bool = false) -> void:
	_bloom_target = clampf(t, 0.0, 1.0)
	if instant:
		_bloom = _bloom_target
		_apply_bloom()

func _process(delta: float) -> void:
	if not _started or is_equal_approx(_bloom, _bloom_target):
		return
	_bloom = move_toward(_bloom, _bloom_target, delta * 0.35)
	_apply_bloom()

func _apply_bloom() -> void:
	if not _started:
		return
	var k := smoothstep(0.05, 0.9, _bloom)
	_music_sync.set_sync_stream_volume(1, linear_to_db(maxf(k, 0.001)))
	_amb_life.volume_db = linear_to_db(maxf(k, 0.001)) - 12.0
	_amb_dry.volume_db = linear_to_db(maxf(1.0 - k, 0.001)) - 14.0

func _stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		var path := DIR + sound + ".wav"
		if not ResourceLoader.exists(path):
			path = DIR + sound + ".ogg"
		_cache[sound] = load(path)
	return _cache[sound]

## Bruitage sans position (interface, événements de la zone).
func play(sound: String, db: float = 0.0, pitch: float = 1.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p := AudioStreamPlayer.new()
	p.stream = _stream(sound)
	p.bus = "Effets"
	p.volume_db = db
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()

## Bruitage placé dans le monde : on l'entend plus ou moins selon la distance.
func play_at(sound: String, pos: Vector3, db: float = 0.0, pitch: float = 1.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(sound)
	p.bus = "Effets"
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = 6.0
	p.max_distance = 45.0
	p.finished.connect(p.queue_free)
	add_child(p)
	p.global_position = pos
	p.play()

## Volume d'un groupe (« Musique » ou « Effets »), de 0 à 1.
func set_volume(bus_name: String, v: float, save: bool = true) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v * v, 0.0001)))
	AudioServer.set_bus_mute(i, v <= 0.005)
	if save:
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS_PATH)
		cfg.set_value("reglages", "volume_" + bus_name.to_lower(), v)
		cfg.save(SETTINGS_PATH)

func get_volume(bus_name: String) -> float:
	return _load("volume_" + bus_name.to_lower(), 0.8)

func _load(key: String, default: float) -> float:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		return float(cfg.get_value("reglages", key, default))
	return default
