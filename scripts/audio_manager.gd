extends Node

# Diccionario sin tipo estricto para almacenar los AudioStream en memoria
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
const POOL_SIZE := 6

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var sound_files := {
		"slide": "res://assets/audio/glideSlide.wav",
		"bump": "res://assets/audio/thud.wav",
		"merge": "res://assets/audio/merge.wav",
		"snap": "res://assets/audio/snap.wav",
		"void": "res://assets/audio/void.wav",
		"undo": "res://assets/audio/undo.wav",
		"victory": "res://assets/audio/victory.wav"
	}

	for key in sound_files:
		var path: String = sound_files[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
		else:
			push_warning("AudioManager: Archivo no encontrado en: " + path)

	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

func play(sfx_name: String, pitch: float = 1.0, volume_db: float = 0.0, max_duration: float = 0.0, fade_out_duration: float = 0.5) -> void:
	if not _streams.has(sfx_name):
		return

	# Garantizar que existan reproductores si por orden de carga _ready() no los creó
	if _players.is_empty():
		for i in POOL_SIZE:
			var new_p := AudioStreamPlayer.new()
			new_p.bus = "Master"
			add_child(new_p)
			_players.append(new_p)

	# Buscar un canal disponible
	var target_player: AudioStreamPlayer = null
	for p in _players:
		if is_instance_valid(p) and not p.playing:
			target_player = p
			break

	# Fallback: reutilizar el primer reproductor si todos están ocupados
	if target_player == null and not _players.is_empty():
		target_player = _players[0]

	# Comprobación de seguridad final para evitar accesos nulos
	if not is_instance_valid(target_player):
		return

	# Interrumpir tween activo si el reproductor estaba haciendo un fade out previo
	if target_player.has_meta("active_tween"):
		var old_tw = target_player.get_meta("active_tween")
		if old_tw is Tween and is_instance_valid(old_tw) and old_tw.is_running():
			old_tw.kill()

	target_player.stop()
	target_player.stream = _streams[sfx_name]
	target_player.pitch_scale = pitch * randf_range(0.98, 1.02)
	target_player.volume_db = volume_db
	target_player.play()

	if max_duration > 0.0:
		var current_stream: AudioStream = _streams[sfx_name]
		var tw := create_tween()
		target_player.set_meta("active_tween", tw)

		var hold_time := maxf(0.0, max_duration - fade_out_duration)
		if hold_time > 0.0:
			tw.tween_interval(hold_time)

		tw.tween_property(target_player, "volume_db", volume_db - 40.0, fade_out_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			if is_instance_valid(target_player) and target_player.stream == current_stream:
				target_player.stop()
				target_player.volume_db = volume_db
		)
