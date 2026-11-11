class_name Offhand
extends Node3D
## The player's left arm and a butterfly knife that never sits still.
## Between fights it does real balisong tricks: fanning it open and shut,
## chaplins round the finger, zen rollovers across the knuckles, helixes,
## aerials, flipping it open straight into a stab. The Finisher drives it
## for slashes and for gutting.
##
## The arm is one straight yellow block like the gun hand, held well out to
## the left, and it follows the wrist with a little lag so every flick has
## some snap. The knife is all red-and-black checks.
##
## Rig: this node (camera space) > arm (the block) > hand (wrist) > knife
## (the held "safe" handle). The blade and the free "bite" handle hang off
## the pivot pin at the top of the safe handle and swing round it when the
## knife is flipped open or shut. Spins happen round the pin, like a real
## one turning on the index finger.

const REST := Vector3(-0.145, -0.092, -0.21)
const VM_SCALE := 0.36
const KNIFE_SCALE := 1.5
const ARM_REST := Vector3(0.1, 0.12, 0.0)
const HAND_REST := Vector3(0.55, -0.6, 0.3)     # blade up and angled in, side on to the camera
const TRICKS := ["fan", "chaplin", "zen", "helix", "aerial", "stab", "fan", "twirl", "chaplin", "zen", "inspect"]
const TRICK_DUR := {"fan": 1.5, "chaplin": 1.25, "zen": 1.4, "helix": 1.2, "aerial": 1.45, "stab": 1.0,
	"twirl": 1.0, "inspect": 1.7}
const PIN_Z := -0.03            # pivot pin, knife space
const BLADE_LEN := 0.25
const HANDLE_LEN := 0.16
const STEEL := Color(1, 1, 1)

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
var _pos_s := REST
var _arm_s := ARM_REST
var _hand_s := HAND_REST


func _ready() -> void:
	scale = Vector3.ONE * VM_SCALE
	position = REST
	_build()
	Collage.outline_viewmodel(self)


func _build() -> void:
	arm = Models.pivot()
	add_child(arm)
	# one straight block, one colour: the knife handle sits in its end the
	# way the pistol grip sits in the gun hand
	var axis := Vector3(-0.45, -0.67, 0.6).normalized()
	var block := BoxMesh.new()
	block.size = Vector3(0.085, 1.0, 0.1)
	arm.add_child(_along(block, Mat.world("glove", {"origin": true}), Vector3(0.0, -0.01, 0.02), axis, 0.48))
	hand = Models.pivot()
	arm.add_child(hand)
	_build_knife()


## A proper balisong, in blocks: two channel handles (side plates, a dark
## channel, an end spacer, a pivot collar), a latch on the bite handle, and
## a blade with a tang, a kicker, a swedge to a clipped point and a zen pin.
func _build_knife() -> void:
	knife = Models.pivot(Vector3(0, 0.005, -0.015))
	knife.scale = Vector3.ONE * KNIFE_SCALE
	hand.add_child(knife)
	var check := Mat.make("knife_checker", {"origin": true, "shade": 0.55, "gloss": 0.7})
	var dark := Mat.world("knife_checker", {"origin": true, "tint": Color(0.35, 0.3, 0.3)})
	# the safe handle, held
	_handle(knife, 0.0125, PIN_Z, check, dark, false)
	# blade on the pin
	blade_pivot = Models.pivot(Vector3(0, 0, PIN_Z))
	knife.add_child(blade_pivot)
	blade_mat = Mat.make("knife_checker", {"origin": true, "shade": 0.5, "gloss": 1.0, "fullbright": 0.1})
	var blade := MeshInstance3D.new()
	blade.mesh = _blade_mesh()
	blade.material_override = blade_mat
	blade_pivot.add_child(blade)
	blade_pivot.add_child(Models.mi(Models.cyl(0.004, 0.004, 0.03, 6), dark, Vector3(0, 0.004, -0.045), Vector3(0, 0, 90)))
	tip_marker = Marker3D.new()
	tip_marker.position = Vector3(0, 0.0, -BLADE_LEN * 0.88)
	blade_pivot.add_child(tip_marker)
	# the bite handle swings free on the same pin, with the latch on its end
	bite_pivot = Models.pivot(Vector3(0, 0, PIN_Z))
	knife.add_child(bite_pivot)
	_handle(bite_pivot, -0.0125, 0.0, check, dark, true)
	# the pivot pin through everything
	knife.add_child(Models.mi(Models.cyl(0.005, 0.005, 0.052, 8), dark, Vector3(0, 0, PIN_Z), Vector3(0, 0, 90)))


func _handle(parent: Node3D, x: float, z0: float, mat: Material, dark: Material, latch: bool) -> void:
	var L := HANDLE_LEN
	var side := signf(x)
	# outer and inner side plates, with the dark channel between
	parent.add_child(Models.mi(Models.box(0.006, 0.03, L), mat, Vector3(x + side * 0.0045, 0, z0 + L * 0.5)))
	parent.add_child(Models.mi(Models.box(0.004, 0.03, L * 0.9), mat, Vector3(x - side * 0.004, 0, z0 + L * 0.52)))
	parent.add_child(Models.mi(Models.box(0.005, 0.02, L * 0.86), dark, Vector3(x, 0, z0 + L * 0.53)))
	# end spacer and pivot collar
	parent.add_child(Models.mi(Models.box(0.016, 0.03, 0.012), mat, Vector3(x, 0, z0 + L - 0.006)))
	parent.add_child(Models.mi(Models.cyl(0.017, 0.017, 0.015, 8), mat, Vector3(x, 0, z0), Vector3(0, 0, 90)))
	if latch:
		parent.add_child(Models.mi(Models.box(0.004, 0.012, 0.05), dark, Vector3(x - side * 0.004, -0.017, z0 + L - 0.01), Vector3(-12, 0, 0)))


## A mesh laid along `axis` (its local Y), its centre `offset` along it from `start`.
func _along(mesh: Mesh, mat: Material, start: Vector3, axis: Vector3, offset: float) -> MeshInstance3D:
	var y := axis.normalized()
	var x := y.cross(Vector3.FORWARD).normalized()
	var z := x.cross(y)
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.transform = Transform3D(Basis(x, y, z), start + y * offset)
	return m


## Tang with a kicker, straight spine, a swedge down to a clipped point,
## and a belly sweeping back to the choil.
func _blade_mesh() -> ArrayMesh:
	var L := BLADE_LEN
	var prof := PackedVector2Array([
		Vector2(0.014, -0.012), Vector2(0.014, 0.012), Vector2(0.0, 0.016),        # tang
		Vector2(-L * 0.62, 0.016), Vector2(-L, 0.003),                             # spine, swedge, point
		Vector2(-L * 0.86, -0.011), Vector2(-L * 0.55, -0.017), Vector2(-0.03, -0.017),   # belly
		Vector2(-0.02, -0.011), Vector2(-0.008, -0.024), Vector2(0.004, -0.02)])   # choil, kicker
	var tris := Geometry2D.triangulate_polygon(prof)
	if tris.is_empty():
		prof.reverse()
		tris = Geometry2D.triangulate_polygon(prof)
	var th := 0.0028
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [1.0, -1.0]:
		for i in range(0, tris.size(), 3):
			var order := [0, 1, 2] if side > 0.0 else [0, 2, 1]
			for o in order:
				var q: Vector2 = prof[tris[i + o]]
				st.set_normal(Vector3(side, 0, 0))
				st.set_uv(Vector2(-q.x / L, (q.y + 0.024) / 0.04))
				# thinner along the edge than at the spine
				st.add_vertex(Vector3(th * side * (0.35 if q.y < -0.008 and q.x < -0.02 else 1.0), q.y, q.x))
	for i in prof.size():
		var a: Vector2 = prof[i]
		var b: Vector2 = prof[(i + 1) % prof.size()]
		var n := Vector3(0, b.x - a.x, -(b.y - a.y)).normalized()
		var quad := [Vector3(th, a.y, a.x), Vector3(-th, a.y, a.x), Vector3(th, b.y, b.x), Vector3(-th, b.y, b.x)]
		for q in [0, 2, 1, 1, 2, 3]:
			st.set_normal(n)
			st.set_uv(Vector2(-quad[q].z / L, 0.5))
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
	blade_mat.set_shader_parameter("tint", STEEL.lerp(Color(0.55, 0.04, 0.05), clampf(blood, 0.0, 1.0)))
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
	var smooth := true
	match mode:
		"slash":
			slash_t += delta
			var k := clampf(slash_t / 0.32, 0.0, 1.0)
			var s := sin(k * PI)
			var sweep := smoothstep(0.1, 0.6, k)
			pos += Vector3(lerpf(0.17, 0.0, sweep), lerpf(0.05, -0.02, sweep), -0.06 * s)
			arm_rot += Vector3(-0.15 * s, 0.25 * s, 0)
			hand_rot = HAND_REST.lerp(Vector3(0.0, -0.2, lerpf(-1.3, 0.9, sweep)), s)
			smooth = false
			if slash_t >= 0.32:
				mode = "idle"
				wait_t = randf_range(1.0, 2.5)
		"gut":
			var r := _gut_pose()
			pos = r[0]
			arm_rot = r[1]
			hand_rot = r[2]
			k_rot = r[3]
			smooth = false
		_:
			var r := _trick_pose(delta)
			pos += r[0]
			# the whole arm follows the wrist, so tricks move the arm too
			var hr: Vector3 = r[1]
			arm_rot = ARM_REST + Vector3(hr.x * 0.45, hr.y * 0.4, hr.z * 0.4)
			hand_rot = HAND_REST + hr * 0.7
			k_pos = r[2]
			k_rot = r[3]
			open_k = r[4]
			swing = r[5]
	if smooth:
		# the arm lags the wrist, the wrist lags the trick: follow-through
		_pos_s = _pos_s.lerp(pos, 1.0 - exp(-delta * 20.0))
		_arm_s = _arm_s.lerp(arm_rot, 1.0 - exp(-delta * 13.0))
		_hand_s = _hand_s.lerp(hand_rot, 1.0 - exp(-delta * 24.0))
	else:
		_pos_s = pos
		_arm_s = arm_rot
		_hand_s = hand_rot
	position = _pos_s
	arm.rotation = _arm_s
	hand.rotation = _hand_s
	# knife offsets are given in arm space (up is up on screen); spins turn
	# round the pivot pin, not the middle of the handle
	var kb := Basis.from_euler(k_rot)
	var pin := Vector3(0, 0, PIN_Z) * KNIFE_SCALE
	knife.position = Vector3(0, 0.005, -0.015) + Basis.from_euler(_hand_s).inverse() * k_pos + (pin - kb * pin)
	knife.rotation = k_rot
	_set_open(open_k, swing)


func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


## Fast out, soft landing: how a flicked knife moves.
func _snap(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)


## One flip of the butterfly knife over local time q (0..1): shut if it
## was open, open if it was shut. The free handle swings a full turn.
func _flip(q: float, opening: bool) -> Array:
	var e := _snap(q)
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
			# fanning: shut, open, shut, open, the wrist snapping the other way
			# each time and the arm lifting into every flick
			var n := 4
			var seg := minf(k * n, n - 0.001)
			var i := int(seg)
			var q := seg - i
			var f := _flip(q, i % 2 == 1)
			open_k = f[0]
			swing = f[1]
			var dir := 1.0 if i % 2 == 0 else -1.0
			hr.z += dir * (0.85 * sin(_snap(q) * PI))
			hr.x -= 0.25 * sin(q * PI)
			ap.y += 0.012 * sin(q * PI)
			for c in n:
				_cue((c + 0.08) / n, "knife_flip", -18.0, 1.4 + c * 0.05)
				_cue((c + 0.85) / n, "knife_catch", -12.0, 1.15 if c % 2 == 0 else 0.92)
		"chaplin":
			# the knife goes over the top of the index finger: a full turn
			# round the pin, the handles flopping open mid-spin and snapping
			# back together on the catch
			var q := _snap(clampf((k - 0.12) / 0.7, 0.0, 1.0))
			hr.x += 0.3 * clampf(k / 0.12, 0.0, 1.0) if k < 0.12 else 0.3 * (1.0 - q)
			kr.x -= TAU * q
			open_k = 1.0 - 0.55 * sin(q * PI)
			swing = 0.08 * sin(q * TAU)
			ap += Vector3(0.0, 0.015, -0.01) * sin(q * PI)
			if k > 0.82:
				ap.y -= 0.012 * sin((k - 0.82) / 0.18 * PI)
			_cue(0.12, "knife_flip", -14.0, 0.9)
			_cue(0.82, "knife_catch", -11.0, 1.0)
		"zen":
			# zen rollover: rolled across the back of the hand, closing on the
			# way over and opening as it comes back into the grip
			var q := _ease(clampf(k / 0.85, 0.0, 1.0))
			kr.z += TAU * q
			hr.z -= 0.7 * sin(q * PI)
			ap += Vector3(0.03 * sin(q * PI), 0.016 * sin(q * PI), 0.0)
			if q < 0.5:
				var f := _flip(q * 2.0, false)
				open_k = f[0]
				swing = f[1] * 0.5
			else:
				var f := _flip(q * 2.0 - 1.0, true)
				open_k = f[0]
				swing = 0.5 + f[1] * 0.5
			_cue(0.05, "knife_flip", -17.0, 0.85)
			_cue(0.45, "knife_catch", -15.0, 1.25)
			_cue(0.86, "knife_catch", -12.0, 1.0)
		"helix":
			# helix: the knife corkscrews round its own length while the free
			# handle loops the blade
			var q := _ease(k)
			kr.z += TAU * 2.0 * q
			swing = q
			open_k = 1.0 - 0.6 * sin(q * PI)
			hr.z += 0.45 * sin(q * TAU)
			hr.x -= 0.2 * bump
			_cue(0.05, "knife_flip", -16.0, 1.2)
			_cue(0.5, "knife_flip", -18.0, 1.4)
			_cue(0.95, "knife_catch", -12.0)
		"aerial":
			# shut, flicked up out of the hand, two turns end over end round
			# the pin, caught and snapped open
			var q := clampf((k - 0.2) / 0.52, 0.0, 1.0)
			if k < 0.2:
				var f := _flip(k / 0.2, false)
				open_k = f[0]
				swing = f[1]
				hr.x += 0.35 * k / 0.2
			elif k < 0.72:
				open_k = 0.0
				kp += Vector3(0.03, 0.34, -0.12) * sin(q * PI)
				kr.x -= TAU * 2.0 * q
				hr.x -= 0.5 * sin(q * PI)
			else:
				var f := _flip((k - 0.72) / 0.22, true)
				open_k = f[0]
				swing = f[1]
				ap.y -= 0.022 * sin(clampf((k - 0.72) / 0.28, 0.0, 1.0) * PI)
			_cue(0.18, "knife_catch", -14.0, 1.2)
			_cue(0.21, "knife_flip", -11.0)
			_cue(0.72, "knife_catch", -10.0, 0.9)
			_cue(0.92, "knife_catch", -12.0, 1.25)
		"stab":
			# shut, then flipped open so hard it carries straight into a stab
			if k < 0.2:
				var f := _flip(k / 0.2, false)
				open_k = f[0]
				swing = f[1]
			elif k < 0.42:
				var f := _flip((k - 0.2) / 0.22, true)
				open_k = f[0]
				swing = f[1]
				hr.z += 0.6 * sin((k - 0.2) / 0.22 * PI)
			var j := sin(clampf((k - 0.38) / 0.32, 0.0, 1.0) * PI) if k > 0.38 else 0.0
			ap += Vector3(0.05, 0.012, -0.1) * j
			hr += Vector3(-0.6, 0.5, 0.0) * j
			_cue(0.02, "knife_catch", -14.0, 1.1)
			_cue(0.22, "knife_flip", -14.0, 1.3)
			_cue(0.4, "knife_catch", -10.0, 0.95)
			_cue(0.45, "knife_swing", -12.0, 1.2)
		"twirl":
			# open, spun end over end round the pin between the fingers
			kr.x -= TAU * 2.0 * _ease(k)
			hr.x -= 0.25 * bump
			_cue(0.05, "knife_flip", -15.0, 1.3)
			_cue(0.92, "knife_catch", -13.0)
		"inspect":
			# brought up and turned so the edge catches the light
			ap += Vector3(0.05, 0.03, -0.015) * bump
			hr.y += 0.7 * bump
			hr.z += sin(k * TAU * 1.5) * 0.8 * bump
	if k >= 1.0:
		trick = ""
		wait_t = randf_range(1.0, 3.5)
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
