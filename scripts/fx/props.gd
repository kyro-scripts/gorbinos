class_name Props
extends RefCounted
## Decorative / functional props placed by the level map.


static func _body(radius: float, height: float) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = radius
	c.height = height
	cs.shape = c
	cs.position = Vector3(0, height * 0.5, 0)
	b.add_child(cs)
	return b


static func make_prop(kind: String, level: Node, pos: Vector3) -> Node3D:
	var root: Node3D
	var o := {"origin": true}
	match kind:
		"lamp":
			# street lamp: footed pole, a bent arm, a caged lantern with a glowing bulb
			root = _body(0.25, 2.2)
			var iron := Mat.world("gun_dark", o)
			var glow := Mat.world("lamp", {"origin": true, "fullbright": 1.0, "tint": level.data.get("lamp_color", Color(1, 0.95, 0.7))})
			root.add_child(Models.mi(Models.cyl(0.16, 0.2, 0.18, 8), iron, Vector3(0, 0.09, 0)))
			root.add_child(Models.mi(Models.cyl(0.05, 0.07, 2.3, 8), iron, Vector3(0, 1.3, 0)))
			root.add_child(Models.mi(Models.box(0.06, 0.06, 0.55), iron, Vector3(0, 2.42, -0.24), Vector3(-12, 0, 0)))
			root.add_child(Models.mi(Models.cyl(0.02, 0.02, 0.2, 5), iron, Vector3(0, 2.36, -0.5)))
			var lantern := Models.pivot(Vector3(0, 2.12, -0.5))
			root.add_child(lantern)
			lantern.add_child(Models.mi(Models.sphere(0.13, 8, 6), glow, Vector3.ZERO))
			for k in 4:
				var a := k * TAU / 4.0 + PI * 0.25
				lantern.add_child(Models.mi(Models.box(0.025, 0.36, 0.025), iron, Vector3(cos(a) * 0.15, 0, sin(a) * 0.15)))
			lantern.add_child(Models.mi(Models.cyl(0.0, 0.22, 0.14, 4), iron, Vector3(0, 0.24, 0), Vector3(0, 45, 0)))
			lantern.add_child(Models.mi(Models.cyl(0.16, 0.12, 0.05, 4), iron, Vector3(0, -0.2, 0), Vector3(0, 45, 0)))
			# a few dead flies stuck to the glass
			for k in 4:
				lantern.add_child(Models.mi(Models.box(0.025, 0.012, 0.012), Mat.world("black", o), Vector3(cos(k * 2.1) * 0.13, -0.05 + k * 0.03, sin(k * 2.1) * 0.13)))
		"statue":
			# a little shrine to the Gorbino: stepped pedestal, a brass plaque,
			# candles burning round the base
			root = _body(0.75, 2.6)
			var stone := Mat.world("stone", o)
			root.add_child(Models.mi(Models.box(1.5, 0.2, 1.5), stone, Vector3(0, 0.1, 0)))
			root.add_child(Models.mi(Models.box(1.2, 0.5, 1.2), stone, Vector3(0, 0.45, 0)))
			root.add_child(Models.mi(Models.box(1.32, 0.1, 1.32), stone, Vector3(0, 0.74, 0)))
			root.add_child(Models.mi(Models.box(0.5, 0.2, 0.02), Mat.world("gun_brass", o), Vector3(0, 0.45, -0.61)))
			var g := Models.gorbino(Color(0.75, 0.73, 0.7))
			g.position = Vector3(0, 0.79, 0)
			g.scale = Vector3.ONE * 1.05
			# turn the statue to stone
			_stoneify(g)
			root.add_child(g)
			var wax := Mat.world("white", {"origin": true, "tint": Color(0.95, 0.9, 0.75)})
			var flame := Mat.world("white", {"origin": true, "tint": Color(1.0, 0.7, 0.2), "fullbright": 1.0})
			for k in 6:
				var a := k * TAU / 6.0 + 0.3
				var cp := Vector3(cos(a) * 0.68, 0.2, sin(a) * 0.68)
				var h := 0.12 + 0.08 * fmod(k * 0.37, 1.0)
				root.add_child(Models.mi(Models.cyl(0.025, 0.03, h, 6), wax, cp + Vector3(0, h * 0.5, 0)))
				root.add_child(Models.mi(Models.cyl(0.0, 0.014, 0.04, 4), flame, cp + Vector3(0, h + 0.02, 0)))
		"tree":
			root = _body(0.35, 3.0)
			# someone left a noose on it
			var rope := Mat.world("white", {"origin": true, "tint": Color(0.7, 0.6, 0.4)})
			root.add_child(Models.mi(Models.box(0.6, 0.03, 0.03), rope, Vector3(0.45, 2.25, 0.0), Vector3(0, 0, -8)))
			root.add_child(Models.mi(Models.cyl(0.012, 0.012, 0.8, 4), rope, Vector3(0.72, 1.85, 0.0)))
			root.add_child(Models.mi(Models.cyl(0.09, 0.09, 0.025, 8), rope, Vector3(0.72, 1.42, 0.0), Vector3(90, 0, 0)))
			var trunk := Mat.world("m_beam", o)
			root.add_child(Models.mi(Models.cyl(0.15, 0.25, 2.2, 6), trunk, Vector3(0, 1.1, 0), Vector3(0, 0, 4)))
			var leaf := Mat.world(String(level.data.get("tree_tex", "v_hedge")), o)
			root.add_child(Models.mi(Models.sphere(1.0, 7, 5), leaf, Vector3(0, 2.6, 0), Vector3.ZERO, Vector3(1.0, 0.8, 1.0)))
			root.add_child(Models.mi(Models.sphere(0.6, 6, 4), leaf, Vector3(0.6, 2.2, 0.3)))
			root.add_child(Models.mi(Models.sphere(0.55, 6, 4), leaf, Vector3(-0.5, 2.3, -0.4)))
		"machine":
			# a humming cabinet: pipes out of the top, a gauge, blinking lamps, a vent
			root = _body(0.8, 2.0)
			var dk := Mat.world("gun_dark", o)
			var metal := Mat.world("gun_metal", o)
			root.add_child(Models.mi(Models.box(1.5, 2.0, 1.5), Mat.world("tech_panel", {"origin": true, "fullbright": 0.3}), Vector3(0, 1.0, 0)))
			root.add_child(Models.mi(Models.box(1.6, 0.2, 1.6), dk, Vector3(0, 2.05, 0)))
			root.add_child(Models.mi(Models.box(1.56, 0.12, 1.56), dk, Vector3(0, 0.06, 0)))
			for x in [-0.4, 0.15]:
				root.add_child(Models.mi(Models.cyl(0.09, 0.09, 0.8, 8), metal, Vector3(x, 2.5, 0.3)))
				root.add_child(Models.mi(Models.cyl(0.11, 0.11, 0.06, 8), dk, Vector3(x, 2.88, 0.3)))
			root.add_child(Models.mi(Models.cyl(0.07, 0.07, 0.9, 8), metal, Vector3(-0.4, 2.95, 0.75), Vector3(90, 0, 0)))
			root.add_child(Models.mi(Models.cyl(0.16, 0.16, 0.04, 12), Mat.world("white", {"origin": true, "tint": Color(0.9, 0.9, 0.8)}), Vector3(0.35, 1.45, -0.77), Vector3(90, 0, 0)))
			root.add_child(Models.mi(Models.cyl(0.18, 0.18, 0.03, 12), dk, Vector3(0.35, 1.45, -0.755), Vector3(90, 0, 0)))
			var needle := Models.mi(Models.box(0.01, 0.12, 0.01), Mat.world("gun_red", o), Vector3(0.35, 1.5, -0.795), Vector3(0, 0, -35))
			root.add_child(needle)
			for k in 3:
				var col: Color = [Color(1, 0.1, 0.1), Color(0.2, 1, 0.2), Color(1, 0.8, 0.1)][k]
				root.add_child(Models.mi(Models.sphere(0.05, 6, 4), Mat.world("white", {"origin": true, "tint": col, "fullbright": 1.0}), Vector3(-0.45 + k * 0.17, 1.75, -0.77)))
			for k in 5:
				root.add_child(Models.mi(Models.box(0.8, 0.03, 0.03), dk, Vector3(-0.15, 0.4 + k * 0.08, -0.77)))
		"checkpoint":
			root = _body(0.3, 1.6)
			root.add_child(Models.mi(Models.box(0.5, 1.4, 0.5), Mat.world("checkpoint", {"origin": true, "fullbright": 0.7}), Vector3(0, 0.7, 0)))
			var head := Models.gorbino(Color(0.25, 0.45, 0.12))
			head.scale = Vector3.ONE * 0.35
			head.position = Vector3(0, 1.4, 0)
			root.add_child(head)
			root.set_script(load("res://scripts/fx/spinner.gd"))
			root.set("spin_node", head)
		"exit_pad":
			root = Node3D.new()
			root.add_child(Models.mi(Models.cyl(0.95, 0.95, 0.06, 12), Mat.world("teleport_pad", {"origin": true, "fullbright": 1.0, "tint": Color(1, 0.4, 0.4)}), Vector3(0, 0.03, 0)))
			var sign := Models.mi(Models.box(1.0, 0.5, 0.05), Mat.world("exit_panel", {"origin": true, "fullbright": 1.0}), Vector3(0, 2.2, 0))
			root.add_child(sign)
			root.set_script(load("res://scripts/fx/spinner.gd"))
			root.set("spin_node", sign)
			Fx.light(level, pos + Vector3(0, 1.0, 0), Color(1.0, 0.3, 0.3), 5.0, 1.3, -1.0, root)
		"teleporter":
			root = Node3D.new()
			root.add_child(Models.mi(Models.cyl(0.95, 0.95, 0.06, 12), Mat.world("teleport_pad", {"origin": true, "fullbright": 1.0, "scroll": Vector2(0.0, 0.3)}), Vector3(0, 0.03, 0)))
			Fx.light(level, pos + Vector3(0, 1.0, 0), Color(0.3, 1.0, 0.8), 4.0, 1.0, -1.0, root)
		_:
			root = Node3D.new()
	root.position = pos
	return root


static func _stoneify(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			c.material_override = Mat.world("stone", {"origin": true})
		_stoneify(c)
