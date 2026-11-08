class_name HUD
extends Control
## In-game overlay: pulsing flesh lump + HP (top left), ammo (bottom right),
## keys, crosshair, a jittering noise border, messages, boss bar, automap.

var player: Player
var level: Level
var messages: Array = []         # [text, time]
var center_msg := ""
var center_t := 0.0
var boss: Node = null
var show_map := false
var _jar: Texture2D
var _specimen: Texture2D
var _jar_t := 0.0
var _bubbles: Array = []
var _noise_t := 0.0
var _noise_seed := 0
var _shown_hp := 100.0
var _hit_t := 0.0
var _last_hp := 100
var _dead_t := 0.0
var _death_tex: Texture2D
var _splats: Array = []           # blood on the screen: [pos 0..1, radius, life, drip]
var _face_t := 0.0                # subliminal face flash
var _face_kind := 0

const BORDER_COLS := [Color(1, 0.2, 0.3), Color(0.25, 1, 0.3), Color(0.3, 0.4, 1), Color(1, 0.9, 0.2), Color(0.05, 0.05, 0.05)]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_jar = load("res://assets/ui/hud_jar.png")
	_specimen = load("res://assets/ui/hud_gorb.png")
	_death_tex = load("res://assets/ui/death.png")


## Blood thrown onto the screen (the gutting finisher).
func splatter(n: int) -> void:
	for k in n:
		_splats.append([Vector2(randf_range(0.08, 0.92), randf_range(0.08, 0.85)), randf_range(12.0, 38.0), randf_range(2.2, 3.8), 0.0, randi()])
	if _splats.size() > 24:
		_splats = _splats.slice(_splats.size() - 24)


## A face, for a couple of frames.
func flash_face(dur := 0.07) -> void:
	_face_t = dur
	_face_kind = randi() % 2


func message(t: String) -> void:
	messages.append([t, 3.0])
	if messages.size() > 4:
		messages.pop_front()


func center(t: String, dur := 2.5) -> void:
	center_msg = t
	center_t = dur


func _process(delta: float) -> void:
	for m in messages:
		m[1] -= delta
	while messages.size() > 0 and messages[0][1] <= 0.0:
		messages.pop_front()
	center_t -= delta
	if player:
		var hp := float(player.health)
		# the specimen gets more agitated the closer you are to death
		_jar_t += delta * (1.0 + (100.0 - clampf(hp, 0, 100)) * 0.05)
		if randf() < delta * 3.0 and hp > 0:
			_bubbles.append(Vector3(randf_range(0.1, 0.9), 1.0, randf_range(0.6, 1.4)))
		for b in _bubbles:
			b.y -= delta * 0.5 * b.z
		_bubbles = _bubbles.filter(func(b): return b.y > 0.0)
		_shown_hp = move_toward(_shown_hp, hp, delta * 160.0)
		if player.health < _last_hp:
			_hit_t = 0.25
		_last_hp = player.health
	_hit_t -= delta
	_face_t -= delta
	for sp in _splats:
		sp[2] -= delta
		sp[3] += delta * (10.0 + sp[1] * 0.4)
	_splats = _splats.filter(func(sp): return sp[2] > 0.0)
	_dead_t = _dead_t + delta if player and player.dead else 0.0
	_noise_t -= delta
	if _noise_t <= 0.0:
		_noise_t = 0.07
		_noise_seed += 1
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var W := size.x
	var H := size.y
	if show_map:
		_draw_automap(Rect2(0, 0, W, H))
	_draw_splats(W, H)
	_draw_border(W, H)
	_draw_crosshair(W, H)
	_draw_gut_prompt(W, H)
	_draw_ammo_marker(W, H)
	_draw_health()
	_draw_ammo(W, H)
	_draw_keys()
	# messages, bottom left
	var y := H - 24.0 - messages.size() * 17.0
	for m in messages:
		var a := clampf(float(m[1]) * 2.0, 0.0, 1.0)
		var tw := UI.text_width("term", String(m[0]), 16)
		draw_rect(Rect2(8, y, tw + 10, 16), Color(0, 0, 0, 0.6 * a))
		UI.text(self, "term", Vector2(13, y - 1), String(m[0]), Color(UI.BONE, a), 16)
		y += 17
	if center_t > 0.0 and center_msg != "":
		var a := clampf(center_t * 2.0, 0.0, 1.0)
		UI.text_centered(self, "anton", W * 0.5, H * 0.26, center_msg, Color(UI.BONE, a), 30)
	if boss and is_instance_valid(boss) and not boss.dead:
		var bw := W * 0.5
		var r := Rect2(W * 0.25, 22, bw, 8)
		draw_rect(r.grow(2), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(r.position, Vector2(bw * clampf(boss.hp / boss.max_hp, 0, 1), 8)), Color(0.85, 0.25, 0.35))
		UI.text_centered(self, "term", W * 0.5, 4, String(boss.def["name"]), UI.BONE, 16)
	if Settings.get_v("show_fps"):
		UI.text(self, "term", Vector2(W - 70, 8), "FPS %d" % Engine.get_frames_per_second(), UI.ACID, 16)
	if _face_t > 0.0:
		_draw_face(W, H)
	if player.dead and _dead_t > 0.3:
		var k := clampf((_dead_t - 0.3) * 3.0, 0.0, 1.0)
		var s := _death_tex.get_size() * 0.62 * lerpf(2.2, 1.0, k * k)
		var c := Vector2(W * 0.5, 92) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (1.0 - k) * 6.0
		draw_texture_rect(_death_tex, Rect2(c - s * 0.5, s), false, Color(1, 1, 1, k))


func _draw_border(W: float, H: float) -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = _noise_seed
	var step := 4.0
	var x := 0.0
	while x < W:
		var t1 := rnd.randi_range(1, 3)
		var t2 := rnd.randi_range(1, 3)
		draw_rect(Rect2(x, 0, step, t1), BORDER_COLS[rnd.randi() % BORDER_COLS.size()])
		draw_rect(Rect2(x, H - t2, step, t2), BORDER_COLS[rnd.randi() % BORDER_COLS.size()])
		x += step
	var yy := 0.0
	while yy < H:
		var t3 := rnd.randi_range(1, 3)
		var t4 := rnd.randi_range(1, 3)
		draw_rect(Rect2(0, yy, t3, step), BORDER_COLS[rnd.randi() % BORDER_COLS.size()])
		draw_rect(Rect2(W - t4, yy, t4, step), BORDER_COLS[rnd.randi() % BORDER_COLS.size()])
		yy += step


func _draw_crosshair(W: float, H: float) -> void:
	var ch := int(Settings.get_v("crosshair"))
	if ch >= 3 or player.dead or show_map or player.gutting:
		return
	var c := Vector2(W, H) * 0.5
	var col := Color(1.0, 0.15, 0.15, 0.9)
	match ch:
		0:
			draw_arc(c, 7.0, 0, TAU, 20, Color(0, 0, 0, 0.5), 2.5)
			draw_arc(c, 7.0, 0, TAU, 20, col, 1.0)
			draw_line(c + Vector2(-10, 0), c + Vector2(-4, 0), col, 1.0)
			draw_line(c + Vector2(4, 0), c + Vector2(10, 0), col, 1.0)
			draw_line(c + Vector2(0, -10), c + Vector2(0, -4), col, 1.0)
			draw_line(c + Vector2(0, 4), c + Vector2(0, 10), col, 1.0)
		1:
			draw_rect(Rect2(c - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), col)
		2:
			draw_line(c + Vector2(-6, 0), c + Vector2(6, 0), col, 1.0)
			draw_line(c + Vector2(0, -6), c + Vector2(0, 6), col, 1.0)


func _draw_health() -> void:
	var hp := player.health
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (1.5 if _hit_t > 0.0 else 0.0)
	var pos := Vector2(8, 6) + shake
	var js := Vector2(40, 70)
	# interior of the jar (texture box 16..64 x 20..120 on an 80x140 image)
	var inner := Rect2(pos + Vector2(8, 10), Vector2(24, 50))
	draw_rect(inner, Color(0.02, 0.03, 0.03, 0.75))
	var frac := clampf(_shown_hp / 100.0, 0.0, 1.0)
	var col := Color(0.35, 0.95, 0.25)
	if hp < 60:
		col = Color(0.95, 0.75, 0.15)
	if hp < 30:
		col = Color(0.95, 0.15, 0.12)
	if hp > 100:
		col = Color(0.3, 1.0, 0.8)
	if player.dead:
		col = Color(0.25, 0.2, 0.2)
	var top := inner.end.y - inner.size.y * frac
	if frac > 0.0:
		var pts := PackedVector2Array()
		var steps := 8
		for k in steps + 1:
			var x := inner.position.x + inner.size.x * k / steps
			pts.append(Vector2(x, clampf(top + sin(_jar_t * 3.0 + k * 0.9) * 1.2, inner.position.y, inner.end.y)))
		pts.append(inner.end)
		pts.append(Vector2(inner.position.x, inner.end.y))
		draw_colored_polygon(pts, Color(col, 0.75))
		draw_rect(Rect2(inner.position.x, top, inner.size.x, 2), Color(col.lightened(0.5), 0.8))
		for b in _bubbles:
			var by: float = lerpf(inner.end.y, top, 1.0 - b.y)
			if by > top + 1:
				draw_circle(Vector2(inner.position.x + inner.size.x * b.x, by), 1.0, Color(1, 1, 1, 0.6))
	# the specimen floats in the fluid; it twitches when you are hurt
	var agit := 1.0 - clampf(hp / 100.0, 0.0, 1.0)
	var sy := clampf(maxf(top, inner.position.y) + 6.0, inner.position.y + 4, inner.end.y - 20)
	var sp := Vector2(inner.get_center().x - 10 + sin(_jar_t * 2.0) * 2.0 + randf_range(-1, 1) * agit * 2.0, sy + sin(_jar_t * 1.3) * 3.0)
	var sm := Color(1, 1, 1) if not player.dead else Color(0.4, 0.4, 0.4)
	draw_texture_rect(_specimen, Rect2(sp, Vector2(20, 20)), false, sm)
	draw_texture_rect(_jar, Rect2(pos, js), false)
	UI.text(self, "anton", Vector2(54, 10), str(int(round(_shown_hp))), Color(1, 0.3, 0.25) if hp <= 25 else UI.BONE, 34)
	if player.armor > 0:
		var ac := Color(0.55, 0.85, 1.0) if player.armor_type == 2 else Color(0.75, 0.95, 0.55)
		UI.text(self, "anton", Vector2(56, 50), "%d ARMOR" % player.armor, ac, 16)


func _draw_keys() -> void:
	var kcols := {"red": Color(1, 0.15, 0.2), "blue": Color(0.25, 0.45, 1), "yellow": Color(1, 0.9, 0.15)}
	var x := 14.0
	for kn in ["red", "blue", "yellow"]:
		if player.has_key(kn):
			var r := Rect2(x, 80, 16, 10)
			draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.6))
			draw_rect(r, kcols[kn])
			draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(5, 2)), Color(1, 1, 1))
			x += 20


func _ammo_state() -> int:
	## 0 fine, 1 low, 2 empty (for the current weapon)
	var wp := player.weapons
	var d := wp.cur()
	var total := wp.mag_count() + wp.reserve() if String(d["style"]) != "heat" else wp.reserve()
	if total <= 0:
		return 2
	var low := maxi(int(d["mag"]), 8) if String(d["style"]) != "heat" else 60
	return 1 if total <= low else 0


func _draw_ammo(W: float, H: float) -> void:
	var wp := player.weapons
	var d := wp.cur()
	var kind := String(d["ammo"])
	var kc: Color = Pickup.AMMO_COLOR.get(kind, UI.BONE)
	var right := W - 14.0
	var big := ""
	var small := ""
	if String(d["style"]) == "heat":
		big = str(wp.reserve())
	else:
		big = str(wp.mag_count())
		small = "/%d" % wp.reserve()
	var st := _ammo_state()
	var flash_on := fmod(Time.get_ticks_msec() * 0.001, 0.5) < 0.3
	var bw := UI.text_width("anton", big, 40)
	var sw := UI.text_width("anton", small, 20) if small != "" else 0.0
	var col := Color(1, 0.3, 0.25) if (String(d["style"]) != "heat" and wp.mag_count() == 0) else UI.BONE
	UI.text(self, "anton", Vector2(right - sw - bw - 4, H - 58), big, col, 40)
	if small != "":
		UI.text(self, "anton", Vector2(right - sw, H - 40), small, kc.lerp(UI.BONE, 0.35), 20)
	# weapon name with the colour chip of the ammo it eats
	var label := "%s  %s" % [String(d["name"]), kind.to_upper()]
	var lw := UI.text_width("term", label, 16)
	UI.text(self, "term", Vector2(right - lw, H - 76), label, UI.BONE, 16)
	draw_rect(Rect2(right - lw - 13, H - 71, 8, 8), kc)
	# all four reserves at a glance; the one in use is boxed
	var x := right
	for k in ["cells", "rockets", "shells", "bullets"]:
		var n: int = int(wp.ammo.get(k, 0))
		var txt := str(n)
		var tw := UI.text_width("term", txt, 16)
		var c: Color = Pickup.AMMO_COLOR[k]
		var a := 1.0 if n > 0 else 0.35
		x -= tw
		UI.text(self, "term", Vector2(x, H - 96), txt, Color(UI.BONE, a), 16)
		x -= 11
		draw_rect(Rect2(x, H - 91, 7, 7), Color(c, a))
		if k == kind:
			draw_rect(Rect2(x - 3, H - 97, tw + 16, 18), Color(c, 0.9), false, 1.0)
		x -= 12
	var status := ""
	var scol := UI.ACID
	if wp.state == "reload":
		status = "RELOADING"
	elif wp.current == "plasma" and wp.overheat:
		status = "OVERHEAT"
		scol = Color(1, 0.3, 0.2)
	elif st == 2:
		status = "OUT OF AMMO - FIND " + kind.to_upper() if flash_on else ""
		scol = Color(1, 0.25, 0.2)
	elif st == 1:
		status = "LOW AMMO" if flash_on else ""
		scol = kc
	if status != "":
		UI.text(self, "term", Vector2(right - UI.text_width("term", status, 16), H - 116), status, scol, 16)
	if wp.current == "plasma":
		var hk := wp.heat / 100.0
		var r2 := Rect2(right - 90, H - 16, 90, 5)
		draw_rect(r2.grow(1), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(r2.position, Vector2(90 * hk, 5)), Color(0.3, 0.9, 1.0) if not wp.overheat else Color(1, 0.2, 0.1))


## When ammo runs low, point at the nearest pickup of the right kind.
func _draw_ammo_marker(W: float, H: float) -> void:
	if player.dead or show_map or player.gutting or level == null:
		return
	if _ammo_state() == 0:
		return
	var kind := String(player.weapons.cur()["ammo"])
	var best: Node = null
	var bd := 60.0
	for pk in level.pickups:
		if not is_instance_valid(pk):
			continue
		var k: String = Pickup.AMMO_KIND.get(pk.ptype, "")
		if k != kind and k != "all":
			continue
		var dd: float = pk.global_position.distance_to(player.global_position)
		if dd < bd:
			bd = dd
			best = pk
	if best == null:
		return
	var cam: Camera3D = player.camera
	var wp: Vector3 = best.global_position + Vector3(0, 0.6, 0)
	var vp_size := Vector2(cam.get_viewport().get_visible_rect().size)
	var sp := cam.unproject_position(wp) / vp_size * Vector2(W, H)
	var behind := cam.is_position_behind(wp)
	var c := Vector2(W, H) * 0.5
	var margin := 40.0
	var on_screen := not behind and Rect2(margin, margin, W - margin * 2, H - margin * 2).has_point(sp)
	if not on_screen:
		var dir := (sp - c) if not behind else (c - sp)
		if dir.length() < 1.0:
			dir = Vector2(0, 1)
		dir = dir.normalized()
		var sx := (W * 0.5 - margin) / maxf(absf(dir.x), 0.001)
		var sy := (H * 0.5 - margin) / maxf(absf(dir.y), 0.001)
		sp = c + dir * minf(sx, sy)
	var col: Color = Pickup.AMMO_COLOR[kind]
	var bob := sin(Time.get_ticks_msec() * 0.008) * 3.0
	var p := sp + Vector2(0, bob)
	var s := 7.0
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)]), Color(0, 0, 0, 0.6))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s + 2), p + Vector2(s - 2, 0), p + Vector2(0, s - 2), p + Vector2(-s + 2, 0)]), col)
	var txt := "%s %dM" % [kind.to_upper(), int(bd)]
	UI.text_centered(self, "term", p.x, p.y + 9, txt, col, 16)


func _draw_gut_prompt(W: float, H: float) -> void:
	var f = player.finisher
	if f == null or f.active() or f.available == null or player.dead or show_map:
		return
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.012)
	var key := Settings.bind_label("melee").split(" / ")[0]
	UI.text_centered(self, "anton", W * 0.5, H * 0.5 + 18, "[%s] GUT" % key, Color(1, 0.12, 0.08, pulse), 24)


func _draw_splats(W: float, H: float) -> void:
	for sp in _splats:
		var a := clampf(float(sp[2]) / 1.2, 0.0, 1.0) * 0.7
		var col := Color(0.42, 0.0, 0.03, a)
		var c := Vector2(sp[0].x * W, sp[0].y * H)
		var r := float(sp[1])
		var rnd := RandomNumberGenerator.new()
		rnd.seed = int(sp[4])
		draw_circle(c, r, col)
		for k in 3:
			var o := Vector2(rnd.randf_range(-1, 1), rnd.randf_range(-1, 1)) * r * 1.2
			draw_circle(c + o, r * rnd.randf_range(0.15, 0.4), col)
		for k in 2:
			var dx := rnd.randf_range(-0.6, 0.6) * r
			var dw := r * rnd.randf_range(0.12, 0.22)
			draw_rect(Rect2(c.x + dx - dw * 0.5, c.y, dw, float(sp[3]) * rnd.randf_range(0.5, 1.0)), col)


func _draw_face(W: float, H: float) -> void:
	var tex: Texture2D
	var src: Rect2
	if _face_kind == 0:
		tex = Mat.tex("cr_snirby_face")
		src = Rect2(Vector2(0.1, 0.15) * tex.get_size(), Vector2(0.8, 0.75) * tex.get_size())
	else:
		tex = Mat.tex("cr_gorb_black")
		src = Rect2(Vector2(0.02, 0.48) * tex.get_size(), Vector2(0.5, 0.5) * tex.get_size())
	var s := H * 1.3
	var r := Rect2(Vector2(W * 0.5 - s * 0.5 + randf_range(-8, 8), H * 0.5 - s * 0.5 + randf_range(-8, 8)), Vector2(s, s))
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
	draw_texture_rect_region(tex, r, src, Color(1.0, 0.6, 0.55, 0.8))


func _draw_automap(area: Rect2) -> void:
	draw_rect(area, Color(0.0, 0.0, 0.02, 0.82))
	var lv := level
	var pp := player.global_position
	var scale := 4.0
	var center := area.get_center()
	var org := center - Vector2(pp.x, pp.z) / Level.S * scale
	var wall := Color(0.95, 0.35, 0.6)
	var step := Color(0.5, 0.45, 0.2)
	var door := Color(0.9, 0.9, 0.2)
	for z in lv.H:
		for x in lv.W:
			var i := z * lv.W + x
			if lv.seen[i] == 0 or lv.solid[i] == 1:
				continue
			var p0 := org + Vector2(x, z) * scale
			if not area.has_point(p0):
				continue
			if lv.movers.has(i):
				draw_rect(Rect2(p0, Vector2(scale, scale)), Color(door, 0.35))
			if lv.exit_cells.has(i):
				draw_rect(Rect2(p0, Vector2(scale, scale)), Color(1, 0.2, 0.2, 0.6))
			for dv in Level.DIRS4:
				var j := lv._idx(x + dv.x, z + dv.y)
				var a: Vector2
				var b: Vector2
				if dv == Vector2i(1, 0):
					a = p0 + Vector2(scale, 0); b = p0 + Vector2(scale, scale)
				elif dv == Vector2i(-1, 0):
					a = p0; b = p0 + Vector2(0, scale)
				elif dv == Vector2i(0, 1):
					a = p0 + Vector2(0, scale); b = p0 + Vector2(scale, scale)
				else:
					a = p0; b = p0 + Vector2(scale, 0)
				if j < 0 or lv.solid[j] == 1:
					draw_line(a, b, wall, 1.0)
				elif abs(lv.floor_h[j] - lv.floor_h[i]) > 0.3 and j > i:
					draw_line(a, b, step, 1.0)
	# ammo the player has seen
	for pk in lv.pickups:
		if not is_instance_valid(pk):
			continue
		var kind: String = Pickup.AMMO_KIND.get(pk.ptype, "")
		if kind == "":
			continue
		var cell: Vector2i = lv.cell_of(pk.global_position)
		var ci := lv.idx_of(cell)
		if ci < 0 or lv.seen[ci] == 0:
			continue
		var mp := org + Vector2(pk.global_position.x, pk.global_position.z) / Level.S * scale
		if area.has_point(mp):
			draw_rect(Rect2(mp - Vector2(2, 2), Vector2(4, 4)), Pickup.AMMO_COLOR[kind])
	# player arrow
	var fwd := Vector2(-sin(player.yaw), -cos(player.yaw))
	var side := Vector2(-fwd.y, fwd.x)
	var tip := center + fwd * 6
	draw_colored_polygon(PackedVector2Array([tip, center - fwd * 4 + side * 3.5, center - fwd * 4 - side * 3.5]), UI.ACID)
	var st := level.stats
	UI.text(self, "anton", Vector2(area.position.x + 14, area.position.y + 10), String(level.data.get("name", "")), UI.BONE, 22)
	UI.text(self, "term", Vector2(area.position.x + 14, area.position.y + 40), "KILLS %d/%d   ITEMS %d/%d   SECRETS %d/%d   TIME %s" % [st["kills"], st["kills_total"], st["items"], st["items_total"], st["secrets"], st["secrets_total"], Game.format_time(float(st["time"]))], UI.BONE, 16)
