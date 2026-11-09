class_name Offhand
extends Node3D
## The player's left arm and a butterfly knife that never sits still.
## Between fights it fans the knife open and shut, rolls it over the
## knuckles, flips it into the air and turns the weird blade to the light;
## the Finisher drives it for slashes and for gutting.
##
## Rig: this node (camera space) > arm (forearm, moves) > hand (wrist,
## twists) > knife (the held "safe" handle; spins). The blade and the free
## "bite" handle hang off the pivot pin at the top of the safe handle and
## swing round it when the knife is flipped open or shut.

const REST := Vector3(-0.09, -0.085, -0.2)
const VM_SCALE := 0.36
const KNIFE_SCALE := 1.5
const ARM_REST := Vector3(0.1, 0.12, 0.0)
const HAND_REST := Vector3(0.55, -0.6, 0.3)     # blade up and angled in, side on to the camera
const TRICKS := ["fan", "fan", "rollover", "aerial", "fan", "inspect", "twirl", "jab", "rollover"]
const TRICK_DUR := {"fan": 1.6, "rollover": 1.1, "aerial": 1.3, "inspect": 1.7, "twirl": 1.0, "jab": 0.6}
const PIN_Z := -0.03            # pivot pin, knife space
const BLADE_LEN := 0.27
const HANDLE_LEN := 0.15

var player: Node
var arm: Node3D
var hand: Node3D
var knife: Node3D
var blade_pivot: Node3D
var bite_pivot: Node3D
var blade_mat: ShaderMaterial
var tip_marker: Marker3D       # the point of the knife (guts get dragged out on it)
var mode := "idle"            # idle, slash, gut
var trick := ""
var trick_t := 0.0
var wait_t := 2.0
var slash_t := 0.0
var gut_phase := ""
var gut_k := 0.0
var gut_aim := Vector3(0, 0, -0.6)   # cut position in camera space
var blood := 0.0              # how bloody the blade is (fades)
var _sounds := {}


func _ready() -> void:
	scale = Vector3.ONE * VM_SCALE
	position = REST
	_build()


func _build() -> void:
	var sleeve := Mat.world("sleeve", {"origin": true})
	var cuff := Mat.world("sleeve", {"origin": true, "tint": Color(0.7, 0.72, 0.6)})
	var glove := Mat.make("glove", {"origin": true, "shade": 0.6, "gloss": 0.25})
	arm = Models.pivot()
	add_child(arm)
	# forearm: a tapered sleeve coming in from the bottom-left corner of the
	# screen to the wrist, a rolled cuff, and the glove's gauntlet
	var axis := Vector3(-0.45, -0.67, 0.6).normalized()
	var wrist := Vector3(0.0, -0.035, 0.05)
	arm.add_child(_along(Models.cyl(0.07, 0.052, 0.85, 9), sleeve, wrist, axis, 0.55))
	arm.add_child(_along(Models.cyl(0.07, 0.07, 0.07, 9), cuff, wrist, axis, 0.15))
	arm.add_child(_along(Models.cyl(0.065, 0.065, 0.025, 9), cuff, wrist, axis, 0.2))
	arm.add_child(_along(Models.cyl(0.052, 0.046, 0.1, 9), glove, wrist, axis, 0.05))
	hand = Models.pivot()
	arm.add_child(hand)
	# gloved fist wrapped round the handle: palm, four knuckles, curled
	# fingers underneath and the thumb laid along the top
	hand.add_child(Models.mi(Creatures.blob_mesh(0.048, Vector3(0.8, 0.9, 1.15), 6101, 0.03, 8, 12), glove, Vector3(0.0, -0.012, 0.035)))
	for i in 4:
		var z := -0.008 + i * 0.022
		hand.add_child(Models.mi(Models.sphere(0.016, 7, 5), glove, Vector3(-0.038, 0.016 - i * 0.003, z)))
		hand.add_child(Models.mi(Models.box(0.032, 0.022, 0.018), glove, Vector3(-0.018, -0.03, z), Vector3(0, 0, 25)))
		hand.add_child(Models.mi(Models.sphere(0.012, 6, 4), glove, Vector3(0.01, -0.026, z)))
	hand.add_child(Models.mi(Models.cyl(0.013, 0.016, 0.07, 7), glove, Vector3(0.025, 0.034, -0.002), Vector3(-80, 0, 0)))
	hand.add_child(Models.mi(Models.sphere(0.014, 7, 5), glove, Vector3(0.025, 0.038, -0.038)))
	_build_knife()


func _build_knife() -> void:
	knife = Models.pivot(Vector3(0, 0.005, -0.015))
	knife.scale = Vector3.ONE * KNIFE_SCALE
	hand.add_child(knife)
	var handle_m := Mat.make("bali_handle", {"origin": true, "shade": 0.6, "gloss": 0.7})
	var brass := Mat.world("gun_brass", {"origin": true})
	var eye_m := Mat.make("bali_eye", {"origin": true, "shade": 0.5, "gloss": 1.0, "fullbright": 0.2})
	# the safe handle, in the fist
	var hl := HANDLE_LEN
	knife.add_child(Models.mi(_handle_mesh(), handle_m, Vector3(0.011, 0, PIN_Z)))
	knife.add_child(Models.mi(Models.cyl(0.006, 0.006, 0.05, 6), brass, Vector3(0, 0, PIN_Z), Vector3(0, 0, 90)))
	# blade on the pin
	blade_pivot = Models.pivot(Vector3(0, 0, PIN_Z))
	knife.add_child(blade_pivot)
	blade_mat = Mat.make("bali_blade", {"origin": true, "shade": 0.6, "gloss": 1.0, "fullbright": 0.15})
	var blade := MeshInstance3D.new()
	blade.mesh = _blade_mesh()
	blade.material_override = blade_mat
	blade_pivot.add_child(blade)
	tip_marker = Marker3D.new()
	tip_marker.position = Vector3(0, 0, -BLADE_LEN * 0.85)
	blade_pivot.add_child(tip_marker)
	# the bite handle swings free on the same pin, with an eyeball for a latch
	bite_pivot = Models.pivot(Vector3(0, 0, PIN_Z))
	knife.add_child(bite_pivot)
	bite_pivot.add_child(Models.mi(_handle_mesh(), handle_m, Vector3(-0.011, 0, 0)))
	bite_pivot.add_child(Models.mi(Models.sphere(0.017, 8, 6), eye_m, Vector3(-0.011, 0.0, hl + 0.012), Vector3(0, 180, 0)))


## A cylinder laid along `axis`, its centre `offset` along it from `start`.
func _along(mesh: Mesh, mat: Material, start: Vector3, axis: Vector3, offset: float) -> MeshInstance3D:
	var y := axis.normalized()
	var x := y.cross(Vector3.FORWARD).normalized()
	var z := x.cross(y)
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.transform = Transform3D(Basis(x, y, z), start + y * offset)
	return m


## One balisong handle: a flat bar from the pin back along +Z.
func _handle_mesh() -> Mesh:
	var b := BoxMesh.new()
	b.size = Vector3(0.016, 0.03, HANDLE_LEN)
	var m := ArrayMesh.new()
	var arr := b.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in v.size():
		v[i].z += HANDLE_LEN * 0.5
	arr[Mesh.ARRAY_VERTEX] = v
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## The weird blade: a saw-toothed spine, a wavy edge and a hooked point.
func _blade_mesh() -> ArrayMesh:
	var L := BLADE_LEN
	var prof := PackedVector2Array()       # (z, y), counter-clockwise
	prof.append(Vector2(0.0, -0.016))
	# wavy cutting edge, out to the point
	for i in range(1, 9):
		var z := -L * 0.86 * i / 8.0
		prof.append(Vector2(z, -0.02 - 0.009 * sin(i * PI * 0.9)))
	prof.append(Vector2(-L * 0.95, -0.006))
	prof.append(Vector2(-L, 0.02))           # hooked point
	prof.append(Vector2(-L * 0.93, 0.034))
	prof.append(Vector2(-L * 0.84, 0.022))
	# saw teeth back along the spine
	for i in range(8, 0, -1):
		var z := -L * 0.8 * i / 8.0
		prof.append(Vector2(z + 0.008, 0.026))
		prof.append(Vector2(z, 0.016))
	prof.append(Vector2(0.0, 0.016))
	var tris := Geometry2D.triangulate_polygon(prof)
	if tris.is_empty():
		prof.reverse()
		tris = Geometry2D.triangulate_polygon(prof)
	var th := 0.005
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [1.0, -1.0]:
		for i in range(0, tris.size(), 3):
			var order := [0, 1, 2] if side > 0.0 else [0, 2, 1]
			for o in order:
				var q: Vector2 = prof[tris[i + o]]
				st.set_normal(Vector3(side, 0, 0))
				st.set_uv(Vector2(-q.x / L, clampf((q.y + 0.025) / 0.06, 0.0, 1.0)))
				st.add_vertex(Vector3(th * side, q.y, q.x))
	for i in prof.size():
		var a: Vector2 = prof[i]
		var b: Vector2 = prof[(i + 1) % prof.size()]
		var n := Vector3(0, b.x - a.x, -(b.y - a.y)).normalized()
		var quad := [Vector3(th, a.y, a.x), Vector3(-th, a.y, a.x), Vector3(th, b.y, b.x), Vector3(-th, b.y, b.x)]
		for q in [0, 2, 1, 1, 2, 3]:
			st.set_normal(n)
			st.set_uv(Vector2(-quad[q].z / L, 0.05))
			st.add_vertex(quad[q])
	return st.commit()


## Distance from the knife pivot to its point, in camera space.
func tip_length() -> float:
	return (BLADE_LEN - PIN_Z) * KNIFE_SCALE * VM_SCALE


## 0 = shut (blade folded back between the handles), 1 = open.
## swing: how far round the free handle has travelled (0..1 = one turn).
func _set_open(open_k: float, swing: float) -> void:
	blade_pivot.rotation = Vector3(PI * (1.0 - open_k), 0, 0)
	bite_pivot.rotation = Vector3(TAU * swing, 0, 0)


func _snd(sname: String, vol: float, pitch := 1.0) -> void:
	Audio.play(sname, vol, pitch * randf_range(0.95, 1.05))


func start_slash() -> void:
	mode = "slash"
	slash_t = 0.0
	trick = ""
	_snd("knife_swing", -4.0)


func _process(delta: float) -> void:
	if player == null:
		return
	blood = move_toward(blood, 0.0, delta * 0.06)
	blade_mat.set_shader_parameter("tint", Color(1, 1, 1).lerp(Color(0.55, 0.04, 0.05), clampf(blood, 0.0, 1.0)))
	visible = not player.dead
	var w = player.weapons
	var bob_x: float = sin(w._bob_t * 0.5 + PI) * 0.006 * w._bob_a
	var bob_y: float = absf(cos(w._bob_t * 0.5)) * 0.005 * w._bob_a
	var sway: Vector2 = w.sway_v
	var pos := REST + Vector3(bob_x - sway.x, -bob_y + sway.y, 0)
	var arm_rot := ARM_REST
	var hand_rot := HAND_REST
	var k_pos := Vector3.ZERO
	var k_rot := Vector3.ZERO
	var open_k := 1.0
	var swing := 0.0
	match mode:
		"slash":
			slash_t += delta
			var k := clampf(slash_t / 0.32, 0.0, 1.0)
			var s := sin(k * PI)
			var sweep := smoothstep(0.1, 0.6, k)
			pos += Vector3(lerpf(0.13, -0.03, sweep), lerpf(0.05, -0.02, sweep), -0.06 * s)
			arm_rot += Vector3(-0.15 * s, 0.25 * s, 0)
			hand_rot = HAND_REST.lerp(Vector3(0.0, -0.2, lerpf(-1.3, 0.9, sweep)), s)
			if slash_t >= 0.32:
				mode = "idle"
				wait_t = randf_range(1.0, 2.5)
		"gut":
			var r := _gut_pose()
			pos = r[0]
			arm_rot = r[1]
			hand_rot = r[2]
			k_rot = r[3]
		_:
			var r := _trick_pose(delta)
			pos += r[0]
			hand_rot += r[1]
			k_pos = r[2]
			k_rot = r[3]
			open_k = r[4]
			swing = r[5]
	position = pos
	arm.rotation = arm_rot
	hand.rotation = hand_rot
	# knife offsets are given in arm space (up is up on screen), undo the wrist turn
	knife.position = Vector3(0, 0.005, -0.015) + Basis.from_euler(hand_rot).inverse() * k_pos
	knife.rotation = k_rot
	_set_open(open_k, swing)


func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


## One flip of the butterfly knife over local time q (0..1): shut if it
## was open, open if it was shut. The free handle swings a full turn.
func _flip(q: float, opening: bool) -> Array:
	var e := _ease(clampf(q, 0.0, 1.0))
	return [e if opening else 1.0 - e, e]


## [arm position offset, wrist rotation offset, knife offset (arm space),
##  knife rotation, open amount, free-handle swing]
func _trick_pose(delta: float) -> Array:
	var ap := Vector3.ZERO
	var hr := Vector3.ZERO
	var kp := Vector3.ZERO
	var kr := Vector3.ZERO
	var open_k := 1.0
	var swing := 0.0
	var t := Time.get_ticks_msec() * 0.001
	# idle: slow, restless breathing and a thumb rolling the handle
	ap.y = sin(t * 1.3) * 0.004
	hr.z = sin(t * 0.7) * 0.05
	if trick == "":
		wait_t -= delta
		if wait_t <= 0.0:
			trick = TRICKS[randi() % TRICKS.size()]
			trick_t = 0.0
			_sounds = {}
		return [ap, hr, kp, kr, open_k, swing]
	trick_t += delta
	var dur: float = TRICK_DUR[trick]
	var k := clampf(trick_t / dur, 0.0, 1.0)
	var bump := sin(k * PI)
	match trick:
		"fan":
			# shut, open, shut, open: the handles whip round the pin and the
			# wrist rolls back and forth with each flip
			var n := 4
			var seg := minf(k * n, n - 0.001)
			var i := int(seg)
			var f := _flip(seg - i, i % 2 == 1)
			open_k = f[0]
			swing = f[1]
			hr.z += sin(seg * PI) * 0.7 * (1.0 if i % 2 == 0 else -1.0)
			hr.x -= 0.15 * bump
			for c in n:
				_cue((c + 0.15) / n, "knife_flip", -18.0, 1.4 + c * 0.05)
				_cue((c + 0.92) / n, "knife_catch", -13.0, 1.1 if c % 2 == 0 else 0.9)
		"rollover":
			# rolled over the knuckles around the handle, then snapped shut and open
			kr.z += TAU * _ease(clampf(k / 0.6, 0.0, 1.0))
			if k > 0.6:
				var q := (k - 0.6) / 0.4
				var f := _flip(clampf(q * 2.0, 0.0, 1.0), false) if q < 0.5 else _flip(q * 2.0 - 1.0, true)
				open_k = f[0]
				swing = f[1]
			_cue(0.05, "knife_flip", -17.0, 0.9)
			_cue(0.78, "knife_catch", -14.0, 1.1)
			_cue(0.98, "knife_catch", -13.0)
		"aerial":
			# shut, tossed, spins end over end, caught and flicked open
			var q := clampf((k - 0.2) / 0.55, 0.0, 1.0)
			if k < 0.2:
				var f := _flip(k / 0.2, false)
				open_k = f[0]
				swing = f[1]
			elif k < 0.75:
				open_k = 0.0
				kp += Vector3(0.03, 0.3, -0.12) * sin(q * PI)
				kr.x += TAU * 2.0 * q
			else:
				var f := _flip((k - 0.75) / 0.25, true)
				open_k = f[0]
				swing = f[1]
			hr.x -= 0.5 * (k / 0.2 if k < 0.2 else 0.0)
			ap.y -= 0.012 * bump
			_cue(0.18, "knife_catch", -14.0, 1.2)
			_cue(0.22, "knife_flip", -12.0)
			_cue(0.75, "knife_catch", -11.0, 0.9)
			_cue(0.98, "knife_catch", -12.0, 1.2)
		"twirl":
			# open, end over end around the fingers
			kr.x += TAU * 2.0 * _ease(k)
			hr.x -= 0.2 * bump
			_cue(0.05, "knife_flip", -15.0, 1.3)
			_cue(0.92, "knife_catch", -14.0)
		"inspect":
			# brought up to the face and turned so the oily blade catches the light
			ap += Vector3(0.035, 0.03, -0.015) * bump
			hr.y += 0.7 * bump
			hr.z += sin(k * TAU * 1.5) * 0.8 * bump
		"jab":
			# a quick stab at nothing
			var j := sin(clampf(k / 0.4, 0.0, 1.0) * PI) if k < 0.4 else 0.0
			ap += Vector3(0.04, 0.01, -0.08) * j
			hr += Vector3(-0.55, 0.45, 0) * j
			_cue(0.02, "knife_swing", -14.0, 1.2)
	if k >= 1.0:
		trick = ""
		wait_t = randf_range(1.2, 4.0)
	return [ap, hr, kp, kr, open_k, swing]


func _cue(at_k: float, sname: String, vol: float, pitch := 1.0) -> void:
	var dur: float = TRICK_DUR[trick]
	if trick_t / dur >= at_k and not _sounds.has(at_k):
		_sounds[at_k] = true
		_snd(sname, vol, pitch)


## Camera-space pose for each phase of the gutting finisher:
## [arm position, arm rotation, wrist rotation, knife rotation].
func _gut_pose() -> Array:
	var k := gut_k
	# the point sits 6 cm inside the cut; the hand comes in from below-left
	var dir := gut_aim.normalized()
	var stab_pos := gut_aim - dir * (tip_length() - 0.06) + Vector3(-0.015, -0.02, 0)
	var ready := Vector3(-0.07, -0.09, -0.24)
	var aim_hand := Vector3(0.0, 0.05, 0.0)       # wrist straight: knife points into the screen
	var pos := REST
	var ar := ARM_REST
	var hr := HAND_REST
	var kr := Vector3.ZERO
	match gut_phase:
		"approach":
			var e := _ease(k)
			pos = REST.lerp(ready + Vector3(0, 0, 0.04 * e), e)
			hr = HAND_REST.lerp(aim_hand + Vector3(0.25, 0, 0), e)
		"stab":
			var e := 1.0 - pow(1.0 - k, 3.0)
			pos = (ready + Vector3(0, 0, 0.04)).lerp(stab_pos, e)
			hr = (aim_hand + Vector3(0.25, 0, 0)).lerp(aim_hand, e)
		"slice":
			var sweep := _ease(k)
			pos = stab_pos + Vector3(lerpf(-0.07, 0.08, sweep), 0.01 * sin(k * PI), 0.008 * sin(k * TAU * 7.0))
			hr = aim_hand + Vector3(0, -0.15 * sweep, -0.2 + 0.35 * sweep)
		"rip":
			var e := _ease(k)
			pos = stab_pos + Vector3(0.08 - 0.05 * e, -0.03 * e, 0.025 * e) + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.003
			hr = aim_hand + Vector3(0.35 * e, -0.15, 0.15 - 1.2 * e)
		"yank":
			var e := 1.0 - pow(1.0 - k, 2.0)
			pos = (stab_pos + Vector3(0.03, -0.03, 0.025)).lerp(ready + Vector3(0.02, 0.03, 0.02), e)
			hr = (aim_hand + Vector3(0.35, -0.15, -1.05)).lerp(Vector3(-0.5, 0, -0.4), e)
		_:
			var e := _ease(k)
			pos = (ready + Vector3(0.02, 0.03, 0.02)).lerp(REST, e)
			hr = Vector3(-0.5, 0, -0.4).lerp(HAND_REST, e)
	return [pos, ar, hr, kr]
