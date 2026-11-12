class_name Hyper
extends RefCounted
## FISH-style hyperreal bits in the world: photo-real trout cut out of a
## magazine and pasted on the walls round every level (tied to the COLLAGE
## FX option), and the trout the trout launcher fires.

const WALL_SKIP := ["window", "sign", "poster", "exit", "switch", "elevator", "computer", "logo", "lantern", "stencil",
	"alert", "warning", "panel", "vat", "static", "void", "snirbface", "eyes", "glyph", "swirl"]

static var _shader: Shader


## A flat photo quad of the given width (height follows the picture).
static func quad(name: String, width: float, billboard := false) -> MeshInstance3D:
	if _shader == null:
		_shader = load("res://shaders/hyperreal.gdshader")
	var t: Texture2D = Collage.texture(name)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, width * float(t.get_height()) / float(t.get_width()))
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tex", t)
	m.set_shader_parameter("billboard", 1.0 if billboard else 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A handful of trout pasted on walls round the level, at random (but the
## same ones every time you play it).
static func paste_fish(lv: Level) -> Node3D:
	var root := Node3D.new()
	root.name = "WallFish"
	lv.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(lv.data.get("name", "")) + "fish")
	var cands := []
	for i in lv.solid.size():
		if lv.solid[i] != 0 or lv.movers.has(i) or lv.use_cells.has(i):
			continue
		if lv.ceil_h[i] - lv.floor_h[i] < 2.6:
			continue
		var sec: Dictionary = lv.cells[i]
		if sec.get("secret", false) or String(sec.get("liquid", "")) != "":
			continue
		var c := Vector2i(i % lv.W, i / lv.W)
		for dv in Level.DIRS4:
			var n := lv.idx_of(c + dv)
			if n < 0 or lv.solid[n] != 1 or lv.movers.has(n) or lv.use_cells.has(n):
				continue
			var wsec: Dictionary = lv.cells[n]
			if wsec.get("secret", false):
				continue
			# leave windows, signs, switches and the like alone
			var wt := String(wsec.get("wall", lv.data.get("wall", "")))
			var skip := false
			for w in WALL_SKIP:
				if wt.contains(w):
					skip = true
			if skip:
				continue
			# the wall has to carry on either side, so a fish doesn't hang off a corner
			var side := Vector2i(dv.y, dv.x)
			var s1 := lv.idx_of(c + dv + side)
			var s2 := lv.idx_of(c + dv - side)
			if s1 < 0 or s2 < 0 or lv.solid[s1] != 1 or lv.solid[s2] != 1:
				continue
			cands.append([c, dv])
	var want := int(lv.data.get("wall_fish", 6))
	var placed := []
	var tries := 0
	while placed.size() < want and tries < 500 and cands.size() > 0:
		tries += 1
		var cand: Array = cands[rng.randi_range(0, cands.size() - 1)]
		var c: Vector2i = cand[0]
		var far := true
		for pc in placed:
			if absi(pc.x - c.x) + absi(pc.y - c.y) < 9:
				far = false
				break
		if not far:
			continue
		placed.append(c)
		var dv: Vector2i = cand[1]
		var i := lv.idx_of(c)
		var dir := Vector3(dv.x, 0, dv.y)
		var mi := quad("hr_fish", rng.randf_range(1.1, 2.0))
		root.add_child(mi)
		var hgt := (mi.mesh as QuadMesh).size.y
		var pos := lv.cell_center(c) + dir * (Level.S * 0.5 - 0.03)
		pos.y = lv.floor_h[i] + clampf(rng.randf_range(0.9, 2.1), hgt * 0.5 + 0.15, lv.ceil_h[i] - lv.floor_h[i] - hgt * 0.5 - 0.15)
		mi.global_position = pos
		var b := Basis.looking_at(dir, Vector3.UP)
		if rng.randf() < 0.5:
			b = b.scaled_local(Vector3(-1, 1, 1))       # swimming the other way
		mi.basis = b
		mi.rotate_object_local(Vector3.FORWARD, rng.randf_range(-0.4, 0.4))
	root.visible = Collage.enabled()
	return root
