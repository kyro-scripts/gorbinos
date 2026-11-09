class_name Creatures
extends RefCounted
## The creatures of Gorbino's Quest:
##  - Gorbino: the supplied model (assets/models/gorbino), a glossy round blob
##    on two round feet, recoloured per variant. Moves with the hop style.
##  - Snirby: a blue ball wearing the supplied face texture, with a long beak
##    in the same blue skin and orange shoes. Moves with the wobble style.
##  - Snotling: a little pink, lumpy, snot-nosed blob.
## Each model stores its animatable parts in the "parts" metadata, and
## animate() / death_pose() drive them.

const GORB_H := 1.45            # Gorbino height in metres at scale 1
const GORB_SQUASH_Y := 0.1      # bottom of the body sphere (model units)
const GORB_EYES := [Vector3(0.12, 0.589, -0.43), Vector3(-0.137, 0.599, -0.423)]
const GORB_MOUTH := Vector3(-0.08, 0.348, -0.393)
const SNIRBY_R := 0.5           # Snirby body radius
const SNIRBY_Y := 0.62          # Snirby body centre height

static var _mesh_cache := {}


# ================================================================== meshes
## Lumpy ellipsoid. UV u = 0.5 faces -Z (the creature's front), v = 0 at top.
static func blob_mesh(radius: float, stretch: Vector3, seed: int, lumpiness := 0.08, rings := 12, segs := 18) -> ArrayMesh:
	var key := "blob%s%s%d%s%d%d" % [radius, stretch, seed, lumpiness, rings, segs]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var rnd := RandomNumberGenerator.new()
	rnd.seed = seed
	var lumps := []
	for k in 6:
		var d := Vector3(rnd.randf_range(-1, 1), rnd.randf_range(-1, 1), rnd.randf_range(-1, 1)).normalized()
		lumps.append([d, rnd.randf_range(0.5, 1.0) * lumpiness, rnd.randf_range(2.0, 5.0), rnd.randf() * TAU])
	var pos := []
	var uvs := []
	for i in rings + 1:
		var v := float(i) / rings
		var theta := v * PI
		var row_p := []
		var row_uv := []
		for j in segs + 1:
			var u := float(j) / segs
			var phi := (u - 0.5) * TAU
			var dir := Vector3(sin(theta) * sin(phi), cos(theta), -sin(theta) * cos(phi))
			var r := radius
			for L in lumps:
				r *= 1.0 + float(L[1]) * sin(dir.dot(L[0]) * float(L[2]) + float(L[3]))
			row_p.append(dir * r * stretch)
			row_uv.append(Vector2(u, v))
		pos.append(row_p)
		uvs.append(row_uv)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings:
		for j in segs:
			var quad := [[i, j], [i, j + 1], [i + 1, j], [i + 1, j + 1]]
			for tri in [[0, 2, 1], [1, 2, 3]]:
				for q in tri:
					var a: Array = quad[q]
					var p: Vector3 = pos[a[0]][a[1]]
					var n := p.normalized() if p.length() > 0.0001 else Vector3.UP
					st.set_normal(Vector3(n.x / stretch.x, n.y / stretch.y, n.z / stretch.z).normalized())
					st.set_uv(uvs[a[0]][a[1]])
					st.add_vertex(p)
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


## Sphere with a planar UV projection on its front (-Z) face, for eyes and
## mouths drawn as flat images.
static func face_mesh(rings := 8, segs := 12) -> ArrayMesh:
	var key := "face%d%d" % [rings, segs]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for i in rings + 1:
		var theta := float(i) / rings * PI
		var row := []
		for j in segs + 1:
			var phi := (float(j) / segs - 0.5) * TAU
			row.append(Vector3(sin(theta) * sin(phi), cos(theta), -sin(theta) * cos(phi)))
		pts.append(row)
	for i in rings:
		for j in segs:
			var quad := [pts[i][j], pts[i][j + 1], pts[i + 1][j], pts[i + 1][j + 1]]
			for tri in [[0, 2, 1], [1, 2, 3]]:
				for q in tri:
					var p: Vector3 = quad[q]
					st.set_normal(p)
					st.set_uv(Vector2(0.5 - p.x * 0.5, 0.5 - p.y * 0.5))
					st.add_vertex(p * 0.5)
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


static func _skin(tex: String, tint: Color, extra := {}) -> ShaderMaterial:
	var o := {"tint": tint, "origin": true, "shade": 0.85, "gloss": 0.45}
	for k in extra.keys():
		o[k] = extra[k]
	return Mat.make(tex, o)


static func _part(mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	return Models.mi(mesh, mat, pos, rot, scl)


# ================================================================== GORBINO
static func _gorb_mesh(part: String) -> Mesh:
	var key := "gorb_" + part
	if not _mesh_cache.has(key):
		_mesh_cache[key] = load("res://assets/models/gorbino/gorbino_%s.res" % part)
	return _mesh_cache[key]


## opts: skin (green/yellow/red/blue/purple/black), gun, launcher, glow_eyes
static func gorbino(color: Color, opts := {}) -> Node3D:
	var root := Node3D.new()
	var parts := {"kind": "gorbino"}
	var skin := Mat.make("cr_gorb_" + String(opts.get("skin", "green")), {"origin": true, "shade": 0.9, "gloss": 0.7})
	var limb := Mat.make("white", {"origin": true, "tint": color, "shade": 0.9, "gloss": 1.0})
	var maw_m := Mat.make("cr_gorbino_maw", {"origin": true, "shade": 0.5, "gloss": 0.8})
	parts["skin_mat"] = skin
	var H := GORB_H
	var body := Models.pivot()
	root.add_child(body)
	parts["body"] = body
	var squash := Models.pivot(Vector3(0, GORB_SQUASH_Y * H, 0))
	body.add_child(squash)
	parts["squash"] = squash
	parts["core"] = squash                  # pivot sits at the bottom of the body
	parts["core_y"] = squash.position.y
	parts["core_r"] = 0.0
	parts["roll_cy"] = 0.55 * H             # body centre height, and radius, for rolling over
	parts["roll_r"] = 0.42 * H
	squash.add_child(_part(_gorb_mesh("body"), skin, Vector3(0, -GORB_SQUASH_Y * H, 0), Vector3.ONE * H))
	# the two feet, each on its own pivot so they can step
	var feet := []
	var feet_base := []
	for side in ["l", "r"]:
		var m := _gorb_mesh("foot_" + side)
		var c := m.get_aabb().get_center() * H
		var f := Models.pivot(c)
		body.add_child(f)
		f.add_child(_part(m, skin, -c, Vector3.ONE * H))
		feet.append(f)
		feet_base.append(c)
	parts["feet"] = feet
	parts["feet_base"] = feet_base
	# glowing eyes for the elite; the others' eyes are painted on
	var eyes := []
	if opts.get("glow_eyes", false):
		var eye_m := Mat.make("white", {"origin": true, "tint": Color(1.0, 0.12, 0.05), "fullbright": 1.0, "shade": 0.3})
		for e in GORB_EYES:
			var ep := Models.pivot(Vector3(e.x, e.y - GORB_SQUASH_Y, e.z - 0.012) * H)
			squash.add_child(ep)
			ep.add_child(_part(Models.sphere(0.045 * H, 8, 6), eye_m))
			eyes.append(ep)
	parts["eyes"] = eyes
	# maw: a dark slit over the painted mouth that gapes when it attacks
	var mouth := Models.pivot(Vector3(GORB_MOUTH.x, GORB_MOUTH.y - GORB_SQUASH_Y, GORB_MOUTH.z - 0.03) * H)
	squash.add_child(mouth)
	mouth.add_child(_part(face_mesh(), maw_m, Vector3.ZERO, Vector3(0.36, 0.02, 0.1)))
	parts["mouth"] = mouth
	if opts.get("gun", false):
		# a pseudopod reaching forward with the gun
		var arm := Models.pivot(Vector3(0.55, 0.45, -0.22))
		squash.add_child(arm)
		arm.add_child(_part(blob_mesh(0.13, Vector3(1.0, 0.8, 2.2), 5140, 0.05, 6, 10), limb, Vector3(0, 0, -0.18)))
		var g := Models.pivot(Vector3(0, 0.02, -0.42))
		arm.add_child(g)
		g.add_child(Models.mi(Models.box(0.07, 0.09, 0.3), Mat.world("gun_dark", {"origin": true})))
		g.add_child(Models.mi(Models.box(0.05, 0.12, 0.06), Mat.world("gun_wood", {"origin": true}), Vector3(0, -0.08, 0.08)))
		parts["arm"] = arm
	if opts.get("launcher", false):
		var l := Models.pivot(Vector3(0.4, 1.12, 0.05))
		squash.add_child(l)
		l.add_child(Models.mi(Models.cyl(0.11, 0.11, 0.8, 8), Mat.world("gun_red", {"origin": true}), Vector3.ZERO, Vector3(90, 0, 0)))
		l.add_child(Models.mi(Models.cyl(0.08, 0.08, 0.05, 8), Mat.world("black", {"origin": true}), Vector3(0, 0, -0.41), Vector3(90, 0, 0)))
		parts["launcher"] = l
	root.set_meta("parts", parts)
	animate(root, 0.0, 0.016, {})
	return root


# ================================================================== SNIRBY
## Sphere wearing the face texture on its front (planar projection, viewer's
## left = texture left); the back faces sample plain blue skin.
static func snirby_body_mesh(rings := 14, segs := 22) -> ArrayMesh:
	var key := "snirby_body%d%d" % [rings, segs]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var pts := []
	for i in rings + 1:
		var theta := float(i) / rings * PI
		var row := []
		for j in segs + 1:
			var phi := (float(j) / segs - 0.5) * TAU
			row.append(Vector3(sin(theta) * sin(phi), cos(theta), -sin(theta) * cos(phi)))
		pts.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings:
		for j in segs:
			var quad := [pts[i][j], pts[i][j + 1], pts[i + 1][j], pts[i + 1][j + 1]]
			for tri in [[0, 2, 1], [1, 2, 3]]:
				var front: bool = (quad[tri[0]].z + quad[tri[1]].z + quad[tri[2]].z) < 0.15
				for q in tri:
					var p: Vector3 = quad[q]
					st.set_normal(p)
					st.set_uv(Vector2(0.5 - p.x * 0.5, 0.5 - p.y * 0.5) if front else Vector2(0.04, 0.5))
					st.add_vertex(p * SNIRBY_R)
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


## The beak: a cone pointing down -Z from its base at the origin, slightly
## flattened. Its UVs sample the plain blue of the face texture so it is
## the same skin as the body.
static func snirby_beak_mesh(length := 1.05, radius := 0.2, flat := 0.85, segs := 12) -> ArrayMesh:
	var key := "snirby_beak%s%s%s%d" % [length, radius, flat, segs]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip := Vector3(0, 0, -length)
	for j in segs:
		var a0 := float(j) / segs * TAU
		var a1 := float(j + 1) / segs * TAU
		var tri := [[a0, 0.0], [a1, 0.0], [(a0 + a1) * 0.5, 1.0]]
		for k in [0, 2, 1]:
			var a: float = tri[k][0]
			var t: float = tri[k][1]
			var ring := Vector3(cos(a) * radius, sin(a) * radius * flat, 0.0)
			st.set_normal(Vector3(cos(a), sin(a) / flat, radius / length).normalized())
			st.set_uv(Vector2(0.015 + 0.045 * a / TAU, 0.27 + 0.16 * t))
			st.add_vertex(tip if t > 0.5 else ring)
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


## Point on the Snirby's face for a texture coordinate (puff-local).
static func _snirby_face_point(uv: Vector2) -> Vector3:
	var x := (0.5 - uv.x) * 2.0
	var y := (0.5 - uv.y) * 2.0
	return Vector3(x, y, -sqrt(maxf(0.0, 1.0 - x * x - y * y))) * SNIRBY_R


## opts: tint, glow (glowing pupils), fly
static func snirby(opts := {}) -> Node3D:
	var root := Node3D.new()
	var parts := {"kind": "snirby"}
	var tint: Color = opts.get("tint", Color(1, 1, 1))
	var skin := Mat.make("cr_snirby_face", {"origin": true, "tint": tint, "shade": 0.85, "gloss": 0.6, "fullbright": 0.12})
	var foot_m := Mat.make("cr_snirby_feet", {"origin": true, "shade": 0.85, "gloss": 0.9})
	parts["skin_mat"] = skin
	var body := Models.pivot()
	root.add_child(body)
	parts["body"] = body
	var puff := Models.pivot(Vector3(0, SNIRBY_Y, 0))
	body.add_child(puff)
	parts["puff"] = puff
	parts["core"] = puff                    # pivot sits at the centre of the ball
	parts["core_y"] = SNIRBY_Y
	parts["core_r"] = SNIRBY_R
	parts["roll_cy"] = SNIRBY_Y
	parts["roll_r"] = SNIRBY_R
	puff.add_child(_part(snirby_body_mesh(), skin))
	# the long beak grows out of the nose, in the same skin as the body
	var beak := Models.pivot(_snirby_face_point(Vector2(0.5, 0.585)) * 0.85)
	puff.add_child(beak)
	beak.add_child(_part(snirby_beak_mesh(), skin))
	parts["beak"] = beak
	var eyes := []
	if opts.get("glow", false):
		var eye_m := Mat.make("white", {"origin": true, "tint": Color(1.0, 0.15, 0.08), "fullbright": 1.0, "shade": 0.3})
		for uv in [Vector2(0.32, 0.44), Vector2(0.67, 0.44)]:
			var e := Models.pivot(_snirby_face_point(uv) * 1.01)
			puff.add_child(e)
			e.add_child(_part(Models.sphere(0.035, 6, 4), eye_m))
			eyes.append(e)
	parts["eyes"] = eyes
	# rounded orange shoes
	var feet := []
	var feet_base := []
	for sx in [-1.0, 1.0]:
		var fb := Vector3(0.21 * sx, 0.1, -0.1)
		var f := Models.pivot(fb)
		body.add_child(f)
		f.add_child(_part(blob_mesh(0.17, Vector3(0.9, 0.62, 1.35), 5230, 0.03, 6, 10), foot_m))
		feet.append(f)
		feet_base.append(fb)
	parts["feet"] = feet
	parts["feet_base"] = feet_base
	parts["fly"] = opts.get("fly", false)
	parts["hop"] = true                     # wobbles, but still hops and pecks
	parts["peck_off"] = randf() * 2.0
	root.set_meta("parts", parts)
	animate(root, 0.0, 0.016, {})
	return root


# ================================================================== SNOTLING
## The little pink guy: a lumpy, droopy-eyed blob with a runny nose.
static func snotling(opts := {}) -> Node3D:
	var root := Node3D.new()
	var parts := {"kind": "snotling"}
	var tint: Color = opts.get("tint", Color(1, 1, 1))
	var skin := _skin("cr_snirby_skin", tint, {"gloss": 0.35})
	var lidm := _skin("cr_snirby_skin", tint.darkened(0.15), {"gloss": 0.2})
	var eye_m := Mat.make("cr_snirby_eye_h", {"origin": true, "shade": 0.5, "gloss": 1.0})
	var foot_m := _skin("cr_snirby_foot", Color(1, 1, 1), {"gloss": 0.3})
	var mouth_m := Mat.make("cr_gorbino_mouth", {"origin": true, "shade": 0.5, "gloss": 0.6})
	var hole_m := Mat.make("white", {"origin": true, "tint": Color(0.18, 0.02, 0.04), "shade": 0.3})
	var snot_m := Mat.make("cr_snot", {"origin": true, "fullbright": 0.35, "gloss": 1.0, "shade": 0.5, "scroll": Vector2(0, -0.4)})
	parts["skin_mat"] = skin
	var body := Models.pivot()
	root.add_child(body)
	parts["body"] = body
	var puff := Models.pivot(Vector3(0, 0.55, 0))
	body.add_child(puff)
	parts["puff"] = puff
	puff.add_child(_part(blob_mesh(0.5, Vector3(1.06, 0.93, 1.0), 4201, 0.06, 12, 20), skin))
	# droopy eyes under heavy lids
	var eyes := []
	var lids := []
	for sx in [-1.0, 1.0]:
		var big := 1.0 if sx < 0 else 0.78
		var e := Models.pivot(Vector3(0.15 * sx, 0.15 + (0.0 if sx < 0 else -0.02), -0.44), Vector3(0, -12 * sx, 0))
		puff.add_child(e)
		e.add_child(_part(face_mesh(), eye_m, Vector3.ZERO, Vector3(0.21, 0.19, 0.12) * big))
		var lid := _part(blob_mesh(0.125 * big, Vector3(1.0, 0.6, 0.8), 4210, 0.05, 6, 10), lidm, Vector3(0, 0.1, -0.005))
		e.add_child(lid)
		eyes.append(e)
		lids.append(lid)
	parts["eyes"] = eyes
	parts["lids"] = lids
	var mouth := Models.pivot(Vector3(0, -0.11, -0.46))
	puff.add_child(mouth)
	mouth.add_child(_part(face_mesh(), mouth_m, Vector3.ZERO, Vector3(0.32, 0.13, 0.08)))
	for sx in [-1.0, 1.0]:
		puff.add_child(_part(Models.sphere(0.022, 6, 4), hole_m, Vector3(0.035 * sx, 0.03, -0.495)))
	var rb := RandomNumberGenerator.new()
	rb.seed = 4250
	for k in 7:
		var d := Vector3(rb.randf_range(-1, 1), rb.randf_range(-0.6, 1), rb.randf_range(-0.2, 1)).normalized()
		puff.add_child(_part(blob_mesh(rb.randf_range(0.04, 0.08), Vector3.ONE, 4260 + k, 0.1, 5, 8), skin, d * 0.5 * Vector3(1.06, 0.93, 1.0)))
	parts["mouth"] = mouth
	# runny nose
	var snot := Models.pivot(Vector3(0.03, 0.02, -0.495))
	puff.add_child(snot)
	snot.add_child(_part(Models.cyl(0.012, 0.02, 1.0, 5), snot_m, Vector3(0, -0.5, 0)))
	var drop := _part(Models.sphere(0.03, 6, 4), snot_m, Vector3(0, -1.0, 0))
	snot.add_child(drop)
	parts["snot"] = snot
	parts["snot_drop"] = drop
	# stubby arms
	var arms := []
	for sx in [-1.0, 1.0]:
		var a := Models.pivot(Vector3(0.45 * sx, 0.0, 0.0))
		puff.add_child(a)
		a.add_child(_part(blob_mesh(0.16, Vector3(1.0, 0.72, 0.85), 4220, 0.08, 6, 10), skin, Vector3(0.09 * sx, -0.04, 0)))
		arms.append(a)
	parts["arms"] = arms
	var feet := []
	for sx in [-1.0, 1.0]:
		var f := Models.pivot(Vector3(0.21 * sx, 0.1, -0.04))
		body.add_child(f)
		f.add_child(_part(blob_mesh(0.18, Vector3(0.95, 0.55, 1.45), 4230, 0.05, 6, 10), foot_m))
		feet.append(f)
	parts["feet"] = feet
	root.set_meta("parts", parts)
	animate(root, 0.0, 0.016, {})
	return root


# ================================================================== gutting
## Where a knife opens this creature: [pivot node, position in that pivot,
## wound width]. The wound is parented to the pivot so it squashes and
## falls with the body.
static func gut_anchor(root: Node3D) -> Array:
	var p: Dictionary = root.get_meta("parts")
	# low on the belly, under the face; the last value tilts the wound to the surface
	match p.get("kind", ""):
		"gorbino":
			return [p["squash"], Vector3(0, (0.24 - GORB_SQUASH_Y) * GORB_H, -0.35 * GORB_H), 0.55, -0.72]
		"snirby":
			return [p["puff"], Vector3(0, -0.33, -0.37), 0.42, -0.72]
		_:
			return [p["puff"], Vector3(0, -0.3, -0.38), 0.4, -0.7]


# ================================================================== animation
## Two ways of moving, shared by the Gorbino and the Snirby:
##  - hop: bouncy, breathing, puffs right up to fly, pecks, rolls over dead
##    (the Gorbino moves like this)
##  - wobble: jelly squash-and-stretch, rears up before it attacks, flattens
##    when hurt and when it dies (the Snirby moves like this, and with "hop"
##    set it also hops along and pecks in quick bursts)
## st keys: move (0..1), windup, pain, blink, fly, look (Vector3, model local)
static func animate(root: Node3D, t: float, delta: float, st: Dictionary) -> void:
	var p: Dictionary = root.get_meta("parts")
	match p.get("kind", ""):
		"gorbino":
			_anim_hop(p, t, delta, st)
		"snirby":
			_anim_wobble(p, t, delta, st)
		_:
			_anim_snotling(p, t, delta, st)


## Keep the bottom of the body on its feet whatever the core's scale is.
static func _plant(p: Dictionary) -> void:
	var core: Node3D = p["core"]
	core.position.y = float(p["core_y"]) + float(p["core_r"]) * (core.scale.y - 1.0)


static func _anim_hop(p: Dictionary, t: float, delta: float, st: Dictionary) -> void:
	var m := float(st.get("move", 0.0))
	var windup: bool = st.get("windup", false)
	var pain: bool = st.get("pain", false)
	var fly: bool = st.get("fly", false) or p.get("fly", false)
	var body: Node3D = p["body"]
	var core: Node3D = p["core"]
	var step := t * (9.0 + 6.0 * m)
	var breathe := 1.0 + 0.04 * sin(t * 2.0)
	if fly:
		core.scale = Vector3(1.3, 1.25, 1.3) * breathe
		body.position.y = 0.2 + sin(t * 2.4) * 0.12
	else:
		var squish := absf(sin(step)) * m
		core.scale = Vector3(breathe + 0.05 * squish, breathe - 0.07 * squish, breathe) * (0.85 if pain else 1.0)
		body.position.y = absf(sin(step)) * 0.14 * m
	_plant(p)
	body.rotation.x = (0.3 if pain else 0.0) - (0.25 if windup else 0.0)
	body.rotation.z = sin(step * 0.5) * 0.1 * m
	# the peck: a beak rears up and jabs; a mouth snaps open
	if p.has("beak"):
		var beak: Node3D = p["beak"]
		var bx := 0.35 if windup else (-0.25 if pain else sin(t * 1.7) * 0.06 + sin(step) * 0.08 * m)
		beak.rotation.x = lerpf(beak.rotation.x, bx, clampf(delta * 14.0, 0.0, 1.0))
		beak.rotation.y = sin(t * 0.9) * 0.08
	if p.has("mouth"):
		var mouth: Node3D = p["mouth"]
		var open := 6.0 if windup else (3.0 if pain else 1.0 + 1.5 * maxf(0.0, sin(t * 1.7)) * maxf(0.0, sin(t * 0.6)))
		mouth.scale = mouth.scale.lerp(Vector3(1.0 + (open - 1.0) * 0.04, open, 1.0), clampf(delta * 14.0, 0.0, 1.0))
	if p.has("arm"):
		p["arm"].rotation.x = -0.25 if windup else 0.1 + sin(t * 2.0) * 0.08
	var feet: Array = p["feet"]
	var base: Array = p["feet_base"]
	for i in feet.size():
		var f: Node3D = feet[i]
		var b: Vector3 = base[i]
		if fly:
			f.rotation.x = 0.5 + sin(t * 3.0 + i) * 0.2
			f.position = b + Vector3(0, 0.02, 0.06)
		else:
			f.rotation.x = 0.0
			f.position = b + Vector3(0, maxf(0.0, sin(step + i * PI)) * 0.08 * m, sin(step + i * PI) * 0.16 * m)
	for e in p["eyes"]:
		e.scale = Vector3.ONE * (1.0 + 0.2 * sin(t * 7.0))


static func _anim_wobble(p: Dictionary, t: float, delta: float, st: Dictionary) -> void:
	var m := float(st.get("move", 0.0))
	var windup: bool = st.get("windup", false)
	var pain: bool = st.get("pain", false)
	var fly: bool = st.get("fly", false) or p.get("fly", false)
	var body: Node3D = p["body"]
	var core: Node3D = p["core"]
	var hop: bool = p.get("hop", false)
	var step := t * ((9.0 if hop else 8.0) + 6.0 * m)
	# jelly wobble; it stretches up before attacking and flattens when hurt
	var wob := sin(t * 3.1) * 0.03 + sin(step * 2.0) * 0.06 * m
	var sy := 1.0 + wob + (0.16 if windup else 0.0) - (0.2 if pain else 0.0)
	if hop and not fly:
		# squashes as it lands from each hop
		sy -= pow(1.0 - absf(sin(step)), 4.0) * 0.14 * m
	var sxz := 1.0 / sqrt(maxf(sy, 0.3))
	core.scale = core.scale.lerp(Vector3(sxz, sy, sxz), clampf(delta * 16.0, 0.0, 1.0))
	_plant(p)
	body.position.y = absf(sin(step)) * (0.14 if hop else 0.1) * m + (0.25 + sin(t * 2.0) * 0.1 if fly else 0.0)
	body.rotation.x = (-0.2 if windup else 0.0) + sin(step) * 0.05 * m
	body.rotation.z = sin(step * 0.5) * 0.08 * m
	# the gape: a mouth stretches open; a beak lifts open
	if p.has("mouth"):
		var mouth: Node3D = p["mouth"]
		var open := 7.0 if windup else (4.0 if pain else 1.0)
		mouth.scale = mouth.scale.lerp(Vector3(1.0 + (open - 1.0) * 0.04, open, 1.0), clampf(delta * 14.0, 0.0, 1.0))
	if p.has("beak"):
		var beak: Node3D = p["beak"]
		var bx := 0.55 if windup else (0.3 if pain else sin(t * 1.2) * 0.04)
		if hop and not windup and not pain:
			# quick pecks: bursts of fast jabs, and a peck with every hop
			var burst := fmod(t + float(p.get("peck_off", 0.0)), 1.6) < 0.65
			var jab := pow(maxf(0.0, sin(t * 30.0)), 2.0) if burst else 0.0
			bx += -0.5 * jab - 0.12 * maxf(0.0, sin(step)) * m
			body.rotation.x -= 0.12 * jab
		beak.rotation.x = lerpf(beak.rotation.x, bx, clampf(delta * 45.0, 0.0, 1.0))
		beak.rotation.y = 0.0
	if p.has("arm"):
		p["arm"].rotation.x = -0.25 if windup else 0.1 + sin(t * 2.0) * 0.08
	var feet: Array = p["feet"]
	var base: Array = p["feet_base"]
	for i in feet.size():
		var f: Node3D = feet[i]
		var b: Vector3 = base[i]
		var ph := float(i) * PI
		if fly:
			f.position = b + Vector3(0, 0.02 + sin(t * 4.0 + ph) * 0.04, 0.05)
			f.rotation.x = 0.4
		else:
			f.rotation.x = -maxf(0.0, sin(step + ph)) * 0.5 * m
			f.position = b + Vector3(0, maxf(0.0, sin(step + ph)) * 0.12 * m, -sin(step + ph) * 0.12 * m)
	var blink: bool = st.get("blink", false)
	for e in p["eyes"]:
		e.scale = Vector3.ONE * (0.4 if blink else (1.0 + 0.15 * sin(t * 9.0)))


static func _anim_snotling(p: Dictionary, t: float, delta: float, st: Dictionary) -> void:
	var m := float(st.get("move", 0.0))
	var windup: bool = st.get("windup", false)
	var pain: bool = st.get("pain", false)
	var fly: bool = st.get("fly", false)
	var body: Node3D = p["body"]
	var puff: Node3D = p["puff"]
	var step := t * (9.0 + 6.0 * m)
	var breathe := 1.0 + 0.04 * sin(t * 2.0)
	if fly:
		puff.scale = Vector3(1.3, 1.25, 1.3) * breathe
		body.position.y = 0.2 + sin(t * 2.4) * 0.12
	else:
		puff.scale = Vector3(breathe + 0.04 * absf(sin(step)) * m, breathe - 0.06 * absf(sin(step)) * m, breathe)
		body.position.y = absf(sin(step)) * 0.12 * m
	body.rotation.x = (0.3 if pain else 0.0) - (0.25 if windup else 0.0)
	body.rotation.z = sin(step * 0.5) * 0.1 * m
	var arms: Array = p["arms"]
	for i in arms.size():
		var sx := -1.0 if i == 0 else 1.0
		var a: Node3D = arms[i]
		if fly:
			a.rotation.z = sx * (0.6 + sin(t * 14.0) * 0.6)
		elif windup:
			a.rotation.z = sx * 1.1
		else:
			a.rotation.z = sx * (0.15 + sin(step + i * PI) * 0.35 * m + sin(t * 1.3) * 0.05)
	var feet: Array = p["feet"]
	for i in feet.size():
		var f: Node3D = feet[i]
		f.rotation.x = 0.0
		f.position.z = -0.04 + sin(step + i * PI) * 0.16 * m
		f.position.y = 0.1 + maxf(0.0, sin(step + i * PI)) * 0.08 * m
	var mouth: Node3D = p["mouth"]
	var open := 3.0 if windup else (2.2 if pain else 1.0 + 0.3 * maxf(0.0, sin(t * 4.0)))
	mouth.scale = mouth.scale.lerp(Vector3(1.0 + (open - 1.0) * 0.3, open, 1.0), clampf(delta * 12.0, 0.0, 1.0))
	# snot: stretches, drips, snaps back
	var cyc := fmod(t * 0.45, 1.0)
	var L := 0.05 + cyc * cyc * 0.32
	var snot: Node3D = p["snot"]
	snot.scale = Vector3(1.0 + 0.3 * sin(t * 6.0), L, 1.0)
	p["snot_drop"].scale = Vector3(1.0, 1.0 / maxf(L, 0.01), 1.0) * (0.6 + cyc)
	var blink: bool = st.get("blink", false)
	for i in p["eyes"].size():
		var lid: Node3D = p["lids"][i]
		lid.position.y = -0.01 if blink else (0.03 if pain else 0.055)
		lid.scale.y = 1.9 if blink else 1.15


## k: 0..1 death progress. The Gorbino rolls over; the Snirby flattens.
static func death_pose(root: Node3D, k: float) -> void:
	var p: Dictionary = root.get_meta("parts")
	var body: Node3D = p["body"]
	match p.get("kind", ""):
		"gorbino":
			_death_roll(p, k)
		"snirby":
			_death_flatten(p, k)
		_:
			body.rotation.z = lerpf(0.0, deg_to_rad(80), k * k)
			body.position.y = lerpf(0.0, 0.05, k)
			p["puff"].scale = Vector3(1.0 + 0.2 * k, 1.0 - 0.35 * k, 1.0 + 0.2 * k)
			p["mouth"].scale = Vector3(1.5, 3.0, 1.0)
			for lid in p["lids"]:
				lid.position.y = 0.0


## Topples onto its side and lies there, mouth or beak hanging open.
static func _death_roll(p: Dictionary, k: float) -> void:
	var body: Node3D = p["body"]
	var core: Node3D = p["core"]
	var a := deg_to_rad(80) * k * k
	body.rotation = Vector3(0, 0, a)
	# lift so the ball rests on its side instead of sinking into the floor
	body.position.y = maxf(0.0, float(p["roll_r"]) - float(p["roll_cy"]) * cos(a)) * k
	core.scale = Vector3(1.0 + 0.2 * k, 1.0 - 0.35 * k, 1.0 + 0.2 * k)
	_plant(p)
	if p.has("mouth"):
		p["mouth"].scale = Vector3(1.3, 5.0, 1.0)
	if p.has("beak"):
		p["beak"].rotation.x = lerpf(0.0, -0.5, k)
	for e in p["eyes"]:
		e.scale = Vector3.ONE * maxf(0.05, 1.0 - k)


## Sags into a puddle where it stood.
static func _death_flatten(p: Dictionary, k: float) -> void:
	var body: Node3D = p["body"]
	var core: Node3D = p["core"]
	core.scale = Vector3(1.0 + 0.45 * k, 1.0 - 0.6 * k, 1.0 + 0.45 * k)
	_plant(p)
	body.position.y = 0.0
	body.rotation = Vector3(lerpf(0.0, 0.2, k), 0, 0)
	if p.has("mouth"):
		p["mouth"].scale = Vector3(1.3, 6.0, 1.0)
	if p.has("beak"):
		p["beak"].rotation.x = lerpf(0.0, -0.3, k)
	for e in p["eyes"]:
		e.scale = Vector3.ONE * maxf(0.05, 1.0 - k)
