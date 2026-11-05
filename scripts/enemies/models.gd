class_name Models
extends RefCounted
## Low-poly model construction from primitives. Every model is a Node3D
## whose animatable parts are stored in the "parts" metadata dictionary.

const SKIN_SEG := 10


static func mi(mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = rot
	m.scale = scl
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


static func sphere(r: float, seg := 8, rings := 5) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = rings
	return s


static func cyl(r_top: float, r_bot: float, h: float, seg := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func box(sx: float, sy: float, sz: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(sx, sy, sz)
	return b


static func pivot(pos := Vector3.ZERO, rot := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = rot
	return n


# ================================================================== GORBINO
## A round, grinning blob-creature with googly eyes, a sprout, stubby limbs.
static func gorbino(color: Color, opts := {}) -> Node3D:
	var root := Node3D.new()
	var parts := {}
	var skin := Mat.make("gorbino_skin", {"tint": color, "origin": true, "uv": Vector2(2, 1)})
	var dark := Mat.make("gorbino_skin", {"tint": color.darkened(0.45), "origin": true})
	var white := Mat.world("white", {"origin": true})
	var black := Mat.world("black", {"origin": true})
	var mouth_m := Mat.world("white", {"origin": true, "tint": Color(0.35, 0.02, 0.08)})
	var eye_glow: bool = opts.get("glow_eyes", false)
	var pupil_m := black
	if eye_glow:
		pupil_m = Mat.world("white", {"tint": Color(1.0, 0.1, 0.05), "fullbright": 1.0, "origin": true})
	parts["skin_mat"] = skin
	# body pivot (bobs / rolls when walking)
	var body := pivot(Vector3(0, 0.32, 0))
	root.add_child(body)
	parts["body"] = body
	var blob := mi(sphere(0.55, SKIN_SEG, 7), skin, Vector3(0, 0.52, 0), Vector3.ZERO, Vector3(1.0, 0.92, 0.88))
	body.add_child(blob)
	parts["blob"] = blob
	# belly patch
	body.add_child(mi(sphere(0.36, 8, 5), Mat.make("gorbino_skin", {"tint": color.lightened(0.35), "origin": true}),
		Vector3(0, 0.38, -0.3), Vector3.ZERO, Vector3(1.0, 0.85, 0.5)))
	# sprout on top
	var sprout := pivot(Vector3(0, 1.0, 0))
	body.add_child(sprout)
	sprout.add_child(mi(cyl(0.025, 0.04, 0.22, 5), dark, Vector3(0, 0.1, 0)))
	sprout.add_child(mi(sphere(0.08, 6, 4), skin, Vector3(0.05, 0.22, 0), Vector3.ZERO, Vector3(1.3, 0.6, 0.8)))
	sprout.add_child(mi(sphere(0.07, 6, 4), skin, Vector3(-0.06, 0.18, 0), Vector3.ZERO, Vector3(1.2, 0.6, 0.8)))
	parts["sprout"] = sprout
	# eyes
	var eyes := []
	var pupils := []
	for sx in [-1.0, 1.0]:
		var eye := pivot(Vector3(0.2 * sx, 0.68, -0.42))
		body.add_child(eye)
		eye.add_child(mi(sphere(0.15, 8, 5), white))
		var pu := mi(sphere(0.065, 6, 4), pupil_m, Vector3(0, 0, -0.12), Vector3.ZERO, Vector3(1, 1, 0.6))
		eye.add_child(pu)
		eyes.append(eye)
		pupils.append(pu)
		# eyebrow (gives a determined look)
		eye.add_child(mi(box(0.2, 0.04, 0.05), dark, Vector3(0.0, 0.17, -0.06), Vector3(0, 0, -14.0 * sx)))
	parts["eyes"] = eyes
	parts["pupils"] = pupils
	# mouth: dark slot with teeth
	var mouth := pivot(Vector3(0, 0.36, -0.47))
	body.add_child(mouth)
	mouth.add_child(mi(box(0.44, 0.11, 0.08), mouth_m))
	for k in 5:
		mouth.add_child(mi(box(0.06, 0.045, 0.03), white, Vector3(-0.16 + k * 0.08, 0.03, -0.035)))
	parts["mouth"] = mouth
	# arms
	var arms := []
	for sx in [-1.0, 1.0]:
		var sh := pivot(Vector3(0.5 * sx, 0.5, 0))
		body.add_child(sh)
		sh.add_child(mi(cyl(0.07, 0.09, 0.36, 6), skin, Vector3(0.08 * sx, -0.15, 0), Vector3(0, 0, 25 * sx)))
		sh.add_child(mi(sphere(0.1, 6, 4), dark, Vector3(0.16 * sx, -0.32, 0)))
		arms.append(sh)
	parts["arms"] = arms
	# legs
	var legs := []
	for sx in [-1.0, 1.0]:
		var hip := pivot(Vector3(0.22 * sx, 0.36, 0))
		root.add_child(hip)
		hip.add_child(mi(cyl(0.1, 0.11, 0.3, 6), skin, Vector3(0, -0.17, 0)))
		hip.add_child(mi(sphere(0.13, 6, 4), dark, Vector3(0, -0.33, -0.06), Vector3.ZERO, Vector3(1, 0.5, 1.4)))
		legs.append(hip)
	parts["legs"] = legs
	# held item
	if opts.get("gun", false):
		var g := Node3D.new()
		arms[1].add_child(g)
		g.position = Vector3(0.18, -0.36, -0.12)
		g.add_child(mi(box(0.07, 0.09, 0.28), Mat.world("gun_dark", {"origin": true})))
		g.add_child(mi(box(0.05, 0.12, 0.06), Mat.world("gun_wood", {"origin": true}), Vector3(0, -0.08, 0.08)))
	if opts.get("launcher", false):
		var l := Node3D.new()
		body.add_child(l)
		l.position = Vector3(0.48, 0.85, 0.0)
		l.add_child(mi(cyl(0.11, 0.11, 0.8, 8), Mat.world("gun_red", {"origin": true}), Vector3.ZERO, Vector3(90, 0, 0)))
		l.add_child(mi(cyl(0.08, 0.08, 0.05, 8), black, Vector3(0, 0, -0.41), Vector3(90, 0, 0)))
		parts["launcher"] = l
	root.set_meta("parts", parts)
	return root


# ================================================================== SNIRBY
## A tall, lanky, long-snouted sniffing creature with rabbit ears.
static func snirby(opts := {}) -> Node3D:
	var root := Node3D.new()
	var parts := {}
	var tint: Color = opts.get("tint", Color(1, 1, 1))
	var skin := Mat.make("snirby_skin", {"origin": true, "tint": tint, "uv": Vector2(2, 1)})
	var belly := Mat.world("snirby_belly", {"origin": true})
	var pink := Mat.world("white", {"origin": true, "tint": Color(1.0, 0.45, 0.6)})
	var black := Mat.world("black", {"origin": true})
	var eye_m := Mat.world("white", {"origin": true, "tint": Color(1.0, 0.9, 0.1), "fullbright": 0.6 if opts.get("glow", false) else 0.0})
	parts["skin_mat"] = skin
	var body := pivot(Vector3(0, 0.55, 0))
	root.add_child(body)
	parts["body"] = body
	body.add_child(mi(sphere(0.36, 9, 6), skin, Vector3(0, 0.42, 0), Vector3.ZERO, Vector3(0.85, 1.35, 0.8)))
	body.add_child(mi(sphere(0.28, 8, 5), belly, Vector3(0, 0.32, -0.12), Vector3.ZERO, Vector3(0.8, 1.2, 0.6)))
	# head pivot: snout, eyes, ears
	var head := pivot(Vector3(0, 0.86, 0))
	body.add_child(head)
	parts["head"] = head
	head.add_child(mi(sphere(0.25, 8, 5), skin, Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(0.9, 0.85, 0.9)))
	var snout := pivot(Vector3(0, 0.0, -0.18))
	head.add_child(snout)
	snout.add_child(mi(cyl(0.035, 0.12, 0.55, 7), skin, Vector3(0, 0, -0.27), Vector3(-90, 0, 0)))
	var nose := mi(sphere(0.065, 6, 4), pink, Vector3(0, 0.0, -0.56))
	snout.add_child(nose)
	parts["snout"] = snout
	parts["nose"] = nose
	var eyes := []
	for sx in [-1.0, 1.0]:
		var e := pivot(Vector3(0.13 * sx, 0.1, -0.15))
		head.add_child(e)
		e.add_child(mi(sphere(0.065, 6, 4), eye_m))
		e.add_child(mi(sphere(0.035, 5, 3), black, Vector3(0, 0, -0.045)))
		eyes.append(e)
	parts["eyes"] = eyes
	var ears := pivot(Vector3(0, 0.18, 0.02))
	head.add_child(ears)
	parts["ears"] = ears
	for sx in [-1.0, 1.0]:
		var ear := pivot(Vector3(0.09 * sx, 0.0, 0), Vector3(0, 0, -18 * sx))
		ears.add_child(ear)
		ear.add_child(mi(box(0.08, 0.5, 0.14), skin, Vector3(0, 0.25, 0)))
		ear.add_child(mi(box(0.05, 0.4, 0.02), pink, Vector3(0, 0.25, -0.075)))
	# arms
	var arms := []
	for sx in [-1.0, 1.0]:
		var sh := pivot(Vector3(0.27 * sx, 0.62, -0.02))
		body.add_child(sh)
		sh.add_child(mi(cyl(0.035, 0.04, 0.62, 5), skin, Vector3(0.03 * sx, -0.3, 0), Vector3(0, 0, 6 * sx)))
		for k in 3:
			sh.add_child(mi(cyl(0.0, 0.02, 0.12, 4), black, Vector3(0.06 * sx + (k - 1) * 0.03, -0.66, -0.02), Vector3(180, 0, 0)))
		arms.append(sh)
	parts["arms"] = arms
	var legs := []
	for sx in [-1.0, 1.0]:
		var hip := pivot(Vector3(0.14 * sx, 0.6, 0))
		root.add_child(hip)
		hip.add_child(mi(cyl(0.045, 0.05, 0.56, 5), skin, Vector3(0, -0.3, 0)))
		hip.add_child(mi(box(0.12, 0.05, 0.26), skin, Vector3(0, -0.58, -0.07)))
		legs.append(hip)
	parts["legs"] = legs
	# tail
	body.add_child(mi(cyl(0.02, 0.05, 0.35, 5), skin, Vector3(0, 0.1, 0.32), Vector3(-60, 0, 0)))
	root.set_meta("parts", parts)
	return root


# ================================================================== WEAPONS
## Builds a first-person (or pickup) weapon model. Front of gun = -Z.
static func weapon(wname: String, with_hands := true) -> Node3D:
	var root := Node3D.new()
	var parts := {}
	var metal := Mat.world("gun_metal", {"origin": true})
	var dark := Mat.world("gun_dark", {"origin": true})
	var wood := Mat.world("gun_wood", {"origin": true})
	var brass := Mat.world("gun_brass", {"origin": true})
	var glove := Mat.world("glove", {"origin": true})
	var muzzle := Marker3D.new()
	root.add_child(muzzle)
	parts["muzzle"] = muzzle
	match wname:
		"pistol":
			var slide := pivot()
			root.add_child(slide)
			slide.add_child(mi(box(0.05, 0.055, 0.25), metal, Vector3(0, 0.03, -0.05)))
			slide.add_child(mi(box(0.052, 0.012, 0.25), Mat.world("gun_green", {"origin": true}), Vector3(0, 0.0, -0.05)))
			slide.add_child(mi(box(0.012, 0.02, 0.015), dark, Vector3(0, 0.065, -0.16)))
			parts["slide"] = slide
			root.add_child(mi(box(0.045, 0.04, 0.2), dark, Vector3(0, -0.015, -0.04)))
			root.add_child(mi(box(0.045, 0.14, 0.065), wood, Vector3(0, -0.09, 0.04), Vector3(-14, 0, 0)))
			root.add_child(mi(box(0.03, 0.035, 0.05), dark, Vector3(0, -0.045, -0.03)))
			var mag := mi(box(0.035, 0.1, 0.05), dark, Vector3(0, -0.12, 0.045), Vector3(-14, 0, 0))
			root.add_child(mag)
			parts["mag"] = mag
			muzzle.position = Vector3(0, 0.03, -0.19)
			if with_hands:
				root.add_child(mi(box(0.075, 0.1, 0.11), glove, Vector3(0, -0.1, 0.06), Vector3(-14, 0, 0)))
				root.add_child(mi(box(0.03, 0.03, 0.08), glove, Vector3(-0.045, -0.03, 0.0), Vector3(0, 10, 0)))
		"shotgun":
			root.add_child(mi(cyl(0.022, 0.022, 0.62, 7), dark, Vector3(0, 0.02, -0.33), Vector3(90, 0, 0)))
			root.add_child(mi(cyl(0.018, 0.018, 0.48, 6), metal, Vector3(0, -0.025, -0.27), Vector3(90, 0, 0)))
			root.add_child(mi(box(0.06, 0.085, 0.2), metal, Vector3(0, 0.0, 0.02)))
			root.add_child(mi(box(0.05, 0.1, 0.3), wood, Vector3(0, -0.04, 0.24), Vector3(8, 0, 0)))
			var pump := pivot()
			root.add_child(pump)
			pump.add_child(mi(box(0.065, 0.06, 0.17), wood, Vector3(0, -0.025, -0.26)))
			if with_hands:
				pump.add_child(mi(box(0.09, 0.07, 0.12), glove, Vector3(-0.01, -0.06, -0.26)))
			parts["pump"] = pump
			muzzle.position = Vector3(0, 0.02, -0.65)
			if with_hands:
				root.add_child(mi(box(0.07, 0.09, 0.1), glove, Vector3(0.0, -0.08, 0.13), Vector3(20, 0, 0)))
		"ssg":
			var barrels := pivot(Vector3(0, -0.01, -0.06))
			root.add_child(barrels)
			for sx in [-1.0, 1.0]:
				barrels.add_child(mi(cyl(0.026, 0.026, 0.52, 7), dark, Vector3(0.027 * sx, 0.03, -0.26), Vector3(90, 0, 0)))
			barrels.add_child(mi(box(0.08, 0.03, 0.3), wood, Vector3(0, -0.01, -0.2)))
			barrels.add_child(mi(box(0.1, 0.06, 0.04), brass, Vector3(0, 0.02, -0.01)))
			var shells := pivot()
			barrels.add_child(shells)
			for sx in [-1.0, 1.0]:
				shells.add_child(mi(cyl(0.022, 0.022, 0.06, 6), Mat.world("gun_red", {"origin": true}), Vector3(0.027 * sx, 0.03, 0.03), Vector3(90, 0, 0)))
			shells.visible = false
			parts["shells"] = shells
			parts["barrels"] = barrels
			root.add_child(mi(box(0.07, 0.07, 0.12), metal, Vector3(0, 0.0, 0.02)))
			root.add_child(mi(box(0.055, 0.1, 0.28), wood, Vector3(0, -0.05, 0.2), Vector3(10, 0, 0)))
			muzzle.position = Vector3(0, 0.02, -0.6)
			if with_hands:
				root.add_child(mi(box(0.075, 0.09, 0.1), glove, Vector3(0.0, -0.08, 0.12), Vector3(20, 0, 0)))
				barrels.add_child(mi(box(0.1, 0.06, 0.12), glove, Vector3(-0.02, -0.05, -0.22)))
		"mg":
			root.add_child(mi(box(0.08, 0.1, 0.34), Mat.world("gun_red", {"origin": true}), Vector3(0, 0, 0.0)))
			root.add_child(mi(box(0.03, 0.04, 0.18), dark, Vector3(0, 0.08, 0.0)))
			var spin := pivot(Vector3(0, 0.0, -0.2))
			root.add_child(spin)
			for k in 3:
				var a := k * TAU / 3.0
				spin.add_child(mi(cyl(0.012, 0.012, 0.36, 5), dark, Vector3(cos(a) * 0.025, sin(a) * 0.025, -0.16), Vector3(90, 0, 0)))
			spin.add_child(mi(cyl(0.045, 0.045, 0.03, 8), metal, Vector3(0, 0, -0.3), Vector3(90, 0, 0)))
			parts["spin"] = spin
			var drum := mi(cyl(0.075, 0.075, 0.06, 10), brass, Vector3(0, -0.1, -0.03), Vector3(0, 0, 90))
			root.add_child(drum)
			parts["mag"] = drum
			root.add_child(mi(box(0.05, 0.12, 0.06), wood, Vector3(0, -0.1, 0.12), Vector3(-10, 0, 0)))
			muzzle.position = Vector3(0, 0, -0.56)
			if with_hands:
				root.add_child(mi(box(0.075, 0.09, 0.1), glove, Vector3(0.0, -0.13, 0.12), Vector3(-10, 0, 0)))
				root.add_child(mi(box(0.09, 0.07, 0.1), glove, Vector3(-0.03, -0.07, -0.15)))
		"rocket":
			var green := Mat.world("gun_green", {"origin": true})
			root.add_child(mi(cyl(0.065, 0.065, 0.62, 10), green, Vector3(0, 0.02, -0.12), Vector3(90, 0, 0)))
			root.add_child(mi(cyl(0.08, 0.065, 0.08, 10), dark, Vector3(0, 0.02, -0.45), Vector3(90, 0, 0)))
			root.add_child(mi(cyl(0.05, 0.05, 0.02, 10), Mat.world("black", {"origin": true}), Vector3(0, 0.02, -0.495), Vector3(90, 0, 0)))
			var rk := pivot()
			root.add_child(rk)
			rk.add_child(mi(cyl(0.0, 0.045, 0.1, 8), Mat.world("gun_red", {"origin": true}), Vector3(0, 0.02, -0.53), Vector3(-90, 0, 0)))
			parts["rocket"] = rk
			root.add_child(mi(box(0.03, 0.05, 0.12), dark, Vector3(0, 0.1, -0.1)))
			root.add_child(mi(box(0.05, 0.13, 0.06), dark, Vector3(0, -0.1, 0.0), Vector3(-10, 0, 0)))
			muzzle.position = Vector3(0, 0.02, -0.55)
			if with_hands:
				root.add_child(mi(box(0.075, 0.09, 0.1), glove, Vector3(0.0, -0.13, 0.01), Vector3(-10, 0, 0)))
		"plasma":
			var purple := Mat.world("gun_purple", {"origin": true})
			var glow := Mat.make("gun_plasma", {"origin": true, "fullbright": 1.0})
			parts["glow_mat"] = glow
			root.add_child(mi(box(0.09, 0.09, 0.4), purple, Vector3(0, 0, -0.05)))
			for k in 3:
				root.add_child(mi(cyl(0.06, 0.06, 0.035, 8), glow, Vector3(0, 0, -0.08 - k * 0.07), Vector3(90, 0, 0)))
			for sx in [-1.0, 1.0]:
				root.add_child(mi(cyl(0.0, 0.02, 0.16, 5), dark, Vector3(0.035 * sx, 0.0, -0.32), Vector3(-90, 0, 0)))
			var core := mi(sphere(0.03, 6, 4), glow, Vector3(0, 0, -0.32))
			root.add_child(core)
			parts["core"] = core
			root.add_child(mi(box(0.05, 0.13, 0.06), purple, Vector3(0, -0.1, 0.08), Vector3(-12, 0, 0)))
			muzzle.position = Vector3(0, 0, -0.4)
			if with_hands:
				root.add_child(mi(box(0.075, 0.09, 0.1), glove, Vector3(0.0, -0.13, 0.09), Vector3(-12, 0, 0)))
	root.set_meta("parts", parts)
	return root


# ================================================================== PICKUPS
static func pickup(ptype: String) -> Node3D:
	var root := Node3D.new()
	var o := {"origin": true}
	match ptype:
		"juice":
			root.add_child(mi(cyl(0.12, 0.12, 0.3, 8), Mat.world("pk_juice", o), Vector3(0, 0.15, 0)))
		"medkit":
			root.add_child(mi(box(0.55, 0.3, 0.4), Mat.world("pk_medkit", o), Vector3(0, 0.15, 0)))
		"mega":
			root.add_child(mi(sphere(0.32, 10, 6), Mat.world("pk_orb", {"origin": true, "fullbright": 1.0, "scroll": Vector2(0.2, 0.1)}), Vector3(0, 0.5, 0)))
		"armor_bonus":
			root.add_child(mi(sphere(0.14, 7, 4), Mat.world("pk_orb_blue", {"origin": true, "fullbright": 0.8, "scroll": Vector2(0.2, 0.0)}), Vector3(0, 0.3, 0)))
		"armor_green", "armor_blue":
			var m := Mat.world("pk_" + ptype, o)
			root.add_child(mi(box(0.5, 0.55, 0.22), m, Vector3(0, 0.4, 0)))
			root.add_child(mi(box(0.16, 0.2, 0.22), m, Vector3(-0.2, 0.75, 0)))
			root.add_child(mi(box(0.16, 0.2, 0.22), m, Vector3(0.2, 0.75, 0)))
		"bullets":
			root.add_child(mi(box(0.28, 0.18, 0.16), Mat.world("pk_bullets", o), Vector3(0, 0.09, 0)))
		"bullets_box":
			root.add_child(mi(box(0.6, 0.32, 0.36), Mat.world("pk_bullets", o), Vector3(0, 0.16, 0)))
		"shells":
			for k in 4:
				root.add_child(mi(cyl(0.035, 0.035, 0.16, 6), Mat.world("gun_red", o), Vector3(-0.12 + k * 0.08, 0.08, 0)))
		"shells_box":
			root.add_child(mi(box(0.55, 0.28, 0.32), Mat.world("pk_shells", o), Vector3(0, 0.14, 0)))
		"rocket":
			root.add_child(mi(cyl(0.06, 0.06, 0.45, 8), Mat.world("gun_green", o), Vector3(0, 0.06, 0), Vector3(90, 0, 0)))
			root.add_child(mi(cyl(0.0, 0.06, 0.15, 8), Mat.world("gun_red", o), Vector3(0, 0.06, -0.3), Vector3(-90, 0, 0)))
		"rockets_box":
			root.add_child(mi(box(0.8, 0.35, 0.4), Mat.world("pk_rockets", o), Vector3(0, 0.18, 0)))
		"cells":
			root.add_child(mi(cyl(0.1, 0.1, 0.3, 8), Mat.world("pk_cells", {"origin": true, "fullbright": 0.5}), Vector3(0, 0.15, 0)))
		"cells_box":
			root.add_child(mi(box(0.5, 0.35, 0.35), Mat.world("pk_cells", {"origin": true, "fullbright": 0.5}), Vector3(0, 0.18, 0)))
		"backpack":
			root.add_child(mi(box(0.5, 0.55, 0.3), Mat.world("v_planks", o), Vector3(0, 0.3, 0)))
			root.add_child(mi(box(0.4, 0.2, 0.1), Mat.world("pk_bullets", o), Vector3(0, 0.25, -0.18)))
		"key_red", "key_blue", "key_yellow":
			root.add_child(mi(box(0.45, 0.3, 0.04), Mat.world("pk_" + ptype, {"origin": true, "fullbright": 0.6}), Vector3(0, 0.55, 0)))
		_:
			if ptype.begins_with("w_"):
				var w := weapon(ptype.substr(2).replace("shotgun", "shotgun").replace("ssg", "ssg"), false)
				w.scale = Vector3.ONE * 1.8
				w.position = Vector3(0, 0.35, 0)
				w.rotation_degrees = Vector3(0, 90, 0)
				root.add_child(w)
	return root


# ================================================================== PROPS
static func barrel() -> Node3D:
	var root := Node3D.new()
	var o := {"origin": true}
	root.add_child(mi(cyl(0.38, 0.38, 1.1, 10), Mat.world("barrel", o), Vector3(0, 0.55, 0)))
	root.add_child(mi(cyl(0.37, 0.37, 0.02, 10), Mat.world("barrel_top", {"origin": true, "fullbright": 0.3}), Vector3(0, 1.105, 0)))
	return root
