extends Node
## Sound and music playback. Sounds are loaded lazily by name from
## res://assets/sounds/<name>.wav, music from res://assets/music/<name>.ogg.

const POOL_2D := 16
const POOL_3D := 40

var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _players3d: Array[AudioStreamPlayer3D] = []
var _next2d := 0
var _next3d := 0
var _world: Node = null
var music_player: AudioStreamPlayer
var amb_player: AudioStreamPlayer
var current_music := ""
var _music_tween: Tween
var _voice_cool := 4.0
const VOICES := ["voice_canthide", "voice_runpig", "voice_seeyou"]
var _last_voice := ""


func _process(delta: float) -> void:
	_voice_cool -= delta


## A whispered line from an enemy. Rate limited so it stays unsettling
## rather than repetitive. Returns true if a line was played.
func voice_line(pos: Vector3, pitch := 1.0, force := false) -> bool:
	if _voice_cool > 0.0 and not force:
		return false
	_voice_cool = randf_range(9.0, 16.0)
	var choices := VOICES.filter(func(v): return v != _last_voice)
	var v: String = choices[randi() % choices.size()]
	_last_voice = v
	play_at(v, pos, 8.0, pitch)
	return true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	amb_player = AudioStreamPlayer.new()
	amb_player.bus = "SFX"
	add_child(amb_player)


func get_sound(sname: String) -> AudioStream:
	if _cache.has(sname):
		return _cache[sname]
	var path := "res://assets/sounds/%s.wav" % sname
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	_cache[sname] = s
	return s


func make_loop(s: AudioStream) -> AudioStream:
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate) - 1
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	return s


func play(sname: String, volume_db := 0.0, pitch := 1.0) -> void:
	var s := get_sound(sname)
	if s == null:
		return
	var p := _players[_next2d]
	_next2d = (_next2d + 1) % POOL_2D
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Registers the node (inside the game's 3D world) that hosts positional players.
func set_world(node: Node) -> void:
	for p in _players3d:
		if is_instance_valid(p):
			p.queue_free()
	_players3d.clear()
	_world = node
	if node == null:
		return
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 7.0
		p.max_distance = 70.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 0.8
		node.add_child(p)
		_players3d.append(p)


func play_at(sname: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if _players3d.is_empty():
		play(sname, volume_db - 6.0, pitch)
		return
	var s := get_sound(sname)
	if s == null:
		return
	# prefer a free player, otherwise steal round-robin
	var p: AudioStreamPlayer3D = null
	for i in POOL_3D:
		var c := _players3d[(_next3d + i) % POOL_3D]
		if not c.playing:
			p = c
			_next3d = (_next3d + i + 1) % POOL_3D
			break
	if p == null:
		p = _players3d[_next3d]
		_next3d = (_next3d + 1) % POOL_3D
	p.stream = s
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_music(mname: String, fade := 0.6) -> void:
	if mname == current_music and music_player.playing:
		return
	current_music = mname
	var path := "res://assets/music/%s.ogg" % mname
	if mname == "" or not ResourceLoader.exists(path):
		stop_music(fade)
		return
	var s: AudioStream = load(path)
	make_loop(s)
	if _music_tween:
		_music_tween.kill()
	music_player.stream = s
	music_player.volume_db = -30.0
	music_player.play()
	_music_tween = create_tween()
	_music_tween.tween_property(music_player, "volume_db", 0.0, fade)


func stop_music(fade := 0.5) -> void:
	current_music = ""
	if _music_tween:
		_music_tween.kill()
	if not music_player.playing:
		return
	_music_tween = create_tween()
	_music_tween.tween_property(music_player, "volume_db", -40.0, fade)
	_music_tween.tween_callback(music_player.stop)


func play_ambience(aname: String, volume_db := -14.0) -> void:
	if aname == "":
		amb_player.stop()
		return
	var s := get_sound(aname)
	if s == null:
		amb_player.stop()
		return
	make_loop(s)
	amb_player.stream = s
	amb_player.volume_db = volume_db
	amb_player.play()


func stop_ambience() -> void:
	amb_player.stop()
