class_name Finisher
extends Node
## Knife work. Press MELEE (F) near a creature to gut it: the camera locks
## on, the knife goes in, slices across, rips the belly open and the guts
## spill out. Nothing can hurt the player while it happens. With nobody in
## reach, MELEE is a quick slash.

const REACH := 1.9                      # metres beyond the creature's radius
const PHASES := ["approach", "stab", "slice", "rip", "yank", "return"]
const DUR := {"approach": 0.3, "stab": 0.14, "slice": 0.85, "rip": 0.65, "yank": 0.28, "return": 0.4}
const SLASH_DMG := 34.0

var player: Node
var offhand: Offhand
var target: Node = null
var phase := ""
var t := 0.0
var available: Node = null              # creature currently in reach (for the HUD prompt)
var _scan_t := 0.0
var _stand := Vector3.ZERO
var _blood_t := 0.0
var _rope: GutRope
var _slash_cd := 0.0
var _slash_hit := false


func active() -> bool:
	return phase != ""


func _want_melee() -> bool:
	if player.autopilot:
		return player.autopilot.get("want_melee") == true
	return Input.is_action_just_pressed("melee")


func find_target() -> Node:
	var lvl: Node = player.level
	if lvl == null:
		return null
	var fwd: Vector3 = -player.camera.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var best: Node = null
	var bd := INF
	for e in lvl.enemies:
		if not is_instance_valid(e) or not e.can_be_gutted():
			continue
		var d: Vector3 = e.global_position - player.global_position
		if absf(d.y) > 1.3:
			continue
		d.y = 0.0
		var dist := d.length()
		if dist > float(e.radius) + REACH:
			continue
		if dist > 0.05 and fwd.dot(d / dist) < 0.4:
			continue
		if not lvl.has_los(player.eye_point(), e.center_point()):
			continue
		if dist < bd:
			bd = dist
			best = e
	return best


func _process(delta: float) -> void:
	if player == null or player.level == null:
		return
	if player.dead:
		if active():
			_abort()
		return
	_slash_cd -= delta
	if not active():
		_scan_t -= delta
		if _scan_t <= 0.0:
			_scan_t = 0.1
			available = find_target()
		if offhand.mode == "slash" and not _slash_hit and offhand.slash_t > 0.1:
			_slash_hit = true
			_slash_damage()
		if _want_melee() and _slash_cd <= 0.0:
			var e := find_target()
			if e:
				start(e)
			else:
				_slash_cd = 0.45
				_slash_hit = false
				offhand.start_slash()
		return
	if target == null or not is_instance_valid(target):
		_abort()
		return
	t += delta
	var dur: float = DUR[phase]
	while t >= dur:
		t -= dur
		var i := PHASES.find(phase) + 1
		if i >= PHASES.size():
			_end()
			return
		phase = PHASES[i]
		dur = DUR[phase]
		_enter(phase)
	var k := clampf(t / dur, 0.0, 1.0)
	_update(k, delta)


func start(e: Node) -> void:
	target = e
	available = null
	phase = "approach"
	t = 0.0
	player.gutting = true
	offhand.mode = "gut"
	offhand.trick = ""
	e.begin_gutted(player)
	var away: Vector3 = player.global_position - e.global_position
	away.y = 0.0
	if away.length() < 0.05:
		away = -player.camera.global_transform.basis.z
		away.y = 0.0
	_stand = e.global_position + away.normalized() * (float(e.radius) + 0.62)
	_enter("approach")


func _enter(p: String) -> void:
	var lvl: Node = player.level
	var cut: Vector3 = target.gut_point()
	var bc: Color = target.blood_color()
	var pitch := float(target.def.get("pitch", 1.0))
	match p:
		"approach":
			Audio.play("knife_swing", -6.0, 0.8)
			Audio.play_at(target.def["pain_snd"], target.center_point(), 0.0, pitch * 1.3)
		"stab":
			Audio.play("knife_stab", 2.0, randf_range(0.9, 1.05))
			Fx.blood(lvl, cut, bc, 16, 0.035)
			player.shake(0.3)
			player.flash_color = Color(0.7, 0.0, 0.0, 0.2)
			offhand.blood = 0.6
			Audio.play_at(target.def["pain_snd"], target.center_point(), 3.0, pitch * 1.45)
			player.world.hud.splatter(3)
		"slice":
			Audio.play("gut_slice", 1.0, randf_range(0.92, 1.05))
		"rip":
			Audio.play("gut_spill", 2.0, randf_range(0.9, 1.05))
			Audio.play_at(target.def["death"], target.center_point(), 2.0, pitch * 0.8)
			Fx.blood(lvl, cut, bc, 22, 0.04)
			player.shake(0.25)
			offhand.blood = 1.0
			_spill(cut, bc)
			player.world.hud.splatter(6)
		"yank":
			Audio.play("knife_pull", 0.0)
			# the knife comes out with a loop of gut snagged on it
			if _rope and is_instance_valid(_rope):
				_rope.anchor = offhand.tip_marker
			Fx.blood(lvl, cut + (player.eye_point() - cut).normalized() * 0.15, bc, 12, 0.035)
			player.world.hud.splatter(4)
		"return":
			var dir: Vector3 = (target.global_position - player.global_position).normalized()
			target.gut_finish(dir)
			if _rope and is_instance_valid(_rope):
				_rope.release()
			for k in 4:
				var off := Vector3(randf_range(-0.7, 0.7), 0, randf_range(-0.7, 0.7))
				var fp: Vector3 = target.global_position + off
				Fx.decal(lvl, Vector3(fp.x, lvl.floor_at(fp), fp.z), Vector3.UP, "splat", randf_range(0.8, 1.5), bc.darkened(0.2))


func _update(k: float, delta: float) -> void:
	target.gut_phase = phase
	target.gut_k = k
	offhand.gut_phase = phase
	offhand.gut_k = k
	var cut: Vector3 = target.gut_point()
	# body: step in close and crouch to the cut
	player.gut_move_to = _stand
	var want_drop := clampf(Player.EYE - (cut.y - player.global_position.y) - 0.15, 0.0, 1.1)
	player.gut_crouch = move_toward(player.gut_crouch, want_drop if phase != "return" else 0.0, delta * 2.5)
	# camera: lock on to the cut
	var cam_pos: Vector3 = player.head.global_position
	var to := cut - cam_pos
	var want_yaw := atan2(-to.x, -to.z)
	var want_pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var rate := 12.0 if phase == "approach" else 20.0
	if phase != "return":
		player.yaw = lerp_angle(player.yaw, want_yaw, clampf(delta * rate, 0.0, 1.0))
		player.pitch = lerpf(player.pitch, want_pitch, clampf(delta * rate, 0.0, 1.0))
	offhand.gut_aim = player.camera.to_local(cut)
	# blood keeps coming while the knife works
	_blood_t -= delta
	if phase in ["slice", "rip"] and _blood_t <= 0.0:
		_blood_t = 0.07
		var tip: Vector3 = offhand.knife.global_position + (-offhand.knife.global_transform.basis.z) * 0.08
		Fx.blood(player.level, tip.lerp(cut, 0.5), target.blood_color(), 4, 0.03)
		if randf() < 0.3:
			player.shake(0.06)


## Guts out: a rope of intestine pinned in the wound, and loose organs.
func _spill(cut: Vector3, bc: Color) -> void:
	var lvl: Node = player.level
	var gore_tint := Color(0.75, 0.95, 0.55) if target.def["model"] == "gorbino" else Color(1, 1, 1)
	var toward: Vector3 = (player.global_position - target.global_position)
	toward.y = 0.0
	toward = toward.normalized()
	_rope = GutRope.new()
	lvl.fx_root().add_child(_rope)
	_rope.setup(lvl, target._gut_wound, 22 if float(target.def.get("scale", 1.0)) > 1.0 else 16, toward, gore_tint)
	var omat := Mat.make("gore_organ", {"tint": gore_tint, "shade": 0.8, "gloss": 1.0, "origin": true})
	for k in 3:
		var g := Gib.new()
		var sz := randf_range(0.08, 0.15)
		g.add_child(Models.mi(Models.sphere(sz, 7, 5), omat, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, randf_range(0.6, 0.9), randf_range(1.0, 1.5))))
		lvl.fx_root().add_child(g)
		g.global_position = cut + toward * 0.1
		g.vel = toward * randf_range(1.0, 2.5) + Vector3(randf_range(-1, 1), randf_range(0.5, 2.0), randf_range(-1, 1))
		g.spin = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
		g.level = lvl
		g.add_to_group("gibs")


func _slash_damage() -> void:
	var lvl: Node = player.level
	var fwd: Vector3 = -player.camera.global_transform.basis.z
	for e in lvl.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: Vector3 = e.center_point() - player.eye_point()
		if d.length() > float(e.radius) + 2.0:
			continue
		if fwd.dot(d.normalized()) < 0.55:
			continue
		e.take_damage(SLASH_DMG, player, d.normalized(), "melee")
		Audio.play("knife_stab", -4.0, 1.3)
		offhand.blood = minf(offhand.blood + 0.3, 1.0)
		return


func _end() -> void:
	phase = ""
	target = null
	player.gutting = false
	player.gut_move_to = Vector3.INF
	offhand.mode = "idle"
	offhand.wait_t = randf_range(0.8, 1.5)
	_slash_cd = 0.3


func _abort() -> void:
	if target and is_instance_valid(target) and not target.dead:
		target.gut_finish(Vector3.FORWARD)
	if _rope and is_instance_valid(_rope):
		_rope.release()
	_end()
	player.gut_crouch = 0.0
