class_name Civilian
extends AnimatableBody3D
## Bystanders. They stand about muttering to themselves, say something weird
## when you get close, scatter screaming when the shooting starts, and cost
## you money if you kill them. The creatures ignore them.

const LINES := {
	"village": ["THE WELL HAS BEEN SINGING SINCE TUESDAY.", "I SOLD MY LEGS TO THE MAYOR. HE SAID HE NEEDED THEM.",
		"DON'T EAT THE MEAT. OR DO. I'M NOT YOUR DAD.", "HAVE YOU SEEN MY SON? HE'S ROUND. HE HOPS.",
		"THE MAYOR WAVES AT ME FROM THE WELL EVERY NIGHT.", "WE USED TO HAVE A BAKERY. NOW WE HAVE A HOLE."],
	"industrial": ["I'VE BEEN ON BREAK FOR NINE YEARS. NOBODY HAS NOTICED.", "THE CHUTE TALKS TO ME. IT KNOWS MY NAME.",
		"IF YOU SEE THE FOREMAN, I WAS NEVER HERE.", "I PACK THEM. I DON'T ASK WHAT THEY ARE.",
		"MY UNION REP WENT INTO THE CHUTE.", "THE BOXES ARE WARM. WHY ARE THE BOXES WARM."],
	"mines": ["THERE'S SOMETHING DOWN THERE THAT HUMS IN A MAJOR KEY.", "MY CANARY DIED. THEN IT CAME BACK. NOW IT WATCHES.",
		"GUS SAYS THE ROCKS ARE WARM BECAUSE THEY'RE ALIVE.", "I'VE BEEN DIGGING SO LONG I FORGOT WHICH WAY IS UP.",
		"DON'T LICK THE PURPLE ONES. TRUST ME."],
	"hq": ["I'M IN A MEETING.", "WE'RE A FAMILY HERE. THE FAMILY IS ON FIRE.", "SYNERGY. SYNERGY. SYNERGY.",
		"I HAVEN'T SEEN A WINDOW SINCE THE MERGER.", "THE CFO PUT MY PENSION IN A JAR. SOMETIMES I SEE IT. IT'S BEAUTIFUL.",
		"CAN YOU CIRCLE BACK? I CAN'T STOP CIRCLING BACK."],
	"facility": ["I VOLUNTEERED. I DON'T REMEMBER VOLUNTEERING.", "DO YOU HAVE ANY OF MY ORIGINAL PARTS?",
		"THE DOCTOR SAYS I'M PROMISING.", "PLEASE DON'T TELL THEM I CAN STILL FEEL MY FEET.",
		"I USED TO BE TALLER. AND ONE PERSON."],
	"dimension": ["YOU'VE BEEN HERE BEFORE. YOU ALWAYS COME BACK.", "I WAS A DOOR ONCE.", "IT'S NICE HERE. THE WALLS ARE SOFT.",
		"THE CLIENT IS WATCHING. WAVE.", "WHICH ONE OF US IS DREAMING?"],
}
const PANIC := ["AAAAAAA!", "NOT THE FACE!", "I HAVE A FAMILY! THEY'RE ALSO HERE!", "TAKE THE INTERN!", "I'M JUST A GUY!"]
const TITLES := {"village": "VILLAGER", "industrial": "PACKER", "mines": "MINER", "hq": "ASSOCIATE",
	"facility": "TEST SUBJECT", "dimension": "SOMEONE"}
const TINTS := [Color(0.85, 0.85, 0.8), Color(0.75, 0.8, 0.95), Color(0.95, 0.8, 0.6), Color(0.7, 0.9, 0.75), Color(0.9, 0.7, 0.8)]
const CIV_ID := 950000

var level: Level
var model: Node3D
var parts: Dictionary
var spawn_id := -1
var title := "BYSTANDER"
var lines: Array = []
var line_i := 0
var dead := false
var hp := 30.0
var radius := 0.4
var height := 1.0
var home := Vector3.ZERO
var yaw := 0.0
var panic_t := 0.0
var talk_cd := 0.0
var _goal := Vector3.ZERO
var _goal_t := 0.0
var _anim_t := 0.0
var _move := 0.0
var _scan := 0.0
var _death_t := -1.0
var _death_side := 0.0
var _skin_mat: Material
var _flash := 0.0


static func populate(lv: Level) -> void:
	var theme := String(lv.data.get("dress", lv.data.get("music", "")))
	if not LINES.has(theme):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(lv.data.get("name", "")) + "civ")
	var W: int = lv.W
	# reachable cells, the way the player walks
	var keys := {"red": true, "blue": true, "yellow": true}
	var tags := {99: true}
	for t in lv.tagged.keys():
		tags[t] = true
	var start := lv.idx_of(lv.cell_of(lv.player_start))
	var seen := {start: true}
	var q := [start]
	while q.size() > 0:
		var c: int = q.pop_front()
		for dv in Level.DIRS4:
			var n := lv._idx(c % W + dv.x, c / W + dv.y)
			if n >= 0 and not seen.has(n) and not lv.use_cells.has(n) and lv.player_can_traverse(c, n, keys, tags):
				seen[n] = true
				q.append(n)
	var avoid := []
	for e in lv.entity_specs:
		if String(e["type"]) in Level.ENEMY_TYPES:
			avoid.append(e["cell"])
	if lv.target != null:
		avoid.append(lv.cell_of(lv.target.global_position))
	var taken := {}
	for e in lv.entity_specs:
		taken[lv.idx_of(e["cell"])] = true
	var cands := []
	for i in seen.keys():
		if taken.has(i) or lv.movers.has(i) or lv.solid[i] != 0:
			continue
		var sec: Dictionary = lv.cells[i]
		if sec.get("secret", false) or String(sec.get("liquid", "")) != "" or float(sec.get("damage", 0.0)) > 0.0:
			continue
		var c := Vector2i(i % W, i / W)
		var far := true
		for a in avoid:
			if maxi(absi(a.x - c.x), absi(a.y - c.y)) < 4:
				far = false
				break
		if far:
			cands.append(i)
	cands.sort()
	var placed := []
	var want := int(lv.data.get("civilians", 6))
	var tries := 0
	while placed.size() < want and not cands.is_empty() and tries < 400:
		tries += 1
		var i: int = cands[rng.randi_range(0, cands.size() - 1)]
		var c := Vector2i(i % W, i / W)
		var ok := true
		for p in placed:
			if maxi(absi(p.x - c.x), absi(p.y - c.y)) < 6:
				ok = false
				break
		if not ok:
			continue
		placed.append(c)
		var cv := Civilian.new()
		cv.spawn_id = CIV_ID + placed.size()
		lv.entity_root().add_child(cv)
		cv.setup(lv, lv.cell_center(c), theme, rng)
		lv.civilians.append(cv)


func setup(lv: Level, pos: Vector3, theme: String, rng: RandomNumberGenerator) -> void:
	level = lv
	collision_layer = 32         # shots hit them; you can brush past them
	collision_mask = 0
	sync_to_physics = false
	var big := rng.randf() < 0.3
	var tint: Color = TINTS[rng.randi_range(0, TINTS.size() - 1)]
	if big:
		model = Models.snirby({"tint": tint})
		model.scale = Vector3.ONE * 0.8
		height = 1.1
		radius = 0.42
	else:
		model = Models.snotling({"tint": tint})
		model.scale = Vector3.ONE * 0.9
		height = 0.95
		radius = 0.38
	add_child(model)
	parts = model.get_meta("parts")
	_skin_mat = parts.get("skin_mat")
	_clothes(theme, rng)
	_dress(rng.randi_range(0, 4))
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(height, radius * 2.0 + 0.01)
	cs.shape = cap
	cs.position = Vector3(0, height * 0.5, 0)
	add_child(cs)
	global_position = pos
	home = pos
	_goal = pos
	yaw = rng.randf() * TAU
	rotation.y = yaw
	title = TITLES.get(theme, "BYSTANDER")
	lines = LINES[theme].duplicate()
	line_i = rng.randi_range(0, lines.size() - 1)
	_anim_t = rng.randf() * 10.0
	talk_cd = rng.randf_range(0.0, 2.0)


const SMOCKS := {
	"village": [Color(0.45, 0.35, 0.2), Color(0.3, 0.45, 0.25), Color(0.6, 0.55, 0.45)],
	"industrial": [Color(1.0, 0.55, 0.05), Color(0.95, 0.85, 0.1)],
	"mines": [Color(0.35, 0.35, 0.38), Color(0.4, 0.3, 0.2)],
	"hq": [Color(0.92, 0.92, 0.9), Color(0.8, 0.85, 0.95)],
	"facility": [Color(0.6, 0.8, 0.85), Color(0.85, 0.9, 0.85)],
	"dimension": [Color(1.0, 0.3, 0.8), Color(0.3, 1.0, 0.8), Color(0.95, 0.95, 0.3)],
}


## Work clothes in the level's colours: the quickest way to tell a person
## from a monster at a glance.
func _clothes(theme: String, rng: RandomNumberGenerator) -> void:
	var body: Node3D = parts.get("core", parts.get("puff"))
	if body == null:
		return
	var cols: Array = SMOCKS.get(theme, [Color(0.6, 0.6, 0.6)])
	var c: Color = cols[rng.randi_range(0, cols.size() - 1)]
	var m := Mat.world("dr_fabric", {"origin": true, "shade": 0.7, "tint": c * 1.6})
	var snot := String(parts.get("kind", "")) == "snotling"
	var r := 0.5 if snot else Creatures.SNIRBY_R
	var smock := Models.mi(Models.cyl(r * 0.92, r * 1.06, r * 0.75, 14), m, Vector3(0, -r * 0.38, 0))
	body.add_child(smock)
	if theme == "industrial":
		# reflective stripes on the hi-vis vest
		body.add_child(Models.mi(Models.cyl(r * 1.0, r * 1.02, 0.05, 14), Mat.world("white", {"origin": true, "fullbright": 0.5}), Vector3(0, -r * 0.3, 0)))


## Something to wear, so they read as people rather than monsters.
func _dress(kind: int) -> void:
	var head: Node3D = parts.get("core", parts.get("puff"))
	if head == null:
		return
	var top := 0.42 if parts.get("kind", "") == "snotling" else Creatures.SNIRBY_R * 0.86
	var o := {"origin": true, "shade": 0.6}
	match kind:
		0:  # flat cap
			var m := Mat.world("dr_fabric", o.merged({"tint": Color(0.45, 0.4, 0.35)}))
			var cap := Models.mi(Models.sphere(0.3, 10, 5), m, Vector3(0, top, 0))
			cap.scale = Vector3(1, 0.35, 1.1)
			head.add_child(cap)
			head.add_child(Models.mi(Models.box(0.36, 0.03, 0.2), m, Vector3(0, top - 0.02, -0.3)))
		1:  # tie
			var tie := Mat.world("white", o.merged({"tint": [Color(0.8, 0.1, 0.1), Color(0.1, 0.2, 0.7), Color(0.2, 0.6, 0.2)][randi() % 3]}))
			head.add_child(Models.mi(Models.box(0.1, 0.32, 0.03), tie, Vector3(0, -0.18, -0.47), Vector3(-15, 0, 0)))
			head.add_child(Models.mi(Models.box(0.12, 0.07, 0.04), tie, Vector3(0, -0.02, -0.48)))
		2:  # glasses
			var fr := Mat.world("black", o)
			for sx in [-1, 1]:
				head.add_child(Models.mi(Models.cyl(0.09, 0.09, 0.02, 10), fr, Vector3(sx * 0.15, 0.08, -0.47), Vector3(90, 0, 0)))
			head.add_child(Models.mi(Models.box(0.12, 0.02, 0.02), fr, Vector3(0, 0.1, -0.48)))
		3:  # a bucket on its head
			var b := Mat.world("gun_metal", o.merged({"tint": Color(0.7, 0.75, 0.8)}))
			head.add_child(Models.mi(Models.cyl(0.22, 0.28, 0.32, 10), b, Vector3(0, top + 0.08, 0), Vector3(12, 0, 0)))
		_:  # paper party hat
			var h := Mat.world("white", o.merged({"tint": Color(1.0, 0.4, 0.7)}))
			head.add_child(Models.mi(Models.cyl(0.0, 0.16, 0.4, 8), h, Vector3(0.05, top + 0.16, 0), Vector3(0, 0, -12)))


func center_point() -> Vector3:
	return global_position + Vector3(0, height * 0.55, 0)


func blood_color() -> Color:
	return Color(0.55, 0.0, 0.05)


## Gunfire or a death nearby: run.
func panic(from: Vector3) -> void:
	if dead:
		return
	if panic_t <= 0.0:
		Audio.play_at("civ_scream_" + ["a", "b"][randi() % 2], center_point(), -2.0, randf_range(0.9, 1.25))
		if level.world and global_position.distance_to(level.player.global_position) < 12.0 and randf() < 0.6:
			level.world.say(title, PANIC[randi() % PANIC.size()])
	panic_t = randf_range(5.0, 8.0)
	_pick_flee(from)


func _pick_flee(from: Vector3) -> void:
	var best := global_position
	var bd := -1.0
	for k in 10:
		var a := randf() * TAU
		var p := global_position + Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 7.0)
		if level.circle_blocked(p, radius, global_position.y, false, height):
			continue
		var d := p.distance_to(from)
		if d > bd:
			bd = d
			best = p
	_goal = best
	_goal_t = randf_range(1.0, 2.0)


func take_damage(amount: float, source: Node, dir: Vector3, kind := "bullet") -> void:
	if dead:
		return
	hp -= amount
	_flash = 0.7
	if _skin_mat:
		_skin_mat.set_shader_parameter("flash", _flash)
	Fx.blood(level, center_point() - dir * 0.2, blood_color(), clampi(int(amount / 6.0), 3, 10))
	var by_player: bool = source != null and source == level.player
	if by_player and level.world:
		level.world.hud.hit_marker(hp <= 0.0)
	if hp <= 0.0:
		_die(amount, dir, by_player)
	else:
		panic(source.global_position if source is Node3D else global_position - dir)


func _die(amount: float, dir: Vector3, by_player: bool, quiet := false) -> void:
	dead = true
	collision_layer = 0
	var local := global_transform.basis.inverse() * Vector3(dir.x, 0, dir.z).normalized()
	_death_side = signf(local.x) if absf(local.x) > 0.45 else 0.0
	_death_t = 0.0
	if quiet:
		_death_t = 10.0
		Creatures.death_pose(model, 1.0, _death_side)
		return
	Audio.play_at("civ_scream_" + ["a", "b"][randi() % 2], center_point(), 0.0, randf_range(1.2, 1.5))
	Fx.blood(level, center_point(), blood_color(), 14, 0.07, (Vector3(dir.x, 0.4, dir.z)).normalized(), 50.0)
	if amount > 60.0:
		Fx.gibs(level, center_point(), Color(0.9, 0.7, 0.75), blood_color(), 6)
		model.visible = false
	Fx.pool(level, Vector3(global_position.x, level.floor_at(global_position), global_position.z), blood_color(), 0.9)
	if by_player:
		level.stats["civilians"] = int(level.stats.get("civilians", 0)) + 1
		if level.world:
			level.world.hud.message("COLLATERAL  -$250")
	# the others nearby lose it
	for c in level.civilians:
		if c != self and is_instance_valid(c) and c.global_position.distance_to(global_position) < 14.0:
			c.panic(global_position)


func _physics_process(delta: float) -> void:
	if level == null or level.player == null:
		return
	_anim_t += delta
	if _flash > 0.0 and _skin_mat:
		_flash = maxf(0.0, _flash - delta * 6.0)
		_skin_mat.set_shader_parameter("flash", _flash)
	if dead:
		if _death_t < 1.0:
			_death_t += delta
			Creatures.death_pose(model, clampf(_death_t / 0.5, 0.0, 1.0), _death_side)
		return
	var pl: Player = level.player
	var to_p := pl.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	panic_t -= delta
	talk_cd -= delta
	var speed := 0.0
	if panic_t > 0.0:
		speed = 4.6
		_goal_t -= delta
		if _goal_t <= 0.0 or global_position.distance_to(_goal) < 0.4:
			_pick_flee(pl.global_position)
	else:
		# shuffle about near home, turn to look at you, and talk when you're close
		_goal_t -= delta
		if _goal_t <= 0.0:
			_goal_t = randf_range(3.0, 7.0)
			var a := randf() * TAU
			var p := home + Vector3(cos(a), 0, sin(a)) * randf_range(0.0, 1.6)
			_goal = p if not level.circle_blocked(p, radius, global_position.y, false, height) else global_position
		speed = 0.9
		_scan -= delta
		if dist < 4.5 and _scan <= 0.0:
			_scan = 0.3
			if talk_cd <= 0.0 and level.world and level.has_los(center_point(), pl.eye_point()):
				talk_cd = randf_range(7.0, 10.0)
				level.world.say(title, String(lines[line_i % lines.size()]))
				line_i += 1
				Audio.play_at("civ_mumble_" + ["a", "b", "c"][randi() % 3], center_point(), -2.0, randf_range(0.85, 1.2))
		if dist < 1.7 and dist > 0.01:
			# you're walking into them: shuffle out of the way
			var away := -to_p / dist
			var side := Vector3(-away.z, 0, away.x)
			for cand in [global_position + (away + side) * 1.2, global_position + (away - side) * 1.2, global_position + away * 1.2]:
				if not level.circle_blocked(cand, radius, global_position.y, false, height):
					_goal = cand
					break
			speed = 2.4
		elif dist < 4.5:
			_goal = global_position
	var d := _goal - global_position
	d.y = 0.0
	var moving := d.length() > 0.15
	if moving:
		var step := d.normalized() * minf(speed * delta, d.length())
		var np := global_position + step
		if not level.circle_blocked(np, radius, global_position.y, false, height):
			np.y = level.floor_at(np)
			global_position = np
		else:
			_goal_t = 0.0
		yaw = lerp_angle(yaw, atan2(-d.x, -d.z), clampf(delta * 8.0, 0.0, 1.0))
	elif dist < 6.0:
		yaw = lerp_angle(yaw, atan2(-to_p.x, -to_p.z), clampf(delta * 4.0, 0.0, 1.0))
	rotation.y = yaw
	_move = move_toward(_move, (1.0 if panic_t > 0.0 else 0.4) if moving else 0.0, delta * 4.0)
	Creatures.animate(model, _anim_t * (1.8 if panic_t > 0.0 else 1.0), delta, {"move": _move, "pain": panic_t > 0.0 and fmod(_anim_t, 0.6) < 0.1,
		"blink": fmod(_anim_t, 3.3) < 0.12, "look": model.to_local(pl.global_position + Vector3(0, 1.5, 0))})


func serialize() -> Dictionary:
	return {"id": spawn_id, "dead": dead, "x": global_position.x, "y": global_position.y, "z": global_position.z}


func restore(d: Dictionary) -> void:
	global_position = Vector3(float(d["x"]), float(d["y"]), float(d["z"]))
	if d.get("dead", false) and not dead:
		_die(0.0, Vector3.FORWARD, false, true)
