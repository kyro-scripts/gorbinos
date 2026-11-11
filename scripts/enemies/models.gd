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


# ================================================================== CREATURES
## Kept for callers; the creature models live in creatures.gd.
static func gorbino(color: Color, opts := {}) -> Node3D:
	return Creatures.gorbino(color, opts)


static func snirby(opts := {}) -> Node3D:
	return Creatures.snirby(opts)


static func snotling(opts := {}) -> Node3D:
	return Creatures.snotling(opts)


# ================================================================== WEAPONS
## Builds a first-person (or pickup) weapon model. Front of gun = -Z.
static func weapon(wname: String, with_hands := true) -> Node3D:
	var root := Node3D.new()
	var parts := {}
	var o := {"origin": true}
	var metal := Mat.world("gun_metal", o)
	var dark := Mat.world("gun_dark", o)
	var wood := Mat.world("gun_wood", o)
	var brass := Mat.world("gun_brass", o)
	var red := Mat.world("gun_red", o)
	var green := Mat.world("gun_green", o)
	var black := Mat.world("black", o)
	var white := Mat.world("white", o)
	var check := Mat.world("knife_checker", o)
	var glove := Mat.world("glove", o)
	var muzzle := Marker3D.new()
	root.add_child(muzzle)
	parts["muzzle"] = muzzle
	match wname:
		"pistol":
			# a chunky service pistol with a checkered grip and a little
			# Gorbino keychain swinging off the bottom
			var slide := pivot()
			root.add_child(slide)
			slide.add_child(mi(box(0.054, 0.058, 0.26), metal, Vector3(0, 0.032, -0.05)))
			slide.add_child(mi(box(0.056, 0.012, 0.26), green, Vector3(0, 0.002, -0.05)))
			for i in 5:
				slide.add_child(mi(box(0.057, 0.044, 0.005), dark, Vector3(0, 0.034, 0.03 + i * 0.012)))
			slide.add_child(mi(box(0.004, 0.022, 0.05), black, Vector3(0.027, 0.04, -0.03)))
			slide.add_child(mi(box(0.012, 0.02, 0.014), dark, Vector3(0, 0.07, -0.168)))
			for sx in [-1.0, 1.0]:
				slide.add_child(mi(box(0.012, 0.018, 0.014), dark, Vector3(0.014 * sx, 0.07, 0.065)))
			parts["slide"] = slide
			root.add_child(mi(box(0.048, 0.04, 0.21), dark, Vector3(0, -0.012, -0.045)))
			root.add_child(mi(cyl(0.017, 0.017, 0.02, 8), metal, Vector3(0, 0.03, -0.183), Vector3(90, 0, 0)))
			root.add_child(mi(cyl(0.009, 0.009, 0.022, 6), black, Vector3(0, 0.03, -0.186), Vector3(90, 0, 0)))
			root.add_child(mi(box(0.012, 0.008, 0.065), dark, Vector3(0, -0.062, -0.04)))
			root.add_child(mi(box(0.012, 0.034, 0.008), dark, Vector3(0, -0.046, -0.072)))
			root.add_child(mi(box(0.007, 0.024, 0.008), metal, Vector3(0, -0.04, -0.036), Vector3(-15, 0, 0)))
			root.add_child(mi(box(0.016, 0.026, 0.014), dark, Vector3(0, 0.056, 0.088), Vector3(25, 0, 0)))
			root.add_child(mi(box(0.05, 0.15, 0.068), wood, Vector3(0, -0.095, 0.045), Vector3(-14, 0, 0)))
			for sx in [-1.0, 1.0]:
				root.add_child(mi(box(0.006, 0.1, 0.048), check, Vector3(0.026 * sx, -0.095, 0.047), Vector3(-14, 0, 0)))
			var mag := pivot(Vector3(0, -0.12, 0.05), Vector3(-14, 0, 0))
			root.add_child(mag)
			mag.add_child(mi(box(0.036, 0.11, 0.05), dark))
			mag.add_child(mi(box(0.056, 0.016, 0.074), dark, Vector3(0, -0.06, 0.004)))
			parts["mag"] = mag
			var charm := pivot(Vector3(0, -0.19, 0.075))
			root.add_child(charm)
			charm.add_child(mi(cyl(0.002, 0.002, 0.05, 4), dark, Vector3(0, -0.025, 0)))
			charm.add_child(mi(Creatures.blob_mesh(0.018, Vector3(1.0, 0.9, 1.0), 7101, 0.06, 6, 8), Mat.world("cr_gorb_green", o), Vector3(0, -0.06, 0)))
			for sx in [-1.0, 1.0]:
				charm.add_child(mi(sphere(0.006, 5, 4), white, Vector3(0.007 * sx, -0.058, -0.016)))
			parts["charm"] = charm
			muzzle.position = Vector3(0, 0.03, -0.19)
			if with_hands:
				root.add_child(mi(box(0.075, 0.1, 0.11), glove, Vector3(0, -0.1, 0.06), Vector3(-14, 0, 0)))
				root.add_child(mi(box(0.03, 0.03, 0.08), glove, Vector3(-0.045, -0.03, 0.0), Vector3(0, 10, 0)))
		"shotgun":
			# pump gun: vented heat shield, ribbed pump, spare shells taped on
			root.add_child(mi(cyl(0.022, 0.022, 0.62, 8), dark, Vector3(0, 0.02, -0.33), Vector3(90, 0, 0)))
			root.add_child(mi(box(0.05, 0.02, 0.42), metal, Vector3(0, 0.046, -0.29)))
			for i in 5:
				root.add_child(mi(box(0.03, 0.006, 0.03), black, Vector3(0, 0.057, -0.13 - i * 0.07)))
			root.add_child(mi(sphere(0.008, 6, 4), brass, Vector3(0, 0.05, -0.63)))
			root.add_child(mi(cyl(0.018, 0.018, 0.48, 8), metal, Vector3(0, -0.025, -0.27), Vector3(90, 0, 0)))
			root.add_child(mi(cyl(0.02, 0.02, 0.02, 8), dark, Vector3(0, -0.025, -0.51), Vector3(90, 0, 0)))
			root.add_child(mi(box(0.066, 0.09, 0.2), metal, Vector3(0, 0.0, 0.02)))
			root.add_child(mi(box(0.004, 0.03, 0.06), black, Vector3(0.034, 0.015, -0.01)))
			# taped spare shells on the side
			root.add_child(mi(box(0.012, 0.06, 0.13), Mat.world("white", {"origin": true, "tint": Color(0.6, 0.6, 0.62)}), Vector3(-0.038, -0.005, 0.02)))
			for i in 4:
				var sh := pivot(Vector3(-0.05, -0.024 + i * 0.0, 0.02), Vector3(90, 0, 0))
				root.add_child(sh)
				sh.position = Vector3(-0.05, 0.02 - i * 0.015, 0.02)
				sh.add_child(mi(cyl(0.008, 0.008, 0.05, 6), red, Vector3(0, -0.01, 0)))
				sh.add_child(mi(cyl(0.0085, 0.0085, 0.014, 6), brass, Vector3(0, 0.02, 0)))
			root.add_child(mi(box(0.05, 0.1, 0.3), wood, Vector3(0, -0.04, 0.24), Vector3(8, 0, 0)))
			root.add_child(mi(box(0.054, 0.106, 0.022), dark, Vector3(0, -0.06, 0.39), Vector3(8, 0, 0)))
			root.add_child(mi(box(0.012, 0.008, 0.06), dark, Vector3(0, -0.06, 0.06)))
			root.add_child(mi(box(0.007, 0.026, 0.008), metal, Vector3(0, -0.05, 0.07), Vector3(-15, 0, 0)))
			var pump := pivot()
			root.add_child(pump)
			pump.add_child(mi(box(0.07, 0.066, 0.17), wood, Vector3(0, -0.025, -0.26)))
			for i in 4:
				pump.add_child(mi(box(0.073, 0.069, 0.008), dark, Vector3(0, -0.025, -0.21 - i * 0.035)))
			parts["pump"] = pump
			muzzle.position = Vector3(0, 0.02, -0.65)
			if with_hands:
				root.add_child(mi(box(0.07, 0.09, 0.1), glove, Vector3(0.0, -0.08, 0.13), Vector3(20, 0, 0)))
		"ssg":
			# double barrel: rib, engraved brass receiver, twin hammers and a
			# Snirby sticker slapped on the stock
			var barrels := pivot(Vector3(0, -0.01, -0.06))
			root.add_child(barrels)
			for sx in [-1.0, 1.0]:
				barrels.add_child(mi(cyl(0.026, 0.026, 0.52, 8), dark, Vector3(0.027 * sx, 0.03, -0.26), Vector3(90, 0, 0)))
				barrels.add_child(mi(cyl(0.028, 0.028, 0.03, 8), brass, Vector3(0.027 * sx, 0.03, -0.51), Vector3(90, 0, 0)))
			barrels.add_child(mi(box(0.014, 0.01, 0.5), metal, Vector3(0, 0.06, -0.26)))
			barrels.add_child(mi(sphere(0.007, 6, 4), brass, Vector3(0, 0.068, -0.5)))
			barrels.add_child(mi(box(0.08, 0.032, 0.3), wood, Vector3(0, -0.01, -0.2)))
			for i in 5:
				barrels.add_child(mi(box(0.082, 0.004, 0.012), dark, Vector3(0, -0.026, -0.1 - i * 0.04)))
			barrels.add_child(mi(box(0.1, 0.064, 0.04), brass, Vector3(0, 0.02, -0.01)))
			var shells := pivot()
			barrels.add_child(shells)
			for sx in [-1.0, 1.0]:
				shells.add_child(mi(cyl(0.022, 0.022, 0.06, 6), red, Vector3(0.027 * sx, 0.03, 0.03), Vector3(90, 0, 0)))
				shells.add_child(mi(cyl(0.024, 0.024, 0.012, 6), brass, Vector3(0.027 * sx, 0.03, 0.062), Vector3(90, 0, 0)))
			shells.visible = false
			parts["shells"] = shells
			parts["barrels"] = barrels
			root.add_child(mi(box(0.074, 0.074, 0.12), brass, Vector3(0, 0.0, 0.02)))
			root.add_child(mi(box(0.076, 0.03, 0.08), Mat.world("gun_brass", {"origin": true, "tint": Color(0.6, 0.5, 0.35)}), Vector3(0, -0.01, 0.02)))
			root.add_child(mi(box(0.012, 0.01, 0.05), metal, Vector3(0, 0.04, 0.06)))
			for sx in [-1.0, 1.0]:
				root.add_child(mi(box(0.01, 0.03, 0.014), dark, Vector3(0.02 * sx, 0.045, 0.075), Vector3(-30, 0, 0)))
			root.add_child(mi(box(0.055, 0.1, 0.28), wood, Vector3(0, -0.05, 0.2), Vector3(10, 0, 0)))
			root.add_child(mi(box(0.004, 0.06, 0.06), Mat.world("cr_snirby_face", o), Vector3(0.029, -0.045, 0.21), Vector3(10, 0, 0)))
			root.add_child(mi(box(0.012, 0.008, 0.06), dark, Vector3(0, -0.055, 0.09)))
			for i in 2:
				root.add_child(mi(box(0.007, 0.024, 0.007), metal, Vector3(0, -0.045, 0.08 + i * 0.02), Vector3(-15, 0, 0)))
			muzzle.position = Vector3(0, 0.02, -0.6)
			if with_hands:
				root.add_child(mi(box(0.075, 0.09, 0.1), glove, Vector3(0.0, -0.08, 0.12), Vector3(20, 0, 0)))
		"mg":
			# six-barrel rotary in hazard paint, carry handle, ammo drum with
			# a Snirby face stuck on it
			root.add_child(mi(box(0.09, 0.11, 0.34), red, Vector3(0, 0, 0.0)))
			for i in 4:
				root.add_child(mi(box(0.092, 0.03, 0.025), Mat.world("gun_brass", {"origin": true, "tint": Color(1.2, 1.1, 0.2)}), Vector3(0, -0.03, -0.12 + i * 0.07), Vector3(0, 0, 0)))
				root.add_child(mi(box(0.093, 0.03, 0.025), black, Vector3(0, -0.03, -0.085 + i * 0.07)))
			root.add_child(mi(box(0.014, 0.012, 0.16), dark, Vector3(0, 0.1, 0.0)))
			for z in [-0.07, 0.07]:
				root.add_child(mi(box(0.014, 0.05, 0.014), dark, Vector3(0, 0.077, z)))
			var spin := pivot(Vector3(0, 0.0, -0.2))
			root.add_child(spin)
			for k in 6:
				var a := k * TAU / 6.0
				spin.add_child(mi(cyl(0.01, 0.01, 0.38, 6), dark, Vector3(cos(a) * 0.03, sin(a) * 0.03, -0.16), Vector3(90, 0, 0)))
			spin.add_child(mi(cyl(0.008, 0.008, 0.4, 5), metal, Vector3(0, 0, -0.16), Vector3(90, 0, 0)))
			for z in [-0.04, -0.2, -0.33]:
				spin.add_child(mi(cyl(0.046, 0.046, 0.022, 10), metal, Vector3(0, 0, z), Vector3(90, 0, 0)))
			parts["spin"] = spin
			var drum := pivot(Vector3(0, -0.1, -0.03))
			root.add_child(drum)
			drum.add_child(mi(cyl(0.08, 0.08, 0.07, 12), brass, Vector3.ZERO, Vector3(0, 0, 90)))
			drum.add_child(mi(cyl(0.05, 0.05, 0.074, 10), dark, Vector3.ZERO, Vector3(0, 0, 90)))
			drum.add_child(mi(box(0.004, 0.07, 0.07), Mat.world("cr_snirby_face", o), Vector3(0.039, 0, 0)))
			drum.add_child(mi(box(0.03, 0.05, 0.04), dark, Vector3(0, 0.07, 0.0)))
			parts["mag"] = drum
			root.add_child(mi(box(0.05, 0.12, 0.06), wood, Vector3(0, -0.1, 0.12), Vector3(-10, 0, 0)))
			root.add_child(mi(box(0.007, 0.026, 0.008), metal, Vector3(0, -0.07, 0.08), Vector3(-15, 0, 0)))
			muzzle.position = Vector3(0, 0, -0.56)
			if with_hands:
				root.add_child(mi(box(0.075, 0.09, 0.1), glove, Vector3(0.0, -0.13, 0.12), Vector3(-10, 0, 0)))
		"rocket":
			# a launcher with a shark face painted on: eyes, teeth, red mouth
			root.add_child(mi(cyl(0.068, 0.068, 0.62, 12), green, Vector3(0, 0.02, -0.12), Vector3(90, 0, 0)))
			root.add_child(mi(cyl(0.085, 0.07, 0.07, 12), dark, Vector3(0, 0.02, -0.46), Vector3(90, 0, 0)))
			root.add_child(mi(cyl(0.06, 0.06, 0.02, 12), black, Vector3(0, 0.02, -0.496), Vector3(90, 0, 0)))
			# back end: a green rim round a smaller dark opening
			root.add_child(mi(cyl(0.074, 0.074, 0.03, 12), green, Vector3(0, 0.02, 0.18), Vector3(90, 0, 0)))
			root.add_child(mi(cyl(0.048, 0.048, 0.004, 12), black, Vector3(0, 0.02, 0.196), Vector3(90, 0, 0)))
			for z in [-0.3, 0.05]:
				root.add_child(mi(cyl(0.071, 0.071, 0.025, 12), dark, Vector3(0, 0.02, z), Vector3(90, 0, 0)))
			# the face
			for sx in [-1.0, 1.0]:
				root.add_child(mi(sphere(0.018, 8, 6), white, Vector3(0.05 * sx, 0.06, -0.33)))
				root.add_child(mi(sphere(0.009, 6, 4), black, Vector3(0.062 * sx, 0.065, -0.337)))
			root.add_child(mi(box(0.004, 0.03, 0.12), red, Vector3(0.068, 0.0, -0.38)))
			root.add_child(mi(box(0.004, 0.03, 0.12), red, Vector3(-0.068, 0.0, -0.38)))
			for i in 5:
				for sx in [-1.0, 1.0]:
					root.add_child(mi(cyl(0.0, 0.008, 0.016, 4), white, Vector3(0.07 * sx, 0.01, -0.33 - i * 0.022), Vector3(180, 0, 0)))
					root.add_child(mi(cyl(0.0, 0.008, 0.016, 4), white, Vector3(0.07 * sx, -0.01, -0.34 - i * 0.022)))
			var rk := pivot()
			root.add_child(rk)
			rk.add_child(mi(cyl(0.0, 0.045, 0.1, 8), red, Vector3(0, 0.02, -0.53), Vector3(-90, 0, 0)))
			parts["rocket"] = rk
			root.add_child(mi(box(0.03, 0.05, 0.12), dark, Vector3(0, 0.1, -0.1)))
			root.add_child(mi(cyl(0.012, 0.012, 0.01, 8), Mat.world("white", {"origin": true, "tint": Color(1, 0.1, 0.1), "fullbright": 1.0}), Vector3(0, 0.11, -0.165), Vector3(90, 0, 0)))
			root.add_child(mi(box(0.05, 0.13, 0.06), dark, Vector3(0, -0.1, 0.0), Vector3(-10, 0, 0)))
			root.add_child(mi(box(0.04, 0.1, 0.05), dark, Vector3(0, -0.08, -0.25), Vector3(-5, 0, 0)))
			muzzle.position = Vector3(0, 0.02, -0.55)
			if with_hands:
				root.add_child(mi(box(0.075, 0.09, 0.1), glove, Vector3(0.0, -0.13, 0.01), Vector3(-10, 0, 0)))
		"plasma":
			# coils and prongs, and a specimen jar on top with something in it
			var purple := Mat.world("gun_purple", o)
			var glow := Mat.make("gun_plasma", {"origin": true, "fullbright": 1.0})
			parts["glow_mat"] = glow
			root.add_child(mi(box(0.09, 0.09, 0.4), purple, Vector3(0, 0, -0.05)))
			root.add_child(mi(box(0.06, 0.02, 0.36), dark, Vector3(0, 0.054, -0.05)))
			for k in 3:
				root.add_child(mi(cyl(0.062, 0.062, 0.03, 10), glow, Vector3(0, 0, -0.08 - k * 0.07), Vector3(90, 0, 0)))
			for i in 4:
				root.add_child(mi(box(0.095, 0.012, 0.012), dark, Vector3(0, -0.03 + i * 0.02, 0.13)))
			for sx in [-1.0, 1.0]:
				root.add_child(mi(cyl(0.0, 0.02, 0.16, 5), dark, Vector3(0.035 * sx, 0.0, -0.32), Vector3(-90, 0, 0)))
			var core := mi(sphere(0.03, 8, 6), glow, Vector3(0, 0, -0.32))
			root.add_child(core)
			parts["core"] = core
			# the jar
			root.add_child(mi(cyl(0.034, 0.034, 0.012, 10), brass, Vector3(0, 0.07, 0.0)))
			root.add_child(mi(cyl(0.034, 0.034, 0.012, 10), brass, Vector3(0, 0.15, 0.0)))
			root.add_child(mi(cyl(0.028, 0.028, 0.07, 10), Mat.make("liq_goo", {"origin": true, "fullbright": 0.8, "tint": Color(0.5, 1.0, 0.4), "scroll": Vector2(0, 0.3)}), Vector3(0, 0.11, 0.0)))
			for k in 4:
				var a := k * TAU / 4.0 + 0.4
				root.add_child(mi(box(0.005, 0.08, 0.005), brass, Vector3(cos(a) * 0.032, 0.11, sin(a) * 0.032)))
			var specimen := mi(Creatures.blob_mesh(0.016, Vector3(1.0, 0.9, 1.0), 7102, 0.08, 6, 8), Mat.world("cr_gorb_green", o), Vector3(0, 0.11, -0.03))
			root.add_child(specimen)
			parts["specimen"] = specimen
			root.add_child(mi(box(0.05, 0.13, 0.06), purple, Vector3(0, -0.1, 0.08), Vector3(-12, 0, 0)))
			muzzle.position = Vector3(0, 0, -0.4)
			if with_hands:
				root.add_child(mi(box(0.075, 0.09, 0.1), glove, Vector3(0.0, -0.13, 0.09), Vector3(-12, 0, 0)))
		"flamer":
			# a red gas canister slung under a long nozzle, a brass feed pipe,
			# a little blue pilot light, and a Gorbino sticker on the tank
			var tank_m := Mat.world("gun_red", o)
			root.add_child(mi(cyl(0.065, 0.065, 0.26, 12), tank_m, Vector3(0, -0.075, 0.02), Vector3(90, 0, 0)))
			root.add_child(mi(sphere(0.065, 12, 6), tank_m, Vector3(0, -0.075, -0.11)))
			root.add_child(mi(sphere(0.065, 12, 6), tank_m, Vector3(0, -0.075, 0.15)))
			root.add_child(mi(cyl(0.067, 0.067, 0.03, 12), Mat.world("white", {"origin": true, "tint": Color(1.0, 0.85, 0.1)}), Vector3(0, -0.075, -0.04), Vector3(90, 0, 0)))
			root.add_child(mi(box(0.004, 0.05, 0.05), Mat.world("cr_gorb_yellow", o), Vector3(0.066, -0.075, 0.06)))
			root.add_child(mi(cyl(0.02, 0.02, 0.05, 8), brass, Vector3(0, -0.005, 0.14)))
			root.add_child(mi(box(0.07, 0.06, 0.32), dark, Vector3(0, 0.02, -0.05)))
			root.add_child(mi(cyl(0.022, 0.026, 0.3, 10), metal, Vector3(0, 0.03, -0.32), Vector3(90, 0, 0)))
			root.add_child(mi(cyl(0.04, 0.026, 0.06, 10), dark, Vector3(0, 0.03, -0.49), Vector3(90, 0, 0)))
			for k in 4:
				root.add_child(mi(cyl(0.03, 0.03, 0.01, 10), dark, Vector3(0, 0.03, -0.22 - k * 0.05), Vector3(90, 0, 0)))
			# the brass feed pipe from the tank up to the barrel
			root.add_child(mi(cyl(0.008, 0.008, 0.28, 6), brass, Vector3(0.04, -0.02, -0.2), Vector3(90, 0, 0)))
			root.add_child(mi(cyl(0.008, 0.008, 0.06, 6), brass, Vector3(0.04, -0.045, -0.07), Vector3(0, 0, 0)))
			var pilot := mi(sphere(0.012, 6, 4), Mat.make("white", {"origin": true, "fullbright": 1.0, "tint": Color(0.35, 0.6, 1.0)}), Vector3(0, -0.01, -0.53))
			root.add_child(pilot)
			parts["pilot"] = pilot
			root.add_child(mi(box(0.04, 0.12, 0.05), dark, Vector3(0, -0.06, 0.2), Vector3(-15, 0, 0)))
			muzzle.position = Vector3(0, 0.03, -0.55)
			if with_hands:
				root.add_child(mi(box(0.075, 0.09, 0.1), glove, Vector3(0.0, -0.11, 0.21), Vector3(-15, 0, 0)))
	root.set_meta("parts", parts)
	return root


# ================================================================== PICKUPS
static func pickup(ptype: String) -> Node3D:
	var root := Node3D.new()
	var o := {"origin": true}
	match ptype:
		"juice":
			# a can of juice with a bendy straw
			root.add_child(mi(cyl(0.11, 0.11, 0.3, 10), Mat.world("pk_juice", o), Vector3(0, 0.15, 0)))
			root.add_child(mi(cyl(0.1, 0.11, 0.02, 10), Mat.world("gun_metal", o), Vector3(0, 0.31, 0)))
			root.add_child(mi(cyl(0.11, 0.1, 0.02, 10), Mat.world("gun_metal", o), Vector3(0, 0.0, 0)))
			var straw := Mat.world("white", {"origin": true, "tint": Color(1.0, 0.3, 0.5)})
			root.add_child(mi(cyl(0.012, 0.012, 0.16, 6), straw, Vector3(0.03, 0.39, 0)))
			root.add_child(mi(cyl(0.012, 0.012, 0.09, 6), straw, Vector3(0.065, 0.49, 0), Vector3(0, 0, -55)))
		"medkit":
			# a lunchbox of medicine with a syringe strapped to it
			root.add_child(mi(box(0.5, 0.28, 0.34), Mat.world("pk_medkit", o), Vector3(0, 0.14, 0)))
			root.add_child(mi(box(0.52, 0.04, 0.36), Mat.world("white", {"origin": true, "tint": Color(0.75, 0.75, 0.72)}), Vector3(0, 0.28, 0)))
			root.add_child(mi(box(0.2, 0.025, 0.03), Mat.world("gun_dark", o), Vector3(0, 0.36, 0)))
			for sx in [-1.0, 1.0]:
				root.add_child(mi(box(0.025, 0.08, 0.03), Mat.world("gun_dark", o), Vector3(0.09 * sx, 0.32, 0)))
				root.add_child(mi(box(0.05, 0.05, 0.02), Mat.world("gun_metal", o), Vector3(0.16 * sx, 0.24, -0.175)))
			root.add_child(mi(cyl(0.025, 0.025, 0.2, 8), Mat.world("liq_goo", {"origin": true, "fullbright": 0.6, "tint": Color(0.4, 1.0, 0.5)}), Vector3(0.0, 0.1, -0.2), Vector3(0, 0, 90)))
			root.add_child(mi(cyl(0.004, 0.004, 0.08, 4), Mat.world("gun_metal", o), Vector3(0.14, 0.1, -0.2), Vector3(0, 0, 90)))
			root.add_child(mi(box(0.02, 0.06, 0.06), Mat.world("gun_dark", o), Vector3(-0.11, 0.1, -0.2)))
		"mega":
			# a heart that won't stop beating, caged in brass, glowing
			var heart := pivot(Vector3(0, 0.5, 0))
			heart.name = "Beat"
			root.add_child(heart)
			heart.add_child(mi(Creatures.blob_mesh(0.2, Vector3(1.0, 1.15, 0.85), 7201, 0.08, 10, 14), Mat.make("gore_organ", {"origin": true, "tint": Color(1.4, 0.6, 0.9), "fullbright": 0.6, "gloss": 1.0, "shade": 0.6})))
			for sx in [-1.0, 1.0]:
				heart.add_child(mi(cyl(0.04, 0.05, 0.14, 7), Mat.world("gore_guts", {"origin": true, "fullbright": 0.4}), Vector3(0.06 * sx, 0.24, 0.02), Vector3(0, 0, -20 * sx)))
			var brass := Mat.world("gun_brass", o)
			for k in 3:
				root.add_child(mi(cyl(0.3, 0.3, 0.02, 14), brass, Vector3(0, 0.5, 0), Vector3(90, k * 60, 0)))
			root.add_child(mi(cyl(0.12, 0.16, 0.08, 10), brass, Vector3(0, 0.04, 0)))
			root.add_child(mi(cyl(0.015, 0.015, 0.2, 6), brass, Vector3(0, 0.16, 0)))
		"armor_bonus":
			# a pill, half white, half blue
			var pill := pivot(Vector3(0, 0.25, 0), Vector3(0, 0, 60))
			root.add_child(pill)
			pill.add_child(mi(cyl(0.06, 0.06, 0.1, 10), Mat.world("white", o), Vector3(0, 0.05, 0)))
			pill.add_child(mi(sphere(0.06, 10, 6), Mat.world("white", o), Vector3(0, 0.1, 0)))
			var blue := Mat.world("pk_orb_blue", {"origin": true, "fullbright": 0.5})
			pill.add_child(mi(cyl(0.061, 0.061, 0.1, 10), blue, Vector3(0, -0.05, 0)))
			pill.add_child(mi(sphere(0.061, 10, 6), blue, Vector3(0, -0.1, 0)))
		"armor_green", "armor_blue":
			# a vest: front plate, side panels, straps, collar and pouches
			var m := Mat.world("pk_" + ptype, o)
			var dk := Mat.world("gun_dark", o)
			root.add_child(mi(box(0.46, 0.5, 0.12), m, Vector3(0, 0.42, 0.04)))
			root.add_child(mi(box(0.46, 0.5, 0.06), m, Vector3(0, 0.42, 0.24)))
			for sx in [-1.0, 1.0]:
				root.add_child(mi(box(0.05, 0.42, 0.22), m, Vector3(0.24 * sx, 0.4, 0.14)))
				root.add_child(mi(box(0.1, 0.05, 0.3), dk, Vector3(0.15 * sx, 0.69, 0.14)))
				root.add_child(mi(box(0.1, 0.12, 0.05), dk, Vector3(0.12 * sx, 0.27, -0.04)))
			root.add_child(mi(box(0.2, 0.06, 0.13), dk, Vector3(0, 0.67, 0.02)))
			root.add_child(mi(box(0.48, 0.04, 0.27), dk, Vector3(0, 0.2, 0.14)))
		"bullets":
			# a cardboard tray of standing cartridges, two spilled beside it
			root.add_child(mi(box(0.24, 0.05, 0.15), Mat.world("pk_bullets", o), Vector3(0, 0.025, 0)))
			for i in 8:
				_cartridge(root, Vector3(-0.08 + (i % 4) * 0.053, 0.05, -0.035 + (i / 4) * 0.07), Vector3.ZERO)
			_cartridge(root, Vector3(0.17, 0.02, 0.06), Vector3(90, 0, 70))
			_cartridge(root, Vector3(-0.16, 0.02, -0.07), Vector3(90, 0, -30))
		"bullets_box":
			# an olive ammo can with its lid latched, a loose belt hanging off it
			var can := Mat.world("gun_green", o)
			var dk := Mat.world("gun_dark", o)
			root.add_child(mi(box(0.46, 0.28, 0.22), can, Vector3(0, 0.14, 0)))
			root.add_child(mi(box(0.48, 0.04, 0.24), dk, Vector3(0, 0.3, 0)))
			root.add_child(mi(box(0.18, 0.025, 0.03), dk, Vector3(0, 0.335, 0)))
			root.add_child(mi(box(0.1, 0.06, 0.006), Mat.world("gun_brass", o), Vector3(0, 0.18, -0.113)))
			for i in 9:
				_cartridge(root, Vector3(-0.2 + i * 0.05, 0.035, -0.17 - 0.02 * sin(i * 0.9)), Vector3(90, 0, 0), 1.2)
		"shells":
			# loose shotgun shells: red hulls on brass heads
			for i in 4:
				_shell(root, Vector3(-0.09 + i * 0.06, 0.0, 0.0), Vector3.ZERO)
			_shell(root, Vector3(0.0, 0.03, 0.09), Vector3(90, 0, 60))
		"shells_box":
			root.add_child(mi(box(0.4, 0.18, 0.26), Mat.world("pk_shells", o), Vector3(0, 0.09, 0)))
			for i in 6:
				_shell(root, Vector3(-0.15 + i * 0.06, 0.12, 0.0), Vector3.ZERO)
		"rocket":
			_rocket(root, Vector3(0, 0.07, 0), Vector3(90, 0, 0))
		"rockets_box":
			root.add_child(mi(box(0.8, 0.28, 0.38), Mat.world("crate", o), Vector3(0, 0.14, 0)))
			_rocket(root, Vector3(-0.1, 0.35, -0.06), Vector3(90, 0, 0))
			_rocket(root, Vector3(0.12, 0.35, 0.08), Vector3(90, 8, 0))
		"cells":
			_cell(root, Vector3(0, 0.0, 0))
		"cells_box":
			root.add_child(mi(box(0.36, 0.05, 0.36), Mat.world("gun_dark", o), Vector3(0, 0.025, 0)))
			for i in 4:
				_cell(root, Vector3(-0.08 + (i % 2) * 0.16, 0.05, -0.08 + (i / 2) * 0.16))
		"backpack":
			# a stuffed canvas pack with pockets, straps and a Gorbino patch
			var dk := Mat.world("gun_dark", o)
			root.add_child(mi(Creatures.blob_mesh(0.27, Vector3(0.95, 1.1, 0.6), 7301, 0.05, 8, 12), Mat.world("gun_green", o), Vector3(0, 0.3, 0)))
			root.add_child(mi(box(0.4, 0.16, 0.1), Mat.world("gun_green", {"origin": true, "tint": Color(0.75, 0.75, 0.6)}), Vector3(0, 0.2, -0.17)))
			root.add_child(mi(box(0.42, 0.14, 0.2), Mat.world("gun_green", {"origin": true, "tint": Color(0.85, 0.85, 0.7)}), Vector3(0, 0.5, -0.06), Vector3(-15, 0, 0)))
			for sx in [-1.0, 1.0]:
				root.add_child(mi(box(0.05, 0.5, 0.03), dk, Vector3(0.11 * sx, 0.3, 0.17)))
				root.add_child(mi(box(0.08, 0.18, 0.12), Mat.world("gun_green", {"origin": true, "tint": Color(0.8, 0.8, 0.65)}), Vector3(0.27 * sx, 0.24, 0)))
			root.add_child(mi(box(0.12, 0.12, 0.01), Mat.world("cr_gorb_green", {"origin": true, "fullbright": 0.2}), Vector3(0, 0.22, -0.225)))
		"key_red", "key_blue", "key_yellow":
			# a keycard on a lanyard with a clip
			root.add_child(mi(box(0.45, 0.3, 0.035), Mat.world("pk_" + ptype, {"origin": true, "fullbright": 0.6}), Vector3(0, 0.55, 0)))
			root.add_child(mi(box(0.05, 0.03, 0.04), Mat.world("gun_metal", o), Vector3(0, 0.72, 0)))
			var lan := Mat.world("pk_" + ptype, {"origin": true, "tint": Color(0.7, 0.7, 0.7)})
			for sx in [-1.0, 1.0]:
				root.add_child(mi(box(0.02, 0.3, 0.008), lan, Vector3(0.08 * sx, 0.88, 0), Vector3(0, 0, -15 * sx)))
		"fuel", "fuel_box":
			# red jerry cans with a spout
			var can := Mat.world("gun_red", o)
			var n := 1 if ptype == "fuel" else 2
			for k in n:
				var x := (k - (n - 1) * 0.5) * 0.3
				root.add_child(mi(box(0.22, 0.3, 0.12), can, Vector3(x, 0.15, 0)))
				root.add_child(mi(box(0.2, 0.025, 0.1), Mat.world("white", {"origin": true, "tint": Color(1.0, 0.85, 0.1)}), Vector3(x, 0.2, 0)))
				root.add_child(mi(cyl(0.02, 0.025, 0.08, 6), Mat.world("gun_dark", o), Vector3(x + 0.06, 0.33, 0), Vector3(0, 0, -20)))
				root.add_child(mi(box(0.12, 0.03, 0.03), Mat.world("gun_dark", o), Vector3(x - 0.03, 0.31, 0)))
		_:
			if ptype.begins_with("w_"):
				var w := weapon(ptype.substr(2).replace("shotgun", "shotgun").replace("ssg", "ssg"), false)
				w.scale = Vector3.ONE * 1.8
				w.position = Vector3(0, 0.35, 0)
				w.rotation_degrees = Vector3(0, 90, 0)
				root.add_child(w)
	return root


## A brass cartridge with a copper bullet, standing on `pos` along +Y.
static func _cartridge(root: Node3D, pos: Vector3, rot: Vector3, scl := 1.0) -> void:
	var c := pivot(pos, rot)
	c.scale = Vector3.ONE * scl
	root.add_child(c)
	c.add_child(mi(cyl(0.019, 0.019, 0.07, 8), Mat.world("gun_brass", {"origin": true}), Vector3(0, 0.035, 0)))
	c.add_child(mi(cyl(0.004, 0.017, 0.035, 8), Mat.world("gun_brass", {"origin": true, "tint": Color(1.0, 0.55, 0.35)}), Vector3(0, 0.0875, 0)))


static func _shell(root: Node3D, pos: Vector3, rot: Vector3) -> void:
	var c := pivot(pos, rot)
	root.add_child(c)
	c.add_child(mi(cyl(0.028, 0.028, 0.11, 8), Mat.world("gun_red", {"origin": true}), Vector3(0, 0.075, 0)))
	c.add_child(mi(cyl(0.03, 0.03, 0.03, 8), Mat.world("gun_brass", {"origin": true}), Vector3(0, 0.015, 0)))


static func _rocket(root: Node3D, pos: Vector3, rot: Vector3) -> void:
	var c := pivot(pos, rot)
	root.add_child(c)
	c.add_child(mi(cyl(0.06, 0.06, 0.42, 8), Mat.world("gun_green", {"origin": true})))
	c.add_child(mi(cyl(0.0, 0.06, 0.15, 8), Mat.world("gun_red", {"origin": true}), Vector3(0, 0.285, 0)))
	for k in 3:
		c.add_child(mi(box(0.012, 0.1, 0.09), Mat.world("gun_dark", {"origin": true}), Vector3(0, -0.18, 0).rotated(Vector3.UP, k * TAU / 3.0) + Vector3(sin(k * TAU / 3.0), 0, cos(k * TAU / 3.0)) * 0.07, Vector3(0, rad_to_deg(k * TAU / 3.0), 0)))


## A fat battery with a glowing band and a terminal on top.
static func _cell(root: Node3D, pos: Vector3) -> void:
	var c := pivot(pos)
	root.add_child(c)
	c.add_child(mi(cyl(0.065, 0.065, 0.24, 10), Mat.world("gun_dark", {"origin": true}), Vector3(0, 0.12, 0)))
	c.add_child(mi(cyl(0.067, 0.067, 0.05, 10), Mat.world("pk_cells", {"origin": true, "fullbright": 0.9}), Vector3(0, 0.15, 0)))
	c.add_child(mi(cyl(0.022, 0.022, 0.03, 8), Mat.world("gun_metal", {"origin": true}), Vector3(0, 0.255, 0)))


# ================================================================== PROPS
static func barrel() -> Node3D:
	var root := Node3D.new()
	var o := {"origin": true}
	root.add_child(mi(cyl(0.38, 0.38, 1.1, 12), Mat.world("barrel", o), Vector3(0, 0.55, 0)))
	root.add_child(mi(cyl(0.37, 0.37, 0.02, 12), Mat.world("barrel_top", {"origin": true, "fullbright": 0.3}), Vector3(0, 1.105, 0)))
	var rim := Mat.world("gun_dark", o)
	for y in [0.04, 0.38, 0.72, 1.08]:
		root.add_child(mi(cyl(0.395, 0.395, 0.04, 12), rim, Vector3(0, y, 0)))
	root.add_child(mi(cyl(0.05, 0.05, 0.04, 8), Mat.world("gun_metal", o), Vector3(0.18, 1.12, 0.05)))
	return root
