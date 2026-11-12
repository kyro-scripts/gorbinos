class_name TroutShot
extends Node3D
## A trout fired from the trout launcher: a photo-real fish tumbling end
## over end in an arc. Straight into something, it slaps it hard and bursts.
## Otherwise it bounces, lands, flops about on the floor for a moment, and
## then bursts, slapping anything close.

const GRAVITY := 14.0
const FLOP_TIME := 1.1

var level: Level
var shooter: Node
var vel := Vector3.ZERO
var damage := 70.0
var splash := 40.0
var splash_r := 3.0
var bounces := 0
var flop_t := -1.0
var ttl := 6.0
var _spin := 0.0
var _spin_v := 14.0
var _hop_t := 0.0
var _fish: MeshInstance3D
var _mat: ShaderMaterial
var _exclude: Array = []


func launch(lvl: Level, p_shooter: Node, pos: Vector3, p_vel: Vector3, dmg: float) -> void:
	level = lvl
	shooter = p_shooter
	vel = p_vel
	damage = dmg
	if shooter is CollisionObject3D:
		_exclude = [shooter.get_rid()]
	_fish = Hyper.quad("hr_fish", 0.85, true)
	_mat = _fish.material_override
	add_child(_fish)
	global_position = pos
	_spin_v = randf_range(11.0, 16.0) * (1.0 if randf() < 0.5 else -1.0)


func _physics_process(delta: float) -> void:
	ttl -= delta
	if ttl <= 0.0:
		_burst()
		return
	if flop_t >= 0.0:
		_flop(delta)
		return
	_spin += _spin_v * delta
	_mat.set_shader_parameter("spin", _spin)
	vel.y -= GRAVITY * delta
	var from := global_position
	var to := from + vel * delta
	var hit := level.ray(from, to, 1 | 4 | 8 | 32, _exclude, true)
	if hit.is_empty():
		global_position = to
		return
	var col = hit["collider"]
	if col and col.has_method("take_damage"):
		# a trout across the face
		col.take_damage(damage, shooter, vel.normalized(), "proj")
		Audio.play_at("trout_slap", hit["position"], 2.0, randf_range(0.9, 1.1))
		global_position = hit["position"]
		_burst()
		return
	# off a wall or the floor: bounce, losing most of its go
	var n: Vector3 = hit["normal"]
	global_position = hit["position"] + n * 0.08
	vel = vel.bounce(n) * 0.45
	bounces += 1
	_spin_v *= -0.7
	Audio.play_at("trout_flop", global_position, -2.0, randf_range(0.85, 1.15))
	Fx.decal(level, hit["position"], n, "splat", randf_range(0.25, 0.4), Color(0.7, 0.75, 0.7, 0.8))
	if n.y > 0.6 and (vel.length() < 4.0 or bounces >= 3):
		flop_t = FLOP_TIME
		vel = Vector3.ZERO


## Lying on the floor, flapping about, little hops.
func _flop(delta: float) -> void:
	flop_t -= delta
	_hop_t -= delta
	_spin = sin(Time.get_ticks_msec() * 0.03) * 0.6
	_mat.set_shader_parameter("spin", _spin + PI * 0.5)
	if _hop_t <= 0.0:
		_hop_t = randf_range(0.18, 0.35)
		Audio.play_at("trout_flop", global_position, -8.0, randf_range(1.0, 1.4))
	var floor_y := level.floor_at(global_position) + 0.12
	global_position.y = floor_y + absf(sin((FLOP_TIME - flop_t) * 16.0)) * 0.18
	if flop_t <= 0.0:
		_burst()


## Bursts: a slap for anything close, guts and silver scales everywhere.
func _burst() -> void:
	var p := global_position
	if splash > 0.0:
		level.radius_damage(p + Vector3(0, 0.3, 0), splash_r, splash, shooter, "proj")
	Fx.gibs(level, p, Color(0.78, 0.8, 0.74), Color(0.75, 0.15, 0.2), 5)
	Fx.debris(level, p + Vector3(0, 0.3, 0), Color(0.85, 0.88, 0.85), 10)
	Fx.light(level, p + Vector3(0, 0.5, 0), Color(1.0, 0.6, 0.7), 4.0, 0.8, 0.1)
	Audio.play_at("trout_slap", p, -2.0, randf_range(0.7, 0.85))
	Collage.burst(level, p + Vector3(0, 0.6, 0))
	queue_free()
