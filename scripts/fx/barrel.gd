class_name Barrel
extends StaticBody3D
## GORB-COLA barrel. Shoot it. It explodes. Chains into other barrels.

var level: Node
var hp := 25.0
var exploded := false
var spawn_id := -1
var _pending := -1.0
var _killer: Node = null
var model: Node3D


func setup(lvl: Node, pos: Vector3) -> void:
	level = lvl
	collision_layer = 8
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.38
	cyl.height = 1.1
	cs.shape = cyl
	cs.position = Vector3(0, 0.55, 0)
	add_child(cs)
	model = Models.barrel()
	add_child(model)
	global_position = pos
	rotation.y = randf() * TAU


func center_point() -> Vector3:
	return global_position + Vector3(0, 0.55, 0)


func take_damage(amount: float, source: Node, _dir: Vector3, kind := "bullet") -> void:
	if exploded or _pending >= 0.0:
		return
	hp -= amount
	if hp <= 0.0:
		_killer = source
		_pending = 0.12 if kind == "explosion" else 0.02


func _physics_process(delta: float) -> void:
	if _pending < 0.0 or exploded:
		return
	_pending -= delta
	if _pending <= 0.0:
		_explode()


func _explode() -> void:
	exploded = true
	var c := center_point()
	visible = false
	collision_layer = 0
	Fx.explosion(level, c, true)
	Fx.decal(level, global_position + Vector3(0, 0.02, 0), Vector3.UP, "splat", 2.2, Color(0.1, 0.25, 0.05))
	level.radius_damage(c, 5.0, 115.0, _killer if _killer else self, "explosion")
	level.noise_at(c, 14)


func remove_silently() -> void:
	exploded = true
	visible = false
	collision_layer = 0
