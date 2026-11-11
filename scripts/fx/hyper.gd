class_name Hyper
extends RefCounted
## FISH-style hyperreal bits: photo-real eyes, lips and noses stuck onto some
## of the cartoon creatures, a few watching eyes and mouths pasted on the
## walls, real teeth and eyeballs in the gibs, photo cut-outs in the kill
## stickers. All of it is tied to the COLLAGE FX option.

const ATLAS_FRAMES := {"hr_eye": 7, "hr_eye_b": 7, "hr_eye_sore": 7, "hr_mouth": 4}
const EYE := {"center": 0, "left": 1, "right": 2, "up": 3, "half": 4, "shut": 5, "wide": 6}
const MOUTH := {"shut": 0, "open": 1, "scream": 2, "grin": 3}
const GIB_BITS := [["hr_eyeball", 4], ["hr_tooth", 3], ["hr_meat", 2], ["hr_nose", 1]]
const WALL_SKIP := ["window", "sign", "poster", "exit", "switch", "elevator", "computer", "logo", "lantern", "stencil",
	"alert", "warning", "panel", "vat", "static", "void", "snirbface", "eyes", "glyph", "swirl"]
const WALL_KINDS := [["eye", 6], ["mouth", 3], ["hr_fish", 2], ["hr_nose", 1], ["hr_meat", 1], ["hr_eyeball", 1]]

static var _shader: Shader
static var _regions := {}


static func shader() -> Shader:
	if _shader == null:
		_shader = load("res://shaders/hyperreal.gdshader")
	return _shader


static func frames_of(name: String) -> int:
	return int(ATLAS_FRAMES.get(name, 1))


## A flat photo quad of the given width (height follows the picture).
static func quad(name: String, width: float, billboard := false) -> MeshInstance3D:
	var t: Texture2D = Collage.texture(name)
	var fr := frames_of(name)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, width * float(t.get_height()) / (float(t.get_width()) / fr))
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = shader()
	m.set_shader_parameter("tex", t)
	m.set_shader_parameter("frames", float(fr))
	m.set_shader_parameter("billboard", 1.0 if billboard else 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("hyper", true)
	mi.set_meta("no_outline", true)
	return mi


static func set_frame(mi: MeshInstance3D, f: int) -> void:
	if mi.get_meta("frame", -1) == f:
		return
	mi.set_meta("frame", f)
	(mi.material_override as ShaderMaterial).set_shader_parameter("frame", float(f))


static func set_tint(mi: MeshInstance3D, c: Color) -> void:
	(mi.material_override as ShaderMaterial).set_shader_parameter("tint", c)


## One frame of an atlas as a texture of its own (for the HUD).
static func region(name: String, f := 0) -> Texture2D:
	var key := "%s:%d" % [name, f]
	if not _regions.has(key):
		var t: Texture2D = Collage.texture(name)
		var fr := frames_of(name)
		if fr == 1:
			_regions[key] = t
		else:
			var at := AtlasTexture.new()
			at.atlas = t
			var w := float(t.get_width()) / fr
			at.region = Rect2(w * f, 0, w, t.get_height())
			_regions[key] = at
	return _regions[key]


static func _pick(rng: RandomNumberGenerator, table: Array) -> String:
	var tot := 0.0
	for e in table:
		tot += float(e[1])
	var r := rng.randf() * tot
	for e in table:
		r -= float(e[1])
		if r <= 0.0:
			return String(e[0])
	return String(table[0][0])


## A photo cut-out for a kill sticker.
static func sticker_tex() -> Texture2D:
	match randi() % 8:
		0, 1:
			return region("hr_eyeball")
		2:
			return region("hr_tooth")
		3:
			return region("hr_mouth", MOUTH["scream"])
		4:
			return region("hr_eye", EYE["wide"])
		5:
			return region("hr_fish")
		6:
			return region("hr_meat")
	return region("hr_nose")


# ------------------------------------------------------------------ faces
## Maybe give a creature some human features. Deterministic per seed, so a
## reloaded save shows the same faces. Returns the face, or null.
static func decorate(host: Node3D, model: Node3D, seed: int, civ := false) -> HyperFace:
	var parts: Dictionary = model.get_meta("parts", {})
	var kind := String(parts.get("kind", ""))
	if not kind in ["gorbino", "snirby", "snotling"]:
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var p := [0.3, 0.38, 0.12, 0.0] if civ else [0.2, 0.14, 0.09, 0.035]
	var want_eyes: bool = rng.randf() < float(p[0])
	var want_mouth: bool = rng.randf() < float(p[1])
	var want_nose: bool = rng.randf() < float(p[2]) and kind == "gorbino"
	var cyclops: bool = rng.randf() < float(p[3]) and kind == "gorbino"
	if OS.get_cmdline_user_args().has("--hyperall"):        # debug: everyone gets the works
		want_eyes = true
		want_mouth = true
		want_nose = true
		cyclops = false
	if (parts.get("eyes", []) as Array).size() > 0 and kind == "gorbino":
		want_eyes = false            # the elite's glowing eyes stay
		cyclops = false
	if not (want_eyes or want_mouth or want_nose or cyclops):
		return null
	var face := HyperFace.new()
	face.host = host
	face.grin = rng.randf() < 0.3
	face.seed_rng(seed)
	var eye_tex := "hr_eye_b" if rng.randf() < 0.45 else "hr_eye"
	if rng.randf() < 0.15:
		eye_tex = "hr_eye_sore"
	var anchor: Node3D
	var eyes_at := []         # [position, normal, flip]
	var mouth_at := []
	var nose_at := []
	var eye_w := 0.42
	var mouth_w := 0.64
	match kind:
		"gorbino":
			anchor = parts["squash"]
			var H := Creatures.GORB_H
			var c := Vector3(0, (0.55 - Creatures.GORB_SQUASH_Y) * H, 0)
			var on := func(mx: float, my: float) -> Array:
				var R := 0.452
				var z := -sqrt(maxf(R * R - mx * mx - (my - 0.55) * (my - 0.55), 0.01))
				var pt := Vector3(mx, my - Creatures.GORB_SQUASH_Y, z) * H
				return [pt, (pt - c).normalized()]
			for e in Creatures.GORB_EYES:
				var a: Array = on.call(e.x, e.y)
				eyes_at.append([a[0], a[1], e.x > 0.0])
			if cyclops:
				eyes_at = [on.call(-0.01, 0.57) + [false]]
				eye_w = 0.75
			mouth_at = on.call(Creatures.GORB_MOUTH.x, Creatures.GORB_MOUTH.y + 0.01)
			nose_at = on.call(-0.01, 0.47)
		"snirby":
			anchor = parts["puff"]
			eye_w = 0.32
			mouth_w = 0.4
			for uv in [Vector2(0.32, 0.44), Vector2(0.67, 0.44)]:
				var pt := Creatures._snirby_face_point(uv)
				eyes_at.append([pt, pt.normalized(), uv.x < 0.5])
			var mp := Creatures._snirby_face_point(Vector2(0.5, 0.83))
			mouth_at = [mp, mp.normalized()]
		"snotling":
			anchor = parts["puff"]
			eye_w = 0.3
			mouth_w = 0.42
			for sx in [-1.0, 1.0]:
				var pt := Vector3(0.15 * sx, 0.15, -0.44)
				eyes_at.append([pt, (pt * Vector3(1, 0.5, 1)).normalized(), sx > 0.0])
			var mp := Vector3(0, -0.12, -0.46)
			mouth_at = [mp, (mp * Vector3(1, 0.5, 1)).normalized()]
	if anchor == null:
		face.free()
		return null
	anchor.add_child(face)
	if want_eyes or cyclops:
		var layer := 0.035
		for e in eyes_at:
			# the two patches overlap a little: one sits on top of the other
			face.add_eye(Hyper.quad(eye_tex, eye_w), e[0], e[1], e[2], layer)
			layer += 0.02
	if want_mouth and mouth_at.size() == 2:
		face.add_mouth(Hyper.quad("hr_mouth", mouth_w), mouth_at[0], mouth_at[1], 0.035)
	if want_nose and nose_at.size() == 2:
		face.stick(Hyper.quad("hr_nose", 0.27), nose_at[0], nose_at[1], false, 0.09)
	face.visible = Collage.enabled()
	return face


# ------------------------------------------------------------------ walls
## A few photo cut-outs pasted on the walls of a level: eyes that follow
## you and blink, mouths that open as you come near, the odd fish.
static func paste_walls(lv: Level) -> Node3D:
	var root := Node3D.new()
	root.name = "HyperWalls"
	lv.add_child(root)
	var name := String(lv.data.get("name", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name + "hyperreal")
	var cands := []
	for i in lv.solid.size():
		if lv.solid[i] != 0 or lv.movers.has(i) or lv.use_cells.has(i):
			continue
		if lv.ceil_h[i] - lv.floor_h[i] < 2.8:
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
			# the wall has to carry on either side, so a big picture doesn't hang off a corner
			var side := Vector2i(dv.y, dv.x)
			var s1 := lv.idx_of(c + dv + side)
			var s2 := lv.idx_of(c + dv - side)
			if s1 < 0 or s2 < 0 or lv.solid[s1] != 1 or lv.solid[s2] != 1:
				continue
			cands.append([c, dv])
	var want := int(lv.data.get("hyper_walls", 4))
	var placed := []
	var tries := 0
	while placed.size() < want and tries < 400 and cands.size() > 0:
		tries += 1
		var cand: Array = cands[rng.randi_range(0, cands.size() - 1)]
		var c: Vector2i = cand[0]
		var far := true
		for pc in placed:
			if absi(pc.x - c.x) + absi(pc.y - c.y) < 10:
				far = false
				break
		if not far:
			continue
		placed.append(c)
		var dv: Vector2i = cand[1]
		var i := lv.idx_of(c)
		var dir := Vector3(dv.x, 0, dv.y)
		var kind := _pick(rng, WALL_KINDS)
		var size := rng.randf_range(1.4, 2.2)
		var mi: MeshInstance3D
		var face: HyperFace = null
		match kind:
			"eye":
				mi = quad("hr_eye_sore" if rng.randf() < 0.3 else ("hr_eye_b" if rng.randf() < 0.5 else "hr_eye"), size)
			"mouth":
				mi = quad("hr_mouth", size)
			_:
				mi = quad(kind, size * 0.9)
		var pos := lv.cell_center(c) + dir * (Level.S * 0.5 - 0.03)
		var hgt := (mi.mesh as QuadMesh).size.y
		pos.y = lv.floor_h[i] + clampf(rng.randf_range(1.2, 2.0), hgt * 0.5 + 0.2, lv.ceil_h[i] - lv.floor_h[i] - hgt * 0.5 - 0.15)
		if kind == "eye" or kind == "mouth":
			face = HyperFace.new()
			face.wall = true
			face.level = lv
			face.seed_rng(rng.randi())
			root.add_child(face)
			face.global_position = pos
			if kind == "eye":
				face.add_eye(mi, Vector3.ZERO, -dir, false, 0.0)
			else:
				face.add_mouth(mi, Vector3.ZERO, -dir, 0.0)
			mi.rotate_object_local(Vector3.FORWARD, rng.randf_range(-0.2, 0.2))
		else:
			root.add_child(mi)
			mi.global_position = pos
			mi.basis = Basis.looking_at(dir, Vector3.UP)
			mi.rotate_object_local(Vector3.FORWARD, rng.randf_range(-0.35, 0.35))
	root.visible = Collage.enabled()
	return root


# ------------------------------------------------------------------ gibs
## A real tooth, eyeball or chunk of steak among the cartoon gibs.
static func gib(level: Node, pos: Vector3) -> void:
	var g := Gib.new()
	var mi := quad(_gib_name(), randf_range(0.32, 0.5), true)
	(mi.material_override as ShaderMaterial).set_shader_parameter("spin", randf_range(-0.6, 0.6))
	# sit on the floor, not half through it
	mi.position.y = (mi.mesh as QuadMesh).size.y * 0.4
	g.add_child(mi)
	level.fx_root().add_child(g)
	g.global_position = pos + Vector3(randf_range(-0.2, 0.2), randf_range(0.0, 0.4), randf_range(-0.2, 0.2))
	g.vel = Vector3(randf_range(-4, 4), randf_range(4, 8), randf_range(-4, 4))
	g.level = level
	g.add_to_group("gibs")


static func _gib_name() -> String:
	var r := randf() * 10.0
	for e in GIB_BITS:
		r -= float(e[1])
		if r <= 0.0:
			return String(e[0])
	return "hr_eyeball"
