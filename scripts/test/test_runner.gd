extends Node
## Headless/xvfb test harness. Usage:
##   godot --path . -- --test [--shots] [--levels=1,2] [--frames=N]
## Builds each level, runs the simulation, validates reachability of the exit
## and optionally writes screenshots to user://shots/.

var results := []
var shots := false
var frames := 240


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shots = args.has("--shots")
	var only := []
	for a in args:
		if a.begins_with("--levels="):
			for s in a.substr(9).split(","):
				only.append(s)
		if a.begins_with("--frames="):
			frames = int(a.substr(9))
	var paths: Array = []
	if only.is_empty():
		paths = Game.LEVELS.duplicate()
	else:
		for s in only:
			if s == "test":
				paths.append("res://scripts/levels/test_level.gd")
			else:
				paths.append(Game.LEVELS[int(s) - 1])
	await get_tree().process_frame
	var ok := true
	if args.has("--savetest"):
		ok = await _save_test()
		print("TEST RESULT: ", "PASS" if ok else "FAIL")
		get_tree().quit(0 if ok else 1)
		return
	for p in paths:
		var r: bool = await _test_level(p)
		ok = ok and r
	print("TEST RESULT: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _test_level(path: String) -> bool:
	print("=== ", path)
	var data: Dictionary = load(path).DATA
	Game.inventory = Game.new_inventory()
	Game.inventory["weapons"] = ["pistol", "shotgun", "ssg", "mg", "rocket", "plasma"]
	Game.inventory["ammo"] = {"bullets": 200, "shells": 50, "rockets": 30, "cells": 300}
	Game.inventory["mags"] = {"pistol": 12, "shotgun": 6, "ssg": 2, "mg": 60, "rocket": 4}
	var idx := Game.LEVELS.find(path)
	Game.level_index = maxi(idx, 0)
	var gw := GameWorld.new()
	# GameWorld reads Game.level_data(Game.level_index); for the test map inject data
	if idx < 0:
		gw.set_meta("override_data", data)
	Game.main.layer.add_child(gw)
	await get_tree().process_frame
	var lv: Level = gw.level
	print("grid %dx%d  enemies=%d pickups=%d secrets=%d movers=%d" % [lv.W, lv.H, lv.enemies.size(), lv.pickups.size(), lv.stats["secrets_total"], lv.movers.size()])
	var ok := _validate_path(lv)
	var t0 := Time.get_ticks_usec()
	for k in 10:
		lv.compute_flow(lv.idx_of(lv.cell_of(lv.player_start)), false)
	print("flow field: %.2f ms" % ((Time.get_ticks_usec() - t0) / 10000.0))
	var shot_dir := "user://shots"
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var name := path.get_file().get_basename()
	if shots:
		var views: Array = data.get("test_views", [])
		var vi := 0
		for v in views:
			gw.player.teleport_to(lv.cell_center(Vector2i(int(v[0]), int(v[1]))))
			gw.player.yaw = deg_to_rad(float(v[2]))
			gw.player.pitch = deg_to_rad(float(v[3]) if v.size() > 3 else 0.0)
			for k in 20:
				await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_view%d.png" % [shot_dir, name, vi])
			vi += 1
		gw.player.teleport_to(lv.player_start)
	for f in frames:
		await get_tree().physics_frame
		if shots and (f == 30 or f == frames - 1):
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/%s_%d.png" % [shot_dir, name, f])
	print("player pos after sim: ", gw.player.global_position, " hp=", gw.player.health)
	gw.queue_free()
	await get_tree().process_frame
	return ok


## Breadth-first search over the grid with the player's movement rules,
## collecting keys and firing switch / walk-over tags, to prove the exit is
## reachable from the start.
func _validate_path(lv: Level) -> bool:
	var keys := {}
	var tags := {}
	var start := lv.idx_of(lv.cell_of(lv.player_start))
	var key_cells := {}
	for pk in lv.pickups:
		if pk.ptype.begins_with("key_"):
			key_cells[lv.idx_of(lv.cell_of(pk.global_position))] = pk.ptype.substr(4)
	var reached_exit := false
	var seen := {}
	for iteration in 16:
		seen = {start: true}
		var q := [start]
		var changed := false
		while q.size() > 0:
			var c: int = q.pop_front()
			if key_cells.has(c) and not keys.has(key_cells[c]):
				keys[key_cells[c]] = true
				changed = true
			if lv.exit_cells.has(c):
				reached_exit = true
			var trig := int(lv.cells[c].get("trigger", 0))
			if trig != 0 and not tags.has(trig):
				tags[trig] = true
				changed = true
			if lv.teleports.has(c):
				var dst: int = lv.idx_of(lv.cell_of(lv.teleports[c]))
				if not seen.has(dst):
					seen[dst] = true
					q.append(dst)
			var cx := c % lv.W
			var cz := c / lv.W
			for dv in Level.DIRS4:
				var n := lv._idx(cx + dv.x, cz + dv.y)
				if n < 0 or seen.has(n):
					continue
				if lv.use_cells.has(n):
					var u: Dictionary = lv.use_cells[n]
					if u["use"] == "exit":
						reached_exit = true
					elif u["use"] == "switch" and not tags.has(int(u["tag"])):
						tags[int(u["tag"])] = true
						changed = true
					continue
				if lv.player_can_traverse(c, n, keys, tags):
					seen[n] = true
					q.append(n)
		if lv.boss != null:
			tags[99] = true
		if not changed:
			break
	var open_cells := 0
	for i in lv.W * lv.H:
		if lv.solid[i] == 0:
			open_cells += 1
	print("reachable cells: %d / %d open  keys: %s  tags: %s" % [seen.size(), open_cells, keys.keys(), tags.keys()])
	# report unreachable pickups / enemies (often a design mistake)
	for pk in lv.pickups:
		var ci := lv.idx_of(lv.cell_of(pk.global_position))
		if not seen.has(ci):
			print("  unreachable pickup ", pk.ptype, " at ", lv.cell_of(pk.global_position))
	print("EXIT REACHABLE: ", reached_exit)
	return reached_exit


## Save/load round trip: change level state, save, rebuild from the save and
## compare.
func _save_test() -> bool:
	Game.inventory = Game.new_inventory()
	Game.level_index = 0
	var gw := GameWorld.new()
	Game.main.layer.add_child(gw)
	await get_tree().process_frame
	var lv: Level = gw.level
	var target_pos := lv.cell_center(Vector2i(27, 28))
	gw.player.teleport_to(target_pos)
	gw.player.health = 57
	gw.player.keys["red"] = true
	gw.player.weapons.give_weapon("shotgun")
	var victim: Enemy = lv.enemies[0]
	victim.take_damage(9999.0, gw.player, Vector3.FORWARD, "bullet")
	var door: Mover = null
	for m in lv.movers.values():
		if m.kind == "door" and m.key == "" and not m.secret and not m.remote:
			door = m
			break
	door.trigger()
	var door_idx: int = lv.movers.find_key(door)
	for k in 240:
		await get_tree().physics_frame
	var taken: Pickup = lv.pickups[0]
	var taken_id := taken.spawn_id
	gw.player.try_pickup(taken)
	lv.pickups.erase(taken)
	taken.queue_free()
	gw.save_to("slot3")
	var expected_pos := gw.player.global_position
	gw.queue_free()
	await get_tree().process_frame
	var d = Game.read_save("slot3")
	if d == null:
		print("save not written")
		return false
	Game.inventory = Game._fix_inventory(d["inventory"])
	Game.pending_restore = d["level_state"]
	var gw2 := GameWorld.new()
	Game.main.layer.add_child(gw2)
	await get_tree().process_frame
	await get_tree().physics_frame
	var lv2: Level = gw2.level
	var ok := true
	var checks := {
		"position": gw2.player.global_position.distance_to(expected_pos) < 0.5,
		"health": gw2.player.health == 57,
		"red key": gw2.player.has_key("red"),
		"shotgun owned": gw2.player.weapons.owned.has("shotgun"),
		"enemy dead": lv2.enemies[0].dead,
		"kill counted": int(lv2.stats["kills"]) >= 1,
		"door open": lv2.movers[door_idx].state == 2,
	}
	var still_there := false
	for p in lv2.pickups:
		if p.spawn_id == taken_id:
			still_there = true
	checks["pickup gone"] = not still_there
	for k in checks.keys():
		print("  ", k, ": ", "ok" if checks[k] else "FAILED")
		ok = ok and checks[k]
	gw2.queue_free()
	return ok
