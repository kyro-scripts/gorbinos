class_name Enemy
extends AnimatableBody3D
## Gorbinos and Snirbies. One script, data-driven variants.

const TYPES := {
	"green": {"model": "gorbino", "color": Color(1.0, 0.48, 0.1), "hp": 51, "speed": 5.4, "radius": 0.55, "height": 1.6,
		"attack": "proj", "proj": "green", "proj_speed": 19.5, "dmg": 10, "count": 1, "spread": 0.0, "cooldown": [1.12, 2.24],
		"windup": 0.40, "range": 45.0, "pain": 0.75, "sight": "gorb_sight", "pain_snd": "gorb_pain", "death": "gorb_death",
		"idle": "gorb_idle", "name": "GORBINO", "drop": ""},
	"yellow": {"model": "gorbino", "color": Color(1.0, 0.85, 0.1), "hp": 38, "speed": 5.9, "radius": 0.55, "height": 1.6,
		"attack": "hitscan", "dmg": 5, "count": 3, "spread": 0.07, "cooldown": [0.91, 1.82], "windup": 0.40, "range": 40.0,
		"pain": 0.8, "sight": "gorb_sight2", "pain_snd": "gorb_pain", "death": "gorb_death", "idle": "gorb_idle",
		"gun": true, "name": "YELLOW GORBINO", "drop": "bullets", "keep_range": 9.0},
	"red": {"model": "gorbino", "color": Color(1.0, 0.18, 0.12), "hp": 110, "speed": 9.7, "radius": 0.6, "height": 1.6,
		"attack": "melee", "dmg": 16, "cooldown": [0.42, 0.70], "windup": 0.20, "range": 1.9, "pain": 0.5,
		"sight": "gorb_attack", "pain_snd": "gorb_pain", "death": "gorb_death", "idle": "gorb_idle", "name": "RED GORBINO", "drop": ""},
	"blue": {"model": "gorbino", "color": Color(0.2, 0.45, 1.0), "hp": 221, "speed": 4.1, "radius": 0.62, "height": 1.7, "scale": 1.12,
		"attack": "proj", "proj": "ice", "proj_speed": 22.1, "dmg": 11, "count": 3, "spread": 0.18, "cooldown": [1.40, 2.38],
		"windup": 0.50, "range": 40.0, "pain": 0.35, "sight": "gorb_sight", "pain_snd": "gorb_pain", "death": "gorb_death",
		"idle": "gorb_idle", "name": "BLUE GORBINO", "drop": "shells", "pitch": 0.85},
	"purple": {"model": "gorbino", "color": Color(0.7, 0.2, 1.0), "hp": 144, "speed": 6.2, "radius": 0.55, "height": 1.6,
		"attack": "proj", "proj": "purple", "proj_speed": 14.3, "homing": 2.2, "dmg": 15, "count": 1, "spread": 0.0,
		"cooldown": [1.26, 2.10], "windup": 0.40, "range": 50.0, "pain": 0.55, "fly": true, "hover": 1.6,
		"sight": "gorb_sight2", "pain_snd": "gorb_pain", "death": "gorb_death", "idle": "gorb_idle", "name": "PURPLE GORBINO",
		"drop": "cells", "pitch": 1.25},
	"black": {"model": "gorbino", "color": Color(0.12, 0.1, 0.14), "hp": 638, "speed": 4.9, "radius": 0.9, "height": 2.5, "scale": 1.55,
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
		"death": "snirb_death", "idle": "snirb_sniff", "name": "SKY SNIRBY", "drop": "", "tint": Color(1.0, 0.86, 0.96), "propeller": true},
	"boss": {"model": "snirby", "hp": 4420, "speed": 4.6, "radius": 1.9, "height": 6.4, "scale": 4.2, "boss": true,
		"attack": "boss", "proj": "spit", "proj_speed": 24.7, "dmg": 12, "count": 1, "spread": 0.0, "cooldown": [0.70, 1.26],
		"windup": 0.50, "range": 90.0, "pain": 0.0, "sight": "boss_roar", "pain_snd": "snirb_pain", "death": "boss_death",
		"idle": "snirb_sniff", "name": "THE GREAT SNIRBY", "drop": "", "tint": Color(1.0, 0.75, 0.85), "glow": true, "pitch": 0.45},
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
var burst_left := 0
var boss_phase := 0
var summoned := false
var col_shape: CollisionShape3D
var _skin_mat: ShaderMaterial
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
	if def["model"] == "gorbino":
		model = Models.gorbino(def["color"], {"gun": def.get("gun", false), "glow_eyes": def.get("glow_eyes", false), "launcher": def.get("launcher", false)})
	else:
		model = Models.snirby({"tint": def.get("tint", Color(1, 1, 1)), "glow": def.get("glow", false), "fly": def.get("fly", false)})
	model.scale = Vector3.ONE * sc
	add_child(model)
	parts = model.get_meta("parts")
	_skin_mat = parts.get("skin_mat")
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
	if not def.get("boss", false) and randf() < 0.45:
		spoke = Audio.voice_line(center_point(), 0.9 if def["model"] == "gorbino" else 1.12)
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


# ------------------------------------------------------------------ attacks
func _muzzle_point() -> Vector3:
	var sc := float(def.get("scale", 1.0))
	var fwd := -global_transform.basis.z
	if def.get("launcher", false):
		return global_position + Vector3(0, 1.2 * sc, 0) + global_transform.basis.x * 0.5 * sc + fwd * 0.6 * sc
	if def["model"] == "snirby":
		return global_position + Vector3(0, 1.4 * sc, 0) + fwd * 0.75 * sc
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
			Audio.play_at("enemy_gun", mp, 0.0, randf_range(0.9, 1.05))
			Fx.light(level, mp, Color(1, 0.8, 0.3), 6.0, 1.2, 0.08)
			for k in int(def["count"]):
				var dir := (target - mp).normalized()
				dir = (dir + Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)) * float(def["spread"])).normalized()
				var hit := level.ray(mp, mp + dir * 80.0, 1 | 2 | 8, [get_rid()])
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
	Audio.play_at("snirb_spit" if def["model"] == "snirby" else "proj_launch", mp, 0.0, float(def.get("pitch", 1.0)))
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
			Audio.play_at("snirb_spit", mp, 4.0, 0.5)
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
				en.setup("skysnirby" if k % 2 == 1 else "snirby", level, Vector3(sp.x, level.floor_h[ci], sp.z), a)
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
			Audio.play_at("proj_launch", mp, 4.0, 0.5)
		3:
			# fire rain: big fireballs with splash
			for k in 3:
				var p := Projectile.new()
				level.fx_root().add_child(p)
				var t2 := target + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
				p.launch(level, self, mp, (t2 - mp).normalized() * 16.0, "fire", 20.0, false)
				p.splash = 40.0
				p.splash_r = 3.0
			Audio.play_at("rocket_fire", mp, 2.0, 0.6)


# ------------------------------------------------------------------ damage
func take_damage(amount: float, source: Node, dir: Vector3, kind := "bullet") -> void:
	if dead:
		return
	hp -= amount
	flash_t = 0.07
	if _skin_mat:
		_skin_mat.set_shader_parameter("flash", 0.7)
	var kb := amount * (0.06 if kind != "explosion" else 0.12) / sqrt(max_hp / 60.0)
	if not def.get("boss", false):
		knock += Vector3(dir.x, 0, dir.z) * minf(kb, 9.0)
	var bc := Color(0.8, 0.25, 0.04) if def["model"] == "gorbino" else Color(0.7, 0.04, 0.1)
	Fx.blood(level, center_point() - dir * 0.2, bc, clampi(int(amount / 6.0), 2, 10))
	if not alerted:
		alert()
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
	col_shape.disabled = true
	var bc := Color(0.8, 0.25, 0.04) if def["model"] == "gorbino" else Color(0.7, 0.04, 0.1)
	if not def.get("boss", false) and (hp < -max_hp * 0.6 or (kind == "explosion" and hp < -15.0) or amount >= max_hp * 1.4):
		gibbed = true
		model.visible = false
		var skin: Color = def.get("color", Color(1.0, 0.6, 0.7))
		Fx.gibs(level, center_point(), skin, bc, 9 if def["model"] == "gorbino" else 7)
		Audio.play_at("hit_flesh", center_point(), 4.0, 0.6)
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


func _animate_death(delta: float) -> void:
	death_t += delta
	if gibbed:
		set_physics_process(false)
		return
	var k := clampf(death_t / 0.45, 0.0, 1.0)
	if flying and global_position.y > level.floor_at(global_position) + 0.05:
		yv -= 20.0 * delta
		global_position.y = maxf(level.floor_at(global_position), global_position.y + yv * delta)
	Creatures.death_pose(model, k)
	if def.get("boss", false) and death_t < 2.5 and fmod(death_t, 0.35) < delta:
		Fx.explosion(level, global_position + Vector3(randf_range(-3, 3), randf_range(1, 6), randf_range(-3, 3)), false)
	if death_t > 3.0:
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
		"hp": hp, "dead": dead, "alerted": alerted, "yaw": yaw, "gib": gibbed, "summoned": summoned}


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
		if not gibbed:
			if def["model"] == "gorbino":
				model.rotation.x = deg_to_rad(80)
				model.position.y = 0.25 * float(def.get("scale", 1.0))
				parts["body"].scale.y = 0.75
			else:
				model.rotation.z = deg_to_rad(85)
				model.position.y = 0.2 * float(def.get("scale", 1.0))
		set_physics_process(false)
	elif d.get("alerted", false):
		alerted = true
		state = "chase"
