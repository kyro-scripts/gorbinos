class_name Enemy
extends AnimatableBody3D
## Gorbinos and Snirbies. One script, data-driven variants.

const TYPES := {
	"green": {"model": "gorbino", "color": Color(0.12, 0.19, 0.06), "hp": 51, "speed": 5.4, "radius": 0.55, "height": 1.6,
		"attack": "proj", "proj": "green", "proj_speed": 19.5, "dmg": 10, "count": 1, "spread": 0.0, "cooldown": [1.12, 2.24],
		"windup": 0.40, "range": 45.0, "pain": 0.75, "sight": "gorb_sight", "pain_snd": "gorb_pain", "death": "gorb_death",
		"idle": "gorb_idle", "name": "GORBINO", "drop": ""},
	"yellow": {"model": "gorbino", "color": Color(0.62, 0.52, 0.06), "hp": 38, "speed": 5.9, "radius": 0.55, "height": 1.6,
		"attack": "hitscan", "dmg": 5, "count": 3, "spread": 0.07, "cooldown": [0.91, 1.82], "windup": 0.40, "range": 40.0,
		"pain": 0.8, "sight": "gorb_sight2", "pain_snd": "gorb_pain", "death": "gorb_death", "idle": "gorb_idle",
		"gun": true, "name": "YELLOW GORBINO", "drop": "bullets", "keep_range": 9.0},
	"red": {"model": "gorbino", "color": Color(0.55, 0.06, 0.05), "hp": 110, "speed": 9.7, "radius": 0.6, "height": 1.6,
		"attack": "melee", "dmg": 16, "cooldown": [0.42, 0.70], "windup": 0.20, "range": 1.9, "pain": 0.5,
		"sight": "gorb_attack", "pain_snd": "gorb_pain", "death": "gorb_death", "idle": "gorb_idle", "name": "RED GORBINO", "drop": ""},
	"blue": {"model": "gorbino", "color": Color(0.08, 0.16, 0.5), "hp": 221, "speed": 4.1, "radius": 0.62, "height": 1.7, "scale": 1.12,
		"attack": "proj", "proj": "ice", "proj_speed": 22.1, "dmg": 11, "count": 3, "spread": 0.18, "cooldown": [1.40, 2.38],
		"windup": 0.50, "range": 40.0, "pain": 0.35, "sight": "gorb_sight", "pain_snd": "gorb_pain", "death": "gorb_death",
		"idle": "gorb_idle", "name": "BLUE GORBINO", "drop": "shells", "pitch": 0.85},
	"purple": {"model": "gorbino", "color": Color(0.36, 0.08, 0.5), "hp": 144, "speed": 6.2, "radius": 0.55, "height": 1.6,
		"attack": "proj", "proj": "purple", "proj_speed": 14.3, "homing": 2.2, "dmg": 15, "count": 1, "spread": 0.0,
		"cooldown": [1.26, 2.10], "windup": 0.40, "range": 50.0, "pain": 0.55, "fly": true, "hover": 1.6,
		"sight": "gorb_sight2", "pain_snd": "gorb_pain", "death": "gorb_death", "idle": "gorb_idle", "name": "PURPLE GORBINO",
		"drop": "cells", "pitch": 1.25},
	"black": {"model": "gorbino", "color": Color(0.07, 0.07, 0.08), "hp": 638, "speed": 4.9, "radius": 0.9, "height": 2.5, "scale": 1.55,
		"attack": "proj", "proj": "fire", "proj_speed": 26.0, "dmg": 25, "splash": 55.0, "splash_r": 3.5, "count": 1, "spread": 0.0,
		"cooldown": [0.98, 1.82], "windup": 0.40, "range": 60.0, "pain": 0.2, "glow_eyes": true, "launcher": true,
		"sight": "gorb_big_sight", "pain_snd": "gorb_pain", "death": "gorb_big_death", "idle": "gorb_idle",
		"name": "BLACK GORBINO", "drop": "rockets_box", "pitch": 0.7, "burst": 2},
	"snirby": {"model": "snirby", "hp": 34, "speed": 9.5, "radius": 0.42, "height": 1.6,
		"attack": "mixed", "proj": "spit", "proj_speed": 23.4, "dmg": 7, "melee_dmg": 9, "count": 1, "spread": 0.0,
		"cooldown": [0.63, 1.40], "windup": 0.20, "range": 30.0, "pain": 0.9, "sight": "snirb_sight", "pain_snd": "snirb_pain",
		"death": "snirb_death", "idle": "snirb_sniff", "name": "SNIRBY", "drop": ""},
	"skysnirby": {"model": "snirby", "hp": 55, "speed": 8.1, "radius": 0.45, "height": 1.6, "fly": true, "hover": 2.4,
		"attack": "mixed", "proj": "spit", "proj_speed": 26.0, "dmg": 8, "melee_dmg": 10, "count": 2, "spread": 0.08,
		"cooldown": [0.77, 1.54], "windup": 0.30, "range": 35.0, "pain": 0.8, "sight": "snirb_sight", "pain_snd": "snirb_pain",
		"death": "snirb_death", "idle": "snirb_sniff", "name": "SKY SNIRBY", "drop": "", "tint": Color(0.85, 1.0, 0.95), "propeller": true},
	"snotling": {"model": "snotling", "hp": 22, "speed": 10.6, "radius": 0.34, "height": 1.0, "scale": 0.7,
		"attack": "mixed", "proj": "spit", "proj_speed": 21.0, "dmg": 5, "melee_dmg": 6, "count": 1, "spread": 0.0,
		"cooldown": [0.8, 1.6], "windup": 0.20, "range": 22.0, "pain": 1.0, "sight": "snirb_sight", "pain_snd": "snirb_pain",
		"death": "snirb_death", "idle": "snirb_sniff", "name": "SNOTLING", "drop": "", "pitch": 1.35, "color": Color(0.85, 0.45, 0.55)},
	"boss": {"model": "snirby", "hp": 4420, "speed": 4.6, "radius": 1.9, "height": 6.4, "scale": 4.2, "boss": true,
		"attack": "boss", "proj": "spit", "proj_speed": 24.7, "dmg": 12, "count": 1, "spread": 0.0, "cooldown": [0.70, 1.26],
		"windup": 0.50, "range": 90.0, "pain": 0.0, "sight": "boss_roar", "pain_snd": "snirb_pain", "death": "boss_death",
		"idle": "snirb_sniff", "name": "THE GREAT SNIRBY", "drop": "", "tint": Color(0.8, 0.85, 1.0), "glow": true, "pitch": 0.45},
}

var spawn_id := -1
var etype := "green"
var def: Dictionary
var level: Level
var model: Node3D
var parts: Dictionary
var hp := 60.0
var max_hp := 60.0
var dead := false
var alerted := false
var flying := false
var radius := 0.5
var height := 1.6
var state := "idle"         # idle, chase, windup, pain, dead
var state_t := 0.0
var attack_timer := 2.0
var los := false
var los_timer := 0.0
var look_timer := 0.0
var vel := Vector3.ZERO
var knock := Vector3.ZERO
var yv := 0.0
var yaw := 0.0
var anim_t := 0.0
var move_amount := 0.0
var strafe := 1.0
var strafe_t := 0.0
var blink_t := 2.0
var flash_t := 0.0
var idle_snd_t := 5.0
var death_t := 0.0
var gibbed := false
var death_kind := ""
var death_side := 1.0         # which way the body falls (away from the killing shot)
var _death_slide := Vector3.ZERO
var _pooled := false
var _crashed := false
var burst_left := 0
var boss_phase := 0
var summoned := false
var col_shape: CollisionShape3D
var gutted := false          # held by the player's knife: frozen, then dies
var burn_t := 0.0             # > 0: on fire, running about screaming
var _burn_src: Node = null
var _burn_tick := 0.0
var _burn_dir := Vector3.ZERO
var _burn_turn := 0.0
var _flames: Array = []
var charred := false
var gut_phase := ""          # set by the finisher: stab, slice, rip, yank
var gut_k := 0.0
var _gut_wound: Node3D
var _gut_base := Vector3.ONE
var _gut_rim: Node3D
var _gut_hole: Node3D
var _gut_bulge: Node3D
var _gut_flaps: Array = []
var _whisper_t := 6.0
var _twitch_t := 2.0
var _twitch := 0.0
var _skin_mat: ShaderMaterial
var hyper_face: HyperFace = null
var _fly_snd_t := 0.0


func setup(t: String, lvl: Level, pos: Vector3, p_yaw: float) -> void:
	etype = t
	def = TYPES[t]
	level = lvl
	max_hp = float(def["hp"])
	if def.get("boss", false):
		max_hp *= [0.6, 1.0, 1.2, 1.4][Game.difficulty]
	hp = max_hp
	radius = float(def["radius"])
	height = float(def["height"])
	flying = def.get("fly", false)
	yaw = p_yaw
	collision_layer = 4
	collision_mask = 0
	sync_to_physics = false
	col_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(height, radius * 2.0 + 0.01)
	col_shape.shape = cap
	col_shape.position = Vector3(0, height * 0.5, 0)
	add_child(col_shape)
	var sc := float(def.get("scale", 1.0))
	match def["model"]:
		"gorbino":
			model = Models.gorbino(def["color"], {"skin": etype, "gun": def.get("gun", false), "glow_eyes": def.get("glow_eyes", false), "launcher": def.get("launcher", false)})
		"snotling":
			model = Models.snotling({"tint": def.get("tint", Color(1, 1, 1))})
		_:
			model = Models.snirby({"tint": def.get("tint", Color(1, 1, 1)), "glow": def.get("glow", false), "fly": def.get("fly", false)})
	model.scale = Vector3.ONE * sc
	add_child(model)
	Collage.outline(model)
	parts = model.get_meta("parts")
	_skin_mat = parts.get("skin_mat")
	hyper_face = Hyper.decorate(self, model, hash(String(lvl.data.get("name", "")) + str(Vector3i(pos * 4.0)) + t))
	global_position = pos
	if flying:
		global_position.y = pos.y + float(def.get("hover", 1.5))
	rotation.y = yaw
	attack_timer = randf_range(1.0, 2.5)
	anim_t = randf() * 10.0
	blink_t = randf_range(1.0, 4.0)
	idle_snd_t = randf_range(4.0, 15.0)


func center_point() -> Vector3:
	return global_position + Vector3(0, height * 0.55, 0)


func eye_point() -> Vector3:
	return global_position + Vector3(0, height * 0.75, 0)


func alert() -> void:
	if alerted or dead:
		return
	alerted = true
	state = "chase"
	attack_timer = randf_range(0.6, 1.6) / Game.diff()["aggro"]
	var spoke := false
	if not def.get("boss", false) and randf() < 0.8:
		spoke = Audio.voice_line(center_point(), {"gorbino": 0.9, "snirby": 1.12}.get(def["model"], 1.35))
	if not spoke:
		Audio.play_at(def["sight"], center_point(), 2.0 if def.get("boss", false) else 0.0, float(def.get("pitch", 1.0)) * randf_range(0.92, 1.08))
	if def.get("boss", false) and level.world:
		level.world.boss_started(self)


func _player() -> Node:
	return level.player if level else null


func _physics_process(delta: float) -> void:
	if level == null:
		return
	anim_t += delta
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0 and _skin_mat:
			_skin_mat.set_shader_parameter("flash", 0.0)
	if dead:
		_animate_death(delta)
		return
	if gutted:
		_gut_animate(delta)
		return
	if burn_t > 0.0:
		_burning(delta)
		return
	var pl := _player()
	if pl == null or not is_instance_valid(pl):
		return
	var ppos: Vector3 = pl.global_position
	var to_p: Vector3 = ppos - global_position
	var dist := Vector2(to_p.x, to_p.z).length()
	var player_dead: bool = pl.dead
	state_t += delta
	if not alerted:
		look_timer -= delta
		if look_timer <= 0.0:
			look_timer = 0.15 + randf() * 0.1
			if not player_dead and dist < 70.0:
				var fwd := -global_transform.basis.z
				var facing := fwd.dot(Vector3(to_p.x, 0, to_p.z).normalized()) > -0.2
				if (facing or dist < 5.0) and level.has_los(eye_point(), pl.eye_point()):
					alert()
		idle_snd_t -= delta
		if idle_snd_t <= 0.0:
			idle_snd_t = randf_range(6.0, 16.0)
			if dist < 25.0:
				Audio.play_at(def["idle"], center_point(), -6.0, float(def.get("pitch", 1.0)))
		_move(Vector3.ZERO, delta)
		_animate(delta, ppos)
		return
	# --- alerted
	# keep whispering at the player while hunting them
	_whisper_t -= delta
	if _whisper_t <= 0.0:
		_whisper_t = randf_range(5.0, 11.0)
		if not player_dead and dist < 32.0 and not def.get("boss", false):
			Audio.voice_line(center_point(), {"gorbino": 0.9, "snirby": 1.12}.get(def["model"], 1.35))
	los_timer -= delta
	if los_timer <= 0.0:
		los_timer = 0.18 + randf() * 0.08
		los = not player_dead and level.has_los(eye_point(), pl.eye_point())
	var dspeed := float(def["speed"]) * float(Game.diff()["speed"])
	var want := Vector3.ZERO
	match state:
		"pain":
			if state_t > 0.28:
				state = "chase"
		"windup":
			_face(to_p, delta, 10.0)
			if state_t >= float(def["windup"]) / sqrt(float(Game.diff()["aggro"])):
				_do_attack(pl, dist)
				if burst_left > 0:
					burst_left -= 1
					state_t = float(def["windup"]) * 0.5
				else:
					state = "chase"
					var cd: Array = def["cooldown"]
					attack_timer = randf_range(cd[0], cd[1]) / float(Game.diff()["aggro"])
		"chase":
			attack_timer -= delta
			var atk: String = def["attack"]
			var rng := float(def["range"])
			var can_attack := los and not player_dead
			if atk == "melee":
				can_attack = can_attack and dist < rng
			elif atk == "mixed":
				can_attack = can_attack and dist < rng
			else:
				can_attack = can_attack and dist < rng
			if can_attack and (attack_timer <= 0.0 or (atk == "melee" and dist < rng and attack_timer < 0.4)):
				state = "windup"
				state_t = 0.0
				burst_left = int(def.get("burst", 1)) - 1
				if atk == "boss":
					boss_phase = (boss_phase + 1) % 4
				if atk == "melee" or (atk == "mixed" and dist < 2.2):
					Audio.play_at("gorb_attack" if def["model"] == "gorbino" else "snirb_pain", center_point(), -2.0, float(def.get("pitch", 1.0)) * 1.2)
			else:
				want = _chase_dir(pl, to_p, dist, los, delta) * dspeed
	if state == "chase" and want.length() > 0.1:
		_face(want, delta, 7.0)
	elif state == "chase" and los:
		_face(to_p, delta, 5.0)
	_move(want, delta)
	_animate(delta, ppos)
	if def.get("propeller", false):
		_fly_snd_t -= delta
		if _fly_snd_t <= 0.0 and dist < 20.0:
			_fly_snd_t = 1.0
			Audio.play_at("snirb_fly", global_position + Vector3(0, 1, 0), -10.0, randf_range(0.9, 1.1))


# ------------------------------------------------------------------ fire
## Set alight (by the flamethrower, or by a burning friend bumping into it).
func ignite(src: Node, dur := 4.0) -> void:
	if dead or gutted or def.get("boss", false):
		return
	if burn_t <= 0.0:
		Audio.play_at("flame_ignite", center_point(), 0.0, randf_range(0.9, 1.15))
		Audio.play_at(def["pain_snd"], center_point(), 3.0, float(def.get("pitch", 1.0)) * 1.4)
		_burn_turn = 0.0
		var sc := float(def.get("scale", 1.0))
		for k in 4:
			var f := Sprite3D.new()
			f.texture = Mat.tex("proj_fire")
			f.hframes = 2
			f.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			f.shaded = false
			f.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			f.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			f.pixel_size = 0.02 * sc
			f.position = Vector3(randf_range(-0.3, 0.3), height * randf_range(0.3, 0.9), randf_range(-0.3, 0.3)) * sc
			add_child(f)
			_flames.append(f)
	burn_t = maxf(burn_t, dur)
	_burn_src = src
	alerted = true


static var _char_mat: Material


func _char_model() -> void:
	if _char_mat == null:
		_char_mat = Mat.make("black", {"origin": true, "tint": Color(0.2, 0.13, 0.1), "shade": 0.8, "gloss": 0.25})
	_char_rec(model)
	if hyper_face:
		hyper_face.burn()


func _char_rec(n: Node) -> void:
	if n.has_meta("hyper"):
		return
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = _char_mat
	for c in n.get_children():
		_char_rec(c)


func _put_out() -> void:
	burn_t = 0.0
	for f in _flames:
		if is_instance_valid(f):
			f.queue_free()
	_flames.clear()


## On fire: forget the player, run about screaming, set others alight.
func _burning(delta: float) -> void:
	burn_t -= delta
	_burn_tick -= delta
	var sc := float(def.get("scale", 1.0))
	if _burn_tick <= 0.0:
		_burn_tick = 0.25
		Audio.play_at("burn_sizzle", center_point(), -6.0, randf_range(0.8, 1.2))
		if randf() < 0.35:
			Audio.play_at(def["pain_snd"], center_point(), 2.0, float(def.get("pitch", 1.0)) * randf_range(1.3, 1.6))
		Fx.smoke(level, center_point() + Vector3(0, height * 0.4 * sc, 0))
		# it spreads to anyone close
		for e in level.enemies:
			if e != self and is_instance_valid(e) and not e.dead and e.burn_t <= 0.0 \
					and e.global_position.distance_to(global_position) < radius + float(e.radius) + 0.5:
				e.ignite(_burn_src, 3.0)
		take_damage(4.0, _burn_src, Vector3.ZERO, "fire")
		if dead:
			return
	# flames lick and flicker
	for f in _flames:
		if is_instance_valid(f):
			f.frame = (int(anim_t * 12.0) + f.get_index()) % 2
			f.scale = Vector3.ONE * (0.8 + 0.4 * absf(sin(anim_t * 9.0 + f.get_index())))
	# run about in a blind panic
	_burn_turn -= delta
	if _burn_turn <= 0.0:
		_burn_turn = randf_range(0.35, 0.8)
		var a := randf() * TAU
		_burn_dir = Vector3(cos(a), 0, sin(a))
	var spd := float(def["speed"]) * 1.25
	var np := global_position + _burn_dir * spd * delta
	if flying or not level.circle_blocked(np, radius, global_position.y, false, height):
		if not flying:
			np.y = level.floor_at(np)
		global_position = np
	else:
		_burn_turn = 0.0
	_face(_burn_dir, delta, 10.0)
	move_amount = 1.0
	Creatures.animate(model, anim_t * 2.2, delta, {"move": 1.0, "pain": fmod(anim_t, 0.5) < 0.25, "windup": fmod(anim_t, 0.5) >= 0.25})
	if burn_t <= 0.0:
		_put_out()
		state = "chase"


func _chase_dir(pl: Node, to_p: Vector3, dist: float, has_los: bool, delta: float) -> Vector3:
	var flat := Vector3(to_p.x, 0, to_p.z)
	var atk: String = def["attack"]
	strafe_t -= delta
	if strafe_t <= 0.0:
		strafe_t = randf_range(0.8, 2.2)
		strafe = -strafe if randf() < 0.6 else strafe
	if dist < radius + 0.7 and atk in ["melee", "mixed"]:
		return Vector3.ZERO
	if has_los and dist < 30.0:
		var dir := flat.normalized()
		var side := Vector3(-dir.z, 0, dir.x) * strafe
		var keep := float(def.get("keep_range", 0.0))
		if atk == "melee" or atk == "mixed" and dist < 7.0:
			return (dir + side * 0.25).normalized()
		if def.get("boss", false):
			return (dir * (1.0 if dist > 12.0 else -0.3) + side * 0.6).normalized()
		if keep > 0.0 and dist < keep:
			return (-dir * 0.6 + side).normalized()
		if dist < 5.0:
			return side
		return (dir * 0.6 + side * 0.7).normalized()
	# path along the flow field
	var wp := level.flow_step(global_position, flying)
	var d := Vector3(wp.x - global_position.x, 0, wp.z - global_position.z)
	if d.length() < 0.05:
		if has_los:
			return flat.normalized()
		return Vector3.ZERO
	# open doors on the way
	var ci := level.idx_of(level.cell_of(wp))
	if level.movers.has(ci):
		var m: Mover = level.movers[ci]
		if m.kind == "door" and m.state == 0 and m.can_monster_open() and d.length() < Level.S * 1.2:
			m.trigger()
	return d.normalized()


func _face(dir: Vector3, delta: float, rate: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	var target := atan2(-dir.x, -dir.z)
	yaw = lerp_angle(yaw, target, clampf(rate * delta, 0.0, 1.0))
	rotation.y = yaw


func _move(want: Vector3, delta: float) -> void:
	vel = vel.lerp(want, clampf(10.0 * delta, 0.0, 1.0))
	knock = knock.lerp(Vector3.ZERO, clampf(6.0 * delta, 0.0, 1.0))
	var motion := (vel + Vector3(knock.x, 0, knock.z)) * delta
	# separation from other enemies
	for o in level.enemies:
		if o == self or not is_instance_valid(o) or o.dead:
			continue
		var dd: Vector3 = global_position - o.global_position
		dd.y = 0
		var min_d: float = radius + o.radius
		var l := dd.length()
		if l < min_d and l > 0.001:
			motion += dd / l * (min_d - l) * 0.5
	# keep out of the player
	var pl := _player()
	if pl and is_instance_valid(pl):
		var dp: Vector3 = global_position + motion - pl.global_position
		dp.y = 0
		var md: float = radius + 0.45
		if dp.length() < md and dp.length() > 0.001 and abs(pl.global_position.y - global_position.y) < height:
			motion += dp.normalized() * (md - dp.length())
	var p := global_position
	var cur_floor := level.floor_at(p) if not flying else p.y
	if not flying:
		cur_floor = minf(level.support_floor(p, radius, p.y), p.y + Level.STEP_ENEMY)
	var nx := Vector3(p.x + motion.x, p.y, p.z)
	if not level.circle_blocked(nx, radius, p.y if not flying else cur_floor, flying, height):
		p.x = nx.x
	else:
		vel.x = 0
		knock.x = 0
	var nz := Vector3(p.x, p.y, p.z + motion.z)
	if not level.circle_blocked(nz, radius, p.y if not flying else cur_floor, flying, height):
		p.z = nz.z
	else:
		vel.z = 0
		knock.z = 0
	move_amount = clampf(Vector2(vel.x, vel.z).length() / maxf(float(def["speed"]), 0.1), 0.0, 1.0)
	if flying:
		var fl := level.floor_at(p)
		var cl := level.ceil_at(p)
		var target := fl + float(def.get("hover", 1.5))
		if pl and is_instance_valid(pl) and alerted:
			target = pl.global_position.y + float(def.get("hover", 1.5)) * 0.7 + sin(anim_t * 1.3) * 0.4
		target = clampf(target, fl + 0.3, cl - height - 0.1)
		p.y = lerpf(p.y, target, clampf(2.0 * delta, 0.0, 1.0))
	else:
		var target := level.support_floor(p, radius, p.y)
		if p.y > target + 0.01:
			yv -= 22.0 * delta
			p.y += yv * delta
			if p.y <= target:
				p.y = target
				yv = 0.0
		else:
			p.y = lerpf(p.y, target, clampf(18.0 * delta, 0.0, 1.0)) if target - p.y < 0.9 else target
			yv = 0.0
	global_position = p


# ------------------------------------------------------------------ sounds
## Every enemy shot (guns, spit, projectiles) uses the player-supplied
## enemy_shot sound when it exists, otherwise the built-in one.
func _shot_sound(fallback: String, pos: Vector3, vol := 0.0, pitch := 1.0) -> void:
	if Audio.get_sound("enemy_shot") != null:
		Audio.play_at("enemy_shot", pos, vol, pitch * randf_range(0.94, 1.06))
	else:
		Audio.play_at(fallback, pos, vol, pitch)


# ------------------------------------------------------------------ gutting
func can_be_gutted() -> bool:
	return not dead and not gutted and not flying and not def.get("boss", false)


## The player's knife goes in: freeze, face the player and open a wound.
func begin_gutted(pl: Node) -> void:
	_put_out()
	gutted = true
	state = "gutted"
	alerted = true
	vel = Vector3.ZERO
	knock = Vector3.ZERO
	var to_p: Vector3 = pl.global_position - global_position
	yaw = atan2(-to_p.x, -to_p.z)
	rotation.y = yaw
	_open_wound()
	_set_wound(0.0, 0.0, 0.0)


## Build the cut on the belly (scaled to nothing until _set_wound opens it).
func _open_wound() -> void:
	var a: Array = Creatures.gut_anchor(model)
	var pivot: Node3D = a[0]
	_gut_base = Vector3(a[2], a[2] * 0.5, 0.06)
	_gut_wound = Models.pivot(a[1], Vector3(rad_to_deg(a[3]), 0, 0))
	pivot.add_child(_gut_wound)
	# the cut: a wet rim round a dark hole, a lump of gut pushing out of it,
	# and two flaps of skin (raw on the inside) that peel back when it's ripped
	_gut_hole = Models.mi(Creatures.face_mesh(), Mat.make("white", {"origin": true, "tint": Color(0.12, 0.0, 0.02), "shade": 0.3, "gloss": 0.8}))
	_gut_wound.add_child(_gut_hole)
	_gut_rim = Models.mi(Creatures.face_mesh(), Mat.make("gore_wound", {"origin": true, "shade": 0.3, "gloss": 1.0, "fullbright": 0.2}))
	_gut_wound.add_child(_gut_rim)
	_gut_bulge = Models.mi(Creatures.blob_mesh(0.5, Vector3(1.4, 0.8, 0.7), 8101, 0.15, 8, 10), Mat.make("gore_guts", {"origin": true, "shade": 0.7, "gloss": 1.0}))
	_gut_wound.add_child(_gut_bulge)
	var skin_col: Color = def.get("color", Color(0.0, 0.5, 0.78)) if def["model"] != "snotling" else Color(0.85, 0.45, 0.55)
	var skin_m := Mat.make("white", {"origin": true, "tint": skin_col, "shade": 0.8, "gloss": 0.8})
	var raw_m := Mat.make("gore_organ", {"origin": true, "shade": 0.6, "gloss": 1.0})
	_gut_flaps.clear()
	for sy in [1.0, -1.0]:
		var hinge := Models.pivot()
		_gut_wound.add_child(hinge)
		hinge.add_child(Models.mi(Creatures.blob_mesh(0.5, Vector3(1.0, 0.18, 0.12), 8111, 0.1, 6, 10), skin_m, Vector3(0, -sy * 0.09, -0.02)))
		hinge.add_child(Models.mi(Creatures.blob_mesh(0.5, Vector3(0.95, 0.15, 0.08), 8112, 0.1, 6, 10), raw_m, Vector3(0, -sy * 0.09, 0.0)))
		hinge.set_meta("side", sy)
		_gut_flaps.append(hinge)


## Shape the cut: w width and h height as fractions of its full size,
## peel how far the flaps have been pulled back.
func _set_wound(w: float, h: float, peel: float) -> void:
	var W := _gut_base.x
	var bw := maxf(W * w, 0.001)
	var bh := maxf(W * 0.5 * h, 0.001)
	_gut_rim.scale = Vector3(bw, bh, 0.06 * (0.4 + h))
	_gut_hole.scale = Vector3(bw * 0.92, bh * 0.85, 0.02 + 0.06 * h)
	_gut_hole.position = Vector3(0, 0, 0.01)
	_gut_bulge.scale = Vector3(bw * 0.7, bh * 0.75, 0.04 + 0.16 * peel) * (0.5 + 0.5 * peel)
	_gut_bulge.position = Vector3(0, -bh * 0.1, -0.02 - 0.05 * peel)
	for f in _gut_flaps:
		var sy: float = f.get_meta("side")
		f.position = Vector3(0, sy * bh * 0.5, -0.01)
		f.scale = Vector3(bw, 1.0, 1.0) * Vector3(1.0, 0.4 + 0.6 * h, 1.0)
		f.rotation = Vector3(-sy * peel * 1.25, 0, 0)


## World position of the cut (where the knife goes).
func gut_point() -> Vector3:
	if _gut_wound and is_instance_valid(_gut_wound):
		return _gut_wound.global_position
	return center_point()


func blood_color() -> Color:
	return Color(0.15, 0.3, 0.05) if def["model"] == "gorbino" else Color(0.7, 0.04, 0.1)


func _gut_animate(delta: float) -> void:
	anim_t += delta
	var k := gut_k
	var w := 0.0
	var h := 0.0
	var peel := 0.0
	var shake := 0.0
	var jolt := 0.0
	match gut_phase:
		"stab":
			w = 0.18 * k
			h = 0.12 * k
			shake = 0.06
			jolt = 1.0 - k
		"slice":
			w = 0.18 + 0.82 * k
			h = 0.12 + 0.12 * k
			peel = 0.1 * k
			shake = 0.035 + 0.02 * absf(sin(anim_t * 40.0))
		"rip":
			w = 1.0 + 0.15 * k
			h = 0.24 + 0.76 * k
			peel = 0.1 + 0.9 * k
			shake = 0.05
		"whipped", "", "approach":
			# on the end of the whip, or about to be cut: no wound yet, flailing
			w = 0.0
			h = 0.0
			peel = 0.0
			shake = 0.06 if gut_phase == "whipped" else 0.02
		_:
			w = 1.15
			h = 1.0
			peel = 1.0
			shake = 0.02
	if _gut_wound:
		_set_wound(w, h, peel)
	var sc := float(def.get("scale", 1.0))
	model.position = (Vector3(randf_range(-1, 1), randf_range(-0.3, 0.5), randf_range(-1, 1)) * shake + Vector3(0, 0.02, 0.09) * jolt) * sc
	Creatures.animate(model, anim_t * 2.5, delta, {"pain": gut_phase != "stab" or k > 0.5, "windup": gut_phase == "stab" or gut_phase == "rip", "move": 0.0})
	var body: Node3D = parts["body"]
	if gut_phase == "rip":
		body.rotation.x = lerpf(0.0, 0.35, k)
	elif gut_phase in ["yank", "return"]:
		body.rotation.x = 0.35
	# a Snirby throws its beak up and screams
	if parts.has("beak"):
		parts["beak"].rotation.x = 1.15 + sin(anim_t * 31.0) * 0.06


## The finisher ends: the creature dies where it stands, opened up.
func gut_finish(dir: Vector3) -> void:
	if dead:
		return
	model.position = Vector3.ZERO
	hp = 0.0
	_die(0.0, "gut", dir)


# ------------------------------------------------------------------ attacks
func _muzzle_point() -> Vector3:
	var sc := float(def.get("scale", 1.0))
	var fwd := -global_transform.basis.z
	if def.get("launcher", false):
		return global_position + Vector3(0, 1.2 * sc, 0) + global_transform.basis.x * 0.5 * sc + fwd * 0.6 * sc
	if def["model"] == "snirby":
		# the tip of the beak
		return global_position + Vector3(0, 0.62 * sc, 0) + fwd * 0.9 * sc
	if def["model"] == "snotling":
		return global_position + Vector3(0, 0.5 * sc, 0) + fwd * 0.5 * sc
	return global_position + Vector3(0, 0.75 * sc, 0) + fwd * 0.6 * sc


func _do_attack(pl: Node, dist: float) -> void:
	var atk: String = def["attack"]
	var target: Vector3 = pl.center_point()
	var mp := _muzzle_point()
	var dm := float(Game.diff()["dmg"])
	match atk:
		"melee":
			if dist < float(def["range"]) + 0.4 and abs(pl.global_position.y - global_position.y) < 1.8:
				pl.take_damage(float(def["dmg"]), self, (target - global_position).normalized(), "melee")
				Audio.play_at("gorb_bite", center_point(), 0.0, randf_range(0.9, 1.1))
			else:
				Audio.play_at("gorb_bite", center_point(), -6.0, 0.8)
		"hitscan":
			_shot_sound("enemy_gun", mp, 0.0, randf_range(0.9, 1.05))
			Fx.light(level, mp, Color(1, 0.8, 0.3), 6.0, 1.2, 0.08)
			for k in int(def["count"]):
				var dir := (target - mp).normalized()
				dir = (dir + Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)) * float(def["spread"])).normalized()
				var hit := level.ray(mp, mp + dir * 80.0, 1 | 2 | 8 | 32, [get_rid()])
				if hit.is_empty():
					continue
				if hit["collider"] == pl:
					pl.take_damage(float(def["dmg"]), self, dir, "bullet")
				elif hit["collider"].has_method("take_damage"):
					hit["collider"].take_damage(float(def["dmg"]), self, dir, "bullet")
				else:
					Fx.puff(level, hit["position"], hit["normal"])
		"proj":
			_fire_proj(mp, target, pl)
		"mixed":
			if dist < 2.3:
				pl.take_damage(float(def["melee_dmg"]), self, (target - global_position).normalized(), "melee")
				Audio.play_at("gorb_bite", center_point(), -2.0, 1.5)
			else:
				_fire_proj(mp, target, pl)
		"boss":
			_boss_attack(pl, mp, target)


func _fire_proj(mp: Vector3, target: Vector3, pl: Node) -> void:
	var n := int(def.get("count", 1))
	var spread := float(def.get("spread", 0.0))
	var spd := float(def["proj_speed"]) * (1.0 + (float(Game.diff()["aggro"]) - 1.0) * 0.3)
	# light leading of the target
	var lead: Vector3 = pl.velocity * (mp.distance_to(target) / spd) * 0.35 if "velocity" in pl else Vector3.ZERO
	var aim := (target + lead - mp).normalized()
	_shot_sound("proj_launch" if def["model"] == "gorbino" else "snirb_spit", mp, 0.0, float(def.get("pitch", 1.0)))
	for k in n:
		var off := 0.0 if n == 1 else (float(k) / (n - 1) - 0.5) * 2.0 * spread
		var dir := aim.rotated(Vector3.UP, off)
		var p := Projectile.new()
		level.fx_root().add_child(p)
		p.launch(level, self, mp, dir * spd, String(def["proj"]), float(def["dmg"]), false)
		p.splash = float(def.get("splash", 0.0))
		p.splash_r = float(def.get("splash_r", 0.0))
		if def.has("homing"):
			p.homing = float(def["homing"])
			p.target = pl


func _boss_attack(pl: Node, mp: Vector3, target: Vector3) -> void:
	var low_hp := hp < max_hp * 0.4
	match boss_phase:
		0:
			# spit fan
			var n := 9 if low_hp else 7
			for k in n:
				var off := (float(k) / (n - 1) - 0.5) * 1.1
				var p := Projectile.new()
				level.fx_root().add_child(p)
				p.launch(level, self, mp, (target - mp).normalized().rotated(Vector3.UP, off) * 18.0, "spit", 12.0, false)
			_shot_sound("snirb_spit", mp, 4.0, 0.5)
		1:
			# summon snirbies
			Audio.play_at("boss_roar", center_point(), 4.0, 0.6)
			var alive := 0
			for e in level.enemies:
				if is_instance_valid(e) and not e.dead and e.summoned:
					alive += 1
			var want := 3 if low_hp else 2
			for k in mini(want, 6 - alive):
				var a := randf() * TAU
				var sp := global_position + Vector3(cos(a), 0, sin(a)) * (radius + 2.0)
				var ci := level.idx_of(level.cell_of(sp))
				if ci < 0 or level.solid[ci] == 1:
					continue
				var en := Enemy.new()
				level.entity_root().add_child(en)
				en.setup(["snirby", "skysnirby", "snotling"][k % 3], level, Vector3(sp.x, level.floor_h[ci], sp.z), a)
				en.summoned = true
				level.enemies.append(en)
				en.alert()
				Fx.telefog(level, sp + Vector3(0, 1, 0))
		2:
			# homing barrage
			for k in (5 if low_hp else 3):
				var p := Projectile.new()
				level.fx_root().add_child(p)
				var dir := (target - mp).normalized().rotated(Vector3.UP, randf_range(-0.8, 0.8)) + Vector3(0, 0.5, 0)
				p.launch(level, self, mp, dir.normalized() * 10.0, "purple", 16.0, false)
				p.homing = 2.5
				p.target = pl
			_shot_sound("proj_launch", mp, 4.0, 0.5)
		3:
			# fire rain: big fireballs with splash
			for k in 3:
				var p := Projectile.new()
				level.fx_root().add_child(p)
				var t2 := target + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
				p.launch(level, self, mp, (t2 - mp).normalized() * 16.0, "fire", 20.0, false)
				p.splash = 40.0
				p.splash_r = 3.0
			_shot_sound("rocket_fire", mp, 2.0, 0.6)


# ------------------------------------------------------------------ damage
func take_damage(amount: float, source: Node, dir: Vector3, kind := "bullet") -> void:
	if dead or gutted:
		return
	hp -= amount
	flash_t = 0.07
	if _skin_mat:
		_skin_mat.set_shader_parameter("flash", 0.7)
	var kb := amount * (0.06 if kind != "explosion" else 0.12) / sqrt(max_hp / 60.0)
	if not def.get("boss", false):
		knock += Vector3(dir.x, 0, dir.z) * minf(kb, 9.0)
	var bc := blood_color()
	Fx.blood(level, center_point() - dir * 0.2, bc, clampi(int(amount / 6.0), 2, 10))
	if not alerted:
		alert()
	if source != null and level.player != null and source == level.player and level.world:
		level.world.hud.hit_marker(hp <= 0.0)
		if hp <= 0.0:
			# a beat of hit-stop on the kill
			level.world.hitstop(0.04)
			level.player.on_kill(self)
			if level.world.endless:
				level.world.endless.on_kill()
	if hp <= 0.0:
		_die(amount, kind, dir)
		return
	if state != "windup" or randf() < 0.3:
		if randf() < float(def["pain"]):
			state = "pain"
			state_t = 0.0
			Audio.play_at(def["pain_snd"], center_point(), -2.0, float(def.get("pitch", 1.0)) * randf_range(0.9, 1.15))


func _die(amount: float, kind: String, dir: Vector3) -> void:
	dead = true
	state = "dead"
	death_kind = kind
	if burn_t > 0.0 or kind == "fire":
		# burnt to a crisp: blackened, still smoking for a while
		charred = true
		_put_out()
		_char_model()
	Collage.sticker(level, center_point() + Vector3(0, 0.5 + height * 0.3, 0), def.get("boss", false))
	col_shape.disabled = true
	var bc := blood_color()
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length() < 0.01:
		flat = global_transform.basis.z
	flat = flat.normalized()
	# fall away from the shot: which side of the body was pushed
	var local := global_transform.basis.inverse() * flat
	# shot from the side it topples sideways, from the front it goes over backwards
	death_side = signf(local.x) if absf(local.x) > 0.45 else 0.0
	if kind == "gut":
		death_side = 0.0
	if kind == "gut":
		# shoved off the knife, so the body lands a little way from your feet
		_death_slide = flat * 3.2
	elif not def.get("boss", false) and not flying:
		_death_slide = flat * clampf(amount * 0.035, 1.0, 6.0)
	if not def.get("boss", false) and (hp < -max_hp * 0.6 or (kind == "explosion" and hp < -15.0) or amount >= max_hp * 1.4):
		gibbed = true
		model.visible = false
		var skin: Color = def.get("color", Color(0.2, 0.45, 0.85))
		var sc := float(def.get("scale", 1.0))
		Fx.gibs(level, center_point(), skin, bc, (9 if def["model"] == "gorbino" else 7) + int(sc * 2.0))
		_fling_parts(flat, bc)
		Fx.splatter_walls(level, center_point(), flat, bc, 6)
		Fx.blood(level, center_point(), bc, 24, 0.07, Vector3.UP, 90.0, Vector2(3.0, 7.0))
		Fx.pool(level, Vector3(global_position.x, level.floor_at(global_position), global_position.z), bc, 1.8 * sc)
		Audio.play_at("hit_flesh", center_point(), 4.0, 0.6)
		Audio.play_at("gut_spill", center_point(), 0.0, randf_range(1.1, 1.3))
	elif kind != "gut":
		Fx.splatter_walls(level, center_point(), flat, bc, 2)
		Fx.blood(level, center_point() + flat * 0.2, bc, 14, 0.07, (flat + Vector3.UP * 0.6).normalized(), 35.0, Vector2(3.0, 6.0))
	Audio.play_at(def["death"], center_point(), 2.0 if def.get("boss", false) else 0.0, float(def.get("pitch", 1.0)) * randf_range(0.95, 1.05))
	var drop: String = def.get("drop", "")
	if drop != "":
		var pk := Pickup.new()
		pk.spawn_id = -1
		level.entity_root().add_child(pk)
		pk.setup(drop, Vector3(global_position.x, level.floor_at(global_position), global_position.z))
		pk.dropped = true
		level.pickups.append(pk)
	level.on_enemy_killed(self)
	if def.get("boss", false):
		for k in 6:
			var off := Vector3(randf_range(-3, 3), randf_range(1, 6), randf_range(-3, 3))
			Fx.explosion(level, global_position + off, k == 0)


## Blown apart: its own feet, beak, gun and launcher go flying too, with a
## string of gut.
func _fling_parts(dir: Vector3, bc: Color) -> void:
	var nodes: Array = []
	for f in parts.get("feet", []):
		nodes.append(f)
	for key in ["beak", "arm", "launcher"]:
		if parts.has(key):
			nodes.append(parts[key])
	for n in nodes:
		var g := Gib.new()
		level.fx_root().add_child(g)
		g.global_transform = n.global_transform
		for c in n.get_children():
			if c is MeshInstance3D:
				g.add_child(c.duplicate())
		g.vel = dir * randf_range(2.0, 5.0) + Vector3(randf_range(-3, 3), randf_range(3.5, 7.5), randf_range(-3, 3))
		g.spin = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		g.level = level
		g.splat = bc
		g.add_to_group("gibs")
	var anchor := Marker3D.new()
	level.fx_root().add_child(anchor)
	anchor.global_position = center_point()
	var rope := GutRope.new()
	level.fx_root().add_child(rope)
	rope.setup(level, anchor, 9, dir + Vector3.UP * 0.8, Color(0.75, 0.95, 0.55) if def["model"] == "gorbino" else Color(1, 1, 1))
	rope.release()


const THROE := 0.22


func _animate_death(delta: float) -> void:
	death_t += delta
	if charred and death_t < 8.0 and fmod(death_t, 0.4) < delta:
		Fx.smoke(level, center_point())
	if gibbed:
		set_physics_process(false)
		return
	var sc := float(def.get("scale", 1.0))
	# slide back from the hit
	if _death_slide.length() > 0.05:
		var np := global_position + _death_slide * delta
		if not level.circle_blocked(Vector3(np.x, global_position.y, np.z), radius * 0.6, global_position.y, false, height * 0.5):
			np.y = maxf(level.floor_at(np), global_position.y - 0.5)
			global_position = np
		else:
			_death_slide = Vector3.ZERO
		_death_slide = _death_slide.move_toward(Vector3.ZERO, delta * 10.0)
	# fliers drop out of the air and land with a splat
	var fl := level.floor_at(global_position)
	if global_position.y > fl + 0.05:
		yv -= 22.0 * delta
		global_position.y = maxf(fl, global_position.y + yv * delta)
		if global_position.y <= fl + 0.001 and not _crashed:
			_crashed = true
			Fx.blood(level, center_point(), blood_color(), 18, 0.07, Vector3.UP, 80.0, Vector2(2.0, 5.0))
			Fx.pool(level, Vector3(global_position.x, fl, global_position.z), blood_color(), 1.5 * sc)
			_pooled = true
			Audio.play_at("hit_flesh", center_point(), 2.0, 0.55)
	var k := 0.0
	if death_kind != "gut" and death_t < THROE:
		# the death throe: a hard shudder, mouth wide, before it goes down
		var j := 1.0 - death_t / THROE
		model.position = Vector3(randf_range(-1, 1), randf_range(0.0, 1.0), randf_range(-1, 1)) * 0.05 * j * sc
		Creatures.animate(model, anim_t + death_t * 8.0, delta, {"pain": true, "windup": true})
	else:
		model.position = model.position.lerp(Vector3.ZERO, clampf(delta * 12.0, 0.0, 1.0))
		k = clampf((death_t - (0.0 if death_kind == "gut" else THROE)) / 0.55, 0.0, 1.0)
		Creatures.death_pose(model, k, death_side, death_kind == "gut")
	if k >= 1.0 and not _pooled:
		_pooled = true
		Fx.pool(level, Vector3(global_position.x, fl, global_position.z), blood_color(), (1.7 if gutted else 1.2) * sc)
	if def.get("boss", false) and death_t < 2.5 and fmod(death_t, 0.35) < delta:
		Fx.explosion(level, global_position + Vector3(randf_range(-3, 3), randf_range(1, 6), randf_range(-3, 3)), false)
	# the dead don't lie still: now and then a corpse jerks
	if k >= 1.0 and not def.get("boss", false):
		_twitch_t -= delta
		if _twitch_t <= 0.0:
			_twitch_t = randf_range(1.5, 6.0)
			_twitch = 1.0
			if gutted and randf() < 0.5:
				Audio.play_at("gut_drip", global_position + Vector3(0, 0.3, 0), -8.0, randf_range(0.8, 1.2))
		_twitch = move_toward(_twitch, 0.0, delta * 5.0)
		parts["body"].rotation.y = sin(death_t * 70.0) * 0.06 * _twitch
		model.position.y = absf(sin(death_t * 45.0)) * 0.02 * _twitch
	if death_t > (3.0 if def.get("boss", false) else 40.0):
		parts["body"].rotation.y = 0.0
		set_physics_process(false)


# ------------------------------------------------------------------ animation
func _animate(delta: float, ppos: Vector3) -> void:
	blink_t -= delta
	var blink := false
	if blink_t < 0.0:
		blink = true
		if blink_t < -0.12:
			blink_t = randf_range(1.5, 5.0)
	var sc := float(def.get("scale", 1.0))
	var look := model.to_local(ppos + Vector3(0, 1.5, 0)) / sc
	Creatures.animate(model, anim_t, delta, {"move": move_amount, "windup": state == "windup", "pain": state == "pain",
		"blink": blink, "fly": flying, "look": look})


# ------------------------------------------------------------------ save
func serialize() -> Dictionary:
	return {"id": spawn_id, "t": etype, "x": global_position.x, "y": global_position.y, "z": global_position.z,
		"hp": hp, "dead": dead, "alerted": alerted, "yaw": yaw, "gib": gibbed, "summoned": summoned,
		"side": death_side, "dk": death_kind}


func restore(d: Dictionary) -> void:
	global_position = Vector3(float(d["x"]), float(d["y"]), float(d["z"]))
	hp = float(d.get("hp", hp))
	yaw = float(d.get("yaw", yaw))
	rotation.y = yaw
	if d.get("dead", false):
		dead = true
		state = "dead"
		col_shape.disabled = true
		gibbed = d.get("gib", false)
		model.visible = not gibbed
		death_t = 10.0
		death_side = float(d.get("side", 1.0))
		death_kind = String(d.get("dk", ""))
		if not gibbed:
			# lie the way it fell; a gutted one keeps its open belly
			if death_kind == "gut" and _gut_wound == null:
				_open_wound()
				_set_wound(1.15, 1.0, 1.0)
			Creatures.death_pose(model, 1.0, death_side, death_kind == "gut")
		set_physics_process(false)
	elif d.get("alerted", false):
		alerted = true
		state = "chase"
