class_name Gib
extends Node3D
## A chunk that flies, bounces on the level floor and settles.

var vel := Vector3.ZERO
var spin := Vector3.ZERO
var level: Node = null
var life := -1.0      # < 0: stays forever (until culled)
var splat := Color(0, 0, 0, 0)   # leaves a splat of this where it first lands
var _rest := false


func _process(delta: float) -> void:
	if life >= 0.0:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
	if _rest or level == null:
		return
	vel.y -= 20.0 * delta
	var p := global_position + vel * delta
	var fl: float = level.floor_at(p)
	var ci: int = level.idx_of(level.cell_of(p))
	if ci < 0 or level.solid[ci] == 1:
		vel.x *= -0.4
		vel.z *= -0.4
		p.x = global_position.x
		p.z = global_position.z
	if p.y <= fl + 0.05:
		if splat.a > 0.0 and vel.y < -2.5 and level.has_method("ray"):
			Fx.decal(level, Vector3(p.x, fl, p.z), Vector3.UP, "splat", randf_range(0.3, 0.7), splat.darkened(0.15))
			splat.a = 0.0
		p.y = fl + 0.05
		if abs(vel.y) < 1.5:
			_rest = true
			rotation.x = 0.0
			rotation.z = 0.0
		vel.y = -vel.y * 0.35
		vel.x *= 0.6
		vel.z *= 0.6
	global_position = p
	rotation += spin * delta
