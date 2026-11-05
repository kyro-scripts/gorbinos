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
			root = _body(0.25, 2.2)
			root.add_child(Models.mi(Models.cyl(0.06, 0.09, 2.0, 6), Mat.world("gun_dark", o), Vector3(0, 1.0, 0)))
			root.add_child(Models.mi(Models.box(0.36, 0.42, 0.36), Mat.world("lamp", {"origin": true, "fullbright": 1.0, "tint": level.data.get("lamp_color", Color(1, 0.95, 0.7))}), Vector3(0, 2.15, 0)))
			root.add_child(Models.mi(Models.cyl(0.0, 0.3, 0.2, 4), Mat.world("gun_dark", o), Vector3(0, 2.45, 0), Vector3(0, 45, 0)))
		"statue":
			root = _body(0.7, 2.6)
			root.add_child(Models.mi(Models.box(1.3, 0.6, 1.3), Mat.world("stone", o), Vector3(0, 0.3, 0)))
			var g := Models.gorbino(Color(0.75, 0.73, 0.7))
			g.position = Vector3(0, 0.6, 0)
			g.scale = Vector3.ONE * 1.1
			# turn the statue to stone
			_stoneify(g)
			root.add_child(g)
		"tree":
			root = _body(0.35, 3.0)
			var trunk := Mat.world("m_beam", o)
			root.add_child(Models.mi(Models.cyl(0.15, 0.25, 2.2, 6), trunk, Vector3(0, 1.1, 0), Vector3(0, 0, 4)))
			var leaf := Mat.world(String(level.data.get("tree_tex", "v_hedge")), o)
			root.add_child(Models.mi(Models.sphere(1.0, 7, 5), leaf, Vector3(0, 2.6, 0), Vector3.ZERO, Vector3(1.0, 0.8, 1.0)))
			root.add_child(Models.mi(Models.sphere(0.6, 6, 4), leaf, Vector3(0.6, 2.2, 0.3)))
			root.add_child(Models.mi(Models.sphere(0.55, 6, 4), leaf, Vector3(-0.5, 2.3, -0.4)))
		"machine":
			root = _body(0.8, 2.0)
			root.add_child(Models.mi(Models.box(1.5, 2.0, 1.5), Mat.world("tech_panel", {"origin": true, "fullbright": 0.3}), Vector3(0, 1.0, 0)))
			root.add_child(Models.mi(Models.box(1.6, 0.2, 1.6), Mat.world("gun_dark", o), Vector3(0, 2.05, 0)))
		"checkpoint":
			root = _body(0.3, 1.6)
			root.add_child(Models.mi(Models.box(0.5, 1.4, 0.5), Mat.world("checkpoint", {"origin": true, "fullbright": 0.7}), Vector3(0, 0.7, 0)))
			var head := Models.gorbino(Color(0.4, 1.0, 0.4))
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
