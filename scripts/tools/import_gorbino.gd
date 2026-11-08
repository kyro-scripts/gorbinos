extends SceneTree
## Converts the supplied Gorbino model (assets/models/gorbino/gorbino.fbx)
## into game-ready meshes: rotated to face -Z, feet on y = 0, 1 unit tall,
## and split into body + feet so the feet can be animated.
##   godot --headless --path . -s scripts/tools/import_gorbino.gd

const SRC := "res://assets/models/gorbino/gorbino.fbx"
const OUT := "res://assets/models/gorbino/"
const WELD := false


func _init() -> void:
	var scene: Node = (load(SRC) as PackedScene).instantiate()
	var mi: MeshInstance3D = _find_mesh(scene)
	var xf := _local_xf(mi, scene)
	# the model's face points along +X; turn it to -Z
	xf = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO) * xf
	var arr: Array = mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	if idx.is_empty():
		for i in verts.size():
			idx.append(i)
	for i in verts.size():
		verts[i] = xf * verts[i]
		norms[i] = (xf.basis * norms[i]).normalized()
	# connected components, welding vertices that share a position
	var parent := PackedInt32Array()
	parent.resize(verts.size())
	for i in verts.size():
		parent[i] = i
	var by_pos := {}
	for i in verts.size():
		var key := Vector3i((verts[i] * 2000.0).round())
		if WELD and by_pos.has(key):
			_union(parent, i, by_pos[key])
		else:
			by_pos[key] = i
	for t in range(0, idx.size(), 3):
		_union(parent, idx[t], idx[t + 1])
		_union(parent, idx[t], idx[t + 2])
	var comps := {}
	for t in range(0, idx.size(), 3):
		var r := _find(parent, idx[t])
		if not comps.has(r):
			comps[r] = PackedInt32Array()
		comps[r].append_array([idx[t], idx[t + 1], idx[t + 2]])
	var list := comps.values()
	list.sort_custom(func(a, b): return a.size() > b.size())
	print("components: ", list.map(func(c): return c.size() / 3))
	# normalise: 1 unit tall, feet on the floor, body centred on x/z
	var all := AABB(verts[idx[0]], Vector3.ZERO)
	for i in idx:
		all = all.expand(verts[i])
	var body_box := AABB()
	for c in list:
		if _box(verts, c).size.y > all.size.y * 0.5:
			body_box = _box(verts, c) if body_box.size == Vector3.ZERO else body_box.merge(_box(verts, c))
	var s := 1.0 / all.size.y
	var off := Vector3(-body_box.get_center().x, -all.position.y, -body_box.get_center().z)
	for i in verts.size():
		verts[i] = (verts[i] + off) * s
	# body shells are tall; the two feet are small shells either side
	var groups := {"body": PackedInt32Array(), "foot_l": PackedInt32Array(), "foot_r": PackedInt32Array()}
	for c in list:
		var b := _box(verts, c)
		var g := "body" if b.size.y > 0.5 else ("foot_l" if b.get_center().x < 0.0 else "foot_r")
		groups[g].append_array(c)
	var names := groups.keys()
	var ordered := groups.values()
	for k in ordered.size():
		var tri: PackedInt32Array = ordered[k]
		var remap := {}
		var v := PackedVector3Array()
		var n := PackedVector3Array()
		var u := PackedVector2Array()
		var ni := PackedInt32Array()
		for i in tri:
			if not remap.has(i):
				remap[i] = v.size()
				v.append(verts[i])
				n.append(norms[i])
				u.append(uvs[i])
			ni.append(remap[i])
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = v
		a[Mesh.ARRAY_NORMAL] = n
		a[Mesh.ARRAY_TEX_UV] = u
		a[Mesh.ARRAY_INDEX] = ni
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		var path := OUT + "gorbino_%s.res" % names[k]
		ResourceSaver.save(m, path)
		print(path, " tris=", ni.size() / 3, " aabb=", m.get_aabb())
	# where the painted features sit on the body (for glowing eyes / the maw)
	var bt: PackedInt32Array = groups["body"]
	for f in [["eye_a", Vector2(0.195, 0.71)], ["eye_b", Vector2(0.34, 0.705)], ["mouth", Vector2(0.31, 0.855)]]:
		print(f[0], " at ", _uv_to_pos(verts, uvs, bt, f[1]))
	scene.free()
	quit()


func _uv_to_pos(verts: PackedVector3Array, uvs: PackedVector2Array, tri: PackedInt32Array, uv: Vector2) -> Vector3:
	for t in range(0, tri.size(), 3):
		var a := uvs[tri[t]]
		var b := uvs[tri[t + 1]]
		var c := uvs[tri[t + 2]]
		var v0 := b - a
		var v1 := c - a
		var v2 := uv - a
		var d := v0.x * v1.y - v1.x * v0.y
		if absf(d) < 1e-9:
			continue
		var l1 := (v2.x * v1.y - v1.x * v2.y) / d
		var l2 := (v0.x * v2.y - v2.x * v0.y) / d
		if l1 >= 0.0 and l2 >= 0.0 and l1 + l2 <= 1.0:
			return verts[tri[t]] * (1.0 - l1 - l2) + verts[tri[t + 1]] * l1 + verts[tri[t + 2]] * l2
	return Vector3.INF


func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_mesh(c)
		if r:
			return r
	return null


func _local_xf(n: Node3D, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != root:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return (root as Node3D).transform * xf


func _box(verts: PackedVector3Array, tri: PackedInt32Array) -> AABB:
	var b := AABB(verts[tri[0]], Vector3.ZERO)
	for i in tri:
		b = b.expand(verts[i])
	return b


func _find(p: PackedInt32Array, i: int) -> int:
	while p[i] != i:
		p[i] = p[p[i]]
		i = p[i]
	return i


func _union(p: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(p, a)
	var rb := _find(p, b)
	if ra != rb:
		p[ra] = rb
