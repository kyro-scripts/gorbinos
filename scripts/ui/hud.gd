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
var _face_t := 0.0                # subliminal face flash
var _hm_t := 0.0                  # hit marker
var _hm_kill := false
var _face_kind := 0

const BORDER_COLS := [Color(1, 0.2, 0.3), Color(0.25, 1, 0.3), Color(0.3, 0.4, 1), Color(1, 0.9, 0.2), Color(0.05, 0.05, 0.05)]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_jar = load("res://assets/ui/hud_jar.png")
	_specimen = load("res://assets/ui/hud_gorb.png")
	_death_tex = load("res://assets/ui/death.png")


## Ticks round the crosshair when a shot lands; a bigger red X on a kill.
func hit_marker(kill: bool) -> void:
	if kill or not _hm_kill or _hm_t <= 0.0:
		_hm_kill = kill
		_hm_t = 0.32 if kill else 0.12


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
	_hm_t -= delta
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
	_draw_border(W, H)
	_draw_crosshair(W, H)
	_draw_hit_marker(W, H)
	_draw_gut_prompt(W, H)
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


func _draw_ammo(W: float, H: float) -> void:
	var wp := player.weapons
	var d := wp.cur()
	var right := W - 14.0
	var big := ""
	var small := ""
	if String(d["style"]) == "heat":
		big = str(wp.reserve())
	else:
		big = str(wp.mag_count())
		small = "/%d" % wp.reserve()
	var bw := UI.text_width("anton", big, 40)
	var sw := UI.text_width("anton", small, 20) if small != "" else 0.0
	var col := Color(1, 0.3, 0.25) if (String(d["style"]) != "heat" and wp.mag_count() == 0) else UI.BONE
	UI.text(self, "anton", Vector2(right - sw - bw - 4, H - 58), big, col, 40)
	if small != "":
		UI.text(self, "anton", Vector2(right - sw, H - 40), small, Color(0.75, 0.7, 0.7), 20)
	var name := String(d["name"])
	UI.text(self, "term", Vector2(right - UI.text_width("term", name, 16), H - 74), name, UI.BONE, 16)
	if wp.state == "reload":
		UI.text(self, "term", Vector2(right - UI.text_width("term", "RELOADING", 16), H - 90), "RELOADING", UI.ACID, 16)
	if wp.current == "plasma":
		var hk := wp.heat / 100.0
		var r2 := Rect2(right - 90, H - 16, 90, 5)
		draw_rect(r2.grow(1), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(r2.position, Vector2(90 * hk, 5)), Color(0.3, 0.9, 1.0) if not wp.overheat else Color(1, 0.2, 0.1))
		if wp.overheat:
			UI.text(self, "term", Vector2(right - UI.text_width("term", "OVERHEAT", 16), H - 90), "OVERHEAT", Color(1, 0.3, 0.2), 16)



func _draw_hit_marker(W: float, H: float) -> void:
	if _hm_t <= 0.0 or player.dead or show_map:
		return
	var c := Vector2(W, H) * 0.5
	var a := clampf(_hm_t / (0.32 if _hm_kill else 0.12), 0.0, 1.0)
	var r0 := 9.0 if _hm_kill else 7.0
	var r1 := (17.0 if _hm_kill else 12.0) + (1.0 - a) * 3.0
	var col := Color(1.0, 0.1, 0.1, a) if _hm_kill else Color(1, 1, 1, a)
	for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var n: Vector2 = d.normalized()
		draw_line(c + n * r0 + Vector2(1, 1), c + n * r1 + Vector2(1, 1), Color(0, 0, 0, a * 0.6), 3.0 if _hm_kill else 2.0)
		draw_line(c + n * r0, c + n * r1, col, 2.0 if _hm_kill else 1.5)


func _draw_gut_prompt(W: float, H: float) -> void:
	var f = player.finisher
	if f == null or f.active() or f.available == null or player.dead or show_map:
		return
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.012)
	var key := Settings.bind_label("melee").split(" / ")[0]
	UI.text_centered(self, "anton", W * 0.5, H * 0.5 + 18, "[%s] GUT" % key, Color(1, 0.12, 0.08, pulse), 24)


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
	# player arrow
	var fwd := Vector2(-sin(player.yaw), -cos(player.yaw))
	var side := Vector2(-fwd.y, fwd.x)
	var tip := center + fwd * 6
	draw_colored_polygon(PackedVector2Array([tip, center - fwd * 4 + side * 3.5, center - fwd * 4 - side * 3.5]), UI.ACID)
	var st := level.stats
	UI.text(self, "anton", Vector2(area.position.x + 14, area.position.y + 10), String(level.data.get("name", "")), UI.BONE, 22)
	UI.text(self, "term", Vector2(area.position.x + 14, area.position.y + 40), "KILLS %d/%d   ITEMS %d/%d   SECRETS %d/%d   TIME %s" % [st["kills"], st["kills_total"], st["items"], st["items_total"], st["secrets"], st["secrets_total"], Game.format_time(float(st["time"]))], UI.BONE, 16)
