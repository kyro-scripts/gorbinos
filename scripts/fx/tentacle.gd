class_name Tentacle
extends Node3D
## The whip: a wet, tapering tentacle with suckers, strung from the player's
## left hand to wherever its tip is. Each segment is a squashed ball placed
## along a curve that writhes and sags; it gets a paper cut-out border like
## the creatures.

const SEGS := 18

var segs: Array = []
var radii: Array = []
var _t := 0.0


func _ready() -> void:
	var skin := Mat.make("d_flesh", {"origin": true, "tint": Color(0.95, 0.45, 0.85), "shade": 0.8, "gloss": 1.0})
	var sucker := Mat.make("white", {"origin": true, "tint": Color(1.0, 0.8, 0.88), "shade": 0.6, "gloss": 1.0})
	for k in SEGS:
		var r := lerpf(0.05, 0.022, float(k) / (SEGS - 1))
		var mi := Models.mi(Models.sphere(r, 7, 5), skin)
		mi.scale = Vector3(1.0, 1.0, 1.6)
		add_child(mi)
		radii.append(r)
		if k % 2 == 1:
			mi.add_child(Models.mi(Models.sphere(r * 0.45, 5, 3), sucker, Vector3(0, -r * 0.8, 0)))
		segs.append(mi)
	Collage.outline_viewmodel(self)


## Lay the tentacle from a (hand) to b (tip). reach 0..1: how much of it is
## out. slack: how much it sags and writhes.
func lay(a: Vector3, b: Vector3, reach: float, slack: float, delta: float) -> void:
	_t += delta
	var tip := a.lerp(b, reach)
	var dir := tip - a
	var length := dir.length()
	if length < 0.01:
		visible = false
		return
	visible = true
	dir /= length
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(dir).normalized()
	for k in SEGS:
		var s := float(k) / (SEGS - 1)
		var p := a + dir * length * s
		var w := sin(s * PI)
		p += up * (-w * slack * length * 0.12 + sin(s * 9.0 - _t * 26.0) * w * slack * 0.12)
		p += side * sin(s * 7.0 + _t * 19.0) * w * slack * 0.15
		var mi: MeshInstance3D = segs[k]
		mi.global_position = p
		# stretch each bit so the tentacle stays one piece however far it reaches
		var spacing := length / (SEGS - 1)
		mi.scale = Vector3(1.0, 1.0, maxf(1.6, spacing / (2.0 * float(radii[k])) * 1.3))
		var nxt := a + dir * length * minf(s + 0.06, 1.0)
		if nxt.distance_to(p) > 0.001:
			mi.look_at(nxt + up * 0.0001, up)
