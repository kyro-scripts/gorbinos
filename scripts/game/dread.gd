class_name Dread
extends Node
## Keeps the player uneasy. Every so often something happens that has
## nothing to do with the fight: a whisper right behind them, knocking far
## off, breathing, metal dragged across a floor, the lights faltering, a
## face for a frame. A heartbeat starts when they're close to death.

var world: Node
var level: Node
var player: Node
var dread := 0.0
var _hold := 0.0
var _next := 15.0
var _hb_t := 0.0
var _flicker := 0.0
var _flick_t := 0.0
var _base := Vector4.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_base = level.fog_params
	_next = randf_range(12.0, 25.0)


func _exit_tree() -> void:
	_set_light(1.0)


func _set_light(k: float) -> void:
	if _base == Vector4.ZERO:
		return
	RenderingServer.global_shader_parameter_set("fog_params", Vector4(_base.x, _base.y, _base.z * k, _base.w))


func _process(delta: float) -> void:
	if player == null or level == null:
		return
	var hp := int(player.health)
	if player.dead:
		dread = move_toward(dread, 0.0, delta)
		world.post.set_shader_parameter("dread", dread)
		return
	_next -= delta
	if _next <= 0.0:
		_next = randf_range(20.0, 45.0)
		_event()
	# heartbeat, faster and louder the closer to death
	if hp < 35:
		_hb_t -= delta
		if _hb_t <= 0.0:
			_hb_t = 0.5 + hp / 70.0
			Audio.play("heartbeat", -8.0 + (35 - hp) * 0.25, 1.0)
	# lights falter
	if _flicker > 0.0:
		_flicker -= delta
		_flick_t -= delta
		if _flick_t <= 0.0:
			_flick_t = randf_range(0.04, 0.18)
			_set_light(0.2 if randf() < 0.55 else 1.0)
		if _flicker <= 0.0:
			_set_light(1.0)
	_hold -= delta
	var want := 0.0
	if _hold > 0.0:
		want = 0.6
	if hp < 25:
		want = maxf(want, 0.3)
	dread = move_toward(dread, want, delta * (0.8 if want > dread else 0.35))
	world.post.set_shader_parameter("dread", dread)


func _behind(dist_min: float, dist_max: float) -> Vector3:
	var fwd: Vector3 = -player.camera.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var side := Vector3(-fwd.z, 0, fwd.x)
	return player.global_position - fwd * randf_range(dist_min, dist_max) + side * randf_range(-2.5, 2.5) + Vector3(0, 1.3, 0)


func _event() -> void:
	var r := randf()
	var w: String = "creep_whisper_" + ["a", "b", "c"][randi() % 3]
	if r < 0.3:
		Audio.play_at(w, _behind(2.5, 6.0), 0.0, randf_range(0.85, 1.05))
	elif r < 0.45:
		var a := randf() * TAU
		Audio.play_at("creep_knock", player.global_position + Vector3(cos(a), 0.5, sin(a)) * 14.0, 2.0, randf_range(0.9, 1.05))
	elif r < 0.57:
		Audio.play_at("creep_breath", _behind(1.0, 1.6), -4.0, randf_range(0.9, 1.05))
		_hold = 2.5
	elif r < 0.69:
		var a2 := randf() * TAU
		Audio.play_at("creep_scrape", player.global_position + Vector3(cos(a2), 0.3, sin(a2)) * 11.0, 0.0, randf_range(0.8, 1.1))
	elif r < 0.88:
		_flicker = randf_range(0.9, 1.8)
		_hold = 3.5
		Audio.play("creep_drone", -10.0, randf_range(0.9, 1.05))
	else:
		world.hud.flash_face(0.06)
		Audio.play(w, -6.0, 0.7)
		_hold = 2.0
