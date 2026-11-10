class_name Dressing
extends RefCounted
## Set dressing. Fills every level with things that make it a place: desks,
## lockers, crates, vending machines, specimen tanks, flesh growths, posters,
## signs, graffiti, litter on the floor and junk hanging off the ceiling.
##
## Everything is generated straight into one merged mesh (a surface per
## material) plus one static body of boxes, so hundreds of props cost a
## handful of draw calls. Props only go against walls where the space is at
## least two cells wide and stay inside a 0.55 m strip, so they never close a
## path; nothing lands next to doors, switches, pickups, keys or the exit.
## The layout is seeded from the level name, so it is the same every time.

const DEPTH_MAX := 0.55
const SKIP_WALL := ["door", "switch", "exit", "window", "elevator", "teleport", "poster", "sign", "logo",
	"glyph", "eyes", "vat", "computer", "lantern", "crystal", "light"]

const POSTERS := {
	"village": ["dr_poster_missing", "dr_poster_meat", "dr_poster_report", "dr_poster_smile", "dr_poster_hydrate", "v_poster"],
	"industrial": ["dr_poster_safety", "dr_poster_norun", "dr_poster_pipes", "dr_poster_wage", "dr_poster_meat", "dr_poster_dontlook", "dr_poster_consume"],
	"mines": ["dr_poster_safety", "dr_poster_missing", "dr_poster_pipes", "dr_poster_dontlook", "dr_poster_report"],
	"hq": ["dr_poster_consume", "dr_poster_employee", "dr_poster_wage", "dr_poster_buysell", "dr_poster_smile", "dr_poster_hydrate",
		"h_poster1", "h_poster2", "h_poster3", "h_poster4"],
	"facility": ["dr_poster_norun", "dr_poster_safety", "dr_poster_missing", "dr_poster_dontlook", "dr_poster_employee", "dr_poster_report"],
	"dimension": ["dr_poster_exit", "dr_poster_visit", "dr_poster_smile", "dr_poster_dontlook", "dr_poster_consume", "dr_poster_employee"],
}
const SIGNS := {
	"village": ["dr_sign_welcome", "dr_sign_quiet"],
	"industrial": ["dr_sign_chute", "dr_sign_max", "dr_sign_wash", "dr_sign_breakroom"],
	"mines": ["dr_sign_shaft", "dr_sign_canary", "dr_sign_max"],
	"hq": ["dr_sign_accounting", "dr_sign_regret", "dr_sign_breakroom", "dr_sign_quiet", "dr_sign_wash"],
	"facility": ["dr_sign_contain", "dr_sign_dontfeed", "dr_sign_wash", "dr_sign_regret"],
	"dimension": ["dr_sign_wrongway", "dr_sign_you", "dr_sign_regret", "dr_sign_welcome"],
}
const GRAFFITI := ["dr_graf_help", "dr_graf_gorb", "dr_graf_hops", "dr_graf_snirb", "dr_graf_nope", "dr_graf_eye"]

# props per theme: [name, weight]
const PROPS := {
	"village_out": [["bench", 3], ["planter", 3], ["trashcan", 3], ["crates", 2], ["woodpile", 2], ["barrel_wood", 2], ["mailbox", 1], ["boxes", 1], ["trash", 2]],
	"village_in": [["shelf", 3], ["dresser", 2], ["tv", 2], ["chair", 2], ["boxes", 2], ["toilet", 1], ["planter", 1], ["trash", 1], ["cot", 2]],
	"industrial": [["crates", 4], ["lockers", 2], ["gas", 2], ["panel", 3], ["drums", 3], ["workbench", 2], ["boxes", 2], ["pipe", 2], ["trash", 2], ["toilet", 1]],
	"mines": [["beam", 4], ["ore", 3], ["cart", 2], ["dynamite", 2], ["barrel_wood", 2], ["lantern", 3], ["bones", 2], ["crates", 2], ["tools", 2]],
	"hq": [["desk", 5], ["cabinet", 3], ["plant", 3], ["vending", 2], ["bookshelf", 3], ["cooler", 2], ["copier", 1], ["couch", 2], ["boxes", 1], ["tv", 1]],
	"facility": [["labbench", 4], ["tank", 3], ["monitors", 3], ["gurney", 2], ["cabinet", 2], ["cage", 2], ["drums", 2], ["pipe", 2], ["lockers", 1]],
	"dimension": [["growth", 4], ["teeth", 2], ["stalk", 3], ["idol", 2], ["tv", 2], ["doorway", 2], ["toilet", 1], ["clock", 2], ["growth", 2]],
}
# centrepieces for the middle of big rooms (they take the whole cell)
const ISLANDS := {
	"village_out": [["well", 2], ["stall", 2], ["haycart", 2], ["stump", 2], ["barrels", 2]],
	"village_in": [["dining", 3], ["bed", 2], ["stove", 1]],
	"industrial": [["pallets", 3], ["forklift", 2], ["machine", 3], ["spool", 2], ["drumstack", 2]],
	"mines": [["orepile", 3], ["campfire", 2], ["cartrail", 2], ["cratepile", 2]],
	"hq": [["conference", 3], ["reception", 1], ["lounge", 3], ["mascot", 1], ["planters", 2]],
	"facility": [["surgery", 3], ["bigtank", 2], ["servers", 3], ["cryo", 2]],
	"dimension": [["bigeye", 2], ["fleshpillar", 3], ["floatjunk", 2], ["tub", 2], ["car", 1], ["teethpile", 2]],
}
const CLUTTER := {
	"village": ["leaves", "paper", "can", "stain", "bottle"],
	"industrial": ["paper", "can", "stain", "bolts", "bottle", "stain"],
	"mines": ["rubble", "bones", "rubble", "stain", "bottle"],
	"hq": ["paper", "paper", "can", "stain", "cup"],
	"facility": ["paper", "syringe", "stain", "stain", "cup"],
	"dimension": ["eye", "bones", "stain", "teeth", "paper"],
}
const HANG := {
	"village": ["bulb"],
	"industrial": ["carcass", "chain", "bulb", "carcass", "cable"],
	"mines": ["roots", "bulb", "rope"],
	"hq": ["tube", "tube", "cable"],
	"facility": ["tube", "cable", "tube", "bulb"],
	"dimension": ["tendril", "tendril", "eyeball", "chain"],
}

var level: Node
var theme := ""
var rng := RandomNumberGenerator.new()
var _surf := {}          # material key -> {"mat", "v", "n", "uv"}
var _boxes := []          # [Transform3D, Vector3 size]
var _xf := Transform3D.IDENTITY
var _taken := {}
var _island := {}
var _spots := []          # [position, facing] of props worth a look (debug tour)
var _count := 0


static func dress(lv: Node) -> void:
	var d := Dressing.new()
	d.level = lv
	d._run()


func _run() -> void:
	theme = String(level.data.get("dress", level.data.get("music", "")))
	if not PROPS.has(theme) and not PROPS.has(theme + "_out"):
		return
	rng.seed = hash(String(level.data.get("name", "")))
	for e in level.entity_specs:
		_taken[level.idx_of(e["cell"])] = true
	for i in level.exit_cells.keys():
		_taken[i] = true
	for i in level.teleports.keys():
		_taken[i] = true
	var dens: float = level.data.get("dress_density", 1.0)
	var W: int = level.W
	var H: int = level.H
	_islands(dens)
	for z in H:
		for x in W:
			var i: int = z * W + x
			if not _floor_ok(i):
				continue
			var near_door := false
			for dv in Level.DIRS4:
				var n: int = level._idx(x + dv.x, z + dv.y)
				if n >= 0 and (level.movers.has(n) or level.use_cells.has(n)):
					near_door = true
			var f: float = level.floor_h[i]
			var clear: float = level.ceil_h[i] - f
			var sky := String(level.cells[i].get("ctex", "")) == "SKY"
			# --- against the walls
			var dirs: Array = Level.DIRS4.duplicate()
			_shuffle(dirs)
			var props_here := 0
			for dv in dirs:
				var n: int = level._idx(x + dv.x, z + dv.y)
				if n < 0 or level.solid[n] != 1 or _island.has(n) or not _wall_ok(n):
					continue
				var o: int = level._idx(x - dv.x, z - dv.y)
				var roomy: bool = o >= 0 and level.solid[o] == 0 and not level.movers.has(o) and absf(level.floor_h[o] - f) < 0.05
				var tall := false
				if roomy and not near_door and not _taken.has(i) and props_here < 1 and rng.randf() < 0.42 * dens:
					var h := _place_prop(x, z, dv, f, clear, sky)
					if h > 0.0:
						props_here += 1
						tall = h > 1.25
				if not tall and clear >= 2.5 and rng.randf() < 0.15 * dens:
					_wall_decor(x, z, dv, f, clear, sky)
			# --- litter on the floor
			if not level.movers.has(i) and rng.randf() < 0.2 * dens:
				_clutter(x, z, f)
			# --- junk hanging off the ceiling
			if not sky and clear >= 3.6 and rng.randf() < 0.07 * dens:
				_hang(x, z, f, level.ceil_h[i])
	_commit()
	level.set_meta("dress_spots", _spots)
	level.set_meta("dress_count", _count)


func _floor_ok(i: int) -> bool:
	if level.solid[i] != 0 or level.movers.has(i):
		return false
	var sec: Dictionary = level.cells[i]
	if String(sec.get("liquid", "")) != "" or float(sec.get("damage", 0.0)) > 0.0:
		return false
	return true


func _wall_ok(n: int) -> bool:
	if level.use_cells.has(n) or level.cells[n].has("use"):
		return false
	var wt := String(level.cells[n].get("wall", ""))
	for s in SKIP_WALL:
		if wt.find(s) >= 0:
			return false
	return true


func _shuffle(a: Array) -> void:
	for k in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var t = a[k]
		a[k] = a[j]
		a[j] = t


func _pick(list: Array) -> String:
	var tot := 0.0
	for e in list:
		tot += float(e[1])
	var r := rng.randf() * tot
	for e in list:
		r -= float(e[1])
		if r <= 0.0:
			return e[0]
	return list[0][0]


func _one(list: Array):
	return list[rng.randi_range(0, list.size() - 1)]


## Frame for something standing against the wall on side dv of cell (x, z):
## local +Z points out into the room, the wall is behind at z = -depth/2.
func _wall_frame(x: int, z: int, dv: Vector2i, f: float, depth: float, width: float, height_up := 0.0) -> Transform3D:
	var S: float = Level.S
	var c := Vector3((x + 0.5) * S, f + height_up, (z + 0.5) * S)
	var out := Vector3(-dv.x, 0, -dv.y)
	var side := Vector3(-out.z, 0, out.x)
	var slack := maxf(0.0, S * 0.5 - width * 0.5 - 0.08)
	var pos := c - out * (S * 0.5 - depth * 0.5 - 0.03) + side * rng.randf_range(-slack, slack)
	var yaw := atan2(out.x, out.z)
	return Transform3D(Basis(Vector3.UP, yaw), pos)


# ================================================================== props
## Builds a prop against the wall; returns its height (0 = nothing placed).
func _place_prop(x: int, z: int, dv: Vector2i, f: float, clear: float, sky: bool) -> float:
	var key := theme
	if theme == "village":
		key = "village_out" if sky else "village_in"
	var name := _pick(PROPS[key])
	var spec := _prop_size(name, clear)
	if spec == Vector3.ZERO:
		return 0.0
	var w: float = spec.x
	var h: float = spec.y
	var d: float = minf(spec.z, DEPTH_MAX)
	if h + 0.15 > clear:
		return 0.0
	_xf = _wall_frame(x, z, dv, f, d, w)
	_build(name, w, h, d, clear)
	if _solid_prop(name):
		_boxes.append([_xf * Transform3D(Basis(), Vector3(0, h * 0.5, 0)), Vector3(w, h, d), false])
	_spots.append([_xf.origin, name])
	_count += 1
	return h


func _solid_prop(name: String) -> bool:
	return not name in ["trash", "tools", "bones", "planter_small"]


func _prop_size(name: String, clear: float) -> Vector3:
	match name:
		"bench": return Vector3(1.6, 0.85, 0.5)
		"planter": return Vector3(0.6, 1.1, 0.5)
		"trashcan": return Vector3(0.55, 0.9, 0.5)
		"crates": return Vector3(1.2, 1.6, 0.55)
		"woodpile": return Vector3(1.4, 0.8, 0.5)
		"barrel_wood": return Vector3(0.6, 1.0, 0.55)
		"mailbox": return Vector3(0.4, 1.2, 0.35)
		"boxes": return Vector3(1.0, 1.1, 0.55)
		"trash": return Vector3(1.0, 0.6, 0.55)
		"shelf": return Vector3(1.2, 1.9, 0.4)
		"dresser": return Vector3(1.0, 1.0, 0.5)
		"tv": return Vector3(0.7, 1.15, 0.5)
		"chair": return Vector3(0.5, 0.95, 0.5)
		"toilet": return Vector3(0.5, 0.85, 0.55)
		"cot": return Vector3(1.8, 0.55, 0.55)
		"lockers": return Vector3(1.0, 2.0, 0.5)
		"gas": return Vector3(0.9, 1.5, 0.4)
		"panel": return Vector3(1.0, 1.4, 0.5)
		"drums": return Vector3(1.2, 1.0, 0.55)
		"workbench": return Vector3(1.6, 1.3, 0.55)
		"pipe": return Vector3(0.4, minf(clear, 9.0), 0.35)
		"beam": return Vector3(0.45, minf(clear, 6.0), 0.4)
		"ore": return Vector3(1.2, 0.8, 0.55)
		"cart": return Vector3(1.3, 1.0, 0.55)
		"dynamite": return Vector3(0.8, 0.75, 0.5)
		"lantern": return Vector3(0.4, 1.9, 0.35)
		"bones": return Vector3(1.0, 0.4, 0.55)
		"tools": return Vector3(0.8, 1.3, 0.3)
		"desk": return Vector3(1.5, 1.25, 0.55)
		"cabinet": return Vector3(0.6, 1.3, 0.5)
		"plant": return Vector3(0.6, 1.7, 0.5)
		"vending": return Vector3(1.0, 2.0, 0.55)
		"bookshelf": return Vector3(1.4, 2.0, 0.4)
		"cooler": return Vector3(0.45, 1.45, 0.45)
		"copier": return Vector3(0.9, 1.1, 0.55)
		"couch": return Vector3(1.9, 0.9, 0.55)
		"labbench": return Vector3(1.6, 1.25, 0.55)
		"tank": return Vector3(0.9, 2.4, 0.55)
		"monitors": return Vector3(1.4, 1.7, 0.5)
		"gurney": return Vector3(1.8, 0.95, 0.55)
		"cage": return Vector3(0.9, 1.3, 0.55)
		"growth": return Vector3(1.2, 1.3, 0.55)
		"teeth": return Vector3(0.6, minf(clear, 3.5), 0.5)
		"stalk": return Vector3(0.5, 2.2, 0.5)
		"idol": return Vector3(0.7, 1.6, 0.55)
		"doorway": return Vector3(1.2, 2.4, 0.2)
		"clock": return Vector3(0.5, 2.0, 0.35)
	return Vector3.ZERO


func _build(name: String, w: float, h: float, d: float, clear: float) -> void:
	var bz := -d * 0.5          # the wall side
	match name:
		"bench":
			var wood := "gun_wood"
			for k in 3:
				_box(Vector3(w, 0.05, 0.12), Vector3(0, 0.45, bz + 0.12 + k * 0.14), wood)
			for k in 2:
				_box(Vector3(w, 0.12, 0.04), Vector3(0, 0.62 + k * 0.16, bz + 0.04), wood)
			for sx in [-1, 1]:
				_box(Vector3(0.06, 0.45, 0.4), Vector3(sx * (w * 0.5 - 0.15), 0.22, bz + 0.25), "gun_dark")
				_box(Vector3(0.05, 0.45, 0.05), Vector3(sx * (w * 0.5 - 0.15), 0.67, bz + 0.03), "gun_dark")
		"planter":
			_cyl(0.24, 0.18, 0.45, Vector3(0, 0.22, 0), "stone")
			_cyl(0.22, 0.22, 0.04, Vector3(0, 0.44, 0), "v_dirt")
			for k in 5:
				var a := k * TAU / 5.0 + rng.randf()
				_ball(0.18, Vector3(cos(a) * 0.12, 0.65 + rng.randf() * 0.25, sin(a) * 0.1), "v_hedge", {}, Vector3(1, 1.3, 1))
			_ball(0.08, Vector3(0.05, 0.98, 0.08), "white", {"tint": Color(1.0, 0.3, 0.6)})
		"trashcan":
			_cyl(0.24, 0.21, 0.82, Vector3(0, 0.41, 0), "gun_metal", {"tint": Color(0.6, 0.7, 0.55)})
			_cyl(0.26, 0.26, 0.05, Vector3(0, 0.85, 0), "gun_metal", {"tint": Color(0.5, 0.6, 0.45)}, Vector3(rng.randf_range(-12, 12), 0, 8))
			_ball(0.14, Vector3(0.1, 0.9, 0.14), "black", {"tint": Color(0.15, 0.15, 0.18)})
		"crates":
			var n := rng.randi_range(2, 3)
			_box(Vector3(0.55, 0.55, 0.55), Vector3(-0.3, 0.275, 0), "crate", {}, Vector3(0, rng.randf_range(-6, 6), 0), true)
			_box(Vector3(0.55, 0.55, 0.55), Vector3(0.3, 0.275, 0), "crate", {}, Vector3(0, rng.randf_range(-6, 6), 0), true)
			if n == 3:
				_box(Vector3(0.5, 0.5, 0.5), Vector3(rng.randf_range(-0.2, 0.2), 0.8, 0), "crate", {}, Vector3(0, rng.randf_range(-15, 15), 0), true)
		"woodpile":
			for row in 3:
				for k in 5 - row:
					_cyl(0.09, 0.09, 0.45, Vector3(-0.4 + (k + row * 0.5) * 0.2, 0.09 + row * 0.16, 0), "gun_wood", {}, Vector3(90, 0, 0), 6)
		"barrel_wood":
			_cyl(0.25, 0.25, 0.9, Vector3(0, 0.45, 0), "gun_wood", {}, Vector3.ZERO, 10)
			for yy in [0.15, 0.75]:
				_cyl(0.265, 0.265, 0.05, Vector3(0, yy, 0), "gun_dark", {}, Vector3.ZERO, 10)
		"mailbox":
			_box(Vector3(0.08, 1.0, 0.08), Vector3(0, 0.5, 0), "gun_wood")
			_box(Vector3(0.3, 0.25, 0.32), Vector3(0, 1.08, 0), "gun_red")
			_box(Vector3(0.03, 0.15, 0.06), Vector3(0.17, 1.2, 0.05), "gun_red")
		"boxes":
			var y := 0.0
			for k in rng.randi_range(1, 3):
				var s := rng.randf_range(0.38, 0.5)
				_box(Vector3(s, s * 0.8, s), Vector3(rng.randf_range(-0.25, 0.25), y + s * 0.4, 0), "dr_cardboard", {}, Vector3(0, rng.randf_range(-20, 20), 0), true)
				y += s * 0.8
		"trash":
			for k in rng.randi_range(2, 4):
				_ball(rng.randf_range(0.18, 0.28), Vector3(rng.randf_range(-0.35, 0.35), 0.16, rng.randf_range(-0.15, 0.1)), "black", {"tint": Color(0.12, 0.12, 0.14)}, Vector3(1, 0.8, 1))
		"shelf":
			_box(Vector3(w, 0.04, d), Vector3(0, h, 0), "v_planks")
			for k in 4:
				_box(Vector3(w, 0.04, d), Vector3(0, 0.1 + k * 0.45, 0), "v_planks")
				for j in rng.randi_range(0, 3):
					var it := rng.randi_range(0, 2)
					var px := rng.randf_range(-w * 0.4, w * 0.4)
					if it == 0:
						_cyl(0.05, 0.05, 0.2, Vector3(px, 0.22 + k * 0.45, 0), "white", {"tint": Color(rng.randf(), rng.randf(), rng.randf())})
					elif it == 1:
						_box(Vector3(0.2, 0.22, 0.25), Vector3(px, 0.23 + k * 0.45, 0), "dr_cardboard", {}, Vector3.ZERO, true)
					else:
						_ball(0.08, Vector3(px, 0.2 + k * 0.45, 0), "white", {"tint": Color(0.9, 0.85, 0.7)})
			for sx in [-1, 1]:
				_box(Vector3(0.04, h, d), Vector3(sx * w * 0.5, h * 0.5, 0), "v_planks")
		"dresser":
			_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), "dr_cabinet", {"tint": Color(0.75, 0.55, 0.35)}, Vector3.ZERO, true)
			_cyl(0.06, 0.1, 0.25, Vector3(-0.3, h + 0.12, 0), "white", {"tint": Color(0.3, 0.6, 0.3)})
			_box(Vector3(0.25, 0.3, 0.02), Vector3(0.2, h + 0.15, bz + 0.05), "dr_poster_employee", {}, Vector3(-8, 0, 0), true)
		"tv":
			_box(Vector3(0.6, 0.55, 0.45), Vector3(0, 0.27, 0), "gun_wood")
			_box(Vector3(0.62, 0.5, 0.45), Vector3(0, 0.82, -0.02), "gun_dark")
			_quad(Vector2(0.48, 0.38), Vector3(0, 0.82, 0.205), _one(["dr_crt", "dr_screen2", "d_static", "dr_screen"]), {"fullbright": 0.8})
			_cyl(0.005, 0.005, 0.35, Vector3(-0.12, 1.2, -0.05), "gun_dark", {}, Vector3(0, 0, 25), 4)
			_cyl(0.005, 0.005, 0.35, Vector3(0.12, 1.2, -0.05), "gun_dark", {}, Vector3(0, 0, -25), 4)
		"chair":
			var t := "gun_wood" if rng.randf() < 0.5 else "gun_metal"
			_box(Vector3(0.45, 0.05, 0.42), Vector3(0, 0.45, 0.02), t)
			_box(Vector3(0.45, 0.45, 0.05), Vector3(0, 0.7, bz + 0.05), t, {}, Vector3(-6, 0, 0))
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_box(Vector3(0.04, 0.45, 0.04), Vector3(sx * 0.19, 0.22, 0.02 + sz * 0.17), t)
		"toilet":
			_cyl(0.2, 0.15, 0.4, Vector3(0, 0.2, 0.06), "white", {"tint": Color(0.92, 0.92, 0.88)})
			_cyl(0.22, 0.22, 0.04, Vector3(0, 0.42, 0.06), "white", {"tint": Color(0.85, 0.85, 0.8)})
			_cyl(0.17, 0.17, 0.02, Vector3(0, 0.44, 0.06), "liq_water")
			_box(Vector3(0.42, 0.38, 0.18), Vector3(0, 0.62, bz + 0.09), "white", {"tint": Color(0.92, 0.92, 0.88)})
		"cot":
			_box(Vector3(w, 0.12, d), Vector3(0, 0.38, 0), "dr_fabric")
			_box(Vector3(0.4, 0.1, d * 0.8), Vector3(-w * 0.5 + 0.25, 0.48, 0), "white", {"tint": Color(0.85, 0.82, 0.75)})
			for sx in [-1, 1]:
				_box(Vector3(0.05, 0.32, d), Vector3(sx * (w * 0.5 - 0.05), 0.16, 0), "gun_metal")
		"lockers":
			_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), "gun_metal", {"tint": Color(0.35, 0.5, 0.65)})
			_quad(Vector2(w * 0.98, h * 0.98), Vector3(0, h * 0.5, d * 0.5 + 0.005), "dr_locker")
		"gas":
			for k in 3:
				var px := -0.3 + k * 0.3
				var gh := rng.randf_range(1.1, 1.4)
				var gc: Color = [Color(0.2, 0.55, 0.25), Color(0.75, 0.1, 0.1), Color(0.85, 0.75, 0.15)][rng.randi_range(0, 2)]
				_cyl(0.13, 0.13, gh, Vector3(px, gh * 0.5, 0), "gun_metal", {"tint": gc}, Vector3(0, 0, rng.randf_range(-3, 3)))
				_ball(0.13, Vector3(px, gh, 0), "gun_metal", {"tint": gc}, Vector3(1, 0.6, 1))
				_cyl(0.03, 0.03, 0.12, Vector3(px, gh + 0.12, 0), "gun_brass")
			_box(Vector3(w, 0.04, 0.04), Vector3(0, 0.9, bz + 0.03), "gun_dark")
		"panel":
			_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), "i_machine")
			_quad(Vector2(0.5, 0.36), Vector3(-0.15, 1.05, d * 0.5 + 0.005), _one(["dr_screen", "dr_screen2", "tech_panel2"]), {"fullbright": 0.75})
			for k in 6:
				var bc: Color = [Color(1, 0.1, 0.1), Color(0.1, 1, 0.2), Color(1, 0.8, 0.1)][k % 3]
				_box(Vector3(0.06, 0.06, 0.04), Vector3(0.22 + (k % 2) * 0.12, 0.85 + (k / 2) * 0.13, d * 0.5 + 0.02), "white", {"tint": bc, "fullbright": 0.9})
			_box(Vector3(0.04, 0.25, 0.04), Vector3(0.3, 0.55, d * 0.5 + 0.04), "gun_dark", {}, Vector3(30, 0, 0))
		"drums":
			var dc: Color = [Color(0.15, 0.3, 0.7), Color(0.7, 0.35, 0.05), Color(0.25, 0.45, 0.15)][rng.randi_range(0, 2)]
			for k in 2:
				_cyl(0.27, 0.27, 0.9, Vector3(-0.29 + k * 0.58, 0.45, 0), "i_rust", {"tint": dc}, Vector3(0, 0, rng.randf_range(-3, 3)), 10)
				_cyl(0.28, 0.28, 0.03, Vector3(-0.29 + k * 0.58, 0.6, 0), "gun_dark", {}, Vector3.ZERO, 10)
			if rng.randf() < 0.5:
				_cyl(0.27, 0.27, 0.9, Vector3(0, 0.25, 0.1), "i_rust", {"tint": dc}, Vector3(90, rng.randf_range(-20, 20), 0), 10)
		"workbench":
			_box(Vector3(w, 0.07, d), Vector3(0, 0.88, 0), "gun_wood")
			_box(Vector3(w, 0.04, d * 0.9), Vector3(0, 0.25, 0), "gun_wood")
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_box(Vector3(0.06, 0.88, 0.06), Vector3(sx * (w * 0.5 - 0.06), 0.44, sz * (d * 0.5 - 0.06)), "gun_dark")
			_box(Vector3(w, 0.4, 0.03), Vector3(0, 1.1, bz + 0.015), "i_grate")
			_box(Vector3(0.18, 0.14, 0.14), Vector3(-w * 0.35, 0.99, 0), "gun_metal")
			_box(Vector3(0.4, 0.12, 0.2), Vector3(0.25, 0.97, 0.05), "gun_red", {}, Vector3(0, 15, 0))
			_cyl(0.015, 0.015, 0.3, Vector3(0.0, 0.93, 0.1), "gun_dark", {}, Vector3(0, 40, 90), 4)
		"pipe":
			_cyl(0.11, 0.11, h, Vector3(0, h * 0.5, bz + 0.13), "i_pipes", {}, Vector3.ZERO, 8)
			_cyl(0.06, 0.06, h, Vector3(0.22, h * 0.5, bz + 0.08), "gun_metal", {"tint": Color(0.7, 0.4, 0.2)}, Vector3.ZERO, 6)
			for yy in range(1, int(h / 1.5)):
				_box(Vector3(0.3, 0.06, 0.26), Vector3(0, yy * 1.5, bz + 0.1), "gun_dark")
			_cyl(0.13, 0.13, 0.2, Vector3(0, 1.2, bz + 0.13), "gun_red")
		"beam":
			_box(Vector3(0.28, h, 0.28), Vector3(0, h * 0.5, bz + 0.14), "m_beam")
			_box(Vector3(0.2, 0.2, 0.2), Vector3(0, h - 0.1, bz + 0.1), "m_beam")
			_box(Vector3(0.14, 1.2, 0.14), Vector3(0.3, h - 0.55, bz + 0.1), "m_beam", {}, Vector3(0, 0, -35))
		"ore":
			for k in rng.randi_range(5, 8):
				var tex: String = _one(["m_ore", "m_rock2", "m_rock", "m_crystal"])
				var s := rng.randf_range(0.15, 0.32)
				_ball(s, Vector3(rng.randf_range(-0.45, 0.45), s * 0.6 + rng.randf() * 0.2, rng.randf_range(-0.12, 0.08)), tex,
					{"fullbright": 0.35} if tex == "m_crystal" else {}, Vector3(1, rng.randf_range(0.7, 1.2), 1))
		"cart":
			_box(Vector3(1.0, 0.55, 0.5), Vector3(0, 0.55, 0), "m_planks")
			_box(Vector3(1.04, 0.06, 0.52), Vector3(0, 0.84, 0), "gun_dark")
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_cyl(0.13, 0.13, 0.06, Vector3(sx * 0.33, 0.17, sz * 0.24), "gun_dark", {}, Vector3(90, 0, 0), 8)
			for k in 4:
				_ball(rng.randf_range(0.12, 0.2), Vector3(rng.randf_range(-0.35, 0.35), 0.88, rng.randf_range(-0.1, 0.1)), "m_ore")
		"dynamite":
			_box(Vector3(0.7, 0.4, 0.45), Vector3(0, 0.2, 0), "crate", {}, Vector3.ZERO, true)
			for k in 5:
				_cyl(0.035, 0.035, 0.35, Vector3(-0.2 + k * 0.1, 0.55, 0), "gun_red", {}, Vector3(0, 0, rng.randf_range(-12, 12)), 6)
			_box(Vector3(0.3, 0.12, 0.02), Vector3(0, 0.25, 0.235), "white", {"tint": Color(1, 0.85, 0)})
		"lantern":
			_box(Vector3(0.1, h, 0.1), Vector3(0, h * 0.5, 0), "m_beam")
			_box(Vector3(0.4, 0.06, 0.06), Vector3(0.15, h - 0.1, 0), "m_beam")
			_cyl(0.002, 0.002, 0.15, Vector3(0.3, h - 0.2, 0), "gun_dark", {}, Vector3.ZERO, 3)
			_ball(0.09, Vector3(0.3, h - 0.35, 0), "lamp", {"fullbright": 1.0, "tint": Color(1, 0.8, 0.4)})
			_cyl(0.11, 0.08, 0.06, Vector3(0.3, h - 0.25, 0), "gun_dark")
		"bones":
			for k in rng.randi_range(4, 7):
				_cyl(0.03, 0.035, rng.randf_range(0.25, 0.45), Vector3(rng.randf_range(-0.4, 0.4), 0.04, rng.randf_range(-0.15, 0.15)), "white",
					{"tint": Color(0.9, 0.86, 0.72)}, Vector3(90, rng.randf() * 180, 0), 5)
			_ball(0.12, Vector3(rng.randf_range(-0.2, 0.2), 0.1, 0.0), "white", {"tint": Color(0.92, 0.88, 0.75)}, Vector3(1.2, 1, 1))
		"tools":
			_cyl(0.025, 0.025, 1.1, Vector3(-0.2, 0.55, bz + 0.12), "gun_wood", {}, Vector3(-10, 0, 8), 5)
			_box(Vector3(0.45, 0.08, 0.05), Vector3(-0.29, 1.08, bz + 0.03), "gun_metal", {}, Vector3(-10, 0, 8))
			_cyl(0.025, 0.025, 1.0, Vector3(0.2, 0.5, bz + 0.12), "gun_wood", {}, Vector3(-10, 0, -6), 5)
			_box(Vector3(0.22, 0.3, 0.03), Vector3(0.25, 0.12, bz + 0.2), "gun_metal", {}, Vector3(-10, 0, -6))
		"desk":
			_box(Vector3(w, 0.06, d), Vector3(0, 0.76, 0), "gun_wood", {"tint": Color(0.8, 0.7, 0.6)})
			_box(Vector3(0.45, 0.7, d * 0.95), Vector3(w * 0.5 - 0.25, 0.37, 0), "dr_cabinet", {}, Vector3.ZERO, true)
			_box(Vector3(0.04, 0.73, d * 0.95), Vector3(-w * 0.5 + 0.04, 0.37, 0), "gun_wood", {"tint": Color(0.8, 0.7, 0.6)})
			_box(Vector3(0.5, 0.38, 0.32), Vector3(-0.15, 0.99, bz + 0.2), "white", {"tint": Color(0.85, 0.83, 0.75)})
			_quad(Vector2(0.4, 0.3), Vector3(-0.15, 1.0, bz + 0.365), _one(["h_computer", "dr_screen", "dr_screen2"]), {"fullbright": 0.7})
			_box(Vector3(0.42, 0.03, 0.14), Vector3(-0.15, 0.8, d * 0.5 - 0.1), "white", {"tint": Color(0.8, 0.78, 0.7)})
			_cyl(0.04, 0.035, 0.1, Vector3(0.3, 0.84, 0.05), "white", {"tint": _one([Color(1, 1, 1), Color(0.9, 0.2, 0.2), Color(0.2, 0.4, 0.9)])})
			_box(Vector3(0.22, 0.01, 0.3), Vector3(0.15, 0.795, 0.0), "dr_paper", {}, Vector3(0, rng.randf_range(-30, 30), 0), true)
		"cabinet":
			_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), "dr_cabinet", {}, Vector3.ZERO, true)
			if rng.randf() < 0.5:
				_box(Vector3(0.3, 0.25, 0.3), Vector3(0, h + 0.12, 0), "dr_cardboard", {}, Vector3(0, rng.randf_range(-20, 20), 0), true)
		"plant":
			_cyl(0.2, 0.15, 0.4, Vector3(0, 0.2, 0), "white", {"tint": Color(0.7, 0.35, 0.2)})
			_cyl(0.03, 0.03, 0.9, Vector3(0, 0.8, 0), "gun_wood", {}, Vector3.ZERO, 4)
			for k in 7:
				var a := k * TAU / 7.0
				_ball(0.2, Vector3(cos(a) * 0.12, 1.15 + rng.randf() * 0.4, sin(a) * 0.1), "v_hedge", {}, Vector3(1, 0.6, 1))
		"vending":
			_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), "gun_red")
			_quad(Vector2(w * 0.96, h * 0.96), Vector3(0, h * 0.5, d * 0.5 + 0.005), "dr_vending", {"fullbright": 0.45})
		"bookshelf":
			_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), "gun_wood")
			_quad(Vector2(w * 0.94, h * 0.92), Vector3(0, h * 0.5, d * 0.5 + 0.005), "dr_books")
		"cooler":
			_box(Vector3(0.38, 1.0, 0.38), Vector3(0, 0.5, 0), "white", {"tint": Color(0.88, 0.88, 0.85)})
			_cyl(0.15, 0.15, 0.4, Vector3(0, 1.22, 0), "white", {"tint": Color(0.35, 0.6, 1.0), "fullbright": 0.25})
			_box(Vector3(0.06, 0.06, 0.06), Vector3(-0.08, 0.8, 0.2), "white", {"tint": Color(0.2, 0.4, 1.0)})
			_box(Vector3(0.06, 0.06, 0.06), Vector3(0.08, 0.8, 0.2), "white", {"tint": Color(1.0, 0.2, 0.2)})
		"copier":
			_box(Vector3(w, 0.9, d), Vector3(0, 0.45, 0), "white", {"tint": Color(0.75, 0.75, 0.72)})
			_box(Vector3(w * 0.9, 0.12, d * 0.9), Vector3(0, 0.96, 0), "gun_dark")
			_box(Vector3(0.3, 0.02, 0.2), Vector3(w * 0.5 + 0.08, 0.6, 0), "dr_paper", {}, Vector3.ZERO, true)
			_box(Vector3(0.08, 0.04, 0.04), Vector3(-0.3, 0.92, d * 0.5 - 0.02), "white", {"tint": Color(0.1, 1, 0.2), "fullbright": 1.0})
		"couch":
			var cc: Color = [Color(0.55, 0.25, 0.2), Color(0.25, 0.35, 0.5), Color(0.4, 0.45, 0.25)][rng.randi_range(0, 2)]
			_box(Vector3(w, 0.4, d), Vector3(0, 0.25, 0.02), "dr_fabric", {"tint": cc})
			_box(Vector3(w, 0.5, 0.16), Vector3(0, 0.62, bz + 0.08), "dr_fabric", {"tint": cc}, Vector3(-8, 0, 0))
			for sx in [-1, 1]:
				_box(Vector3(0.16, 0.6, d), Vector3(sx * (w * 0.5 - 0.08), 0.3, 0), "dr_fabric", {"tint": cc * 0.85})
			_box(Vector3(0.4, 0.12, 0.3), Vector3(rng.randf_range(-0.4, 0.4), 0.51, 0.02), "dr_fabric", {"tint": Color(0.8, 0.75, 0.6)}, Vector3(0, 0, 12))
		"labbench":
			_box(Vector3(w, 0.08, d), Vector3(0, 0.9, 0), "metal_floor")
			_box(Vector3(w, 0.86, d * 0.9), Vector3(0, 0.43, -0.02), "dr_cabinet", {"tint": Color(0.8, 0.9, 0.9)}, Vector3.ZERO, true)
			for k in rng.randi_range(3, 6):
				var bc: Color = [Color(0.2, 1, 0.3), Color(1, 0.3, 0.8), Color(0.3, 0.7, 1), Color(1, 0.9, 0.2)][rng.randi_range(0, 3)]
				var bh := rng.randf_range(0.12, 0.3)
				var bx := rng.randf_range(-w * 0.42, w * 0.42)
				_cyl(0.04, 0.05, bh, Vector3(bx, 0.94 + bh * 0.5, rng.randf_range(-0.1, 0.12)), "white", {"tint": bc, "fullbright": 0.6}, Vector3.ZERO, 6)
			_box(Vector3(0.35, 0.28, 0.25), Vector3(w * 0.3, 1.08, bz + 0.15), "gun_metal")
			_cyl(0.02, 0.02, 0.3, Vector3(w * 0.3, 1.36, bz + 0.15), "gun_metal", {}, Vector3(30, 0, 0), 4)
		"tank":
			var cr: Color = [Color(0.3, 1, 0.5), Color(1, 0.4, 0.8), Color(0.4, 0.8, 1)][rng.randi_range(0, 2)]
			_cyl(0.42, 0.45, 0.25, Vector3(0, 0.12, 0), "gun_metal")
			_cyl(0.37, 0.37, 1.85, Vector3(0, 1.17, 0), "liq_ooze", {"tint": cr, "fullbright": 0.6}, Vector3.ZERO, 10)
			_cyl(0.42, 0.42, 0.3, Vector3(0, 2.25, 0), "gun_metal")
			# something floating in it
			var crt: String = _one(["cr_gorb_green", "cr_snot", "gorbino_skin", "snirby_skin", "cr_gorb_purple"])
			_ball(0.22, Vector3(0, 1.25 + rng.randf() * 0.2, 0.02), crt, {"tint": Color(0.7, 0.9, 0.75)}, Vector3(1, 1.15, 1))
			_ball(0.05, Vector3(-0.07, 1.33, 0.2), "white", {"tint": Color(1, 1, 1), "fullbright": 0.5})
			_ball(0.05, Vector3(0.07, 1.33, 0.2), "white", {"tint": Color(1, 1, 1), "fullbright": 0.5})
			for k in 3:
				_cyl(0.025, 0.025, 2.2, Vector3(cos(k * 2.1) * 0.39, 1.15, sin(k * 2.1) * 0.39), "gun_metal", {}, Vector3.ZERO, 4)
			_cyl(0.05, 0.05, maxf(0.1, clear - 2.4), Vector3(0, 2.4 + maxf(0.1, clear - 2.4) * 0.5, -0.1), "i_pipes", {}, Vector3.ZERO, 6)
		"monitors":
			_box(Vector3(w, 0.85, d), Vector3(0, 0.42, 0), "i_machine")
			for k in 3:
				for row in 2:
					var mx := -w * 0.33 + k * w * 0.33
					var my := 1.05 + row * 0.42
					_box(Vector3(0.4, 0.36, 0.32), Vector3(mx, my, bz + 0.17), "gun_dark")
					_quad(Vector2(0.34, 0.28), Vector3(mx, my, bz + 0.335), _one(["dr_screen", "dr_screen2", "d_static", "tech_panel2", "dr_crt"]), {"fullbright": 0.8})
		"gurney":
			_box(Vector3(w, 0.1, d * 0.9), Vector3(0, 0.82, 0), "dr_fabric", {"tint": Color(0.75, 0.85, 0.8)})
			_box(Vector3(w, 0.04, d), Vector3(0, 0.75, 0), "gun_metal")
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_box(Vector3(0.04, 0.72, 0.04), Vector3(sx * (w * 0.5 - 0.08), 0.37, sz * (d * 0.5 - 0.05)), "gun_metal")
			if rng.randf() < 0.6:
				# a sheet over something
				_ball(0.35, Vector3(rng.randf_range(-0.3, 0.3), 0.92, 0), "white", {"tint": Color(0.85, 0.85, 0.8)}, Vector3(1.6, 0.45, 0.7))
				_quad(Vector2(0.4, 0.4), Vector3(0.5, 0.885, 0.05), "splat", {"tint": Color(0.5, 0.0, 0.05), "alpha_cut": 0.5}, Vector3(-90, 0, 0), Rect2(0, 0, 1.0 / Mat.sprite_frames("splat"), 1))
		"cage":
			_box(Vector3(w, 0.05, d), Vector3(0, 0.03, 0), "gun_dark")
			_box(Vector3(w, 0.05, d), Vector3(0, h, 0), "gun_dark")
			for k in 7:
				var px := -w * 0.5 + 0.05 + k * (w - 0.1) / 6.0
				_cyl(0.015, 0.015, h, Vector3(px, h * 0.5, d * 0.5 - 0.03), "gun_metal", {}, Vector3.ZERO, 4)
			var who: String = _one(["cr_snot", "snirby_skin", "cr_gorb_red", "cr_gorb_yellow"])
			_ball(0.28, Vector3(0, 0.3, -0.05), who, {}, Vector3(1.1, 0.9, 1.0))
			_ball(0.05, Vector3(-0.08, 0.38, 0.2), "white", {"fullbright": 0.6})
			_ball(0.05, Vector3(0.08, 0.38, 0.2), "white", {"fullbright": 0.6})
		"growth":
			var fl: String = _one(["d_flesh", "d_meat"])
			for k in rng.randi_range(4, 7):
				var s := rng.randf_range(0.2, 0.42)
				_ball(s, Vector3(rng.randf_range(-0.4, 0.4), s * 0.7 + rng.randf() * 0.5, rng.randf_range(-0.15, 0.05)), fl, {"wobble": 0.4}, Vector3(1, rng.randf_range(0.8, 1.4), 0.8))
			for k in rng.randi_range(1, 3):
				var ep := Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0.4, 1.1), 0.22)
				_ball(0.08, ep, "white", {"fullbright": 0.4})
				_ball(0.035, ep + Vector3(0, 0, 0.06), "black")
		"teeth":
			_cyl(0.18, 0.28, h, Vector3(0, h * 0.5, 0), "d_teeth", {}, Vector3.ZERO, 7)
			for k in 4:
				_cyl(0.0, 0.07, 0.3, Vector3(cos(k * 1.7) * 0.22, 0.4 + k * 0.5, sin(k * 1.7) * 0.22), "white", {"tint": Color(0.95, 0.92, 0.8)}, Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-60, 60)), 4)
		"stalk":
			_cyl(0.05, 0.12, h - 0.3, Vector3(0, (h - 0.3) * 0.5, 0), "d_flesh", {}, Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)), 6)
			_ball(0.28, Vector3(0, h - 0.2, 0.05), "white", {"tint": Color(0.95, 0.93, 0.88)})
			_ball(0.13, Vector3(0, h - 0.2, 0.26), "white", {"tint": _one([Color(0.1, 0.8, 0.3), Color(0.9, 0.1, 0.2), Color(0.2, 0.5, 1)]), "fullbright": 0.5})
			_ball(0.06, Vector3(0, h - 0.2, 0.36), "black")
		"idol":
			_box(Vector3(0.6, 0.5, 0.5), Vector3(0, 0.25, 0), "stone")
			_ball(0.28, Vector3(0, 0.85, 0), "stone", {}, Vector3(1, 1.15, 1))
			for k in 5:
				_ball(0.08, Vector3(-0.2 + k * 0.1, 0.55, 0.15), "stone")
			for sx in [-1, 1]:
				_ball(0.06, Vector3(sx * 0.1, 0.9, 0.24), "white", {"tint": Color(1, 0.1, 0.1), "fullbright": 1.0})
			for k in 3:
				_cyl(0.025, 0.025, 0.12, Vector3(-0.2 + k * 0.2, 0.56, 0.2), "white", {"tint": Color(0.95, 0.9, 0.75)}, Vector3.ZERO, 5)
				_ball(0.025, Vector3(-0.2 + k * 0.2, 0.65, 0.2), "white", {"tint": Color(1, 0.7, 0.2), "fullbright": 1.0})
		"doorway":
			# a door that goes nowhere
			_box(Vector3(1.1, 2.3, 0.08), Vector3(0, 1.15, bz + 0.04), "door_metal")
			_box(Vector3(1.24, 0.12, 0.16), Vector3(0, 2.36, bz + 0.08), "gun_dark")
			for sx in [-1, 1]:
				_box(Vector3(0.08, 2.4, 0.16), Vector3(sx * 0.6, 1.2, bz + 0.08), "gun_dark")
			_ball(0.04, Vector3(0.4, 1.1, bz + 0.12), "gun_brass")
			_quad(Vector2(0.5, 0.12), Vector3(0, 1.9, bz + 0.085), "dr_sign_you")
		"clock":
			_box(Vector3(0.4, 1.7, 0.3), Vector3(0, 0.85, 0), "gun_wood")
			_cyl(0.18, 0.18, 0.04, Vector3(0, 1.85, 0.0), "gun_brass", {}, Vector3(90, 0, 0), 12)
			_cyl(0.15, 0.15, 0.02, Vector3(0, 1.85, 0.03), "white", {"tint": Color(0.95, 0.92, 0.85)}, Vector3(90, 0, 0), 12)
			_box(Vector3(0.015, 0.12, 0.01), Vector3(0, 1.89, 0.045), "black", {}, Vector3(0, 0, rng.randf() * 360))
			_box(Vector3(0.015, 0.09, 0.01), Vector3(0, 1.87, 0.05), "black", {}, Vector3(0, 0, rng.randf() * 360))
			_cyl(0.008, 0.008, 0.6, Vector3(0.05, 1.1, 0.12), "gun_brass", {}, Vector3(0, 0, 14), 4)


# ================================================================== islands
## Room centrepieces. A cell only gets one when all eight neighbours are open
## floor at the same height, so there is always a way round; the cell is then
## marked solid so enemies, the bot and the level checker path round it too.
func _islands(dens: float) -> void:
	var W: int = level.W
	var H: int = level.H
	# keep the boss arena clear
	var bosses := []
	for e in level.entity_specs:
		if String(e["type"]) == "boss":
			bosses.append(e["cell"])
	for z in range(1, H - 1):
		for x in range(1, W - 1):
			var i: int = z * W + x
			if rng.randf() > 0.07 * dens:
				continue
			if not _floor_ok(i) or _taken.has(i):
				continue
			var sec: Dictionary = level.cells[i]
			if sec.has("trigger") or sec.get("secret", false) or level.secret_group.has(i):
				continue
			var near_boss := false
			for bc in bosses:
				if maxi(absi(bc.x - x), absi(bc.y - z)) < 10:
					near_boss = true
			if near_boss:
				continue
			var f: float = level.floor_h[i]
			var ok := true
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					var n: int = level._idx(x + dx, z + dz)
					if n >= 0 and _island.has(n):
						ok = false
					if absi(dx) <= 1 and absi(dz) <= 1 and (dx != 0 or dz != 0):
						if n < 0 or level.solid[n] != 0 or level.movers.has(n) or absf(level.floor_h[n] - f) > 0.05 \
								or level.teleports.has(n) or level.exit_cells.has(n):
							ok = false
			if not ok:
				continue
			var sky := String(sec.get("ctex", "")) == "SKY"
			var key := theme
			if theme == "village":
				key = "village_out" if sky else "village_in"
			var name := _pick(ISLANDS[key])
			var clear: float = level.ceil_h[i] - f
			var size := _island_size(name, clear)
			# stay inside the cell even when turned a little
			size.x = minf(size.x, 1.8)
			size.z = minf(size.z, 1.8)
			if size.y + 0.2 > clear:
				continue
			var S: float = Level.S
			var yaw := float(rng.randi_range(0, 3)) * PI * 0.5 + rng.randf_range(-0.15, 0.15)
			_xf = Transform3D(Basis(Vector3.UP, yaw), Vector3((x + 0.5) * S, f, (z + 0.5) * S))
			_build_island(name, size, clear)
			# tall enough that nobody steps up onto it (its cell is solid to the pathing)
			var col := Vector3(size.x, maxf(size.y, 1.2), size.z)
			_boxes.append([_xf * Transform3D(Basis(), Vector3(0, col.y * 0.5, 0)), col, true])
			_island[i] = true
			level.solid[i] = 1
			_spots.append([_xf.origin, name])
			_count += 1


func _island_size(name: String, clear: float) -> Vector3:
	match name:
		"well": return Vector3(1.4, 2.4, 1.4)
		"stall": return Vector3(1.7, 2.2, 1.0)
		"haycart": return Vector3(1.7, 1.3, 1.0)
		"stump": return Vector3(0.9, 0.9, 0.9)
		"barrels": return Vector3(1.4, 1.0, 1.4)
		"dining": return Vector3(1.6, 1.0, 1.4)
		"bed": return Vector3(1.9, 0.9, 1.0)
		"stove": return Vector3(0.9, 1.1, 0.8)
		"pallets": return Vector3(1.5, 1.5, 1.3)
		"forklift": return Vector3(1.8, 2.0, 1.0)
		"machine": return Vector3(1.6, 1.8, 1.3)
		"spool": return Vector3(1.4, 1.3, 0.9)
		"drumstack": return Vector3(1.5, 1.4, 1.0)
		"orepile": return Vector3(1.6, 1.1, 1.6)
		"campfire": return Vector3(1.6, 0.55, 1.6)
		"cartrail": return Vector3(1.8, 1.1, 0.9)
		"cratepile": return Vector3(1.6, 1.6, 1.4)
		"conference": return Vector3(1.6, 1.0, 1.6)
		"reception": return Vector3(1.7, 1.2, 0.8)
		"lounge": return Vector3(1.7, 0.9, 1.6)
		"mascot": return Vector3(1.2, minf(3.4, clear - 0.3), 1.2)
		"planters": return Vector3(1.4, 2.0, 1.4)
		"surgery": return Vector3(1.8, 2.3, 0.9)
		"bigtank": return Vector3(1.4, minf(3.2, clear - 0.2), 1.4)
		"servers": return Vector3(1.4, 2.1, 1.1)
		"cryo": return Vector3(1.0, 2.2, 1.0)
		"bigeye": return Vector3(1.6, 2.0, 1.6)
		"fleshpillar": return Vector3(1.2, minf(clear, 6.0), 1.2)
		"floatjunk": return Vector3(1.0, 0.6, 1.0)
		"tub": return Vector3(1.7, 0.9, 0.9)
		"car": return Vector3(1.9, 1.3, 1.0)
		"teethpile": return Vector3(1.5, 1.2, 1.5)
	return Vector3(1.2, 1.0, 1.2)


func _build_island(name: String, size: Vector3, clear: float) -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	match name:
		"well":
			_cyl(0.65, 0.68, 0.8, Vector3(0, 0.4, 0), "stone", {}, Vector3.ZERO, 10)
			_cyl(0.55, 0.55, 0.02, Vector3(0, 0.6, 0), "liq_water", {"wobble": 1.0}, Vector3.ZERO, 10)
			for sx in [-1, 1]:
				_box(Vector3(0.1, 1.6, 0.1), Vector3(sx * 0.6, 1.4, 0), "gun_wood")
			_box(Vector3(1.6, 0.06, 0.9), Vector3(0, 2.25, -0.22), "v_shingle", {}, Vector3(30, 0, 0))
			_box(Vector3(1.6, 0.06, 0.9), Vector3(0, 2.25, 0.22), "v_shingle", {}, Vector3(-30, 0, 0))
			_cyl(0.05, 0.05, 1.2, Vector3(0, 1.85, 0), "gun_wood", {}, Vector3(0, 0, 90), 6)
			_cyl(0.008, 0.008, 0.8, Vector3(0, 1.45, 0), "white", {"tint": Color(0.7, 0.6, 0.4)}, Vector3.ZERO, 3)
			_cyl(0.12, 0.1, 0.18, Vector3(0, 1.0, 0), "gun_wood")
		"stall":
			_box(Vector3(1.5, 0.06, 0.8), Vector3(0, 0.85, 0), "gun_wood")
			_box(Vector3(1.5, 0.8, 0.04), Vector3(0, 0.42, 0.38), "v_planks")
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_box(Vector3(0.07, 2.1, 0.07), Vector3(sx * 0.75, 1.05, sz * 0.42), "gun_wood")
			for k in 6:
				_box(Vector3(0.28, 0.04, 1.1), Vector3(-0.7 + k * 0.28, 2.12 - (k % 2) * 0.02, 0), "white", {"tint": Color(0.9, 0.1, 0.15) if k % 2 == 0 else Color(0.95, 0.95, 0.9)}, Vector3(12, 0, 0))
			# what's for sale: meat
			for k in 7:
				var sk: String = _one(["cr_gorb_green", "cr_gorb_red", "cr_snot", "d_meat"])
				_ball(rng.randf_range(0.1, 0.17), Vector3(rng.randf_range(-0.6, 0.6), 0.98, rng.randf_range(-0.25, 0.25)), sk, {}, Vector3(1, 0.7, 1))
			_quad(Vector2(0.9, 0.22), Vector3(0, 1.85, 0.45), "dr_sign_welcome")
		"haycart":
			_box(Vector3(1.5, 0.4, 0.9), Vector3(0, 0.6, 0), "m_planks")
			_box(Vector3(1.3, 0.5, 0.8), Vector3(0, 1.0, 0), "white", {"tint": Color(0.85, 0.72, 0.3)})
			for sz in [-1, 1]:
				_cyl(0.32, 0.32, 0.08, Vector3(0.1, 0.32, sz * 0.48), "gun_wood", {}, Vector3(90, 0, 0), 10)
			_box(Vector3(0.9, 0.06, 0.06), Vector3(-1.0, 0.55, 0.2), "gun_wood", {}, Vector3(0, 10, -15))
			_box(Vector3(0.9, 0.06, 0.06), Vector3(-1.0, 0.55, -0.2), "gun_wood", {}, Vector3(0, -10, -15))
		"stump":
			_cyl(0.38, 0.45, 0.65, Vector3(0, 0.32, 0), "gun_wood", {}, Vector3.ZERO, 9)
			_cyl(0.37, 0.37, 0.02, Vector3(0, 0.66, 0), "white", {"tint": Color(0.85, 0.7, 0.45)}, Vector3.ZERO, 9)
			_cyl(0.025, 0.025, 0.7, Vector3(0.1, 0.9, 0.0), "gun_wood", {}, Vector3(0, 0, 25), 5)
			_box(Vector3(0.22, 0.12, 0.03), Vector3(-0.02, 0.68, 0.0), "gun_metal", {}, Vector3(0, 0, 25))
			for k in 4:
				_box(Vector3(0.08, 0.02, 0.05), Vector3(rng.randf_range(-0.6, 0.6), 0.01, rng.randf_range(-0.6, 0.6)), "white", {"tint": Color(0.85, 0.7, 0.45)}, Vector3(0, rng.randf() * 360, 0))
		"barrels":
			for k in 4:
				var a := k * TAU / 4.0 + 0.4
				_cyl(0.28, 0.28, 0.95, Vector3(cos(a) * 0.38, 0.47, sin(a) * 0.38), "gun_wood", {}, Vector3.ZERO, 10)
				_cyl(0.29, 0.29, 0.04, Vector3(cos(a) * 0.38, 0.75, sin(a) * 0.38), "gun_dark", {}, Vector3.ZERO, 10)
		"dining":
			_box(Vector3(1.2, 0.06, 0.8), Vector3(0, 0.75, 0), "gun_wood")
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_box(Vector3(0.06, 0.72, 0.06), Vector3(sx * 0.52, 0.36, sz * 0.32), "gun_wood")
			for k in 4:
				var cx := -0.3 + (k % 2) * 0.6
				var cz := 0.6 if k < 2 else -0.6
				_box(Vector3(0.4, 0.04, 0.38), Vector3(cx, 0.45, cz), "gun_wood")
				_box(Vector3(0.4, 0.45, 0.04), Vector3(cx, 0.7, cz + signf(cz) * 0.18), "gun_wood")
				for lx in [-1, 1]:
					_box(Vector3(0.03, 0.45, 0.03), Vector3(cx + lx * 0.17, 0.22, cz), "gun_wood")
				_cyl(0.12, 0.1, 0.02, Vector3(cx, 0.79, cz * 0.5), "white", {"tint": Color(0.95, 0.95, 0.9)}, Vector3.ZERO, 8)
			_ball(0.12, Vector3(0, 0.86, 0), "cr_gorb_green", {"tint": Color(0.8, 0.7, 0.6)}, Vector3(1.3, 0.8, 1))
		"bed":
			_box(Vector3(1.9, 0.35, 0.95), Vector3(0, 0.3, 0), "gun_wood")
			_box(Vector3(1.85, 0.15, 0.9), Vector3(0, 0.55, 0), "dr_fabric", {"tint": Color(0.85, 0.82, 0.78)})
			_box(Vector3(1.2, 0.08, 0.92), Vector3(0.3, 0.64, 0), "dr_fabric", {"tint": Color(0.5, 0.2, 0.25)})
			_box(Vector3(0.35, 0.12, 0.6), Vector3(-0.7, 0.68, 0), "white", {"tint": Color(0.92, 0.9, 0.85)})
			_box(Vector3(0.08, 0.9, 0.95), Vector3(-0.95, 0.45, 0), "gun_wood")
			_quad(Vector2(0.5, 0.5), Vector3(0.4, 0.69, 0.1), "splat", {"alpha_cut": 0.5, "tint": Color(0.4, 0.0, 0.03)}, Vector3(-90, 0, 0), Rect2(0, 0, 1.0 / Mat.sprite_frames("splat"), 1))
		"stove":
			_box(Vector3(0.8, 0.8, 0.7), Vector3(0, 0.45, 0), "gun_dark")
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_box(Vector3(0.06, 0.1, 0.06), Vector3(sx * 0.35, 0.05, sz * 0.3), "gun_dark")
			_box(Vector3(0.3, 0.2, 0.02), Vector3(0, 0.4, 0.36), "lamp", {"fullbright": 1.0, "tint": Color(1, 0.5, 0.1)})
			_cyl(0.08, 0.08, clear - 0.85, Vector3(0.2, 0.85 + (clear - 0.85) * 0.5, -0.15), "gun_dark", {}, Vector3.ZERO, 6)
			_cyl(0.2, 0.18, 0.25, Vector3(-0.15, 0.97, 0.05), "gun_metal")
		"pallets":
			for layer in 2:
				_box(Vector3(1.4, 0.14, 1.2), Vector3(0, 0.07 + layer * 0.75, 0), "gun_wood")
				for k in 4:
					var px := -0.33 + (k % 2) * 0.66
					var pz := -0.28 + (k / 2) * 0.56
					_box(Vector3(0.6, 0.55, 0.52), Vector3(px, 0.42 + layer * 0.75, pz), "dr_cardboard" if layer == 0 else "crate", {}, Vector3(0, rng.randf_range(-5, 5), 0), true)
		"forklift":
			var yel := {"tint": Color(1.0, 0.75, 0.05)}
			_box(Vector3(1.1, 0.6, 0.9), Vector3(-0.25, 0.55, 0), "gun_metal", yel)
			_box(Vector3(0.45, 0.5, 0.85), Vector3(-0.7, 0.9, 0), "gun_metal", yel)
			_box(Vector3(0.4, 0.1, 0.4), Vector3(-0.3, 0.9, 0), "gun_dark")
			_box(Vector3(0.1, 0.45, 0.4), Vector3(-0.5, 1.1, 0), "gun_dark")
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_box(Vector3(0.05, 1.1, 0.05), Vector3(-0.25 + sx * 0.35, 1.35, sz * 0.4), "gun_dark")
				_cyl(0.22, 0.22, 0.18, Vector3(-0.25 + sx * 0.38, 0.22, 0.42), "black", {}, Vector3(90, 0, 0), 10)
				_cyl(0.22, 0.22, 0.18, Vector3(-0.25 + sx * 0.38, 0.22, -0.42), "black", {}, Vector3(90, 0, 0), 10)
			_box(Vector3(0.84, 0.05, 0.84), Vector3(-0.25, 1.9, 0), "gun_dark")
			for sz in [-1, 1]:
				_box(Vector3(0.08, 1.9, 0.08), Vector3(0.35, 0.95, sz * 0.25), "gun_dark")
				_box(Vector3(0.6, 0.05, 0.1), Vector3(0.65, 0.12, sz * 0.25), "gun_metal")
			_box(Vector3(0.6, 0.12, 0.7), Vector3(0.65, 0.2, 0), "gun_wood")
			_box(Vector3(0.5, 0.45, 0.5), Vector3(0.65, 0.48, 0), "dr_cardboard", {}, Vector3.ZERO, true)
		"machine":
			_box(Vector3(1.5, 1.4, 1.2), Vector3(0, 0.7, 0), "i_machine")
			_box(Vector3(1.55, 0.15, 1.25), Vector3(0, 0.08, 0), "i_hazard")
			_box(Vector3(0.6, 0.4, 0.6), Vector3(0.3, 1.6, 0.1), "gun_metal")
			for k in 3:
				_cyl(0.07, 0.07, maxf(0.1, clear - 1.4), Vector3(-0.5 + k * 0.3, 1.4 + maxf(0.1, clear - 1.4) * 0.5, -0.4), "i_pipes", {}, Vector3.ZERO, 6)
			for k in 2:
				_cyl(0.12, 0.12, 0.03, Vector3(-0.4 + k * 0.3, 1.0, 0.61), "white", {"tint": Color(0.95, 0.95, 0.85)}, Vector3(90, 0, 0), 10)
				_box(Vector3(0.01, 0.1, 0.01), Vector3(-0.4 + k * 0.3, 1.02, 0.63), "black", {}, Vector3(0, 0, rng.randf_range(-80, 80)))
			_box(Vector3(0.08, 0.08, 0.04), Vector3(0.5, 1.1, 0.61), "white", {"tint": Color(1, 0.1, 0.1), "fullbright": 1.0})
			_quad(Vector2(0.6, 0.15), Vector3(0.2, 0.55, 0.605), "dr_sign_chute")
		"spool":
			_cyl(0.6, 0.6, 0.12, Vector3(0, 0.6, 0.35), "gun_wood", {}, Vector3(90, 0, 0), 12)
			_cyl(0.6, 0.6, 0.12, Vector3(0, 0.6, -0.35), "gun_wood", {}, Vector3(90, 0, 0), 12)
			_cyl(0.42, 0.42, 0.6, Vector3(0, 0.6, 0), "black", {"tint": Color(0.2, 0.2, 0.25)}, Vector3(90, 0, 0), 12)
			_cyl(0.025, 0.025, 1.4, Vector3(0.7, 0.05, 0.2), "black", {}, Vector3(0, 30, 90), 4)
		"drumstack":
			var dc: Color = [Color(0.15, 0.3, 0.7), Color(0.7, 0.35, 0.05), Color(0.25, 0.45, 0.15)][rng.randi_range(0, 2)]
			for k in 3:
				_cyl(0.28, 0.28, 0.9, Vector3(-0.5 + k * 0.5, 0.28, 0), "i_rust", {"tint": dc}, Vector3(90, 0, 0), 10)
			for k in 2:
				_cyl(0.28, 0.28, 0.9, Vector3(-0.25 + k * 0.5, 0.76, 0), "i_rust", {"tint": dc}, Vector3(90, 0, 0), 10)
			_cyl(0.28, 0.28, 0.9, Vector3(0, 1.24, 0), "i_rust", {"tint": dc}, Vector3(90, 0, 0), 10)
		"orepile":
			for k in 16:
				var a := rng.randf() * TAU
				var rr := rng.randf() * 0.6
				var s := rng.randf_range(0.18, 0.35)
				var tex: String = _one(["m_ore", "m_rock2", "m_rock", "m_ore", "m_crystal"])
				_ball(s, Vector3(cos(a) * rr, maxf(s * 0.5, (0.9 - rr) * 0.9), sin(a) * rr), tex, {"fullbright": 0.35} if tex == "m_crystal" else {}, Vector3(1, 0.8, 1))
			_cyl(0.025, 0.025, 0.9, Vector3(0.1, 1.1, 0.05), "gun_wood", {}, Vector3(15, 0, -25), 5)
			_box(Vector3(0.45, 0.06, 0.05), Vector3(0.3, 1.48, 0.12), "gun_metal", {}, Vector3(15, 0, -25))
		"campfire":
			for k in 9:
				var a := k * TAU / 9.0
				_ball(0.12, Vector3(cos(a) * 0.38, 0.08, sin(a) * 0.38), "m_rock", {}, Vector3(1, 0.7, 1))
			for k in 4:
				_cyl(0.05, 0.05, 0.5, Vector3(0, 0.12, 0), "gun_wood", {"tint": Color(0.3, 0.2, 0.15)}, Vector3(70, k * 45, 0), 5)
			_ball(0.2, Vector3(0, 0.15, 0), "lamp", {"fullbright": 1.0, "tint": Color(1, 0.45, 0.05)}, Vector3(1, 0.5, 1))
			_cyl(0.16, 0.18, 0.4, Vector3(0.62, 0.2, 0.3), "gun_wood", {}, Vector3(0, 0, 90), 7)
			_cyl(0.16, 0.18, 0.4, Vector3(-0.55, 0.2, -0.4), "gun_wood", {}, Vector3(0, 40, 90), 7)
		"cartrail":
			for sz in [-1, 1]:
				_box(Vector3(1.8, 0.06, 0.06), Vector3(0, 0.03, sz * 0.3), "gun_metal")
			for k in 5:
				_box(Vector3(0.15, 0.04, 0.85), Vector3(-0.8 + k * 0.4, 0.02, 0), "m_planks")
			_box(Vector3(1.1, 0.6, 0.7), Vector3(0, 0.55, 0), "m_planks")
			_box(Vector3(1.14, 0.06, 0.74), Vector3(0, 0.86, 0), "gun_dark")
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_cyl(0.15, 0.15, 0.06, Vector3(sx * 0.38, 0.17, sz * 0.32), "gun_dark", {}, Vector3(90, 0, 0), 8)
			for k in 6:
				_ball(rng.randf_range(0.14, 0.22), Vector3(rng.randf_range(-0.4, 0.4), 0.92, rng.randf_range(-0.2, 0.2)), "m_ore")
		"cratepile":
			for k in 3:
				_box(Vector3(0.52, 0.52, 0.52), Vector3(-0.53 + k * 0.53, 0.26, -0.3), "crate", {}, Vector3(0, rng.randf_range(-4, 4), 0), true)
				_box(Vector3(0.52, 0.52, 0.52), Vector3(-0.53 + k * 0.53, 0.26, 0.3), "crate", {}, Vector3(0, rng.randf_range(-4, 4), 0), true)
			for k in 2:
				_box(Vector3(0.52, 0.52, 0.52), Vector3(-0.26 + k * 0.53, 0.78, 0), "crate", {}, Vector3(0, rng.randf_range(-8, 8), 0), true)
			_box(Vector3(0.5, 0.5, 0.5), Vector3(0.05, 1.3, 0), "dr_cardboard", {}, Vector3(0, 20, 0), true)
		"conference":
			_box(Vector3(1.3, 0.06, 0.8), Vector3(0, 0.75, 0), "gun_wood", {"tint": Color(0.6, 0.45, 0.35)})
			_box(Vector3(0.2, 0.72, 0.5), Vector3(0, 0.36, 0), "gun_dark")
			for k in 6:
				var cx := -0.45 + (k % 3) * 0.45
				var cz := 0.62 if k < 3 else -0.62
				_box(Vector3(0.38, 0.06, 0.36), Vector3(cx, 0.46, cz), "black", {"tint": Color(0.15, 0.15, 0.18)})
				_box(Vector3(0.38, 0.5, 0.06), Vector3(cx, 0.75, cz + signf(cz) * 0.17), "black", {"tint": Color(0.15, 0.15, 0.18)})
				_cyl(0.03, 0.03, 0.42, Vector3(cx, 0.22, cz), "gun_metal", {}, Vector3.ZERO, 4)
			for k in 4:
				_box(Vector3(0.22, 0.01, 0.3), Vector3(rng.randf_range(-0.5, 0.5), 0.785, rng.randf_range(-0.25, 0.25)), "dr_paper", {}, Vector3(0, rng.randf() * 360, 0), true)
			_cyl(0.04, 0.035, 0.1, Vector3(0.2, 0.83, 0.1), "white", {"tint": Color(0.95, 0.95, 0.9)}, Vector3.ZERO, 6)
			_ball(0.1, Vector3(-0.3, 0.86, -0.05), "cr_snot", {}, Vector3(1, 0.7, 1))
		"reception":
			_box(Vector3(1.6, 1.05, 0.6), Vector3(0, 0.52, 0), "h_marble")
			_box(Vector3(1.7, 0.06, 0.7), Vector3(0, 1.08, 0), "gun_wood", {"tint": Color(0.6, 0.45, 0.35)})
			_quad(Vector2(1.2, 0.3), Vector3(0, 0.6, 0.305), "dr_sign_regret")
			_box(Vector3(0.45, 0.35, 0.3), Vector3(-0.4, 1.3, -0.1), "white", {"tint": Color(0.85, 0.83, 0.75)})
			_quad(Vector2(0.38, 0.28), Vector3(-0.4, 1.3, -0.255), "h_computer", {"fullbright": 0.7}, Vector3(0, 180, 0))
			_cyl(0.05, 0.07, 0.06, Vector3(0.45, 1.14, 0.15), "gun_brass", {}, Vector3.ZERO, 8)
		"lounge":
			var cc: Color = [Color(0.55, 0.25, 0.2), Color(0.25, 0.35, 0.5), Color(0.4, 0.45, 0.25)][rng.randi_range(0, 2)]
			for sz in [-1, 1]:
				_box(Vector3(1.5, 0.38, 0.5), Vector3(0, 0.22, sz * 0.55), "dr_fabric", {"tint": cc})
				_box(Vector3(1.5, 0.45, 0.14), Vector3(0, 0.6, sz * 0.75), "dr_fabric", {"tint": cc})
			_box(Vector3(0.8, 0.05, 0.4), Vector3(0, 0.42, 0), "gun_wood")
			for sx in [-1, 1]:
				_box(Vector3(0.05, 0.4, 0.35), Vector3(sx * 0.35, 0.2, 0), "gun_dark")
			_box(Vector3(0.25, 0.01, 0.3), Vector3(-0.15, 0.45, 0), "dr_poster_buysell", {}, Vector3(-90, 20, 0), true)
			_cyl(0.04, 0.035, 0.1, Vector3(0.2, 0.5, 0.05), "white", {"tint": Color(0.9, 0.2, 0.2)}, Vector3.ZERO, 6)
		"mascot":
			# the company mascot: a golden Gorbino on a plinth
			var gold := {"tint": Color(1.0, 0.8, 0.3), "gloss": 1.0, "shade": 0.6}
			_box(Vector3(1.1, 0.6, 1.1), Vector3(0, 0.3, 0), "h_marble")
			_quad(Vector2(0.6, 0.15), Vector3(0, 0.35, 0.555), "dr_sign_quiet")
			var hh := h - 0.6
			_ball(hh * 0.32, Vector3(0, 0.6 + hh * 0.55, 0), "gun_brass", gold, Vector3(1, 1.15, 1))
			for k in 6:
				var a := k * TAU / 6.0
				_ball(hh * 0.09, Vector3(cos(a) * hh * 0.25, 0.6 + hh * 0.12, sin(a) * hh * 0.25), "gun_brass", gold, Vector3(1, 1.6, 1))
			for sx in [-1, 1]:
				_ball(hh * 0.07, Vector3(sx * hh * 0.11, 0.6 + hh * 0.62, hh * 0.27), "white", {"fullbright": 0.5})
				_ball(hh * 0.035, Vector3(sx * hh * 0.11, 0.6 + hh * 0.62, hh * 0.33), "black")
		"planters":
			for k in 3:
				var a := k * TAU / 3.0
				var p := Vector3(cos(a) * 0.4, 0, sin(a) * 0.4)
				_box(Vector3(0.5, 0.5, 0.5), p + Vector3(0, 0.25, 0), "h_marble")
				_cyl(0.035, 0.05, 1.2, p + Vector3(0, 1.0, 0), "gun_wood", {}, Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8)), 5)
				for j in 5:
					var b := j * TAU / 5.0
					_box(Vector3(0.6, 0.02, 0.16), p + Vector3(cos(b) * 0.25, 1.55, sin(b) * 0.25), "v_hedge", {}, Vector3(0, -rad_to_deg(b), -25))
		"surgery":
			_box(Vector3(1.8, 0.1, 0.65), Vector3(0, 0.85, 0), "metal_floor")
			_box(Vector3(0.25, 0.8, 0.4), Vector3(0, 0.4, 0), "gun_metal")
			_ball(0.35, Vector3(0.05, 1.0, 0), "white", {"tint": Color(0.86, 0.88, 0.85)}, Vector3(2.0, 0.4, 0.8))
			_ball(0.15, Vector3(-0.72, 1.0, 0), "white", {"tint": Color(0.86, 0.88, 0.85)}, Vector3(1, 0.7, 1))
			_quad(Vector2(0.6, 0.6), Vector3(0.2, 0.91, 0.1), "splat", {"alpha_cut": 0.5, "tint": Color(0.45, 0.0, 0.03)}, Vector3(-90, 0, 0), Rect2(0, 0, 1.0 / Mat.sprite_frames("splat"), 1))
			_cyl(0.04, 0.04, 2.1, Vector3(0.8, 1.05, -0.4), "gun_metal", {}, Vector3.ZERO, 5)
			_box(Vector3(0.6, 0.04, 0.04), Vector3(0.55, 2.1, -0.4), "gun_metal")
			_cyl(0.28, 0.12, 0.15, Vector3(0.25, 2.0, -0.35), "gun_metal")
			_cyl(0.24, 0.24, 0.02, Vector3(0.25, 1.92, -0.35), "white", {"fullbright": 1.0, "tint": Color(0.95, 1, 0.95)})
			_box(Vector3(0.4, 0.03, 0.25), Vector3(-0.6, 1.2, 0.5), "gun_metal")
			_cyl(0.02, 0.02, 1.2, Vector3(-0.6, 0.6, 0.5), "gun_metal", {}, Vector3.ZERO, 4)
			for k in 4:
				_box(Vector3(0.015, 0.01, 0.15), Vector3(-0.72 + k * 0.08, 1.225, 0.5), "gun_metal")
		"bigtank":
			var cr: Color = [Color(0.3, 1, 0.5), Color(1, 0.4, 0.8), Color(0.4, 0.8, 1)][rng.randi_range(0, 2)]
			_cyl(0.68, 0.72, 0.3, Vector3(0, 0.15, 0), "gun_metal", {}, Vector3.ZERO, 12)
			_cyl(0.62, 0.62, h - 0.6, Vector3(0, 0.3 + (h - 0.6) * 0.5, 0), "liq_ooze", {"tint": cr, "fullbright": 0.55, "wobble": 0.6}, Vector3.ZERO, 12)
			_cyl(0.68, 0.68, 0.3, Vector3(0, h - 0.15, 0), "gun_metal", {}, Vector3.ZERO, 12)
			var crt: String = _one(["cr_gorb_green", "cr_gorb_purple", "snirby_skin", "cr_gorb_black"])
			var cy := 0.3 + (h - 0.6) * 0.5
			_ball(0.4, Vector3(0, cy, 0), crt, {"tint": Color(0.7, 0.9, 0.75)}, Vector3(1, 1.2, 1))
			for k in 5:
				var a := k * TAU / 5.0
				_cyl(0.04, 0.07, 0.6, Vector3(cos(a) * 0.22, cy - 0.6, sin(a) * 0.22), crt, {"tint": Color(0.7, 0.9, 0.75)}, Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20)), 5)
			for sx in [-1, 1]:
				_ball(0.08, Vector3(sx * 0.14, cy + 0.12, 0.36), "white", {"fullbright": 0.6})
				_ball(0.04, Vector3(sx * 0.14, cy + 0.12, 0.43), "black")
			if clear - h > 0.2:
				_cyl(0.1, 0.1, clear - h, Vector3(0.3, h + (clear - h) * 0.5, 0), "i_pipes", {}, Vector3.ZERO, 6)
				_cyl(0.1, 0.1, clear - h, Vector3(-0.3, h + (clear - h) * 0.5, 0), "i_pipes", {}, Vector3.ZERO, 6)
		"servers":
			for sz in [-1, 1]:
				_box(Vector3(1.3, 2.0, 0.5), Vector3(0, 1.0, sz * 0.28), "gun_dark")
				for row in 12:
					for k in 6:
						if rng.randf() < 0.5:
							var lc: Color = [Color(0.1, 1, 0.2), Color(1, 0.6, 0.1), Color(0.1, 0.6, 1), Color(1, 0.1, 0.1)][rng.randi_range(0, 3)]
							_box(Vector3(0.03, 0.03, 0.01), Vector3(-0.5 + k * 0.18, 0.25 + row * 0.14, sz * 0.535), "white", {"tint": lc, "fullbright": 1.0})
					_box(Vector3(1.24, 0.01, 0.01), Vector3(0, 0.2 + row * 0.14, sz * 0.532), "gun_metal")
		"cryo":
			_cyl(0.48, 0.48, 0.2, Vector3(0, 0.1, 0), "gun_metal", {}, Vector3.ZERO, 10)
			_cyl(0.42, 0.42, 1.75, Vector3(0, 1.08, 0), "liq_water", {"tint": Color(0.6, 0.85, 1.0), "fullbright": 0.5}, Vector3.ZERO, 10)
			_cyl(0.48, 0.45, 0.25, Vector3(0, 2.05, 0), "gun_metal", {}, Vector3.ZERO, 10)
			_ball(0.18, Vector3(0, 1.5, 0), "cr_snot", {"tint": Color(0.7, 0.85, 1.0)})
			_ball(0.25, Vector3(0, 1.0, 0), "cr_snot", {"tint": Color(0.7, 0.85, 1.0)}, Vector3(0.9, 1.6, 0.9))
			_box(Vector3(0.3, 0.2, 0.05), Vector3(0, 0.4, 0.45), "dr_screen", {"fullbright": 0.8})
		"bigeye":
			var fl: String = _one(["d_flesh", "d_meat"])
			for k in 6:
				var a := k * TAU / 6.0
				_ball(0.35, Vector3(cos(a) * 0.45, 0.2, sin(a) * 0.45), fl, {"wobble": 0.4}, Vector3(1, 0.6, 1))
			_ball(0.75, Vector3(0, 1.1, 0), "white", {"tint": Color(0.95, 0.92, 0.88)}, Vector3.ONE, 12, 8)
			var look := Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.2, 0.3), 1).normalized()
			_ball(0.34, Vector3(0, 1.1, 0) + look * 0.52, "white", {"tint": _one([Color(0.1, 0.7, 0.3), Color(0.8, 0.1, 0.2), Color(0.2, 0.4, 1)]), "fullbright": 0.4}, Vector3(1, 1, 0.5), 10, 6)
			_ball(0.16, Vector3(0, 1.1, 0) + look * 0.72, "black", {}, Vector3(1, 1, 0.5))
		"fleshpillar":
			var fl: String = _one(["d_flesh", "d_meat"])
			var y := 0.0
			while y < h - 0.2:
				var r := rng.randf_range(0.35, 0.6)
				_ball(r, Vector3(rng.randf_range(-0.15, 0.15), y + r * 0.6, rng.randf_range(-0.15, 0.15)), fl, {"wobble": 0.5}, Vector3(1, 0.9, 1))
				y += r * 0.9
			for k in 3:
				var ep := Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.5, minf(h, 3.0)), 0.5)
				_ball(0.1, ep, "white", {"fullbright": 0.4})
				_ball(0.045, ep + Vector3(0, 0, 0.08), "black")
		"floatjunk":
			_cyl(0.45, 0.5, 0.5, Vector3(0, 0.25, 0), "stone", {}, Vector3.ZERO, 8)
			var y := 1.4
			for k in 3:
				var what := rng.randi_range(0, 3)
				var p := Vector3(rng.randf_range(-0.3, 0.3), y, rng.randf_range(-0.3, 0.3))
				var rr := Vector3(rng.randf() * 360, rng.randf() * 360, rng.randf() * 360)
				if what == 0:
					_box(Vector3(0.45, 0.45, 0.45), p, "dr_cardboard", {}, rr, true)
				elif what == 1:
					_box(Vector3(0.5, 0.4, 0.4), p, "gun_dark", {}, rr)
				elif what == 2:
					_ball(0.2, p, "cr_snirby_face", {}, Vector3.ONE)
				else:
					_cyl(0.2, 0.15, 0.4, p, "white", {"tint": Color(0.92, 0.92, 0.88)}, rr)
				y += rng.randf_range(0.6, 0.9)
				if y > clear - 0.4:
					break
		"tub":
			_box(Vector3(1.6, 0.6, 0.8), Vector3(0, 0.4, 0), "white", {"tint": Color(0.92, 0.92, 0.88)})
			_box(Vector3(1.45, 0.02, 0.65), Vector3(0, 0.68, 0), "liq_ooze", {"tint": Color(0.5, 1.0, 0.3), "fullbright": 0.5, "wobble": 1.0})
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_ball(0.06, Vector3(sx * 0.7, 0.06, sz * 0.32), "gun_brass")
			_ball(0.25, Vector3(-0.35, 0.72, 0), "snirby_skin", {}, Vector3(1, 0.6, 1))
			_ball(0.06, Vector3(-0.25, 0.82, 0.12), "white", {"fullbright": 0.5})
			_ball(0.06, Vector3(-0.25, 0.82, -0.12), "white", {"fullbright": 0.5})
			_cyl(0.03, 0.03, 0.4, Vector3(0.75, 0.9, 0), "gun_metal", {}, Vector3(0, 0, 0), 5)
		"car":
			var cc: Color = [Color(0.7, 0.1, 0.1), Color(0.15, 0.3, 0.7), Color(0.9, 0.85, 0.75), Color(0.2, 0.5, 0.2)][rng.randi_range(0, 3)]
			_box(Vector3(1.85, 0.55, 0.95), Vector3(0, 0.5, 0), "gun_metal", {"tint": cc})
			_box(Vector3(1.0, 0.45, 0.85), Vector3(-0.1, 1.0, 0), "gun_metal", {"tint": cc})
			_box(Vector3(1.02, 0.32, 0.87), Vector3(-0.1, 1.0, 0), "black", {"tint": Color(0.15, 0.2, 0.25)})
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_cyl(0.2, 0.2, 0.12, Vector3(sx * 0.6, 0.2, sz * 0.45), "black", {}, Vector3(90, 0, 0), 10)
				_box(Vector3(0.02, 0.12, 0.2), Vector3(sx * 0.93, 0.6, 0.3), "white", {"fullbright": 0.6, "tint": Color(1, 1, 0.8) if sx > 0 else Color(1, 0.1, 0.1)})
				_box(Vector3(0.02, 0.12, 0.2), Vector3(sx * 0.93, 0.6, -0.3), "white", {"fullbright": 0.6, "tint": Color(1, 1, 0.8) if sx > 0 else Color(1, 0.1, 0.1)})
		"teethpile":
			for k in 22:
				var a := rng.randf() * TAU
				var rr := rng.randf() * 0.65
				var th := (0.75 - rr) * 1.3 + rng.randf() * 0.2
				_cyl(0.0, 0.09, 0.28, Vector3(cos(a) * rr, maxf(0.1, th), sin(a) * rr), "white", {"tint": Color(0.95, 0.92, 0.8)},
					Vector3(rng.randf_range(-50, 50), 0, rng.randf_range(-50, 50)), 4)
			_ball(0.55, Vector3(0, 0.25, 0), "d_meat", {}, Vector3(1.3, 0.5, 1.3))


# ================================================================== walls
func _wall_decor(x: int, z: int, dv: Vector2i, f: float, clear: float, sky: bool) -> void:
	var r := rng.randf()
	var tex := ""
	var size := Vector2.ZERO
	var y := 0.0
	var opts := {}
	if r < 0.55:
		tex = _one(POSTERS[theme])
		size = Vector2(0.8, 1.2)
		y = 1.6
	elif r < 0.75 and clear >= 3.0:
		tex = _one(SIGNS[theme])
		size = Vector2(1.6, 0.4)
		y = minf(2.55, clear - 0.4)
	elif theme in ["village", "industrial", "mines", "dimension"]:
		tex = _one(GRAFFITI)
		var s := rng.randf_range(1.0, 1.6)
		size = Vector2(s, s)
		y = rng.randf_range(1.0, 1.7)
		opts = {"alpha_cut": 0.5}
	else:
		# a stain running down the wall
		tex = "splat"
		var s := rng.randf_range(0.6, 1.2)
		size = Vector2(s, s * 1.4)
		y = rng.randf_range(0.6, 1.5)
		opts = {"alpha_cut": 0.5, "tint": Color(0.25, 0.2, 0.12) if rng.randf() < 0.6 else Color(0.45, 0.0, 0.03)}
	_xf = _wall_frame(x, z, dv, f, 0.0, size.x, 0.0)
	_xf.origin -= _xf.basis.z * 0.015
	_xf = _xf * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(rng.randf_range(-4, 4))), Vector3.ZERO)
	var uvr := Rect2(0, 0, 1, 1)
	if tex == "splat":
		var fr := Mat.sprite_frames("splat")
		uvr = Rect2(float(rng.randi_range(0, fr - 1)) / fr, 0, 1.0 / fr, 1)
	_quad(size, Vector3(0, y, 0.02), tex, opts, Vector3.ZERO, uvr)
	_count += 1


# ================================================================== floor and ceiling
func _clutter(x: int, z: int, f: float) -> void:
	var S: float = Level.S
	var what: String = _one(CLUTTER[theme])
	var p := Vector3((x + rng.randf_range(0.15, 0.85)) * S, f, (z + rng.randf_range(0.15, 0.85)) * S)
	_xf = Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p)
	match what:
		"paper":
			for k in rng.randi_range(1, 3):
				_box(Vector3(0.22, 0.004, 0.3), Vector3(rng.randf_range(-0.2, 0.2), 0.003 + k * 0.002, rng.randf_range(-0.2, 0.2)), "dr_paper", {}, Vector3(0, rng.randf() * 360, 0), true)
		"can":
			if rng.randf() < 0.5:
				_cyl(0.035, 0.035, 0.12, Vector3(0, 0.035, 0), "white", {"tint": _one([Color(1, 0.1, 0.1), Color(0.1, 0.8, 0.2), Color(1, 0.9, 0.1)])}, Vector3(90, 0, 0), 6)
			else:
				_cyl(0.035, 0.035, 0.12, Vector3(0, 0.06, 0), "white", {"tint": _one([Color(1, 0.1, 0.1), Color(0.1, 0.8, 0.2), Color(0.2, 0.4, 1)])}, Vector3.ZERO, 6)
		"bottle":
			_cyl(0.04, 0.04, 0.22, Vector3(0, 0.04, 0), "white", {"tint": Color(0.2, 0.5, 0.2)}, Vector3(90, 0, 0), 6)
			_cyl(0.015, 0.02, 0.08, Vector3(0, 0.04, 0.15), "white", {"tint": Color(0.2, 0.5, 0.2)}, Vector3(90, 0, 0), 5)
		"cup":
			_cyl(0.045, 0.035, 0.1, Vector3(0, 0.05, 0), "white", {"tint": Color(0.95, 0.95, 0.9)}, Vector3(0, 0, 0 if rng.randf() < 0.5 else 90), 6)
		"stain":
			var fr := Mat.sprite_frames("splat")
			var s := rng.randf_range(0.6, 1.4)
			var tint: Color = _one([Color(0.22, 0.18, 0.1), Color(0.4, 0.0, 0.03), Color(0.15, 0.25, 0.05)])
			_quad(Vector2(s, s), Vector3(0, 0.012, 0), "splat", {"alpha_cut": 0.5, "tint": tint}, Vector3(-90, 0, 0),
				Rect2(float(rng.randi_range(0, fr - 1)) / fr, 0, 1.0 / fr, 1))
		"leaves":
			for k in rng.randi_range(3, 6):
				_box(Vector3(0.08, 0.005, 0.12), Vector3(rng.randf_range(-0.4, 0.4), 0.004, rng.randf_range(-0.4, 0.4)), "white",
					{"tint": _one([Color(0.6, 0.35, 0.1), Color(0.45, 0.5, 0.1), Color(0.7, 0.2, 0.05)])}, Vector3(0, rng.randf() * 360, 0))
		"bolts":
			for k in rng.randi_range(3, 6):
				_cyl(0.02, 0.02, 0.06, Vector3(rng.randf_range(-0.3, 0.3), 0.02, rng.randf_range(-0.3, 0.3)), "gun_metal", {}, Vector3(90, rng.randf() * 180, 0), 6)
		"rubble":
			for k in rng.randi_range(3, 6):
				_ball(rng.randf_range(0.05, 0.13), Vector3(rng.randf_range(-0.4, 0.4), 0.03, rng.randf_range(-0.4, 0.4)), _one(["m_rock", "m_rock2"]), {}, Vector3(1, 0.6, 1))
		"bones":
			for k in rng.randi_range(2, 4):
				_cyl(0.025, 0.03, rng.randf_range(0.2, 0.35), Vector3(rng.randf_range(-0.3, 0.3), 0.025, rng.randf_range(-0.3, 0.3)), "white",
					{"tint": Color(0.9, 0.86, 0.72)}, Vector3(90, rng.randf() * 180, 0), 5)
		"syringe":
			_cyl(0.012, 0.012, 0.14, Vector3(0, 0.012, 0), "white", {"tint": Color(0.8, 1, 0.85), "fullbright": 0.4}, Vector3(90, 0, 0), 5)
			_cyl(0.002, 0.002, 0.06, Vector3(0, 0.012, 0.1), "gun_metal", {}, Vector3(90, 0, 0), 3)
		"eye":
			_ball(0.07, Vector3(0, 0.07, 0), "white", {"tint": Color(0.95, 0.92, 0.88)})
			_ball(0.035, Vector3(0, 0.08, 0.05), "white", {"tint": Color(0.2, 0.7, 0.3), "fullbright": 0.5})
		"teeth":
			for k in rng.randi_range(3, 7):
				_cyl(0.0, 0.025, 0.06, Vector3(rng.randf_range(-0.25, 0.25), 0.02, rng.randf_range(-0.25, 0.25)), "white", {"tint": Color(0.95, 0.92, 0.8)}, Vector3(rng.randf() * 90, 0, rng.randf() * 90), 4)
	_count += 1


func _hang(x: int, z: int, f: float, c: float) -> void:
	var S: float = Level.S
	var p := Vector3((x + rng.randf_range(0.25, 0.75)) * S, c, (z + rng.randf_range(0.25, 0.75)) * S)
	_xf = Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p)
	var low := f + 2.4          # nothing hangs lower than this
	var what: String = _one(HANG[theme])
	match what:
		"bulb":
			var ln := minf(rng.randf_range(0.5, 1.4), c - low - 0.2)
			_cyl(0.008, 0.008, ln, Vector3(0, -ln * 0.5, 0), "black", {}, Vector3.ZERO, 3)
			_ball(0.07, Vector3(0, -ln - 0.06, 0), "lamp", {"fullbright": 1.0, "tint": Color(1, 0.92, 0.7)})
		"tube":
			_box(Vector3(1.3, 0.05, 0.12), Vector3(0, -0.05, 0), "gun_metal")
			_box(Vector3(1.2, 0.04, 0.05), Vector3(0, -0.1, 0), "white", {"fullbright": 1.0, "tint": Color(0.92, 1, 0.95)})
		"cable":
			var ln := minf(rng.randf_range(0.4, 1.0), c - low)
			for k in 3:
				_cyl(0.012, 0.012, ln, Vector3((k - 1) * 0.08, -ln * 0.5, 0), "black", {}, Vector3(0, 0, (k - 1) * 8), 3)
		"chain":
			var ln := minf(rng.randf_range(0.6, 1.6), c - low)
			for k in int(ln / 0.1):
				_box(Vector3(0.04, 0.09, 0.015), Vector3(0, -0.05 - k * 0.1, 0), "gun_dark", {}, Vector3(0, 90 * (k % 2), 0))
			_box(Vector3(0.03, 0.15, 0.03), Vector3(0, -ln - 0.05, 0), "gun_metal", {}, Vector3(0, 0, 20))
		"carcass":
			# a gutted Gorbino on a meat hook
			var ln := minf(rng.randf_range(0.5, 1.0), c - low - 1.0)
			if ln < 0.1:
				return
			_cyl(0.01, 0.01, ln, Vector3(0, -ln * 0.5, 0), "gun_dark", {}, Vector3.ZERO, 3)
			_cyl(0.02, 0.02, 0.18, Vector3(0, -ln - 0.06, 0.04), "gun_metal", {}, Vector3(40, 0, 0), 4)
			var sk: String = _one(["cr_gorb_green", "cr_gorb_red", "cr_gorb_yellow", "cr_gorb_purple"])
			_ball(0.32, Vector3(0, -ln - 0.48, 0), sk, {"tint": Color(0.75, 0.7, 0.65)}, Vector3(1, 1.25, 0.9))
			_box(Vector3(0.22, 0.4, 0.02), Vector3(0, -ln - 0.5, 0.28), "gore_wound", {}, Vector3(0, 0, 0))
			for k in 4:
				_ball(0.07, Vector3(-0.15 + k * 0.1, -ln - 0.9, 0), sk, {"tint": Color(0.75, 0.7, 0.65)}, Vector3(1, 2.2, 1))
		"roots":
			for k in rng.randi_range(2, 4):
				var ln := minf(rng.randf_range(0.4, 1.2), c - low)
				_cyl(0.005, 0.04, ln, Vector3(rng.randf_range(-0.3, 0.3), -ln * 0.5, rng.randf_range(-0.3, 0.3)), "gun_wood", {"tint": Color(0.5, 0.4, 0.3)}, Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10)), 4)
		"rope":
			var ln := minf(rng.randf_range(0.8, 1.5), c - low)
			_cyl(0.02, 0.02, ln, Vector3(0, -ln * 0.5, 0), "white", {"tint": Color(0.7, 0.6, 0.4)}, Vector3.ZERO, 4)
			_cyl(0.12, 0.12, 0.04, Vector3(0, -ln, 0), "white", {"tint": Color(0.7, 0.6, 0.4)}, Vector3(90, 0, 0), 8)
		"tendril":
			for k in rng.randi_range(2, 4):
				var ln := minf(rng.randf_range(0.6, 1.8), c - low)
				_cyl(0.01, 0.07, ln, Vector3(rng.randf_range(-0.4, 0.4), -ln * 0.5, rng.randf_range(-0.4, 0.4)), "d_flesh", {}, Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-15, 15)), 5)
		"eyeball":
			var ln := minf(rng.randf_range(0.6, 1.4), c - low)
			_cyl(0.015, 0.03, ln, Vector3(0, -ln * 0.5, 0), "d_flesh", {}, Vector3.ZERO, 4)
			_ball(0.18, Vector3(0, -ln - 0.15, 0), "white", {"tint": Color(0.95, 0.93, 0.88)})
			_ball(0.08, Vector3(0, -ln - 0.22, 0.12), "white", {"tint": Color(0.9, 0.1, 0.2), "fullbright": 0.6})
	_count += 1


# ================================================================== geometry
func _mat_entry(tex: String, opts: Dictionary) -> Dictionary:
	var key := tex + str(opts)
	if not _surf.has(key):
		_surf[key] = {"mat": Mat.world(tex, opts), "v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array()}
	return _surf[key]


func _part(pos: Vector3, rot: Vector3) -> Transform3D:
	var b := Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)))
	return _xf * Transform3D(b, pos)


## Emit a quad given corners as seen from the front: bl, br, tr, tl.
func _emit_quad(s: Dictionary, t: Transform3D, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, uv: Array) -> void:
	var p := [t * bl, t * br, t * tr, t * tl]
	var n: Vector3 = (p[1] - p[0]).cross(p[3] - p[0])
	if n.length_squared() < 1e-12:
		n = (p[2] - p[1]).cross(p[0] - p[1])
	n = n.normalized()
	for o in [0, 2, 1, 0, 3, 2]:
		s["v"].append(p[o])
		s["n"].append(n)
		s["uv"].append(uv[o])


func _box(size: Vector3, pos: Vector3, tex: String, opts := {}, rot := Vector3.ZERO, fit := false) -> void:
	var s := _mat_entry(tex, opts)
	var t := _part(pos, rot)
	var h := size * 0.5
	# each face: right axis, up axis, normal axis (right x up = normal)
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK, size.x, size.y],
		[Vector3.LEFT, Vector3.UP, Vector3.FORWARD, size.x, size.y],
		[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT, size.z, size.y],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT, size.z, size.y],
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP, size.x, size.z],
		[Vector3.RIGHT, Vector3.BACK, Vector3.DOWN, size.x, size.z],
	]
	for fc in faces:
		var R: Vector3 = fc[0]
		var U: Vector3 = fc[1]
		var N: Vector3 = fc[2]
		var c := N * (h * N.abs())
		var r := R * (h * R.abs())
		var u := U * (h * U.abs())
		var uw: float = 1.0 if fit else maxf(0.25, fc[3] / 1.0)
		var vh: float = 1.0 if fit else maxf(0.25, fc[4] / 1.0)
		_emit_quad(s, t, c - r - u, c + r - u, c + r + u, c - r + u,
			[Vector2(0, vh), Vector2(uw, vh), Vector2(uw, 0), Vector2(0, 0)])


func _quad(size: Vector2, pos: Vector3, tex: String, opts := {}, rot := Vector3.ZERO, uvr := Rect2(0, 0, 1, 1)) -> void:
	var s := _mat_entry(tex, opts)
	var t := _part(pos, rot)
	var r := Vector3(size.x * 0.5, 0, 0)
	var u := Vector3(0, size.y * 0.5, 0)
	var u0 := uvr.position.x
	var u1 := uvr.end.x
	var v0 := uvr.position.y
	var v1 := uvr.end.y
	_emit_quad(s, t, -r - u, r - u, r + u, -r + u, [Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0), Vector2(u0, v0)])


func _cyl(rt: float, rb: float, h: float, pos: Vector3, tex: String, opts := {}, rot := Vector3.ZERO, seg := 8) -> void:
	var s := _mat_entry(tex, opts)
	var t := _part(pos, rot)
	var hy := h * 0.5
	for k in seg:
		var a0 := float(k) / seg * TAU
		var a1 := float(k + 1) / seg * TAU
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		# seen from outside, a1 is on the left of a0
		var u0 := float(k) / seg
		var u1 := float(k + 1) / seg
		_emit_quad(s, t, d1 * rb + Vector3(0, -hy, 0), d0 * rb + Vector3(0, -hy, 0), d0 * rt + Vector3(0, hy, 0), d1 * rt + Vector3(0, hy, 0),
			[Vector2(u1, 1), Vector2(u0, 1), Vector2(u0, 0), Vector2(u1, 0)])
		if rt > 0.0:
			_emit_tri(s, t, Vector3(0, hy, 0), d1 * rt + Vector3(0, hy, 0), d0 * rt + Vector3(0, hy, 0), Vector3.UP)
		if rb > 0.0:
			_emit_tri(s, t, Vector3(0, -hy, 0), d0 * rb + Vector3(0, -hy, 0), d1 * rb + Vector3(0, -hy, 0), Vector3.DOWN)


func _emit_tri(s: Dictionary, t: Transform3D, a: Vector3, b: Vector3, c: Vector3, want: Vector3) -> void:
	var p := [t * a, t * b, t * c]
	var nw: Vector3 = (t.basis * want).normalized()
	# front faces wind clockwise: (b - a) x (c - a) points away from the viewer
	if (p[1] - p[0]).cross(p[2] - p[0]).dot(nw) > 0.0:
		var tmp = p[1]
		p[1] = p[2]
		p[2] = tmp
	for q in p:
		s["v"].append(q)
		s["n"].append(nw)
		s["uv"].append(Vector2((q.x + q.z) * 0.5, q.y * 0.5))


func _ball(r: float, pos: Vector3, tex: String, opts := {}, scl := Vector3.ONE, seg := 7, rings := 5) -> void:
	var s := _mat_entry(tex, opts)
	var t := _part(pos, Vector3.ZERO)
	var pts := []
	for j in rings + 1:
		var ph := PI * float(j) / rings
		var row := []
		for k in seg + 1:
			var th := TAU * float(k) / seg
			row.append(Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th)))
		pts.append(row)
	for j in rings:
		for k in seg:
			var a: Vector3 = pts[j][k]
			var b: Vector3 = pts[j][k + 1]
			var c: Vector3 = pts[j + 1][k + 1]
			var d: Vector3 = pts[j + 1][k]
			var uv := [Vector2(float(k) / seg, float(j) / rings), Vector2(float(k + 1) / seg, float(j) / rings),
				Vector2(float(k + 1) / seg, float(j + 1) / rings), Vector2(float(k) / seg, float(j + 1) / rings)]
			var P := [t * (a * scl * r), t * (b * scl * r), t * (c * scl * r), t * (d * scl * r)]
			var centre: Vector3 = t * Vector3.ZERO
			var mid: Vector3 = (P[0] + P[1] + P[2] + P[3]) * 0.25
			var out := (mid - centre).normalized()
			# order the two triangles so they face outwards
			var tris := [[0, 1, 2], [0, 2, 3]]
			for tri in tris:
				var q0: Vector3 = P[tri[0]]
				var q1: Vector3 = P[tri[1]]
				var q2: Vector3 = P[tri[2]]
				var i1: int = tri[1]
				var i2: int = tri[2]
				if (q1 - q0).cross(q2 - q0).dot(out) > 0.0:
					var tq := q1
					q1 = q2
					q2 = tq
					var ti := i1
					i1 = i2
					i2 = ti
				var verts := [q0, q1, q2]
				var uvs := [uv[tri[0]], uv[i1], uv[i2]]
				for m in 3:
					s["v"].append(verts[m])
					s["n"].append((verts[m] - centre).normalized())
					s["uv"].append(uvs[m])


func _commit() -> void:
	if _surf.is_empty():
		return
	var mesh := ArrayMesh.new()
	var keys := _surf.keys()
	keys.sort()
	for key in keys:
		var s: Dictionary = _surf[key]
		if s["v"].is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = s["v"]
		arr[Mesh.ARRAY_NORMAL] = s["n"]
		arr[Mesh.ARRAY_TEX_UV] = s["uv"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, s["mat"])
	var mi := MeshInstance3D.new()
	mi.name = "Dressing"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(mi)
	# Centrepieces own their whole cell (enemies path round them), so they
	# stop bullets and sight lines like walls. Props along the walls only stop
	# the player walking (layer 16): enemies move on the grid and can brush
	# into them, and must never end up shielded inside one.
	for solid_kind in [true, false]:
		var body := StaticBody3D.new()
		body.name = "DressingBody" if solid_kind else "DressingProps"
		body.collision_layer = 1 if solid_kind else 16
		body.collision_mask = 0
		for b in _boxes:
			if bool(b[2]) != solid_kind:
				continue
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = b[1]
			cs.shape = bs
			cs.transform = b[0]
			body.add_child(cs)
		if body.get_child_count() > 0:
			level.add_child(body)
		else:
			body.free()
	_surf.clear()
