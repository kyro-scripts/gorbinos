class_name FlameBit
extends Sprite3D
## One puff of the flamethrower's stream: shoots out, slows, swells, goes
## from white-hot to orange to a sooty curl, and is gone.

var vel := Vector3.ZERO
var life := 0.45
var t := 0.0
var level: Node
var size_k := 1.0


static func spawn(lvl: Node, pos: Vector3, v: Vector3) -> void:
	var f := FlameBit.new()
	f.level = lvl
	f.vel = v
	f.life = randf_range(0.22, 0.5)
	f.size_k = randf_range(0.7, 1.25)
	f.texture = Mat.tex("proj_fire")
	f.hframes = 2
	f.frame = randi() % 2
	f.pixel_size = 0.012
	f.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	f.shaded = false
	f.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	f.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	f.rotation.z = randf() * TAU
	lvl.fx_root().add_child(f)
	f.global_position = pos


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	var k := t / life
	vel = vel * pow(0.2, delta) + Vector3(0, 2.5 * delta, 0)
	var np := global_position + vel * delta
	# lick along walls instead of going through them
	if level and level.has_method("ray"):
		var hit: Dictionary = level.ray(global_position, np, 1)
		if not hit.is_empty():
			np = hit["position"] + hit["normal"] * 0.05
			vel = vel.slide(hit["normal"]) * 0.5
	global_position = np
	pixel_size = (0.018 + 0.05 * sqrt(k)) * size_k
	rotation.z += delta * 3.0
	if k < 0.25:
		modulate = Color(1.0, 1.0, 0.85).lerp(Color(1.0, 0.75, 0.2), k / 0.25)
	elif k < 0.7:
		modulate = Color(1.0, 0.75, 0.2).lerp(Color(1.0, 0.25, 0.05), (k - 0.25) / 0.45)
	else:
		modulate = Color(1.0, 0.25, 0.05).lerp(Color(0.15, 0.1, 0.1, 0.0), (k - 0.7) / 0.3)
	if randf() < delta * 10.0:
		frame = (frame + 1) % 2
