class_name GutRope
extends Node3D
## A string of intestine that slides out of a wound and slumps onto the
## floor: a short verlet chain drawn as overlapping wet lumps.

const SEG := 0.11
const MAX_ROPES := 10

var level: Node
var anchor: Node3D             # the wound; the first link stays in it while pinned
var pinned := true
var count := 14
var out_dir := Vector3.FORWARD
var pts := PackedVector3Array()
var prev := PackedVector3Array()
var lumps: Array[MeshInstance3D] = []
var emerged := 0
var _emerge_t := 0.0
var _life := 0.0


func setup(lvl: Node, wound: Node3D, n: int, push: Vector3, tint: Color) -> void:
	level = lvl
	anchor = wound
	count = n
	out_dir = push
	var mat := Mat.make("gore_guts", {"origin": false, "tint": tint, "shade": 0.8, "gloss": 1.0, "fullbright": 0.1})
	var p0 := anchor.global_position
	for i in count:
		pts.append(p0)
		prev.append(p0)
		var r := 0.068 + 0.014 * sin(i * 2.1)
		var m := Models.mi(Models.sphere(r, 7, 5), mat)
		m.visible = false
		add_child(m)
		lumps.append(m)
	add_to_group("guts")
	var all := get_tree().get_nodes_in_group("guts")
	if all.size() > MAX_ROPES:
		all[0].queue_free()


func release() -> void:
	pinned = false


func _process(delta: float) -> void:
	if level == null:
		return
	delta = minf(delta, 1.0 / 30.0)
	_life += delta
	var root := anchor.global_position if anchor and is_instance_valid(anchor) else pts[0]
	# links squeeze out of the wound one by one
	_emerge_t -= delta
	if emerged < count and _emerge_t <= 0.0:
		_emerge_t = 0.045
		pts[emerged] = root
		prev[emerged] = root - (out_dir * 2.2 + Vector3(randf_range(-0.6, 0.6), 0.4, randf_range(-0.6, 0.6))) * delta
		lumps[emerged].visible = true
		emerged += 1
	var g := Vector3(0, -14.0, 0) * delta * delta
	for i in emerged:
		var p := pts[i]
		var v := (p - prev[i]) * 0.97
		prev[i] = p
		p += v + g
		var fl: float = level.floor_at(p) + 0.05
		if p.y < fl:
			p.y = fl
			# friction on the floor
			prev[i] = Vector3(lerpf(prev[i].x, p.x, 0.5), p.y, lerpf(prev[i].z, p.z, 0.5))
		pts[i] = p
	for it in 6:
		if pinned and emerged > 0 and anchor and is_instance_valid(anchor):
			pts[0] = root
		for i in range(1, emerged):
			var d := pts[i] - pts[i - 1]
			var l := d.length()
			if l < 0.0001:
				continue
			var corr := d * (1.0 - SEG / l) * 0.5
			if i - 1 == 0 and pinned:
				pts[i] -= corr * 2.0
			else:
				pts[i - 1] += corr
				pts[i] -= corr
	for i in emerged:
		lumps[i].global_position = pts[i]
	if _life > 12.0 and not pinned:
		set_process(false)
