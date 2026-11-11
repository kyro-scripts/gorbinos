class_name HyperFace
extends Node3D
## Photo-real eyes and lips stuck on a creature's face (or pasted on a
## wall). The eyes follow the player and blink, go wide when it's hurt and
## roll back when it dies; the lips scream when it attacks, flap when a
## local talks, and hang open on a corpse.

var host: Node3D = null          # the Enemy or Civilian wearing it; null on a wall
var level: Node = null           # set for wall pastes (a host brings its own)
var wall := false
var grin := false
var eyes: Array = []
var mouth: MeshInstance3D = null
var _rng := RandomNumberGenerator.new()
var _blink_t := 2.0
var _blink := -1.0
var _wide_t := 0.0
var _grin_t := 0.0
var _flap := 0.0
var _charred := false
var _spoke := false


func seed_rng(s: int) -> void:
	_rng.seed = s
	_blink_t = _rng.randf_range(0.5, 4.0)


## Stick a photo quad flat on the surface at p (in this node's parent's
## space), facing along n, pushed out a little so it doesn't sink in.
func stick(mi: MeshInstance3D, p: Vector3, n: Vector3, flip: bool, out: float) -> void:
	add_child(mi)
	mi.position = p + n * out
	var b := Basis.looking_at(-n, Vector3.UP if absf(n.y) < 0.95 else Vector3.FORWARD)
	if flip:
		b = b.scaled_local(Vector3(-1, 1, 1))
	mi.basis = b


func add_eye(mi: MeshInstance3D, p: Vector3, n: Vector3, flip: bool, out: float) -> void:
	stick(mi, p, n, flip, out)
	eyes.append(mi)


func add_mouth(mi: MeshInstance3D, p: Vector3, n: Vector3, out: float) -> void:
	stick(mi, p, n, false, out)
	mouth = mi


## Burnt: the photos go dark and the eyes shut.
func burn() -> void:
	_charred = true
	for mi in get_children():
		if mi is MeshInstance3D and mi.has_meta("hyper"):
			Hyper.set_tint(mi, Color(0.3, 0.17, 0.11))


func _host_get(prop: String, def: Variant) -> Variant:
	if host == null or not is_instance_valid(host):
		return def
	var v = host.get(prop)
	return def if v == null else v


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var lv = level if level != null else _host_get("level", null)
	var player: Node3D = null
	if lv != null and is_instance_valid(lv):
		player = lv.player
	var dead: bool = _host_get("dead", false) or _charred
	var state := String(_host_get("state", ""))
	var panic := float(_host_get("panic_t", 0.0)) > 0.0
	var talking := float(_host_get("_talk_t", 0.0)) > 0.0
	var dist := 99.0
	if player:
		dist = global_position.distance_to(player.global_position)
	# ---- eyes
	if not eyes.is_empty():
		_blink_t -= delta
		if _blink_t <= 0.0 and _blink < 0.0:
			_blink = 0.0
			_blink_t = _rng.randf_range(1.2, 5.5) * (0.4 if panic else 1.0)
		var f := -1
		if _blink >= 0.0:
			_blink += delta
			f = Hyper.EYE["half"] if _blink < 0.05 or (_blink > 0.13 and _blink < 0.18) else Hyper.EYE["shut"]
			if _blink >= 0.18:
				_blink = -1.0
		if state == "pain" or panic or state == "gutted":
			_wide_t = 0.4
		_wide_t -= delta
		for e in eyes:
			var ef := f
			if _charred:
				ef = Hyper.EYE["shut"]
			elif dead:
				ef = Hyper.EYE["up"]
			elif ef < 0 and _wide_t > 0.0:
				ef = Hyper.EYE["wide"]
			elif ef < 0:
				ef = _gaze(e, player)
			Hyper.set_frame(e, ef)
	# ---- lips
	if mouth:
		var m := Hyper.MOUTH["shut"]
		_grin_t -= delta
		if _grin_t <= 0.0:
			_grin_t = _rng.randf_range(2.0, 7.0)
			grin = _rng.randf() < 0.35
		if dead:
			m = Hyper.MOUTH["open"]
		elif wall:
			if dist < 4.5:
				m = Hyper.MOUTH["scream"]
				if not _spoke:
					_spoke = true
					if _rng.randf() < 0.5:
						Audio.voice_line(global_position, 0.8)
			elif dist < 10.0:
				m = Hyper.MOUTH["open"]
			elif grin:
				m = Hyper.MOUTH["grin"]
			if dist > 14.0:
				_spoke = false
		elif state == "windup" or state == "gutted" or panic:
			m = Hyper.MOUTH["scream"]
		elif state == "pain":
			m = Hyper.MOUTH["open"]
		elif talking:
			_flap -= delta
			if _flap <= 0.0:
				_flap = _rng.randf_range(0.06, 0.14)
				mouth.set_meta("flap", not mouth.get_meta("flap", false))
			m = Hyper.MOUTH["open"] if mouth.get_meta("flap", false) else Hyper.MOUTH["shut"]
		elif grin:
			m = Hyper.MOUTH["grin"]
		Hyper.set_frame(mouth, m)


## Look toward the player: left, centre or right in the picture.
func _gaze(e: MeshInstance3D, player: Node3D) -> int:
	if player == null:
		return Hyper.EYE["center"]
	var lp := e.global_transform.affine_inverse() * (player.global_position + Vector3(0, 1.4, 0))
	if lp.z <= 0.05:
		return Hyper.EYE["center"]
	var r := lp.x / lp.z
	var look: int = e.get_meta("look", 0)     # -1 left, 0 centre, 1 right (in the picture)
	if r > 0.35:
		look = 1
	elif r < -0.35:
		look = -1
	elif absf(r) < 0.2:
		look = 0
	e.set_meta("look", look)
	return Hyper.EYE["right"] if look > 0 else (Hyper.EYE["left"] if look < 0 else Hyper.EYE["center"])
