class_name Weapons
extends Node3D
## Weapon inventory, firing, reloading and the first-person viewmodel.

const ORDER := ["pistol", "shotgun", "ssg", "mg", "rocket", "plasma", "flamer"]
const DATA := {
	"pistol": {"slot": 1, "name": "PISTOL", "ammo": "bullets", "mag": 12, "use": 1, "auto": false, "rate": 0.14,
		"dmg": 18.0, "pellets": 1, "spread": 0.010, "reload": 0.75, "style": "mag", "snd": "pistol_fire", "kick": 1.2, "vkick": 0.05},
	"shotgun": {"slot": 2, "name": "SHOTGUN", "ammo": "shells", "mag": 6, "use": 1, "auto": false, "rate": 0.6,
		"dmg": 10.0, "pellets": 9, "spread": 0.065, "reload": 0.3, "style": "shell", "snd": "shotgun_fire", "kick": 4.5, "vkick": 0.11},
	"ssg": {"slot": 3, "name": "DOUBLE SHOTGUN", "ammo": "shells", "mag": 2, "use": 2, "auto": false, "rate": 0.25,
		"dmg": 10.0, "pellets": 20, "spread": 0.12, "spread_v": 0.05, "reload": 1.0, "style": "break", "snd": "ssg_fire", "kick": 8.0, "vkick": 0.16},
	"mg": {"slot": 4, "name": "MACHINE GUN", "ammo": "bullets", "mag": 60, "use": 1, "auto": true, "rate": 0.06,
		"dmg": 13.0, "pellets": 1, "spread": 0.016, "spread_max": 0.055, "reload": 1.2, "style": "mag", "snd": "mg_fire", "kick": 0.9, "vkick": 0.03},
	"rocket": {"slot": 5, "name": "ROCKET LAUNCHER", "ammo": "rockets", "mag": 4, "use": 1, "auto": false, "rate": 0.6,
		"dmg": 90.0, "splash": 125.0, "splash_r": 5.2, "proj": "rocket", "speed": 42.0, "reload": 1.3, "style": "mag",
		"snd": "rocket_fire", "kick": 5.5, "vkick": 0.12},
	"plasma": {"slot": 6, "name": "PLASMA RIFLE", "ammo": "cells", "mag": 0, "use": 1, "auto": true, "rate": 0.07,
		"dmg": 21.0, "proj": "plasma", "speed": 80.0, "heat": 5.5, "style": "heat", "snd": "plasma_fire", "kick": 0.7, "vkick": 0.025},
	"flamer": {"slot": 7, "name": "FLAMETHROWER", "ammo": "fuel", "mag": 0, "use": 1, "auto": true, "rate": 0.05,
		"dmg": 4.5, "range": 8.5, "style": "flame", "snd": "", "kick": 0.15, "vkick": 0.004},
}
const MAX_AMMO := {"bullets": 200, "shells": 50, "rockets": 30, "cells": 300, "fuel": 200}
const BASE_POS := Vector3(0.07, -0.082, -0.19)
const VM_SCALE := 0.36

var player: Player
var owned := ["pistol"]
var current := "pistol"
var last := "pistol"
var ammo := {"bullets": 40, "shells": 0, "rockets": 0, "cells": 0, "fuel": 0}
var mags := {"pistol": 12}
var backpack := false
var cooldown := 0.0
var state := "idle"         # idle, lower, raise, reload
var state_t := 0.0
var pending := ""
var reload_step := 0
var heat := 0.0
var overheat := false
var heat_delay := 0.0
var spread_bloom := 0.0
var holder: Node3D
var vm: Node3D
var vm_parts := {}
var flash: Sprite3D
var flash_t := 0.0
var recoil := 0.0
var sway_v := Vector2.ZERO
var _bob_t := 0.0
var _bob_a := 0.0
var _fire_held_last := false
var _spin_speed := 0.0
var _eject: Array = []
var holster := 0.0            # 1 = lowered out of sight (while gutting)
var _flame_on := 0.0          # > 0 while the flamethrower is going
var _flame_snd_t := 0.0
var _flame_light_t := 0.0
var _flame_noise_t := 0.0


func _ready() -> void:
	holder = Node3D.new()
	add_child(holder)
	flash = Fx.make_sprite("muzzle", 0.12)
	flash.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	flash.visible = false
	flash.no_depth_test = false
	_build_vm()


func max_ammo(t: String) -> int:
	return int(MAX_AMMO[t]) * (2 if backpack else 1)


func load_from(inv: Dictionary) -> void:
	owned = inv.get("weapons", ["pistol"]).duplicate()
	current = String(inv.get("current", "pistol"))
	if not owned.has(current):
		current = owned[0]
	last = current
	ammo = inv.get("ammo", ammo).duplicate()
	mags = inv.get("mags", {}).duplicate()
	backpack = bool(inv.get("backpack", false))
	for w in owned:
		if not mags.has(w):
			mags[w] = 0
	state = "raise"
	state_t = 0.0
	if is_inside_tree():
		_build_vm()


func save_to(inv: Dictionary) -> void:
	inv["weapons"] = owned.duplicate()
	inv["current"] = current
	inv["ammo"] = ammo.duplicate()
	inv["mags"] = mags.duplicate()
	inv["backpack"] = backpack


func give_ammo(t: String, n: int) -> bool:
	if int(ammo.get(t, 0)) >= max_ammo(t):
		return false
	ammo[t] = mini(int(ammo.get(t, 0)) + n, max_ammo(t))
	return true


func give_weapon(w: String, dropped := false) -> bool:
	var d: Dictionary = DATA[w]
	var t: String = d["ammo"]
	var gave_ammo := give_ammo(t, {"bullets": 20, "shells": 8, "rockets": 2, "cells": 40, "fuel": 60}[t])
	if owned.has(w):
		return gave_ammo
	owned.append(w)
	mags[w] = 0
	if int(d["mag"]) > 0:
		var load_n := mini(int(d["mag"]), int(ammo[t]))
		mags[w] = load_n
		ammo[t] -= load_n
	switch_to(w)
	return true


func cur() -> Dictionary:
	return DATA[current]


func mag_count() -> int:
	return int(mags.get(current, 0))


func reserve() -> int:
	return int(ammo.get(String(cur()["ammo"]), 0))


func switch_to(w: String) -> void:
	if not owned.has(w) or (w == current and state != "lower"):
		return
	if state == "lower" and pending == w:
		return
	pending = w
	state = "lower"
	state_t = 0.0
	Audio.play("weapon_switch", -6.0)


func cycle(dir: int) -> void:
	var base := pending if state == "lower" and pending != "" else current
	var i := ORDER.find(base)
	for k in ORDER.size():
		i = (i + dir + ORDER.size()) % ORDER.size()
		if owned.has(ORDER[i]):
			switch_to(ORDER[i])
			return


func _build_vm() -> void:
	if vm:
		vm.queue_free()
	vm = Models.weapon(current, true)
	vm.scale = Vector3.ONE * VM_SCALE
	holder.add_child(vm)
	Collage.outline_viewmodel(vm)
	vm_parts = vm.get_meta("parts")
	var muzzle: Marker3D = vm_parts["muzzle"]
	if flash.get_parent():
		flash.get_parent().remove_child(flash)
	muzzle.add_child(flash)
	flash.texture = Mat.tex("muzzle_plasma" if current == "plasma" else "muzzle")
	flash.hframes = 3
	flash.pixel_size = (0.5 if current in ["shotgun", "ssg", "rocket"] else 0.32) / 64.0 / VM_SCALE * VM_SCALE
	flash.position = Vector3(0, 0, -0.04)
	_spin_speed = 0.0


func sway(rel: Vector2) -> void:
	sway_v += rel * 0.00012


func set_bob(t: float, a: float) -> void:
	_bob_t = t
	_bob_a = a


func _fire_pressed() -> bool:
	if player.autopilot:
		return player.autopilot.want_fire
	return Input.is_action_pressed("fire")


func _process(delta: float) -> void:
	if player == null or player.dead:
		return
	if Engine.time_scale == 0.0:
		return
	cooldown -= delta
	flash_t -= delta
	_flame_on -= delta
	flash.visible = flash_t > 0.0
	spread_bloom = move_toward(spread_bloom, 0.0, delta * 0.08)
	_handle_heat(delta)
	holster = move_toward(holster, 1.0 if player.gutting else 0.0, delta * (7.0 if player.gutting else 3.5))
	if player.gutting:
		_fire_held_last = true
		_animate(delta)
		return
	_handle_input()
	match state:
		"lower":
			state_t += delta
			if state_t >= 0.09:
				last = current
				current = pending
				pending = ""
				_build_vm()
				state = "raise"
				state_t = 0.0
		"raise":
			state_t += delta
			if state_t >= 0.12:
				state = "idle"
		"reload":
			state_t += delta
			_reload_tick()
	var want_fire := _fire_pressed()
	if want_fire and state == "idle" and cooldown <= 0.0:
		var d := cur()
		if d["auto"] or not _fire_held_last:
			_try_fire()
	if want_fire and state == "reload" and String(cur()["style"]) == "shell" and mag_count() > 0:
		state = "idle"   # interrupt shell-by-shell reload
		Audio.play("shotgun_pump", -4.0)
		cooldown = 0.25
	_fire_held_last = want_fire
	_animate(delta)


func _handle_input() -> void:
	if player.autopilot:
		return
	for i in range(1, ORDER.size() + 1):
		if InputMap.has_action("weapon_%d" % i) and Input.is_action_just_pressed("weapon_%d" % i):
			var w: String = ORDER[i - 1]
			if owned.has(w):
				switch_to(w)
	if Input.is_action_just_pressed("weapon_next"):
		cycle(1)
	if Input.is_action_just_pressed("weapon_prev"):
		cycle(-1)
	if Input.is_action_just_pressed("weapon_last") and owned.has(last) and last != current:
		switch_to(last)
	if Input.is_action_just_pressed("reload"):
		start_reload()


func start_reload() -> bool:
	if state != "idle":
		return false
	var d := cur()
	if String(d["style"]) == "heat":
		if heat > 10.0 and not overheat:
			overheat = true
			Audio.play("plasma_vent", -2.0)
		return false
	if mag_count() >= int(d["mag"]) or reserve() <= 0:
		return false
	state = "reload"
	state_t = 0.0
	reload_step = 0
	match String(d["style"]):
		"mag":
			Audio.play({"pistol": "pistol_reload", "mg": "mg_reload", "rocket": "rocket_reload"}.get(current, "pistol_reload"), -2.0)
		"break":
			Audio.play("ssg_open", -2.0)
		"shell":
			pass
	return true


func _reload_tick() -> void:
	var d := cur()
	var t: String = d["ammo"]
	match String(d["style"]):
		"mag":
			if state_t >= float(d["reload"]):
				var need := int(d["mag"]) - mag_count()
				var n := mini(need, int(ammo[t]))
				mags[current] = mag_count() + n
				ammo[t] -= n
				state = "idle"
		"shell":
			# one shell every reload seconds, then a pump
			var per := float(d["reload"])
			if state_t >= per * (reload_step + 1):
				if mag_count() < int(d["mag"]) and int(ammo[t]) > 0:
					mags[current] = mag_count() + 1
					ammo[t] -= 1
					reload_step += 1
					Audio.play("shell_load", -3.0, randf_range(0.95, 1.05))
				if mag_count() >= int(d["mag"]) or int(ammo[t]) <= 0:
					state = "idle"
					Audio.play("shotgun_pump", -3.0)
					cooldown = 0.3
		"break":
			if reload_step == 0 and state_t > float(d["reload"]) * 0.32:
				reload_step = 1
				var n := mini(int(d["mag"]) - mag_count(), int(ammo[t]))
				mags[current] = mag_count() + n
				ammo[t] -= n
				Audio.play("ssg_load", -2.0)
				vm_parts["shells"].visible = true
			if reload_step == 1 and state_t > float(d["reload"]) * 0.75:
				reload_step = 2
				Audio.play("ssg_close", -2.0)
			if state_t >= float(d["reload"]):
				vm_parts["shells"].visible = false
				state = "idle"


func _handle_heat(delta: float) -> void:
	if current != "plasma" and heat <= 0.0:
		return
	heat_delay -= delta
	if overheat:
		heat = maxf(0.0, heat - 55.0 * delta)
		if heat <= 0.0:
			overheat = false
	elif heat_delay <= 0.0:
		heat = maxf(0.0, heat - 38.0 * delta)
	if vm_parts.has("glow_mat"):
		var g: ShaderMaterial = vm_parts["glow_mat"]
		var k := heat / 100.0
		g.set_shader_parameter("tint", Color(1.0, 1.0 - k * 0.7, 1.0 - k * 0.9) if not overheat else Color(1, 0.3 + 0.3 * sin(Time.get_ticks_msec() * 0.03), 0.2))


func _try_fire() -> void:
	var d := cur()
	var t: String = d["ammo"]
	var style := String(d["style"])
	if style == "flame":
		if int(ammo.get(t, 0)) < int(d["use"]):
			Audio.play("dryfire", -4.0)
			cooldown = 0.3
			_auto_switch_empty()
			return
		ammo[t] -= int(d["use"])
		cooldown = float(d["rate"]) * (0.75 if player.frenzy > 0.0 else 1.0)
		_flame(d)
		return
	if style == "heat":
		if overheat:
			return
		if int(ammo[t]) < int(d["use"]):
			Audio.play("dryfire", -4.0)
			cooldown = 0.3
			_auto_switch_empty()
			return
		ammo[t] -= int(d["use"])
		heat += float(d["heat"])
		heat_delay = 0.25
		if heat >= 100.0:
			heat = 100.0
			overheat = true
			Audio.play("plasma_overheat", -1.0)
			Audio.play("plasma_vent", -4.0)
	else:
		if mag_count() <= 0:
			if reserve() > 0:
				start_reload()
			else:
				Audio.play("dryfire", -4.0)
				cooldown = 0.35
				_auto_switch_empty()
			return
		var use := mini(int(d["use"]), mag_count())
		mags[current] = mag_count() - use
	cooldown = float(d["rate"]) * (0.65 if player.frenzy > 0.0 else 1.0)
	_fire(d)
	if style != "heat" and mag_count() <= 0 and reserve() > 0 and Settings.get_v("auto_reload"):
		# auto reload after the recoil settles
		get_tree().create_timer(float(d["rate"]) * 0.9).timeout.connect(func():
			if is_instance_valid(self) and state == "idle" and mag_count() <= 0:
				start_reload())


## One tick of the flamethrower: a cone of fire in front of you that sets
## alight whatever it touches, and the puffs of flame you can see.
func _flame(d: Dictionary) -> void:
	var lvl: Node = player.level
	var cam := player.camera
	var basis := cam.global_transform.basis
	var fwd := -basis.z
	var eye: Vector3 = cam.global_position
	if _flame_on <= 0.0:
		Audio.play("flame_start", -2.0, randf_range(0.95, 1.05))
		_flame_snd_t = 0.25
	_flame_on = 0.12
	_flame_snd_t -= float(d["rate"])
	if _flame_snd_t <= 0.0:
		_flame_snd_t = 0.95
		Audio.play("flame_loop", -3.0, randf_range(0.95, 1.05))
	_flame_noise_t -= float(d["rate"])
	if _flame_noise_t <= 0.0:
		_flame_noise_t = 0.5
		lvl.noise_at(player.global_position, 18)
	var nozzle: Vector3 = vm_parts["muzzle"].global_position if vm_parts.has("muzzle") else eye + fwd * 0.6
	# the stream you see starts at the nozzle but is aimed from the eye
	var start := nozzle.lerp(eye + fwd * 0.5, 0.5)
	for k in 3:
		var spread := basis.x * randf_range(-1, 1) * 0.14 + basis.y * randf_range(-1, 1) * 0.09
		FlameBit.spawn(lvl, start, (fwd + spread).normalized() * randf_range(15.0, 19.0) + player.velocity * 0.6)
	_flame_light_t -= float(d["rate"])
	if _flame_light_t <= 0.0:
		_flame_light_t = 0.1
		Fx.light(lvl, eye + fwd * 2.5, Color(1.0, 0.55, 0.15), 7.0, 1.6, 0.14)
	# everything in the cone burns
	var rng: float = d["range"]
	var targets: Array = []
	for e in lvl.enemies:
		if is_instance_valid(e) and not e.dead:
			targets.append(e)
	for b in lvl.barrels:
		if is_instance_valid(b) and not b.exploded:
			targets.append(b)
	for c in lvl.civilians:
		if is_instance_valid(c) and not c.dead:
			targets.append(c)
	for tg in targets:
		var to: Vector3 = tg.center_point() - eye
		var dist := to.length()
		if dist > rng + float(tg.get("radius") if tg.get("radius") != null else 0.5):
			continue
		var dir := to / maxf(dist, 0.01)
		if fwd.dot(dir) < (0.84 if dist > 2.0 else 0.5):
			continue
		if not lvl.has_los(eye, tg.center_point()):
			continue
		tg.take_damage(float(d["dmg"]), player, dir, "fire")
		if tg.has_method("ignite"):
			tg.ignite(player)
	recoil = minf(recoil + float(d["vkick"]), 0.05)


func _auto_switch_empty() -> void:
	# pick the best weapon that still has ammo
	for i in range(ORDER.size() - 1, -1, -1):
		var w: String = ORDER[i]
		if w == current or not owned.has(w):
			continue
		var dd: Dictionary = DATA[w]
		if int(mags.get(w, 0)) > 0 or int(ammo[dd["ammo"]]) > 0:
			if w == "rocket":
				continue
			switch_to(w)
			return


func _fire(d: Dictionary) -> void:
	var cam := player.camera
	var origin := cam.global_position
	var basis := cam.global_transform.basis
	var fwd := -basis.z
	Audio.play(String(d["snd"]), 0.0, randf_range(0.94, 1.06))
	player.level.noise_at(player.global_position, 22)
	flash_t = 0.05 if current != "plasma" else 0.04
	flash.frame = randi() % 3
	flash.rotation.z = randf() * TAU
	var lc := Color(1.0, 0.75, 0.35) if current != "plasma" else Color(0.3, 0.8, 1.0)
	Fx.light(player.level, origin + fwd * 1.2, lc, 6.0, 0.75, 0.07)
	recoil = minf(recoil + float(d["vkick"]), 0.3)
	player.add_kick(float(d["kick"]) * 0.35)
	if current == "mg":
		spread_bloom = minf(spread_bloom + 0.004, float(d["spread_max"]) - float(d["spread"]))
		_spin_speed = 40.0
	if d.has("proj"):
		var muzzle: Marker3D = vm_parts["muzzle"]
		# spawn from camera, offset toward the gun so it looks right but aims true
		var start := origin + fwd * 0.4 + basis.x * 0.08 - basis.y * 0.06
		var aim_hit := player.level.ray(origin, origin + fwd * 200.0, 1 | 4 | 8 | 32, [player.get_rid()])
		var aim_pt: Vector3 = aim_hit["position"] if not aim_hit.is_empty() else origin + fwd * 200.0
		var dir := (aim_pt - start).normalized()
		if (aim_pt - origin).length() < 1.2:
			start = origin
			dir = fwd
		var p := Projectile.new()
		player.level.fx_root().add_child(p)
		p.launch(player.level, player, start, dir * float(d["speed"]), String(d["proj"]), float(d["dmg"]), true)
		if d.has("splash"):
			p.splash = float(d["splash"])
			p.splash_r = float(d["splash_r"])
		if current == "rocket" and vm_parts.has("rocket"):
			vm_parts["rocket"].visible = mag_count() > 0
		return
	var pellets := int(d["pellets"])
	var spread := float(d["spread"]) + spread_bloom
	var spread_v := float(d.get("spread_v", spread))
	var hits := {}
	for k in pellets:
		var r := Vector2(randf_range(-1, 1), randf_range(-1, 1))
		if pellets > 1:
			r = Vector2(randfn(0.0, 0.5), randfn(0.0, 0.5)).limit_length(1.0)
		var dir := (fwd + basis.x * r.x * spread + basis.y * r.y * spread_v).normalized()
		var hit := player.level.ray(origin, origin + dir * 250.0, 1 | 4 | 8 | 32, [player.get_rid()], true)
		if hit.is_empty():
			continue
		var col = hit["collider"]
		if col and col.has_method("take_damage"):
			var key = col.get_instance_id()
			if not hits.has(key):
				hits[key] = [col, 0.0, dir]
			hits[key][1] += float(d["dmg"]) * randf_range(0.8, 1.2)
		else:
			Fx.puff(player.level, hit["position"], hit["normal"])
	for key in hits.keys():
		var e = hits[key]
		if is_instance_valid(e[0]):
			e[0].take_damage(e[1], player, e[2], "bullet")
			if e[0] is Enemy or e[0] is Civilian:
				Audio.play_at("hit_flesh", e[0].center_point(), -4.0, randf_range(0.9, 1.2))
	if current in ["shotgun", "ssg", "pistol", "mg"]:
		_eject_casing()


func _eject_casing() -> void:
	# a little brass/red casing flies out of the viewmodel
	var c := Models.mi(Models.box(0.012, 0.012, 0.03), Mat.world("gun_red" if current in ["shotgun", "ssg"] else "gun_brass", {"origin": true}))
	holder.add_child(c)
	c.position = Vector3(0.02, 0.01, -0.06)
	_eject.append([c, Vector3(randf_range(0.4, 0.7), randf_range(0.5, 0.9), randf_range(0.0, 0.2)), 0.5])
	if _eject.size() > 6:
		var o = _eject.pop_front()
		if is_instance_valid(o[0]):
			o[0].queue_free()


func _animate(delta: float) -> void:
	recoil = move_toward(recoil, 0.0, delta * (0.6 + recoil * 8.0))
	sway_v = sway_v.lerp(Vector2.ZERO, clampf(delta * 7.0, 0.0, 1.0))
	sway_v = sway_v.limit_length(0.03)
	var bob_x := sin(_bob_t * 0.5) * 0.006 * _bob_a
	var bob_y := absf(cos(_bob_t * 0.5)) * 0.005 * _bob_a
	var pos := BASE_POS + Vector3(bob_x - sway_v.x, -bob_y + sway_v.y, recoil * 0.18)
	var rot := Vector3(recoil * 1.2, 0.1, 0)      # turned in a little so the side of the gun shows
	var d := cur()
	match state:
		"lower":
			pos.y -= state_t / 0.09 * 0.12
		"raise":
			pos.y -= (1.0 - state_t / 0.12) * 0.12
		"reload":
			var dur := float(d["reload"])
			var style := String(d["style"])
			if style == "shell":
				var k := fmod(state_t, dur) / dur
				rot += Vector3(0.15, 0.0, 0.45)
				pos += Vector3(-0.01, 0.0 - sin(k * PI) * 0.012, 0)
			elif style == "break":
				var k := state_t / dur
				var open := clampf(k * 4.0, 0.0, 1.0) * (1.0 - clampf((k - 0.75) * 5.0, 0.0, 1.0))
				vm_parts["barrels"].rotation.x = -open * 0.9
				rot += Vector3(open * 0.35, 0, open * 0.25)
				pos.y -= open * 0.01
			else:
				var k := state_t / dur
				var tilt := sin(clampf(k, 0.0, 1.0) * PI)
				rot += Vector3(-tilt * 0.4, tilt * 0.3, tilt * 0.7)
				pos += Vector3(0, -tilt * 0.02, 0)
				if vm_parts.has("mag"):
					var mag: Node3D = vm_parts["mag"]
					mag.visible = k < 0.25 or k > 0.6
				if current == "rocket" and vm_parts.has("rocket"):
					vm_parts["rocket"].visible = k > 0.7
	if state != "reload" and vm_parts.has("barrels"):
		vm_parts["barrels"].rotation.x = move_toward(vm_parts["barrels"].rotation.x, 0.0, delta * 6.0)
	if state != "reload" and vm_parts.has("mag"):
		vm_parts["mag"].visible = true
	if current == "rocket" and state != "reload" and vm_parts.has("rocket"):
		vm_parts["rocket"].visible = mag_count() > 0
	# moving parts
	if vm_parts.has("slide"):
		vm_parts["slide"].position.z = recoil * 0.25 if mag_count() > 0 or state == "reload" else 0.05
	if vm_parts.has("pump"):
		var pk := 0.0
		if cooldown > 0.0 and current == "shotgun":
			var k := 1.0 - cooldown / float(d["rate"])
			pk = sin(clampf((k - 0.25) / 0.6, 0.0, 1.0) * PI) * 0.12
		vm_parts["pump"].position.z = pk
	if vm_parts.has("spin"):
		_spin_speed = move_toward(_spin_speed, 0.0, delta * 50.0)
		vm_parts["spin"].rotation.z += _spin_speed * delta
	if vm_parts.has("charm"):
		var ch: Node3D = vm_parts["charm"]
		ch.rotation = Vector3(clampf(-sway_v.y * 30.0 + recoil * 4.0, -1.0, 1.0), 0, clampf(sway_v.x * 30.0 + sin(_bob_t * 0.5) * 0.3 * _bob_a, -1.0, 1.0))
	if vm_parts.has("specimen"):
		var sp: Node3D = vm_parts["specimen"]
		var tt := Time.get_ticks_msec() * 0.001
		sp.position = Vector3(sin(tt * 1.3) * 0.006, 0.11 + sin(tt * 2.1) * 0.012, -0.022)
		sp.rotation.y = tt * 0.8
	if vm_parts.has("core"):
		vm_parts["core"].scale = Vector3.ONE * (1.0 + 0.3 * sin(Time.get_ticks_msec() * 0.02) + heat * 0.01)
	pos += Vector3(0.03, -0.2, 0.05) * holster
	rot += Vector3(-0.7, 0, -0.3) * holster
	holder.position = pos
	holder.rotation = rot
	for k in range(_eject.size() - 1, -1, -1):
		var e = _eject[k]
		var node: Node3D = e[0]
		if not is_instance_valid(node):
			_eject.remove_at(k)
			continue
		e[1].y -= 3.0 * delta
		node.position += e[1] * delta * 0.4
		node.rotation += Vector3(15, 10, 0) * delta
		e[2] -= delta
		if e[2] <= 0.0:
			node.queue_free()
			_eject.remove_at(k)
