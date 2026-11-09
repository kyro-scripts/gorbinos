class_name Offhand
extends Node3D
## The player's left arm: a knife that never sits still. Between fights it
## twirls, tosses, flips and spins; the Finisher drives it for slashes and
## for gutting.
##
## Rig: this node (camera space) > arm (forearm, moves) > hand (wrist,
## twists) > knife (spins). The forearm hangs down and back from the wrist,
## so twisting the wrist never swings it across the screen.

const REST := Vector3(-0.09, -0.085, -0.2)
const VM_SCALE := 0.36
const KNIFE_SCALE := 1.5
const ARM_REST := Vector3(0.1, 0.12, 0.0)
const HAND_REST := Vector3(0.55, -0.6, 0.3)     # blade up and angled in, side on to the camera
const TRICKS := ["twirl", "toss", "butterfly", "palm_spin", "inspect", "jab", "twirl", "toss"]
const TRICK_DUR := {"twirl": 1.0, "toss": 1.2, "butterfly": 0.9, "palm_spin": 1.5, "inspect": 1.7, "jab": 0.6}
const BLADE_LEN := 0.27

var player: Node
var arm: Node3D
var hand: Node3D
var knife: Node3D
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
	var glove := Mat.world("glove", {"origin": true})
	var dark := Mat.world("gun_dark", {"origin": true})
	arm = Models.pivot()
	add_child(arm)
	# forearm: from just behind the wrist, down and back off the bottom of the screen
	arm.add_child(Models.mi(Models.box(0.095, 0.095, 0.8), sleeve, Vector3(0.02, -0.27, 0.36), Vector3(36, -6, 0)))
	arm.add_child(Models.mi(Models.box(0.104, 0.104, 0.04), sleeve, Vector3(0.006, -0.05, 0.05), Vector3(36, -6, 0)))
	hand = Models.pivot()
	arm.add_child(hand)
	hand.add_child(Models.mi(Models.box(0.085, 0.1, 0.11), glove, Vector3(0, -0.012, 0.025)))
	hand.add_child(Models.mi(Models.box(0.09, 0.045, 0.06), glove, Vector3(0, 0.012, -0.03), Vector3(18, 0, 0)))
	hand.add_child(Models.mi(Models.box(0.03, 0.032, 0.075), glove, Vector3(0.05, 0.024, -0.005), Vector3(0, -22, 0)))
	knife = Models.pivot(Vector3(0, 0.005, -0.015))
	knife.scale = Vector3.ONE * KNIFE_SCALE
	hand.add_child(knife)
	knife.add_child(Models.mi(Models.box(0.03, 0.038, 0.13), Mat.world("knife_handle", {"origin": true}), Vector3(0, 0, 0.035)))
	knife.add_child(Models.mi(Models.box(0.036, 0.044, 0.02), dark, Vector3(0, 0, 0.105)))
	knife.add_child(Models.mi(Models.box(0.075, 0.018, 0.018), dark, Vector3(0, 0, -0.04)))
	blade_mat = Mat.make("knife_blade", {"origin": true, "shade": 0.6, "gloss": 1.0, "fullbright": 0.2})
	var blade := MeshInstance3D.new()
	blade.mesh = _blade_mesh()
	blade.material_override = blade_mat
	blade.position = Vector3(0, 0, -0.05)
	knife.add_child(blade)
	tip_marker = Marker3D.new()
	tip_marker.position = Vector3(0, 0, -0.05 - BLADE_LEN * 0.85)
	knife.add_child(tip_marker)


## Flat blade with a spine, a curved belly and a point, along -Z.
func _blade_mesh() -> ArrayMesh:
	var L := BLADE_LEN
	var prof := [Vector2(0.0, -0.022), Vector2(0.0, 0.022), Vector2(-L * 0.72, 0.019), Vector2(-L, 0.004),
		Vector2(-L * 0.9, -0.012), Vector2(-L * 0.6, -0.022)]   # (z, y)
	var th := 0.006
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [1.0, -1.0]:
		for i in range(1, prof.size() - 1):
			var tri := [prof[0], prof[i], prof[i + 1]]
			if side < 0.0:
				tri = [prof[0], prof[i + 1], prof[i]]
			for p in tri:
				st.set_normal(Vector3(side, 0, 0))
				st.set_uv(Vector2(-p.x / L, (p.y + 0.022) / 0.044))
				st.add_vertex(Vector3(th * side * (0.4 if p.y < -0.01 else 1.0), p.y, p.x))
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
	return (BLADE_LEN + 0.05) * KNIFE_SCALE * VM_SCALE


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
	position = pos
	arm.rotation = arm_rot
	hand.rotation = hand_rot
	# knife offsets are given in arm space (up is up on screen), undo the wrist turn
	knife.position = Vector3(0, 0.005, -0.015) + Basis.from_euler(hand_rot).inverse() * k_pos
	knife.rotation = k_rot


func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


## [arm position offset, wrist rotation offset, knife offset (arm space), knife rotation]
func _trick_pose(delta: float) -> Array:
	var ap := Vector3.ZERO
	var hr := Vector3.ZERO
	var kp := Vector3.ZERO
	var kr := Vector3.ZERO
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
		return [ap, hr, kp, kr]
	trick_t += delta
	var dur: float = TRICK_DUR[trick]
	var k := clampf(trick_t / dur, 0.0, 1.0)
	var bump := sin(k * PI)
	match trick:
		"twirl":
			# end over end around the fingers
			kr.x += TAU * 2.0 * _ease(k)
			hr.x -= 0.2 * bump
			_cue(0.05, "knife_flip", -15.0, 1.3)
			_cue(0.92, "knife_catch", -14.0)
		"toss":
			# flicked up, spins twice in the air, caught
			var q := clampf((k - 0.15) / 0.68, 0.0, 1.0)
			if k > 0.15 and k < 0.83:
				kp += Vector3(0.03, 0.3, -0.12) * sin(q * PI)
				kr.x += TAU * 2.0 * q
			hr.x -= 0.5 * (k / 0.15 if k < 0.15 else 0.0)
			ap.y -= 0.012 * bump
			if k > 0.83:
				ap.y -= 0.018 * (1.0 - (k - 0.83) / 0.17)
			_cue(0.15, "knife_flip", -12.0)
			_cue(0.83, "knife_catch", -11.0)
		"butterfly":
			# spun around its own length, blade flashing
			kr.z += TAU * 2.0 * _ease(k)
			hr.z += 0.45 * sin(k * TAU * 2.0) * bump
			_cue(0.05, "knife_flip", -16.0, 1.5)
			_cue(0.5, "knife_catch", -18.0, 1.3)
			_cue(0.95, "knife_catch", -15.0)
		"palm_spin":
			# wrist rolls palm-up and the knife spins flat on it
			hr.z -= 1.0 * bump
			hr.x -= 0.4 * bump
			kp.y += 0.03 * bump
			kr.y += TAU * 3.0 * _ease(k)
			_cue(0.1, "knife_flip", -17.0, 0.8)
			_cue(0.9, "knife_catch", -15.0)
		"inspect":
			# brought up to the face and turned so the edge catches the light
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
		wait_t = randf_range(1.5, 5.0)
	return [ap, hr, kp, kr]


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
