class_name Civilian
extends AnimatableBody3D
## The locals: little pastel Gorbinos in smocks and hats who live here and
## would rather not be part of any of this. They stand about in pairs having
## gurgly conversations, say something to you if you get close, scatter
## squealing when the shooting starts and get out of your way. The monsters
## ignore them; your bullets don't.

# what they say to you when you walk up to them
const LINES := {
	"village": ["GORB. YOU ARE VERY TALL. IS IT CATCHING?", "THE WELL HAS BEEN GURGLING MY NAME SINCE TUESDAY. GORB.",
		"I HOPPED INTO TOWN FOR ONE BREAD. THAT WAS FOUR YEARS AGO.", "DON'T EAT THE PURPLE ONES. THAT'S MY COUSIN.",
		"BLORP. SORRY. THAT WAS MY STOMACH. OR MY BROTHER.", "WE HAD A BAKERY. NOW WE HAVE A HOLE. GORB."],
	"industrial": ["GORB. I PACK THE BOXES. I DON'T ASK WHAT'S IN THE BOXES.", "MY SHIFT ENDED IN 1991. NOBODY TOLD ME TO STOP.",
		"THE CHUTE KNOWS MY NAME. IT SAYS IT ALL WET.", "IF YOU SEE THE FOREMAN, I'M A BOX.",
		"I GOT PROMOTED. NOW I'M IN CHARGE OF THE SMELL.", "BLUB. THE MACHINES ARE WARM. I SLEEP IN THE WARM ONE."],
	"mines": ["GORB. SOMETHING DOWN THERE HUMS IN A MAJOR KEY.", "I LICKED THE PURPLE ROCK. NOW I CAN HEAR COLOURS.",
		"MY CANARY DIED. THEN IT CAME BACK ROUND. NOW IT'S A GORBINO.", "DIG DIG DIG. GORB. DIG.",
		"I'VE BEEN DOWN HERE SO LONG MY FEET WENT DARK."],
	"hq": ["GORB. I'M IN A MEETING.", "WE'RE ALL ONE BIG GORBINO FAMILY HERE. THE FAMILY IS ON FIRE.",
		"SYNERGY. SYNERGY. BLORP. SYNERGY.", "MY PENSION IS IN A JAR. SOMETIMES I GO AND LOOK AT IT.",
		"I HAVEN'T SEEN A WINDOW SINCE THE MERGER. IS IT STILL BLUE?", "CAN YOU CIRCLE BACK? I CAN'T STOP CIRCLING BACK. GORB."],
	"facility": ["GORB. I WAS GROWN IN VAT NINE. NINE IS THE GOOD VAT.", "DO YOU HAVE ANY OF MY ORIGINAL PARTS?",
		"THE DOCTOR SAYS I'M PROMISING. I PROMISE.", "I USED TO BE ONE GORBINO. NOW I'M MOSTLY THREE.",
		"PLEASE DON'T TELL THEM I CAN STILL FEEL MY FEET. BLUB."],
	"dimension": ["GORB. YOU'VE BEEN HERE BEFORE. YOU ALWAYS COME BACK.", "I WAS A DOOR ONCE. IT WAS NICE.",
		"THE WALLS ARE SOFT HERE. I LIKE THE WALLS.", "WHICH ONE OF US IS DREAMING? NOT ME. GORB.",
		"THE BIG SNIRBY SINGS US TO SLEEP. WE DON'T SLEEP."],
}
# what they say to each other when you're within earshot (alternating speakers)
const CHATS := {
	"village": [
		["DID YOU HEAR THAT, GORB?", "HEAR WHAT, GORB?", "EXACTLY. GORB."],
		["MY FEET ARE ON BACKWARDS AGAIN.", "WHICH WAY ARE YOU GOING?", "BACKWARDS, GORB."],
		["THE HUMAN HAS A GUN.", "DON'T LOOK AT IT.", "I'M LOOKING AT IT.", "BLORP."],
		["WANT TO HOP TO THE POND LATER?", "THE POND HOPS TO US NOW.", "OH. NICE. GORB."],
	],
	"industrial": [
		["WHAT ARE WE PACKING TODAY?", "GORBINOS.", "WHAT ARE WE?", "...KEEP PACKING."],
		["I PUT MY LUNCH IN THE CHUTE.", "WHY?", "IT LOOKED HUNGRY. GORB."],
		["FOREMAN SAYS WE GET A BREAK SOON.", "HOW SOON?", "HE DIDN'T SAY A YEAR. BLUB."],
		["DO YOU EVER THINK ABOUT THE BOXES?", "I AM THE BOXES.", "GORB. ME TOO."],
	],
	"mines": [
		["FOUND A ROCK.", "WHAT KIND?", "THE KIND THAT BLINKS. GORB."],
		["HOW DEEP DOES IT GO?", "ALL THE WAY TO THE OTHER GORBINOS.", "THERE ARE OTHER GORBINOS?", "ALWAYS. BLORP."],
		["MY LAMP WENT OUT.", "YOUR LAMP IS YOUR EYE, GUS.", "OH. GORB."],
	],
	"hq": [
		["LET'S TAKE THIS OFFLINE.", "WE ARE OFFLINE.", "THEN LET'S TAKE IT ONLINE. GORB."],
		["HAVE YOU SEEN THE QUARTERLY NUMBERS?", "THEY'RE ALL NINE.", "GOOD NUMBER. GORB."],
		["I'VE BEEN PROMOTED TO SENIOR GORBINO.", "WHAT CHANGES?", "I'M ROUNDER NOW. BLUB."],
		["IS THAT HUMAN FROM HR?", "HR IS A GORBINO IN A JAR.", "THEN WHO IS THAT?", "...GORB."],
	],
	"facility": [
		["WHICH VAT ARE YOU FROM?", "THE WARM ONE.", "THEY'RE ALL WARM.", "THEN ALL OF THEM. GORB."],
		["I GREW A NEW FOOT TODAY.", "WHERE?", "DON'T ASK. BLUB."],
		["THE DOCTOR WANTS ANOTHER SAMPLE.", "OF WHAT?", "OF ME. ALL OF ME. GORB."],
	],
	"dimension": [
		["ARE WE STILL GORBINOS HERE?", "WE ARE MORE GORBINO THAN EVER.", "OH NO. GORB."],
		["THE FLOOR IS BREATHING.", "LET IT. IT WORKED HARD.", "BLORP."],
		["I CAN SEE MY OWN BACK.", "THAT'S MY BACK, GORB.", "OH. IT'S NICE."],
	],
}
const PANIC := ["GORB GORB GORB!", "NOT THE FACE! I ONLY HAVE THE ONE!", "BLORP! HELP!", "I'M JUST A LITTLE GUY!",
	"TAKE HIM, HE'S ROUNDER!", "AAAAGORB!"]
const NAMES := ["GLORBO", "BLUBBERT", "GORBERT", "SNORF", "DORBY", "PLUMBO", "GURT", "WEMBO", "NUBBIN", "GLIMP",
	"SPLORBO", "LIL GORB", "OLD GORB", "BRENDA", "FUNGUS", "MR. GORB", "BOBBO", "GUS", "DONK", "SLUMPY"]
const SKINS := ["civ_pink", "civ_mint", "civ_peach", "civ_lilac", "civ_grey"]
const SMOCKS := {
	"village": [Color(0.45, 0.35, 0.2), Color(0.3, 0.45, 0.25), Color(0.6, 0.55, 0.45)],
	"industrial": [Color(1.0, 0.55, 0.05), Color(0.95, 0.85, 0.1)],
	"mines": [Color(0.35, 0.35, 0.38), Color(0.4, 0.3, 0.2)],
	"hq": [Color(0.92, 0.92, 0.9), Color(0.8, 0.85, 0.95)],
	"facility": [Color(0.6, 0.8, 0.85), Color(0.85, 0.9, 0.85)],
	"dimension": [Color(1.0, 0.3, 0.8), Color(0.3, 1.0, 0.8), Color(0.95, 0.95, 0.3)],
}
const CIV_ID := 950000
const SCALE := 0.62

var level: Level
var model: Node3D
var parts: Dictionary
var spawn_id := -1
var who := "GORBINO"
var theme := ""
var lines: Array = []
var line_i := 0
var partner: Civilian = null
var lead := false                 # the one of a pair that starts the conversations
var dead := false
var hp := 30.0
var radius := 0.36
var height := 0.9
var home := Vector3.ZERO
var home_yaw := 0.0
var yaw := 0.0
var panic_t := 0.0
var talk_cd := 0.0
var chat_cd := 0.0
var _chat: Array = []
var _chat_i := 0
var _chat_t := 0.0
var _goal := Vector3.ZERO
var _goal_t := 0.0
var _anim_t := 0.0
var _move := 0.0
var _scan := 0.0
var _death_t := -1.0
var _death_side := 0.0
var _skin_mat: Material
var _flash := 0.0
var _talk_t := 0.0                # mouth flapping while speaking


static func populate(lv: Level) -> void:
	var th := String(lv.data.get("dress", lv.data.get("music", "")))
	if not LINES.has(th):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(lv.data.get("name", "")) + "civ")
	var W: int = lv.W
	# cells the player can walk to
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
	var taken := {}
	for e in lv.entity_specs:
		taken[lv.idx_of(e["cell"])] = true
		if String(e["type"]) in Level.ENEMY_TYPES:
			avoid.append(e["cell"])
	var ok_cell := func(i: int) -> bool:
		if not seen.has(i) or taken.has(i) or lv.movers.has(i) or lv.solid[i] != 0:
			return false
		var sec: Dictionary = lv.cells[i]
		return not sec.get("secret", false) and String(sec.get("liquid", "")) == "" and float(sec.get("damage", 0.0)) <= 0.0
	var cands := []
	for i in seen.keys():
		if not ok_cell.call(i):
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
	var names := NAMES.duplicate()
	var placed := []
	var groups := int(lv.data.get("civilian_pairs", 4))
	var tries := 0
	while placed.size() < groups and not cands.is_empty() and tries < 400:
		tries += 1
		var i: int = cands[rng.randi_range(0, cands.size() - 1)]
		var c := Vector2i(i % W, i / W)
		var spaced := true
		for p in placed:
			if maxi(absi(p.x - c.x), absi(p.y - c.y)) < 7:
				spaced = false
				break
		if not spaced:
			continue
		# a second Gorbino next to the first, so they can talk
		var mate := Vector2i(-1, -1)
		var dirs: Array = Level.DIRS4.duplicate()
		for k in range(dirs.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var tmp = dirs[k]
			dirs[k] = dirs[j]
			dirs[j] = tmp
		for dv in dirs:
			var n := lv._idx(c.x + dv.x, c.y + dv.y)
			if n >= 0 and ok_cell.call(n) and absf(lv.floor_h[n] - lv.floor_h[i]) < 0.3:
				mate = Vector2i(c.x + dv.x, c.y + dv.y)
				break
		placed.append(c)
		var a_pos := lv.cell_center(c)
		var a := _spawn(lv, th, rng, names, a_pos, placed.size() * 2)
		if mate.x >= 0:
			# stand facing each other, a step apart, in the middle of the two cells
			var b_pos := lv.cell_center(mate)
			var mid := (a_pos + b_pos) * 0.5
			var dir := (b_pos - a_pos).normalized()
			a.global_position = mid - dir * 0.55
			a.home = a.global_position
			var b := _spawn(lv, th, rng, names, mid + dir * 0.55, placed.size() * 2 + 1)
			a.home_yaw = atan2(-dir.x, -dir.z)
			b.home_yaw = atan2(dir.x, dir.z)
			a.yaw = a.home_yaw
			b.yaw = b.home_yaw
			a.partner = b
			b.partner = a
			a.lead = true
			a.chat_cd = rng.randf_range(0.5, 3.0)


static func _spawn(lv: Level, th: String, rng: RandomNumberGenerator, names: Array, pos: Vector3, id: int) -> Civilian:
	var cv := Civilian.new()
	cv.spawn_id = CIV_ID + id
	lv.entity_root().add_child(cv)
	var nm := "GORBINO"
	if not names.is_empty():
		nm = names.pop_at(rng.randi_range(0, names.size() - 1))
	cv.setup(lv, pos, th, rng, nm)
	lv.civilians.append(cv)
	return cv


func setup(lv: Level, pos: Vector3, p_theme: String, rng: RandomNumberGenerator, p_name: String) -> void:
	level = lv
	theme = p_theme
	who = p_name
	collision_layer = 32         # shots hit them; you can brush past them
	collision_mask = 0
	sync_to_physics = false
	var skin: String = SKINS[rng.randi_range(0, SKINS.size() - 1)]
	model = Models.gorbino(Color(0.85, 0.82, 0.8), {"skin": skin})
	model.scale = Vector3.ONE * SCALE
	add_child(model)
	parts = model.get_meta("parts")
	_skin_mat = parts.get("skin_mat")
	_clothes(rng)
	_hat(rng.randi_range(0, 5))
	height = Creatures.GORB_H * SCALE
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
	home_yaw = yaw
	rotation.y = yaw
	lines = LINES[theme].duplicate()
	line_i = rng.randi_range(0, lines.size() - 1)
	_anim_t = rng.randf() * 10.0
	talk_cd = rng.randf_range(0.0, 2.0)


## A smock round the belly in the level's work colours.
func _clothes(rng: RandomNumberGenerator) -> void:
	var body: Node3D = parts.get("squash")
	if body == null:
		return
	var cols: Array = SMOCKS.get(theme, [Color(0.6, 0.6, 0.6)])
	var c: Color = cols[rng.randi_range(0, cols.size() - 1)]
	var m := Mat.world("white", {"origin": true, "shade": 0.7, "tint": c})
	var H := Creatures.GORB_H
	body.add_child(Models.mi(Models.cyl(0.47 * H, 0.43 * H, 0.26 * H, 16), m, Vector3(0, 0.2 * H, 0.0)))
	if theme == "industrial":
		body.add_child(Models.mi(Models.cyl(0.475 * H, 0.47 * H, 0.04 * H, 16), Mat.world("white", {"origin": true, "fullbright": 0.5}), Vector3(0, 0.24 * H, 0)))


## Something on the head: flat cap, bowler, bucket, party hat, a sprout, or nothing.
func _hat(kind: int) -> void:
	var head: Node3D = parts.get("squash")
	if head == null:
		return
	var top := (1.0 - Creatures.GORB_SQUASH_Y) * Creatures.GORB_H - 0.12
	var o := {"origin": true, "shade": 0.6}
	match kind:
		0:
			var m := Mat.world("white", o.merged({"tint": Color(0.4, 0.35, 0.3)}))
			var cap := Models.mi(Models.sphere(0.33, 10, 5), m, Vector3(0, top, 0))
			cap.scale = Vector3(1, 0.35, 1.1)
			head.add_child(cap)
			head.add_child(Models.mi(Models.box(0.4, 0.03, 0.22), m, Vector3(0, top - 0.02, -0.33)))
		1:
			var m := Mat.world("black", o.merged({"tint": Color(0.15, 0.12, 0.1)}))
			var dome := Models.mi(Models.sphere(0.25, 10, 5), m, Vector3(0, top + 0.08, 0))
			dome.scale = Vector3(1, 0.85, 1)
			head.add_child(dome)
			head.add_child(Models.mi(Models.cyl(0.36, 0.36, 0.03, 14), m, Vector3(0, top - 0.02, 0)))
		2:
			head.add_child(Models.mi(Models.cyl(0.24, 0.3, 0.34, 10), Mat.world("gun_metal", o.merged({"tint": Color(0.7, 0.75, 0.8)})), Vector3(0, top + 0.12, 0), Vector3(14, 0, 0)))
		3:
			head.add_child(Models.mi(Models.cyl(0.0, 0.17, 0.42, 8), Mat.world("white", o.merged({"tint": Color(1.0, 0.4, 0.7)})), Vector3(0.05, top + 0.2, 0), Vector3(0, 0, -12)))
		4:
			# a little sprout growing out of its head
			var g := Mat.world("white", o.merged({"tint": Color(0.3, 0.75, 0.2)}))
			head.add_child(Models.mi(Models.cyl(0.015, 0.02, 0.2, 5), g, Vector3(0, top + 0.08, 0)))
			var leaf := Models.mi(Models.sphere(0.07, 6, 4), g, Vector3(0.05, top + 0.18, 0))
			leaf.scale = Vector3(1.6, 0.3, 0.8)
			head.add_child(leaf)


func center_point() -> Vector3:
	return global_position + Vector3(0, height * 0.55, 0)


func blood_color() -> Color:
	return Color(0.1, 0.3, 0.05)


func _say(text: String, loud := false) -> void:
	if level.world:
		level.world.say(who, text)
	Audio.play_at("gorb_talk_" + ["a", "b", "c", "d", "e", "f"][randi() % 6], center_point(), 0.0 if loud else -3.0, randf_range(0.9, 1.25))
	_talk_t = clampf(text.length() * 0.06, 0.8, 2.4)


## Gunfire or a death nearby: run.
func panic(from: Vector3) -> void:
	if dead:
		return
	if panic_t <= 0.0:
		_chat = []
		Audio.play_at("gorb_yelp_" + ["a", "b"][randi() % 2], center_point(), -1.0, randf_range(0.9, 1.3))
		if level.world and global_position.distance_to(level.player.global_position) < 12.0 and randf() < 0.5:
			level.world.say(who, PANIC[randi() % PANIC.size()])
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
	if source != null and source == level.player and level.world:
		level.world.hud.hit_marker(hp <= 0.0)
	if hp <= 0.0:
		_die(amount, dir)
	else:
		panic(source.global_position if source is Node3D else global_position - dir)


func _die(amount: float, dir: Vector3, quiet := false) -> void:
	dead = true
	collision_layer = 0
	_chat = []
	var local := global_transform.basis.inverse() * Vector3(dir.x, 0, dir.z).normalized()
	_death_side = signf(local.x) if absf(local.x) > 0.45 else 0.0
	_death_t = 0.0
	if quiet:
		_death_t = 10.0
		Creatures.death_pose(model, 1.0, _death_side)
		return
	Audio.play_at("gorb_yelp_" + ["a", "b"][randi() % 2], center_point(), 0.0, randf_range(1.2, 1.5))
	Fx.blood(level, center_point(), blood_color(), 14, 0.07, (Vector3(dir.x, 0.4, dir.z)).normalized(), 50.0)
	if amount > 60.0:
		Fx.gibs(level, center_point(), Color(0.9, 0.75, 0.8), blood_color(), 6)
		model.visible = false
	Fx.pool(level, Vector3(global_position.x, level.floor_at(global_position), global_position.z), blood_color(), 0.9)
	if partner and is_instance_valid(partner) and not partner.dead and level.world and randf() < 0.7:
		level.world.say(partner.who, [who + "! NOOO! GORB!", "THEY GOT " + who + "!", "I'LL PACK YOUR BOXES, " + who + "..."][randi() % 3])
	# everyone nearby loses it
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
	chat_cd -= delta
	_talk_t -= delta
	var speed := 0.0
	var face := Vector3.ZERO
	if panic_t > 0.0:
		speed = 4.6
		_goal_t -= delta
		if _goal_t <= 0.0 or global_position.distance_to(_goal) < 0.4:
			_pick_flee(pl.global_position)
	else:
		_goal_t -= delta
		if partner == null or not is_instance_valid(partner) or partner.dead:
			# on their own: shuffle about near home
			if _goal_t <= 0.0:
				_goal_t = randf_range(3.0, 7.0)
				var a := randf() * TAU
				var p := home + Vector3(cos(a), 0, sin(a)) * randf_range(0.0, 1.6)
				_goal = p if not level.circle_blocked(p, radius, global_position.y, false, height) else global_position
			speed = 0.9
		else:
			# back to their spot, facing their friend
			_goal = home
			speed = 1.2
			face = partner.global_position - global_position
		_scan -= delta
		if dist < 3.6 and _scan <= 0.0:
			_scan = 0.3
			if talk_cd <= 0.0 and _chat.is_empty() and level.world and level.has_los(center_point(), pl.eye_point()):
				talk_cd = randf_range(7.0, 10.0)
				if partner:
					partner.talk_cd = maxf(partner.talk_cd, 4.0)
				_say(String(lines[line_i % lines.size()]), true)
				line_i += 1
		if dist < 1.7 and dist > 0.01:
			# you're walking into them: shuffle out of the way
			var away := -to_p / dist
			var side := Vector3(-away.z, 0, away.x)
			for cand in [global_position + (away + side) * 1.2, global_position + (away - side) * 1.2, global_position + away * 1.2]:
				if not level.circle_blocked(cand, radius, global_position.y, false, height):
					_goal = cand
					break
			speed = 2.4
		if dist < 6.0:
			face = to_p
		_chat_tick(delta, dist)
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
		if face == Vector3.ZERO or panic_t > 0.0:
			face = d
	if face != Vector3.ZERO:
		yaw = lerp_angle(yaw, atan2(-face.x, -face.z), clampf(delta * 6.0, 0.0, 1.0))
	elif not moving:
		yaw = lerp_angle(yaw, home_yaw, clampf(delta * 2.0, 0.0, 1.0))
	rotation.y = yaw
	_move = move_toward(_move, (1.0 if panic_t > 0.0 else 0.35) if moving else 0.0, delta * 4.0)
	# a talking Gorbino flaps its mouth
	var talking := _talk_t > 0.0 and fmod(_anim_t * 7.0, 1.0) < 0.5
	Creatures.animate(model, _anim_t * (1.8 if panic_t > 0.0 else 1.0), delta, {"move": _move, "pain": panic_t > 0.0 and fmod(_anim_t, 0.6) < 0.1,
		"windup": talking, "blink": fmod(_anim_t, 3.3) < 0.12, "look": model.to_local(pl.global_position + Vector3(0, 1.5, 0))})


## A pair keeps up a conversation while you're in earshot. The lead one
## starts it; lines alternate between the two.
func _chat_tick(delta: float, dist: float) -> void:
	if not lead or partner == null or not is_instance_valid(partner) or partner.dead or partner.panic_t > 0.0:
		_chat = []
		return
	if _chat.is_empty():
		if chat_cd > 0.0 or dist > 11.0 or dist < 3.0 or level.world == null:
			return
		if level.world.hud.subtitle_busy():
			return
		if not (level.has_los(center_point(), level.player.eye_point()) or dist < 6.0):
			return
		var pool: Array = CHATS.get(theme, CHATS["village"])
		_chat = pool[randi() % pool.size()]
		_chat_i = 0
		_chat_t = 0.0
	_chat_t -= delta
	if _chat_t > 0.0:
		return
	if _chat_i >= _chat.size() or dist > 16.0:
		_chat = []
		chat_cd = randf_range(10.0, 18.0)
		return
	var speaker: Civilian = self if _chat_i % 2 == 0 else partner
	var line := String(_chat[_chat_i])
	speaker._say(line)
	_chat_t = 1.4 + line.length() * 0.055
	_chat_i += 1


func serialize() -> Dictionary:
	return {"id": spawn_id, "dead": dead, "x": global_position.x, "y": global_position.y, "z": global_position.z}


func restore(d: Dictionary) -> void:
	global_position = Vector3(float(d["x"]), float(d["y"]), float(d["z"]))
	if d.get("dead", false) and not dead:
		_die(0.0, Vector3.FORWARD, true)
