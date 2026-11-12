class_name Endless
extends Node
## ENDLESS: wave after wave of Gorbinos pouring into THE GORB PIT for as
## long as you last. Each wave is bigger and nastier; every fifth one brings
## an elite. Between waves there's a breather with ammo, health and armor,
## and new guns as rewards. Your best run is kept.

const BEST_PATH := "user://endless.json"
const REST := 6.0
const SPAWN_GAP := 0.45
const WEAPON_REWARDS := {2: "w_ssg", 3: "w_trout", 4: "w_rocket", 6: "w_flamer", 8: "w_plasma"}

var world: Node
var level: Level
var player: Player
var wave := 0
var state := "rest"           # rest, spawning, fight, over
var t := 3.0
var queue: Array = []
var alive: Array = []
var kills := 0
var time := 0.0
var best := {"wave": 0, "kills": 0, "time": 0.0}
var new_best := false
var _spawn_t := 0.0
var _spawns: Array = []
var _rng := RandomNumberGenerator.new()


func setup(w: Node) -> void:
	world = w
	level = w.level
	player = w.player
	_rng.randomize()
	for s in level.data.get("endless_spawns", []):
		_spawns.append(level.cell_center(Vector2i(int(s[0]), int(s[1]))))
	if _spawns.is_empty():
		_spawns.append(level.player_start + Vector3(0, 0, -10))
	_load_best()
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _load_best() -> void:
	if not FileAccess.file_exists(BEST_PATH):
		return
	var d = JSON.parse_string(FileAccess.open(BEST_PATH, FileAccess.READ).get_as_text())
	if d is Dictionary:
		for k in d.keys():
			best[k] = d[k]


func _save_best() -> void:
	if Game.autoplay:
		return
	var f := FileAccess.open(BEST_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(best))


func _process(delta: float) -> void:
	if state == "over":
		return
	if player.dead:
		_game_over()
		return
	time += delta
	alive = alive.filter(func(e): return is_instance_valid(e) and not e.dead)
	match state:
		"rest":
			t -= delta
			if t <= 0.0:
				_begin_wave()
		"spawning":
			_spawn_t -= delta
			if _spawn_t <= 0.0 and not queue.is_empty():
				_spawn_t = SPAWN_GAP
				_spawn_one(String(queue.pop_front()))
			if queue.is_empty():
				state = "fight"
		"fight":
			if alive.is_empty():
				_wave_cleared()


## What a wave is made of: more of everything, and nastier types unlock.
func _compose(n: int) -> Array:
	var pool := [["green", 4], ["snotling", 3]]
	if n >= 2:
		pool.append(["yellow", 3])
		pool.append(["snirby", 3])
	if n >= 3:
		pool.append(["red", 3])
	if n >= 4:
		pool.append(["purple", 2])
		pool.append(["skysnirby", 2])
	if n >= 5:
		pool.append(["blue", 2])
	if n >= 7:
		pool.append(["black", 1])
	var count := mini(5 + n * 2, 40)
	var out := []
	var tot := 0.0
	for p in pool:
		tot += float(p[1])
	for k in count:
		var r := _rng.randf() * tot
		for p in pool:
			r -= float(p[1])
			if r <= 0.0:
				out.append(p[0])
				break
	if n % 5 == 0:
		out.append("elite")
	return out


func _begin_wave() -> void:
	wave += 1
	queue = _compose(wave)
	state = "spawning"
	_spawn_t = 0.0
	world.hud.center("WAVE %d" % wave, 2.0)
	if Game.autoplay:
		print("[endless] wave %d: %d enemies, %d kills so far, %.0fs" % [wave, queue.size(), kills, time])
	Audio.play("frenzy_on", -4.0, 0.8)


func _spawn_one(type: String) -> void:
	var p: Vector3 = _spawns[_rng.randi_range(0, _spawns.size() - 1)]
	p += Vector3(_rng.randf_range(-1.2, 1.2), 0, _rng.randf_range(-1.2, 1.2))
	p.y = level.floor_at(p)
	var elite := type == "elite"
	var en := Enemy.new()
	en.spawn_id = -1
	level.entity_root().add_child(en)
	var to: Vector3 = player.global_position - p
	en.setup("black" if elite else type, level, p, atan2(-to.x, -to.z))
	var hp_k := minf(1.0 + (wave - 1) * 0.06, 2.0) * (3.0 if elite else 1.0)
	en.max_hp *= hp_k
	en.hp = en.max_hp
	level.enemies.append(en)
	alive.append(en)
	en.alert()
	Fx.telefog(level, p + Vector3(0, 1, 0))
	Audio.play_at("teleport", p, -2.0, _rng.randf_range(0.8, 1.2))


func on_kill() -> void:
	kills += 1


func _wave_cleared() -> void:
	state = "rest"
	t = REST
	world.hud.center("WAVE %d CLEARED" % wave, 2.2)
	Audio.play("secret", 0.0)
	_rewards()


## Drop a few things round the middle of the pit: ammo for what you carry,
## health, armor, and the odd new gun.
func _rewards() -> void:
	var drops := []
	var w: Weapons = player.weapons
	var ammo_of := {"bullets": "bullets_box", "shells": "shells_box", "rockets": "rockets_box", "cells": "cells_box", "fuel": "fuel_box", "trout": "trout_box"}
	var kinds := {}
	for wn in w.owned:
		kinds[String(Weapons.DATA[wn]["ammo"])] = true
	for k in mini(2 + wave / 3, 6):
		var ks := kinds.keys()
		drops.append(ammo_of[ks[_rng.randi_range(0, ks.size() - 1)]])
	drops.append("medkit")
	if _rng.randf() < 0.5:
		drops.append("armor_bonus")
	if wave % 5 == 0:
		drops.append("mega")
	elif wave % 3 == 0:
		drops.append("armor_green")
	if WEAPON_REWARDS.has(wave):
		drops.append(WEAPON_REWARDS[wave])
		world.hud.message("A NEW GUN IN THE PIT")
	var center: Vector3 = level.cell_center(Vector2i(17, 17))
	for d in drops:
		for tries in 12:
			var a := _rng.randf() * TAU
			var p: Vector3 = center + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(2.0, 9.0)
			var i := level.idx_of(level.cell_of(p))
			if i < 0 or level.solid[i] != 0:
				continue
			p.y = level.floor_at(p)
			var pk := Pickup.new()
			pk.spawn_id = -1
			level.entity_root().add_child(pk)
			pk.setup(String(d), p)
			pk.dropped = true
			level.pickups.append(pk)
			Fx.telefog(level, p + Vector3(0, 0.5, 0))
			break


func _game_over() -> void:
	state = "over"
	var reached := maxi(wave - 1, 0)
	if reached > int(best.get("wave", 0)) or (reached == int(best.get("wave", 0)) and kills > int(best.get("kills", 0))):
		new_best = true
		best = {"wave": reached, "kills": kills, "time": time}
		_save_best()
	print("[endless] game over: survived %d waves, %d kills, %.0fs" % [reached, kills, time])


## For the HUD: the line at the top of the screen.
func status() -> String:
	match state:
		"rest":
			return "WAVE %d IN %d" % [wave + 1, int(ceil(t))]
		"spawning", "fight":
			return "WAVE %d   %d LEFT" % [wave, alive.size() + queue.size()]
		"over":
			return "SURVIVED %d WAVES" % maxi(wave - 1, 0)
	return ""
