class_name Contracts
extends RefCounted
## Every level is a contract: one named target, a client, a payout. The
## target is spawned somewhere well into the level with a couple of
## bodyguards, wears something that marks it out, and the exit stays sealed
## until it is dead. Gutting it pays extra.

const LIST := {
	"GORBINO VILLAGE": {
		"name": "MAYOR GLORB", "type": "green", "hat": "tophat", "guards": ["green", "snotling"],
		"crime": "SOLD THE VILLAGE WELLS TO HIMSELF. TWICE. THE WELLS ARE NOW FULL OF GORBINOS.",
		"client": "THE VILLAGE (WHAT IS LEFT OF IT)", "pay": 2400, "id": "0041"},
	"SNIRBY INDUSTRIAL COMPLEX": {
		"name": "FOREMAN SNORBLE", "type": "snirby", "hat": "hardhat", "guards": ["yellow", "yellow"],
		"crime": "FED THREE INTERNS INTO THE PACKING CHUTE FOR MORALE. MORALE IS UP 4%.",
		"client": "SNIRBY INDUSTRIAL, HUMAN RESOURCES", "pay": 3100, "id": "0057"},
	"THE GORBINO MINES": {
		"name": "DEEP GUS", "type": "red", "hat": "miner", "guards": ["snotling", "snotling"],
		"crime": "FOUND SOMETHING AT THE BOTTOM OF SHAFT 9. WILL NOT STOP HUMMING IT.",
		"client": "ANONYMOUS. THE ENVELOPE WAS WET.", "pay": 3600, "id": "0063"},
	"CONSUMER HEADQUARTERS": {
		"name": "CFO BLORBINSON", "type": "blue", "hat": "bowler", "guards": ["yellow", "black"],
		"crime": "MOVED THE ENTIRE PENSION FUND INTO ONE VERY LARGE JAR. THE JAR IS MISSING.",
		"client": "THE BOARD", "pay": 5200, "id": "0088"},
	"THE ENDLESS GORBINO FACILITY": {
		"name": "DR. WEMBLE", "type": "purple", "hat": "goggles", "guards": ["snirby", "green"],
		"crime": "SPLICING SNIRBIES WITH INTERNS. RESULTS: PROMISING. INTERNS: UNAVAILABLE.",
		"client": "THE ETHICS COMMITTEE (DISSOLVED)", "pay": 6100, "id": "0090"},
	"SNIRBY DIMENSION": {
		"name": "THE GREAT SNIRBY", "type": "boss", "hat": "", "guards": [],
		"crime": "IT IS EVERYWHERE. IT IS IN THE PIPES. IT IS THE CLIENT.",
		"client": "YOU", "pay": 9999, "id": "0001"},
}

const TARGET_ID := 900000      # spawn ids for the target and guards (saves)


static func for_level(data: Dictionary) -> Dictionary:
	return LIST.get(String(data.get("name", "")), {})


## Spawn this level's target (or adopt the boss) and its guards.
static func place(level: Node) -> void:
	var c := for_level(level.data)
	if c.is_empty():
		return
	level.contract = c
	if String(c["type"]) == "boss":
		if level.boss != null:
			level.target = level.boss
			level.boss.contract_name = c["name"]
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(c["name"]))
	var cell := _pick_cell(level, rng)
	if cell < 0:
		return
	var W: int = level.W
	var x := cell % W
	var z := cell / W
	var en := Enemy.new()
	en.spawn_id = TARGET_ID
	level.entity_root().add_child(en)
	var face := rng.randf() * TAU
	en.setup(String(c["type"]), level, level.cell_center(Vector2i(x, z)), face)
	en.contract_name = c["name"]
	en.leash = 3.5
	en.home = en.global_position
	en.max_hp *= 2.5
	en.hp = en.max_hp
	level.enemies.append(en)
	level.stats["kills_total"] += 1
	level.target = en
	dress_target(en, c)
	# bodyguards in the neighbouring cells
	var k := 0
	for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if k >= c["guards"].size():
			break
		var n: int = level._idx(x + dv.x, z + dv.y)
		if n < 0 or level.solid[n] != 0 or level.movers.has(n):
			continue
		var g := Enemy.new()
		g.spawn_id = TARGET_ID + 1 + k
		level.entity_root().add_child(g)
		g.setup(String(c["guards"][k]), level, level.cell_center(Vector2i(x + dv.x, z + dv.y)), face)
		level.enemies.append(g)
		level.stats["kills_total"] += 1
		k += 1


## Somewhere between half and nine tenths of the way to the exit, on or near
## the route there (so you run into it rather than having to backtrack), in
## the open, and reachable with every key.
static func _pick_cell(level: Node, rng: RandomNumberGenerator) -> int:
	var keys := {"red": true, "blue": true, "yellow": true}
	var tags := {99: true}
	for t in level.tagged.keys():
		tags[t] = true
	var start: int = level.idx_of(level.cell_of(level.player_start))
	var dist := {start: 0}
	var q := [start]
	var exit_d := -1
	var W: int = level.W
	while q.size() > 0:
		var cur: int = q.pop_front()
		var cx := cur % W
		var cz := cur / W
		if level.exit_cells.has(cur) and exit_d < 0:
			exit_d = dist[cur]
		for dv in Level.DIRS4:
			var n: int = level._idx(cx + dv.x, cz + dv.y)
			if n < 0 or dist.has(n):
				continue
			if level.use_cells.has(n):
				if String(level.use_cells[n]["use"]) == "exit" and exit_d < 0:
					exit_d = dist[cur]
				continue
			if level.player_can_traverse(cur, n, keys, tags):
				dist[n] = dist[cur] + 1
				q.append(n)
	if exit_d < 0:
		exit_d = 0
		for v in dist.values():
			exit_d = maxi(exit_d, int(v))
	# and how far every cell is from the exit, walking the other way
	var back := {}
	var bq := []
	for i in dist.keys():
		if level.exit_cells.has(i):
			back[i] = 0
			bq.append(i)
		else:
			for dv in Level.DIRS4:
				var n: int = level._idx(i % W + dv.x, i / W + dv.y)
				if n >= 0 and level.use_cells.has(n) and String(level.use_cells[n]["use"]) == "exit":
					back[i] = 0
					bq.append(i)
					break
	while bq.size() > 0:
		var cur: int = bq.pop_front()
		for dv in Level.DIRS4:
			var n: int = level._idx(cur % W + dv.x, cur / W + dv.y)
			if n < 0 or back.has(n) or not dist.has(n):
				continue
			if level.player_can_traverse(n, cur, keys, tags):
				back[n] = back[cur] + 1
				bq.append(n)
	var taken := {}
	for e in level.entity_specs:
		taken[level.idx_of(e["cell"])] = true
	var cands := []
	for pass_i in 4:
		var lo: float = [0.5, 0.5, 0.3, 0.0][pass_i]
		var slack: float = [1.15, 1.4, 2.0, 99.0][pass_i]
		for i in dist.keys():
			var d: int = dist[i]
			if d < exit_d * lo or d > exit_d * 0.9 + 2 or taken.has(i) or level.movers.has(i):
				continue
			if d + int(back.get(i, 9999)) > exit_d * slack + 4:
				continue
			var sec: Dictionary = level.cells[i]
			if sec.get("secret", false) or String(sec.get("liquid", "")) != "" or float(sec.get("damage", 0.0)) > 0.0:
				continue
			if level.ceil_h[i] - level.floor_h[i] < 2.6:
				continue
			var open := 0
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var n: int = level._idx(i % W + dx, i / W + dz)
					if n >= 0 and level.solid[n] == 0 and absf(level.floor_h[n] - level.floor_h[i]) < 0.6:
						open += 1
			if open >= 8:
				cands.append(i)
		if not cands.is_empty():
			break
	if cands.is_empty():
		return -1
	cands.sort()
	return cands[rng.randi_range(0, cands.size() - 1)]


# ------------------------------------------------------------------ looks
static func dress_target(en: Node, c: Dictionary) -> void:
	_wear(en.parts, String(c["hat"]))
	var tag := Label3D.new()
	tag.text = String(c["name"])
	tag.font = UI.font("term")
	tag.font_size = 48
	tag.outline_size = 10
	tag.modulate = Color(1.0, 0.15, 0.2)
	tag.outline_modulate = Color(0, 0, 0, 0.9)
	tag.pixel_size = 0.0085
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	tag.position = Vector3(0, float(en.height) * float(en.def.get("scale", 1.0)) + 0.55, 0)
	tag.name = "TargetTag"
	en.add_child(tag)


## What the target wears. Built at creature scale (head radius about 0.5).
static func accessory(kind: String) -> Node3D:
	if kind == "":
		return null
	var root := Node3D.new()
	var o := {"origin": true, "shade": 0.6}
	match kind:
		"tophat":
			var blk := Mat.world("black", o.merged({"tint": Color(0.12, 0.1, 0.12)}))
			root.add_child(Models.mi(Models.cyl(0.42, 0.42, 0.04, 14), blk))
			root.add_child(Models.mi(Models.cyl(0.26, 0.28, 0.55, 14), blk, Vector3(0, 0.3, 0)))
			root.add_child(Models.mi(Models.cyl(0.285, 0.29, 0.09, 14), Mat.world("white", o.merged({"tint": Color(0.75, 0.05, 0.1)})), Vector3(0, 0.08, 0)))
			root.rotation_degrees = Vector3(-8, 0, 10)
		"hardhat":
			var yel := Mat.world("white", o.merged({"tint": Color(1.0, 0.8, 0.05), "gloss": 0.6}))
			var dome := Models.mi(Models.sphere(0.36, 12, 6), yel, Vector3(0, 0.02, 0))
			dome.scale = Vector3(1, 0.7, 1.05)
			root.add_child(dome)
			root.add_child(Models.mi(Models.cyl(0.44, 0.44, 0.03, 14), yel, Vector3(0, -0.02, -0.06)))
			root.add_child(Models.mi(Models.box(0.06, 0.06, 0.74), yel, Vector3(0, 0.25, 0)))
		"miner":
			var hel := Mat.world("gun_dark", o)
			var dome := Models.mi(Models.sphere(0.36, 12, 6), hel, Vector3(0, 0.02, 0))
			dome.scale = Vector3(1, 0.7, 1.05)
			root.add_child(dome)
			root.add_child(Models.mi(Models.cyl(0.08, 0.1, 0.12, 10), Mat.world("gun_metal", o), Vector3(0, 0.12, -0.36), Vector3(90, 0, 0)))
			root.add_child(Models.mi(Models.cyl(0.07, 0.07, 0.02, 10), Mat.world("lamp", {"origin": true, "fullbright": 1.0, "tint": Color(1, 0.95, 0.7)}), Vector3(0, 0.12, -0.43), Vector3(90, 0, 0)))
			var beam := OmniLight3D.new()
			beam.light_color = Color(1, 0.9, 0.6)
			beam.omni_range = 3.0
			beam.light_energy = 0.6
			beam.position = Vector3(0, 0.12, -0.8)
			root.add_child(beam)
		"bowler":
			var blk := Mat.world("black", o.merged({"tint": Color(0.16, 0.13, 0.1)}))
			var dome := Models.mi(Models.sphere(0.27, 12, 6), blk, Vector3(0, 0.12, 0))
			dome.scale = Vector3(1, 0.85, 1)
			root.add_child(dome)
			root.add_child(Models.mi(Models.cyl(0.38, 0.38, 0.03, 14), blk, Vector3(0, 0.0, 0)))
			# gold monocle on a chain, hanging off the brim
			var gold := Mat.world("gun_brass", o.merged({"gloss": 1.0}))
			root.add_child(Models.mi(Models.cyl(0.08, 0.08, 0.015, 12), gold, Vector3(0.2, -0.35, -0.4), Vector3(90, 0, 0)))
			root.add_child(Models.mi(Models.cyl(0.004, 0.004, 0.4, 3), gold, Vector3(0.28, -0.18, -0.3), Vector3(20, 0, 15)))
		"goggles":
			var cap := Mat.world("white", o.merged({"tint": Color(0.55, 0.8, 0.9)}))
			var dome := Models.mi(Models.sphere(0.34, 12, 6), cap, Vector3(0, 0.0, 0))
			dome.scale = Vector3(1, 0.6, 1)
			root.add_child(dome)
			var strap := Mat.world("black", o)
			root.add_child(Models.mi(Models.cyl(0.4, 0.4, 0.06, 16), strap, Vector3(0, -0.12, 0)))
			var lens := Mat.world("white", {"origin": true, "tint": Color(0.3, 1.0, 0.4), "fullbright": 0.8})
			for sx in [-1, 1]:
				root.add_child(Models.mi(Models.cyl(0.11, 0.11, 0.08, 12), Mat.world("gun_brass", o), Vector3(sx * 0.14, -0.1, -0.38), Vector3(90, 0, 0)))
				root.add_child(Models.mi(Models.cyl(0.085, 0.085, 0.02, 12), lens, Vector3(sx * 0.14, -0.1, -0.43), Vector3(90, 0, 0)))
	return root


## A creature in its contract outfit, for the briefing portrait.
static func portrait_model(c: Dictionary) -> Node3D:
	var t := String(c["type"])
	var def: Dictionary = Enemy.TYPES.get(t, {})
	var m: Node3D
	match String(def.get("model", "gorbino")):
		"snirby":
			m = Models.snirby({"tint": def.get("tint", Color(1, 1, 1)), "glow": def.get("glow", false)})
		"snotling":
			m = Models.snotling({"tint": def.get("tint", Color(1, 1, 1))})
		_:
			m = Models.gorbino(def.get("color", Color(0.12, 0.19, 0.06)), {"skin": t, "gun": def.get("gun", false), "glow_eyes": def.get("glow_eyes", false), "launcher": def.get("launcher", false)})
	_wear(m.get_meta("parts"), String(c.get("hat", "")))
	return m


## Put the hat on the top of the head, on the part that squashes with it.
static func _wear(parts: Dictionary, kind: String) -> void:
	var hat := accessory(kind)
	if hat == null:
		return
	match String(parts.get("kind", "")):
		"gorbino":
			hat.position = Vector3(0, (1.0 - Creatures.GORB_SQUASH_Y) * Creatures.GORB_H - 0.1, 0.02)
			parts["squash"].add_child(hat)
		"snirby":
			hat.position = Vector3(0, Creatures.SNIRBY_R * 0.86, 0)
			parts["core"].add_child(hat)
		_:
			hat.position = Vector3(0, 0.42, 0)
			parts["puff"].add_child(hat)
