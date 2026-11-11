class_name Level
extends Node3D
## Builds a playable level from an ASCII grid definition and runs the
## level-wide logic: sector lighting, doors/lifts, triggers, secrets,
## teleporters, pickups, enemy path fields and line-of-sight queries.

const S := 2.0                 # metres per grid cell
const STEP_ENEMY := 0.8
const INF_D := 1 << 28
const DIRS4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIRS8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

const ENTITY_CHARS := {
	"@": "player",
	"g": "green", "y": "yellow", "r": "red", "b": "blue", "p": "purple", "k": "black",
	"s": "snirby", "f": "skysnirby", "$": "snotling", "Z": "boss",
	"+": "juice", "h": "medkit", "M": "mega",
	"*": "armor_bonus", "A": "armor_green", "V": "armor_blue",
	"i": "bullets", "I": "bullets_box", "c": "shells", "C": "shells_box",
	"o": "rocket", "O": "rockets_box", "e": "cells", "E": "cells_box", "B": "backpack",
	"2": "w_shotgun", "3": "w_ssg", "4": "w_mg", "5": "w_rocket", "6": "w_plasma",
	"R": "key_red", "U": "key_blue", "Y": "key_yellow",
	"x": "barrel", "l": "lamp", "T": "statue", "t": "tree", "m": "machine",
	"!": "checkpoint", "X": "exit_pad",
	"q": "tele_a", "Q": "tele_a_dst", "w": "tele_b", "W": "tele_b_dst",
}
const ENEMY_TYPES := ["green", "yellow", "red", "blue", "purple", "black", "snirby", "skysnirby", "snotling", "boss"]
const BRIGHT := {"i_light": 0.9, "h_ceilinglight": 0.85, "f_ceiling": 0.6, "f_glow": 0.9, "m_lantern": 0.55,
	"exit_panel": 0.45, "lamp": 1.0, "liq_magma": 0.95, "liq_sludge": 0.6, "liq_goo": 0.4, "liq_ooze": 0.55,
	"liq_water": 0.25, "switch_on": 0.4, "switch_off": 0.3, "f_vat": 0.55, "m_crystal": 0.35, "tech_panel": 0.35,
	"tech_panel2": 0.45, "d_swirl": 0.5, "d_glyph": 0.6, "d_eyes": 0.25, "teleport_pad": 0.8, "h_window": 0.5,
	"v_window": 0.2, "checkpoint": 0.6, "i_sign": 0.3, "d_static": 0.5}

var data := {}
var W := 0
var H := 0
var cells := []                       # per cell: sector/solid dictionary (shared per legend char)
var solid := PackedByteArray()
var floor_h := PackedFloat32Array()
var ceil_h := PackedFloat32Array()
var movers := {}                      # cell index -> Mover
var tagged := {}                      # tag -> Array[Mover]
var use_cells := {}                   # cell index -> {kind, tag, mesh}
var entity_specs := []                # parsed entity spawns
var player_start := Vector3.ZERO
var start_yaw := 0.0
var light_img: Image
var light_tex: ImageTexture
var flow_walk := PackedInt32Array()
var flow_fly := PackedInt32Array()
var flow_target := -1
var flow_timer := 0.0
var has_fliers := false
var enemies: Array = []
var civilians: Array = []
var pickups: Array = []
var fog_params := Vector4.ZERO      # as sent to the shaders (Dread dims the light boost)
var barrels: Array = []
var props: Array = []
var checkpoints: Array = []
var teleports := {}                   # cell index -> destination Vector3 + yaw
var tele_dst := {}
var player: Node = null
var world: Node = null
var stats := {"kills": 0, "kills_total": 0, "items": 0, "items_total": 0, "secrets": 0, "secrets_total": 0, "time": 0.0}
var secret_group := {}                # cell index -> group id
var secrets_found := {}
var triggers_fired := {}
var exit_cells := {}
var seen := PackedByteArray()
var boss: Node = null
var finished := false
var dyn_lights: Array = []
var _player_cell := -1
var _entity_root: Node3D
var _fx_root: Node3D


func _init() -> void:
	name = "Level"


# ================================================================== parsing
func load_data(d: Dictionary) -> void:
	data = d
	var legend: Dictionary = _resolve_legend(d["legend"])
	var raw: PackedStringArray = String(d["map"]).split("\n")
	var lines: Array[String] = []
	for l in raw:
		lines.append(l)
	while lines.size() > 0 and lines[0].strip_edges() == "":
		lines.pop_front()
	while lines.size() > 0 and lines[-1].strip_edges() == "":
		lines.pop_back()
	H = lines.size()
	W = 0
	for l in lines:
		W = maxi(W, l.length())
	var n := W * H
	cells.resize(n)
	solid.resize(n)
	floor_h.resize(n)
	ceil_h.resize(n)
	seen.resize(n)
	seen.fill(0)
	var void_cell := {"solid": true, "wall": d.get("wall", "black")}
	var default_char: String = d.get("default", ".")
	for z in H:
		var line: String = lines[z]
		for x in W:
			var ch := line[x] if x < line.length() else " "
			var i := z * W + x
			var sec = null
			if legend.has(ch):
				sec = legend[ch]
			elif ENTITY_CHARS.has(ch):
				entity_specs.append({"type": ENTITY_CHARS[ch], "cell": Vector2i(x, z), "id": entity_specs.size()})
				sec = _neighbor_sector(lines, legend, x, z, default_char)
			else:
				sec = void_cell
			# map border is always solid
			if x == 0 or z == 0 or x == W - 1 or z == H - 1:
				if not sec.get("solid", false):
					sec = void_cell
			cells[i] = sec
			solid[i] = 1 if sec.get("solid", false) else 0
			floor_h[i] = float(sec.get("floor", 0.0))
			ceil_h[i] = float(sec.get("ceil", 4.0))
	# door cells inherit heights from neighbours unless explicit
	for z in H:
		for x in W:
			var i := z * W + x
			var sec: Dictionary = cells[i]
			if sec.has("door") and not sec.has("explicit_heights"):
				var fl := -1000.0
				var cl := 1000.0
				for dv in DIRS4:
					var j := _idx(x + dv.x, z + dv.y)
					if j < 0 or solid[j] == 1 or cells[j].has("door"):
						continue
					fl = maxf(fl, floor_h[j])
					cl = minf(cl, ceil_h[j])
				if fl > -999.0:
					floor_h[i] = fl
					ceil_h[i] = minf(cl, fl + float(sec.get("door_h", 3.0)))
	has_fliers = false
	for e in entity_specs:
		if e["type"] in ["skysnirby", "purple", "boss"]:
			has_fliers = true


func _resolve_legend(src: Dictionary) -> Dictionary:
	var out := {}
	var defaults := {"floor": 0.0, "ceil": 4.0, "ftex": "white", "ctex": "white",
		"side": data.get("side", "white"), "light": 0.75, "flicker": 0}
	var pending := src.keys()
	var guard := 0
	while pending.size() > 0 and guard < 1000:
		guard += 1
		var k = pending.pop_front()
		var e: Dictionary = src[k]
		if e.has("like") and not out.has(e["like"]):
			pending.append(k)
			continue
		var base: Dictionary = out[e["like"]].duplicate() if e.has("like") else {}
		if e.get("solid", false) or e.has("wall") and not e.has("door") and not e.get("open", false):
			var r := {"solid": true, "wall": e.get("wall", data.get("wall", "black"))}
			for kk in e.keys():
				r[kk] = e[kk]
			r["solid"] = true
			out[k] = r
			continue
		var r2 := defaults.duplicate()
		for kk in base.keys():
			r2[kk] = base[kk]
		for kk in e.keys():
			r2[kk] = e[kk]
		r2.erase("like")
		r2["solid"] = false
		if r2.has("door") and (e.has("floor") or e.has("ceil")):
			r2["explicit_heights"] = true
		out[k] = r2
	return out


func _neighbor_sector(lines: Array[String], legend: Dictionary, x: int, z: int, default_char: String) -> Dictionary:
	for dv in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-2, 0), Vector2i(2, 0)]:
		var nx: int = x + dv.x
		var nz: int = z + dv.y
		if nz < 0 or nz >= lines.size() or nx < 0 or nx >= lines[nz].length():
			continue
		var ch: String = lines[nz][nx]
		if legend.has(ch):
			var s: Dictionary = legend[ch]
			if not s.get("solid", false) and not s.has("door") and not s.has("lift") and not s.has("lower"):
				return s
	return legend.get(default_char, {"solid": false, "floor": 0.0, "ceil": 4.0})


# ================================================================== building
func build() -> void:
	_entity_root = Node3D.new()
	_entity_root.name = "Entities"
	add_child(_entity_root)
	_fx_root = Node3D.new()
	_fx_root.name = "FX"
	add_child(_fx_root)
	_build_geometry()
	_build_movers()
	_build_light()
	_build_secrets()
	_build_environment()
	_spawn_entities()
	Civilian.populate(self)


func fx_root() -> Node3D:
	return _fx_root


func entity_root() -> Node3D:
	return _entity_root


func _idx(x: int, z: int) -> int:
	if x < 0 or z < 0 or x >= W or z >= H:
		return -1
	return z * W + x


func idx_of(c: Vector2i) -> int:
	return _idx(c.x, c.y)


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / S)), int(floor(p.z / S)))


func cell_center(c: Vector2i) -> Vector3:
	var i := idx_of(c)
	var y := floor_h[i] if i >= 0 else 0.0
	return Vector3((c.x + 0.5) * S, y, (c.y + 0.5) * S)


func is_sky(i: int) -> bool:
	return i >= 0 and solid[i] == 0 and String(cells[i].get("ctex", "")) == "SKY"


var _surf := {}       # matkey -> {"v": PackedVector3Array, "n":..., "uv":...}
var _col := PackedVector3Array()


func _matkey_for(tex: String, kind := "") -> String:
	return kind + ":" + tex


func _material_for(key: String) -> Material:
	var parts := key.split(":")
	var kind := parts[0]
	var tex := parts[1]
	var opts := {}
	if BRIGHT.has(tex):
		opts["fullbright"] = BRIGHT[tex]
	if kind == "liq":
		opts["scroll"] = Vector2(0.04, 0.025)
		opts["wobble"] = 1.0
	return Mat.world(tex, opts)


func _quad(key: String, q: Array, n: Vector3, uv: Array, flip := false, collide := true, render := true, target = null) -> void:
	var order := [0, 1, 2, 0, 2, 3] if flip else [0, 2, 1, 0, 3, 2]
	if render:
		var s: Dictionary
		var dict: Dictionary = _surf if target == null else target
		if not dict.has(key):
			dict[key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array()}
		s = dict[key]
		for o in order:
			s["v"].append(q[o])
			s["n"].append(n)
			s["uv"].append(uv[o])
	if collide:
		for o in order:
			_col.append(q[o])


func _wall_quad(key: String, x: int, z: int, dir: Vector2i, y0: float, y1: float, collide := true, target = null, v_anchor := INF) -> void:
	if y1 - y0 < 0.001:
		return
	var x0 := x * S
	var x1 := (x + 1) * S
	var z0 := z * S
	var z1 := (z + 1) * S
	var bl: Vector3
	var br: Vector3
	var n: Vector3
	var u0: float
	var u1: float
	if dir == Vector2i(0, -1):     # north neighbour -> face at z0, normal +Z
		bl = Vector3(x0, 0, z0); br = Vector3(x1, 0, z0); n = Vector3(0, 0, 1)
		u0 = x0 / 2.0; u1 = x1 / 2.0
	elif dir == Vector2i(0, 1):    # south -> z1, normal -Z
		bl = Vector3(x1, 0, z1); br = Vector3(x0, 0, z1); n = Vector3(0, 0, -1)
		u0 = -x1 / 2.0; u1 = -x0 / 2.0
	elif dir == Vector2i(-1, 0):   # west -> x0, normal +X
		bl = Vector3(x0, 0, z1); br = Vector3(x0, 0, z0); n = Vector3(1, 0, 0)
		u0 = -z1 / 2.0; u1 = -z0 / 2.0
	else:                          # east -> x1, normal -X
		bl = Vector3(x1, 0, z0); br = Vector3(x1, 0, z1); n = Vector3(-1, 0, 0)
		u0 = z0 / 2.0; u1 = z1 / 2.0
	var q := [bl + Vector3(0, y0, 0), br + Vector3(0, y0, 0), br + Vector3(0, y1, 0), bl + Vector3(0, y1, 0)]
	var vb := -y0 / 2.0
	var vt := -y1 / 2.0
	if v_anchor != INF:
		vb = (v_anchor - y0) / 2.0
		vt = (v_anchor - y1) / 2.0
		u0 = 0.0
		u1 = 1.0
	var uv := [Vector2(u0, vb), Vector2(u1, vb), Vector2(u1, vt), Vector2(u0, vt)]
	_quad(key, q, n, uv, false, collide, true, target)


func _build_geometry() -> void:
	_surf.clear()
	_col = PackedVector3Array()
	for z in H:
		for x in W:
			var i := z * W + x
			if solid[i] == 1:
				continue
			var sec: Dictionary = cells[i]
			var f := floor_h[i]
			var c := ceil_h[i]
			var sky := String(sec.get("ctex", "")) == "SKY"
			var x0 := x * S
			var x1 := (x + 1) * S
			var z0 := z * S
			var z1 := (z + 1) * S
			# floor
			var fkind := "liq" if sec.get("liquid", "") != "" else "w"
			var ftex: String = sec.get("liquid", "") if fkind == "liq" else String(sec.get("ftex", "white"))
			var fq := [Vector3(x0, f, z1), Vector3(x1, f, z1), Vector3(x1, f, z0), Vector3(x0, f, z0)]
			var fuv := [Vector2(x0, z1) / 2.0, Vector2(x1, z1) / 2.0, Vector2(x1, z0) / 2.0, Vector2(x0, z0) / 2.0]
			_quad(_matkey_for(ftex, fkind), fq, Vector3.UP, fuv)
			# ceiling
			var cq := [Vector3(x0, c, z1), Vector3(x1, c, z1), Vector3(x1, c, z0), Vector3(x0, c, z0)]
			if sky:
				_quad("", cq, Vector3.DOWN, fuv, true, true, false)
			else:
				_quad(_matkey_for(String(sec.get("ctex", "white"))), cq, Vector3.DOWN, fuv, true)
			# edges
			for dv in DIRS4:
				var j := _idx(x + dv.x, z + dv.y)
				if j < 0 or solid[j] == 1:
					var wtex: String = cells[j].get("wall", "black") if j >= 0 else "black"
					if j >= 0 and cells[j].has("use"):
						_register_use_wall(j, x, z, dv, f, c)
					else:
						_wall_quad(_matkey_for(wtex), x, z, dv, f, c)
					continue
				var nsec: Dictionary = cells[j]
				var nf := floor_h[j]
				var nc := ceil_h[j]
				if nf > f:
					_wall_quad(_matkey_for(String(nsec.get("side", data.get("side", "white")))), x, z, dv, f, minf(nf, c))
				if nc < c:
					var nsky := String(nsec.get("ctex", "")) == "SKY"
					if not (sky and nsky):
						var utex: String = nsec.get("upper", nsec.get("side", data.get("side", "white")))
						_wall_quad(_matkey_for(utex), x, z, dv, maxf(nc, f), c)
	# commit surfaces into chunk-less meshes (one mesh per material keeps it simple)
	var mi := MeshInstance3D.new()
	mi.name = "Geometry"
	var mesh := ArrayMesh.new()
	var keys := _surf.keys()
	keys.sort()
	for key in keys:
		if key == "":
			continue
		var s: Dictionary = _surf[key]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = s["v"]
		arr[Mesh.ARRAY_NORMAL] = s["n"]
		arr[Mesh.ARRAY_TEX_UV] = s["uv"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material_for(key))
	mi.mesh = mesh
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "WorldBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(_col)
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	_surf.clear()


func _register_use_wall(j: int, x: int, z: int, dv: Vector2i, f: float, c: float) -> void:
	var sec: Dictionary = cells[j]
	if not use_cells.has(j):
		use_cells[j] = {"use": sec.get("use", ""), "tag": int(sec.get("tag", 0)), "surf": {}, "used": false,
			"tex": String(sec.get("wall", "switch_off")), "on_tex": String(sec.get("on_wall", "switch_on" if sec.get("use", "") == "switch" else sec.get("wall", "")))}
	var u: Dictionary = use_cells[j]
	# the panel occupies the lower 2 m; the rest of the wall uses the surround texture
	var top := minf(c, f + 2.0)
	_wall_quad("w:" + u["tex"], x, z, dv, f, top, true, u["surf"], f + 2.0)
	if c > top:
		_wall_quad(_matkey_for(String(sec.get("above", data.get("wall", "black")))), x, z, dv, top, c)


func _commit_use_walls() -> void:
	for j in use_cells.keys():
		var u: Dictionary = use_cells[j]
		var mesh := ArrayMesh.new()
		for key in u["surf"].keys():
			var s: Dictionary = u["surf"][key]
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = s["v"]
			arr[Mesh.ARRAY_NORMAL] = s["n"]
			arr[Mesh.ARRAY_TEX_UV] = s["uv"]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			mesh.surface_set_material(mesh.get_surface_count() - 1, _material_for(key))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		add_child(mi)
		u["mesh"] = mi


func _build_movers() -> void:
	_commit_use_walls()
	for z in H:
		for x in W:
			var i := z * W + x
			if solid[i] == 1:
				continue
			var sec: Dictionary = cells[i]
			var m: Mover = null
			if sec.has("door"):
				m = Mover.new()
				m.kind = "door"
				m.key = String(sec.get("key", ""))
				m.secret = bool(sec.get("secret_door", false))
				m.tag = int(sec.get("tag", 0))
				m.remote = bool(sec.get("remote", false))
				add_child(m)
				var tex: String = sec["door"]
				m.setup(self, "door", Vector2i(x, z), floor_h[i], ceil_h[i], tex, String(sec.get("side", "support")), S)
			elif sec.has("lift") or sec.has("lower"):
				m = Mover.new()
				m.kind = "lift" if sec.has("lift") else "lower"
				m.tag = int(sec.get("tag", 0))
				m.remote = m.kind == "lower"
				add_child(m)
				var top := float(sec.get("top", floor_h[i] + 2.0))
				m.setup(self, m.kind, Vector2i(x, z), floor_h[i], top, String(sec.get("side", "support")), String(sec.get("top_tex", sec.get("ftex", "metal_floor"))), S)
				m.position.y = floor_h[i]
				m.y_closed = floor_h[i]
				m.speed = 4.5
			if m:
				m.name = "Mover_%d_%d" % [x, z]
				movers[i] = m
				if m.tag != 0:
					if not tagged.has(m.tag):
						tagged[m.tag] = []
					tagged[m.tag].append(m)


func _build_light() -> void:
	light_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	for z in H:
		for x in W:
			var i := z * W + x
			var l := 0.0
			var fl := 0
			if solid[i] == 0:
				l = float(cells[i].get("light", 0.75))
				fl = int(cells[i].get("flicker", 0))
			else:
				for dv in DIRS4:
					var j := _idx(x + dv.x, z + dv.y)
					if j >= 0 and solid[j] == 0:
						l = maxf(l, float(cells[j].get("light", 0.75)))
			light_img.set_pixel(x, z, Color(clampf(l, 0.0, 1.0), fl / 4.0, 0.0, 1.0))
	light_tex = ImageTexture.create_from_image(light_img)
	apply_globals()


func apply_globals() -> void:
	RenderingServer.global_shader_parameter_set("level_light", light_tex)
	RenderingServer.global_shader_parameter_set("level_info", Vector4(S, W, H, 0))
	var fc: Color = data.get("fog", Color(0, 0, 0, 1))
	RenderingServer.global_shader_parameter_set("fog_color", Vector4(fc.r, fc.g, fc.b, fc.a))
	# a little darker than the map data asks for: the far end of every room fades out sooner
	fog_params = Vector4(float(data.get("fog_start", 18.0)) * 0.85, float(data.get("fog_end", 70.0)) * 0.85,
		float(data.get("light_boost", 1.5)), float(data.get("diminish", 0.03)) * 1.15)
	RenderingServer.global_shader_parameter_set("fog_params", fog_params)


func _build_secrets() -> void:
	var gid := 0
	for i in W * H:
		if solid[i] == 1 or not cells[i].get("secret", false) or secret_group.has(i):
			continue
		gid += 1
		var stack := [i]
		secret_group[i] = gid
		while stack.size() > 0:
			var c: int = stack.pop_back()
			var cx := c % W
			var cz := c / W
			for dv in DIRS4:
				var j := _idx(cx + dv.x, cz + dv.y)
				if j >= 0 and solid[j] == 0 and cells[j].get("secret", false) and not secret_group.has(j):
					secret_group[j] = gid
					stack.append(j)
	stats["secrets_total"] = gid
	for i in W * H:
		if solid[i] == 0 and cells[i].get("exit", false):
			exit_cells[i] = true


func _build_environment() -> void:
	var env := Environment.new()
	var sky_name: String = data.get("sky", "")
	if sky_name != "":
		var sky := Sky.new()
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/sky.gdshader")
		sm.set_shader_parameter("sky_tex", Mat.tex(sky_name))
		var fc: Color = data.get("fog", Color(0, 0, 0, 1))
		sm.set_shader_parameter("bottom_color", fc)
		sky.sky_material = sm
		sky.radiance_size = Sky.RADIANCE_SIZE_32
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = data.get("fog", Color(0, 0, 0, 1))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _spawn_entities() -> void:
	var tele_src := {}
	for e in entity_specs:
		var t: String = e["type"]
		var c: Vector2i = e["cell"]
		var pos := cell_center(c)
		if t == "player":
			player_start = pos
			start_yaw = deg_to_rad(float(data.get("start_angle", 0.0)))
			continue
		if t in ENEMY_TYPES:
			var en := Enemy.new()
			en.spawn_id = e["id"]
			_entity_root.add_child(en)
			en.setup(t, self, pos, randf() * TAU)
			enemies.append(en)
			if t == "boss":
				boss = en
			else:
				stats["kills_total"] += 1
			continue
		match t:
			"barrel":
				var b := Barrel.new()
				b.spawn_id = e["id"]
				_entity_root.add_child(b)
				b.setup(self, pos)
				barrels.append(b)
			"lamp", "statue", "tree", "machine":
				var pr := Props.make_prop(t, self, pos)
				_entity_root.add_child(pr)
				props.append(pr)
			"checkpoint":
				var ck := Props.make_prop("checkpoint", self, pos)
				_entity_root.add_child(ck)
				checkpoints.append({"node": ck, "pos": pos, "used": false, "id": e["id"]})
			"exit_pad":
				exit_cells[idx_of(c)] = true
				var ex := Props.make_prop("exit_pad", self, pos)
				_entity_root.add_child(ex)
			"tele_a", "tele_b":
				tele_src[idx_of(c)] = t
				var tp := Props.make_prop("teleporter", self, pos)
				_entity_root.add_child(tp)
			"tele_a_dst", "tele_b_dst":
				tele_dst[t.replace("_dst", "")] = pos
			_:
				var pk := Pickup.new()
				pk.spawn_id = e["id"]
				_entity_root.add_child(pk)
				pk.setup(t, pos)
				pickups.append(pk)
				if pk.counts_as_item:
					stats["items_total"] += 1
	for i in tele_src.keys():
		var key: String = tele_src[i]
		if tele_dst.has(key):
			teleports[i] = tele_dst[key]
	_spawn_extras()


## Things added after the maps were drawn, without touching the maps: the
## flamethrower in the industrial complex's armory, and fuel cans left next
## to the big ammo boxes from then on.
const EXTRAS := {
	"SNIRBY INDUSTRIAL COMPLEX": [["w_flamer", 60, 27], ["fuel_box", 59, 26]],
}
const FUEL_FROM := ["SNIRBY INDUSTRIAL COMPLEX", "THE GORBINO MINES", "CONSUMER HEADQUARTERS",
	"THE ENDLESS GORBINO FACILITY", "SNIRBY DIMENSION"]


func _spawn_extras() -> void:
	var name := String(data.get("name", ""))
	var taken := {}
	for e in entity_specs:
		taken[idx_of(e["cell"])] = true
	var extra_id := 800000
	for ex in EXTRAS.get(name, []):
		extra_id += 1
		_extra_pickup(String(ex[0]), Vector2i(int(ex[1]), int(ex[2])), extra_id)
		taken[idx_of(Vector2i(int(ex[1]), int(ex[2])))] = true
	if not name in FUEL_FROM:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name + "fuel")
	for e in entity_specs:
		if not String(e["type"]) in ["shells_box", "cells_box", "rockets_box", "bullets_box"] or rng.randf() > 0.6:
			continue
		var c: Vector2i = e["cell"]
		for dv in DIRS4:
			var n: Vector2i = c + dv
			var ni := idx_of(n)
			if ni < 0 or solid[ni] != 0 or movers.has(ni) or taken.has(ni) or absf(floor_h[ni] - floor_h[idx_of(c)]) > 0.05:
				continue
			if String(cells[ni].get("liquid", "")) != "":
				continue
			extra_id += 1
			_extra_pickup("fuel", n, extra_id)
			taken[ni] = true
			break


func _extra_pickup(t: String, c: Vector2i, id: int) -> void:
	var pk := Pickup.new()
	pk.spawn_id = id
	_entity_root.add_child(pk)
	pk.setup(t, cell_center(c))
	pickups.append(pk)


# ================================================================== queries
func eff_floor(i: int) -> float:
	if movers.has(i):
		var m: Mover = movers[i]
		if m.kind != "door":
			return m.current_top()
	return floor_h[i]


func floor_at(p: Vector3) -> float:
	var i := idx_of(cell_of(p))
	return eff_floor(i) if i >= 0 else 0.0


func ceil_at(p: Vector3) -> float:
	var i := idx_of(cell_of(p))
	return ceil_h[i] if i >= 0 else 0.0


func damage_at(p: Vector3) -> float:
	var i := idx_of(cell_of(p))
	if i < 0 or solid[i] == 1:
		return 0.0
	return float(cells[i].get("damage", 0.0))


func is_liquid_at(p: Vector3) -> bool:
	var i := idx_of(cell_of(p))
	return i >= 0 and solid[i] == 0 and cells[i].get("liquid", "") != ""


func floor_class_at(p: Vector3) -> String:
	var i := idx_of(cell_of(p))
	if i < 0 or solid[i] == 1:
		return "stone"
	if cells[i].get("liquid", "") != "":
		return "liquid"
	var t: String = cells[i].get("ftex", "")
	if t.contains("metal") or t.contains("grate") or t.contains("conveyor") or t.begins_with("i_") or t.contains("rail"):
		return "metal"
	if t.contains("flesh") or t.contains("meat") or t.contains("ooze") or t.contains("teeth") or t.contains("grass"):
		return "squish"
	return "stone"


func can_traverse(a: int, b: int, fly: bool) -> bool:
	if solid[a] == 1 or solid[b] == 1:
		return false
	if movers.has(b):
		var m: Mover = movers[b]
		if m.kind == "door" and not m.is_open() and not m.can_monster_open():
			return false
	if fly:
		return ceil_h[b] - eff_floor(b) >= 1.1
	if eff_floor(b) - eff_floor(a) > STEP_ENEMY:
		return false
	return ceil_h[b] - eff_floor(b) >= 1.4


func compute_flow(target: int, fly: bool) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(W * H)
	dist.fill(INF_D)
	if target < 0:
		return dist
	var q := PackedInt32Array()
	q.append(target)
	dist[target] = 0
	var head := 0
	while head < q.size():
		var c := q[head]
		head += 1
		var cx := c % W
		var cz := c / W
		var dc := dist[c] + 1
		for dv in DIRS4:
			var nx: int = cx + dv.x
			var nz: int = cz + dv.y
			if nx < 0 or nz < 0 or nx >= W or nz >= H:
				continue
			var n := nz * W + nx
			if dist[n] != INF_D:
				continue
			if not can_traverse(n, c, fly):
				continue
			dist[n] = dc
			q.append(n)
	return dist


## Next waypoint (world xz) for an enemy at position p following the flow field.
func flow_step(p: Vector3, fly: bool) -> Vector3:
	var flow := flow_fly if fly else flow_walk
	if flow.is_empty():
		return p
	var c := cell_of(p)
	var i := idx_of(c)
	if i < 0:
		return p
	var best := flow[i]
	var best_c := c
	for dv in DIRS8:
		var n := Vector2i(c.x + dv.x, c.y + dv.y)
		var j := idx_of(n)
		if j < 0 or flow[j] >= best:
			continue
		if dv.x != 0 and dv.y != 0:
			# no corner cutting
			var a := idx_of(Vector2i(c.x + dv.x, c.y))
			var b := idx_of(Vector2i(c.x, c.y + dv.y))
			if a < 0 or b < 0 or flow[a] >= INF_D or flow[b] >= INF_D or solid[a] == 1 or solid[b] == 1:
				continue
			if not can_traverse(i, a, fly) or not can_traverse(i, b, fly):
				continue
		if not can_traverse(i, j, fly):
			continue
		best = flow[j]
		best_c = n
	if best_c == c:
		return p
	var ctr := cell_center(best_c)
	return Vector3(ctr.x, p.y, ctr.z)


func flow_dist(p: Vector3, fly := false) -> int:
	var flow := flow_fly if fly else flow_walk
	var i := idx_of(cell_of(p))
	if i < 0 or flow.is_empty():
		return INF_D
	return flow[i]


## Grid collision for enemies (circle vs cells). Returns true if blocked.
func circle_blocked(p: Vector3, r: float, from_floor: float, fly: bool, height: float) -> bool:
	var cx0 := int(floor((p.x - r) / S))
	var cx1 := int(floor((p.x + r) / S))
	var cz0 := int(floor((p.z - r) / S))
	var cz1 := int(floor((p.z + r) / S))
	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			var i := _idx(cx, cz)
			if i < 0 or solid[i] == 1:
				return true
			if movers.has(i):
				var m: Mover = movers[i]
				if m.kind == "door" and not m.is_open():
					return true
			var ef := eff_floor(i)
			if fly:
				if ceil_h[i] - ef < 1.0 or p.y < ef - 0.1:
					return true
			else:
				if ef - from_floor > STEP_ENEMY:
					return true
				if ceil_h[i] - maxf(ef, from_floor) < height * 0.8:
					return true
	return false


func support_floor(p: Vector3, r: float, from_floor: float) -> float:
	var best := -1000.0
	var cx0 := int(floor((p.x - r * 0.7) / S))
	var cx1 := int(floor((p.x + r * 0.7) / S))
	var cz0 := int(floor((p.z - r * 0.7) / S))
	var cz1 := int(floor((p.z + r * 0.7) / S))
	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			var i := _idx(cx, cz)
			if i < 0 or solid[i] == 1:
				continue
			var ef := eff_floor(i)
			if ef - from_floor <= STEP_ENEMY + 0.05:
				best = maxf(best, ef)
	if best < -999.0:
		return from_floor
	return best


func has_los(a: Vector3, b: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	var hit := space.intersect_ray(q)
	return hit.is_empty()


## from_inside: a ray that starts inside a shape hits it (point-blank shots
## into something pressed right up against you).
func ray(a: Vector3, b: Vector3, mask: int, exclude: Array = [], from_inside := false) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a, b, mask, exclude)
	q.hit_from_inside = from_inside
	return space.intersect_ray(q)


# ================================================================== runtime
func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not finished:
		stats["time"] += delta
	var pc := cell_of(player.global_position)
	var pi := idx_of(pc)
	flow_timer -= delta
	if pi >= 0 and (pi != flow_target and flow_timer <= 0.0 or flow_timer <= -0.6):
		flow_target = pi
		flow_timer = 0.25
		flow_walk = compute_flow(pi, false)
		if has_fliers:
			flow_fly = compute_flow(pi, true)
	if pi != _player_cell and pi >= 0:
		_player_cell = pi
		_on_player_enter_cell(pi)
	_mark_seen(pc)
	_check_pickups()
	_check_checkpoints()
	_check_teleport(pi)


func _mark_seen(pc: Vector2i) -> void:
	for dz in range(-4, 5):
		for dx in range(-4, 5):
			var j := _idx(pc.x + dx, pc.y + dz)
			if j >= 0:
				seen[j] = 1


func _on_player_enter_cell(i: int) -> void:
	var sec: Dictionary = cells[i]
	if secret_group.has(i):
		var g: int = secret_group[i]
		if not secrets_found.has(g):
			secrets_found[g] = true
			stats["secrets"] += 1
			Audio.play("secret")
			if world:
				world.message("SECRET FOUND", true)
	var trig := int(sec.get("trigger", 0))
	if trig != 0 and not triggers_fired.has(i):
		triggers_fired[i] = true
		fire_tag(trig)
	if exit_cells.has(i) and not finished:
		if boss != null and is_instance_valid(boss) and not boss.dead:
			if world:
				world.message("THE EXIT IS SEALED", true)
		else:
			complete()


func fire_tag(tag: int) -> void:
	if not tagged.has(tag):
		return
	for m in tagged[tag]:
		m.trigger()


func complete() -> void:
	if finished:
		return
	finished = true
	Audio.play("exit")
	if world:
		world.level_complete()


func _check_pickups() -> void:
	var pp: Vector3 = player.global_position
	for k in range(pickups.size() - 1, -1, -1):
		var pk = pickups[k]
		if not is_instance_valid(pk):
			pickups.remove_at(k)
			continue
		var d: Vector3 = pk.global_position - pp
		if abs(d.y) < 1.8 and Vector2(d.x, d.z).length() < 1.1:
			if player.try_pickup(pk):
				if pk.counts_as_item:
					stats["items"] += 1
				pickups.remove_at(k)
				pk.collected()


func _check_checkpoints() -> void:
	for ck in checkpoints:
		if ck["used"]:
			continue
		var d: Vector3 = ck["pos"] - player.global_position
		if Vector2(d.x, d.z).length() < 1.4 and abs(d.y) < 2.0:
			ck["used"] = true
			if is_instance_valid(ck["node"]):
				ck["node"].set_meta("used", true)
			if world:
				world.checkpoint()


func _check_teleport(i: int) -> void:
	if not teleports.has(i):
		return
	var c := cell_center(cell_of(player.global_position))
	var d: Vector3 = player.global_position - c
	if Vector2(d.x, d.z).length() > 0.9:
		return
	var dst: Vector3 = teleports[i]
	Fx.telefog(self, player.global_position + Vector3(0, 1, 0))
	player.teleport_to(dst)
	Fx.telefog(self, dst + Vector3(0, 1, 0))
	Audio.play("teleport")
	_player_cell = idx_of(cell_of(dst))


## Player pressed USE: hit is the ray result dictionary.
func use_at(hit: Dictionary, user: Node) -> bool:
	var col = hit.get("collider")
	if col is Mover:
		var msg: String = col.try_use(user)
		if msg != "" and world:
			world.message(msg, true)
		return true
	var p: Vector3 = hit["position"] - hit["normal"] * 0.2
	var i := idx_of(cell_of(p))
	if use_cells.has(i):
		var u: Dictionary = use_cells[i]
		if u["used"]:
			return true
		match String(u["use"]):
			"exit":
				u["used"] = true
				Audio.play_at("switch", p)
				if boss != null and is_instance_valid(boss) and not boss.dead:
					u["used"] = false
					if world:
						world.message("THE EXIT IS SEALED", true)
					return true
				complete()
			"switch":
				u["used"] = true
				Audio.play_at("switch", p)
				_swap_use_tex(u)
				fire_tag(int(u["tag"]))
				if world:
					world.message(String(cells[i].get("msg", "A DOOR OPENED")), false)
		return true
	return false


func _swap_use_tex(u: Dictionary) -> void:
	var mi: MeshInstance3D = u.get("mesh")
	if mi and mi.mesh and String(u["on_tex"]) != "":
		var m := _material_for("w:" + String(u["on_tex"]))
		for s in mi.mesh.get_surface_count():
			mi.mesh.surface_set_material(s, m)


func on_secret_door(_m: Mover) -> void:
	pass


func on_enemy_killed(en: Node) -> void:
	if en != boss and not en.summoned:
		stats["kills"] += 1
	else:
		if world:
			world.on_boss_killed()


## Alert enemies that can "hear" a noise made at position p.
func noise_at(p: Vector3, radius_cells := 18) -> void:
	for c in civilians:
		if is_instance_valid(c) and not c.dead and c.global_position.distance_to(p) < 16.0:
			c.panic(p)
	for en in enemies:
		if not is_instance_valid(en) or en.dead or en.alerted:
			continue
		var fd := flow_dist(en.global_position, en.flying)
		if fd <= radius_cells or en.global_position.distance_to(p) < 9.0:
			en.alert()


func radius_damage(center: Vector3, radius: float, max_damage: float, source: Node, kind := "explosion") -> void:
	var targets: Array = []
	for en in enemies:
		if is_instance_valid(en) and not en.dead:
			targets.append(en)
	for b in barrels:
		if is_instance_valid(b) and not b.exploded:
			targets.append(b)
	for c in civilians:
		if is_instance_valid(c) and not c.dead:
			targets.append(c)
	if player and is_instance_valid(player):
		targets.append(player)
	for t in targets:
		var tp: Vector3 = t.center_point()
		var d := tp.distance_to(center)
		if d > radius:
			continue
		if not has_los(center, tp):
			continue
		var dmg := max_damage * (1.0 - d / radius)
		if t == source and t == player:
			dmg *= 0.5
		var dir := (tp - center).normalized() if d > 0.01 else Vector3.UP
		t.take_damage(dmg, source, dir, kind)


func serialize() -> Dictionary:
	var en := []
	for e in enemies:
		if is_instance_valid(e):
			en.append(e.serialize())
	var pk := []
	for p in pickups:
		if is_instance_valid(p) and p.spawn_id >= 0:
			pk.append(p.spawn_id)
	var mv := {}
	for i in movers.keys():
		mv[str(i)] = movers[i].serialize()
	var bl := []
	for b in barrels:
		if is_instance_valid(b) and b.exploded:
			bl.append(b.spawn_id)
	var used := []
	for i in use_cells.keys():
		if use_cells[i]["used"]:
			used.append(i)
	var cks := []
	for c in checkpoints:
		if c["used"]:
			cks.append(c["id"])
	return {"enemies": en, "pickups_left": pk, "movers": mv, "barrels_gone": bl, "uses": used,
		"secrets": secrets_found.keys(), "triggers": triggers_fired.keys(), "stats": stats.duplicate(),
		"checkpoints": cks, "seen": Marshalls.raw_to_base64(seen),
		"civilians": civilians.filter(func(c): return is_instance_valid(c)).map(func(c): return c.serialize())}


func restore(st: Dictionary) -> void:
	var civ_by_id := {}
	for c in civilians:
		civ_by_id[c.spawn_id] = c
	for d in st.get("civilians", []):
		var cid := int(d.get("id", -1))
		if civ_by_id.has(cid):
			civ_by_id[cid].restore(d)
	var by_id := {}
	for e in enemies:
		by_id[e.spawn_id] = e
	for d in st.get("enemies", []):
		var id := int(d.get("id", -1))
		if by_id.has(id):
			by_id[id].restore(d)
	var keep := {}
	for id in st.get("pickups_left", []):
		keep[int(id)] = true
	for k in range(pickups.size() - 1, -1, -1):
		var p = pickups[k]
		if p.spawn_id >= 0 and not keep.has(p.spawn_id):
			p.queue_free()
			pickups.remove_at(k)
	var mv: Dictionary = st.get("movers", {})
	for k in mv.keys():
		var i := int(k)
		if movers.has(i):
			movers[i].restore(mv[k])
	var gone := {}
	for id in st.get("barrels_gone", []):
		gone[int(id)] = true
	for b in barrels:
		if gone.has(b.spawn_id):
			b.remove_silently()
	for i in st.get("uses", []):
		var ii := int(i)
		if use_cells.has(ii):
			use_cells[ii]["used"] = true
			_swap_use_tex(use_cells[ii])
	for g in st.get("secrets", []):
		secrets_found[int(g)] = true
	for t in st.get("triggers", []):
		triggers_fired[int(t)] = true
	var used_ck := {}
	for c in st.get("checkpoints", []):
		used_ck[int(c)] = true
	for c in checkpoints:
		if used_ck.has(c["id"]):
			c["used"] = true
	var s: Dictionary = st.get("stats", {})
	for k in s.keys():
		stats[k] = s[k]
	for k in ["kills", "kills_total", "items", "items_total", "secrets", "secrets_total"]:
		stats[k] = int(stats[k])
	stats["time"] = float(stats["time"])
	if st.has("seen"):
		var raw := Marshalls.base64_to_raw(st["seen"])
		if raw.size() == seen.size():
			seen = raw


## Path validation helper used by tests: can the player walk from a to b
## given the keys held and the trigger tags already fired?
## The player can step 0.55 m and jump about 1.1 m.
## Highest ledge the player gets onto with a jump (the level test lowers it
## to a plain step to find places that need a jump).
static var max_rise := 1.05


func player_can_traverse(a: int, b: int, keys: Dictionary, tags: Dictionary) -> bool:
	if solid[a] == 1 or solid[b] == 1:
		return false
	var fa := floor_h[a]
	var fb := floor_h[b]
	if movers.has(a):
		var ma: Mover = movers[a]
		if ma.kind == "lift":
			fa = ma.top
		elif ma.kind == "lower" and not tags.has(ma.tag):
			fa = ma.top
	if movers.has(b):
		var m: Mover = movers[b]
		if m.kind == "door":
			if m.remote and not tags.has(m.tag):
				return false
			if m.key != "" and not keys.has(m.key):
				return false
		elif m.kind == "lower" and not tags.has(m.tag):
			fb = m.top
	if fb - fa > max_rise:
		return false
	return ceil_h[b] - fb >= 1.75
