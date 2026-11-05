class_name HUD
extends Control
## In-game status bar, messages, crosshair, boss bar and automap.

const BAR_H := 44.0

var player: Player
var level: Level
var messages: Array = []         # [text, time]
var center_msg := ""
var center_t := 0.0
var boss: Node = null
var show_map := false
var face_t := 0.0
var face_look := 0.0
var grin_t := 0.0
var _bg: Texture2D
var _frame: Texture2D
var _cross: Array = []
var _last_kills := 0
var _fps_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg = load("res://assets/ui/hud_bg.png")
	_frame = load("res://assets/ui/hud_frame.png")
	for i in 3:
		_cross.append(load("res://assets/ui/crosshair%d.png" % i))


func message(t: String) -> void:
	messages.append([t, 3.5])
	if messages.size() > 4:
		messages.pop_front()
	Audio.play("message", -12.0)


func center(t: String, dur := 2.5) -> void:
	center_msg = t
	center_t = dur


func _process(delta: float) -> void:
	for m in messages:
		m[1] -= delta
	while messages.size() > 0 and messages[0][1] <= 0.0:
		messages.pop_front()
	center_t -= delta
	face_t -= delta
	grin_t -= delta
	if face_t <= 0.0:
		face_t = randf_range(0.8, 2.0)
		face_look = [-1.0, 0.0, 0.0, 1.0][randi() % 4]
	if level and int(level.stats["kills"]) > _last_kills:
		_last_kills = int(level.stats["kills"])
		grin_t = 1.2
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var W := size.x
	var H := size.y
	# crosshair
	var ch := int(Settings.get_v("crosshair"))
	if ch < 3 and not player.dead and not show_map:
		var tex: Texture2D = _cross[ch]
		draw_texture(tex, (Vector2(W, H - BAR_H) * 0.5 - tex.get_size() * 0.5).round(), Color(0.8, 1.0, 0.3, 0.9))
	if show_map:
		_draw_automap(Rect2(0, 0, W, H - BAR_H))
	_draw_bar(W, H)
	# messages
	var y := 4.0
	for m in messages:
		var a := clampf(float(m[1]), 0.0, 1.0)
		UI.text(self, "small", Vector2(6, y), String(m[0]), Color(1, 1, 0.75, a), 8, true)
		y += 11
	if center_t > 0.0 and center_msg != "":
		var a := clampf(center_t * 2.0, 0.0, 1.0)
		UI.text_centered(self, "menu", W * 0.5, H * 0.28, center_msg, Color(1, 1, 1, a))
	# boss bar
	if boss and is_instance_valid(boss) and not boss.dead:
		var bw := W * 0.6
		var r := Rect2(W * 0.2, 20, bw, 10)
		draw_rect(r.grow(2), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(r.position, Vector2(bw * clampf(boss.hp / boss.max_hp, 0, 1), 10)), Color(0.85, 0.2, 0.9))
		draw_rect(r.grow(2), UI.PINK, false, 1.0)
		UI.text_centered(self, "small_bold", W * 0.5, 7, String(boss.def["name"]), UI.BONE, 8, true)
	# plasma heat
	if player.weapons.current == "plasma":
		var hk := player.weapons.heat / 100.0
		var r2 := Rect2(W * 0.5 - 40, H - BAR_H - 14, 80, 5)
		draw_rect(r2.grow(1), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(r2.position, Vector2(80 * hk, 5)), Color(0.3, 0.9, 1.0) if not player.weapons.overheat else Color(1, 0.2, 0.1))
		if player.weapons.overheat:
			UI.text_centered(self, "small_bold", W * 0.5, H - BAR_H - 26, "OVERHEAT", Color(1, 0.3, 0.2), 8, true)
	if Settings.get_v("show_fps"):
		UI.text(self, "small", Vector2(W - 50, 4), "FPS %d" % Engine.get_frames_per_second(), UI.ACID, 8, true)


func _seg(x: float, w: float, label: String, H: float) -> void:
	UI.text_centered(self, "small_bold", x + w * 0.5, H - 11, label, Color(0.05, 0.1, 0.1), 8)
	UI.text_centered(self, "small_bold", x + w * 0.5 - 1, H - 12, label, UI.BONE, 8)


func _big(x: float, w: float, s: String, H: float, col := Color.WHITE) -> void:
	UI.text_centered(self, "hud", x + w * 0.5, H - BAR_H + 2, s, col)


func _draw_bar(W: float, H: float) -> void:
	var top := H - BAR_H
	UI.tile(self, _bg, Rect2(0, top, W, BAR_H))
	draw_rect(Rect2(0, top, W, 2), Color(0.95, 0.5, 0.55))
	draw_rect(Rect2(0, top + 2, W, 1), Color(0.2, 0.0, 0.05))
	var k := W / 640.0
	var segs := [[0, 104], [104, 106], [210, 90], [300, 44], [344, 106], [450, 40], [490, 150]]
	for s in segs:
		var x: float = s[0] * k
		var w: float = s[1] * k
		draw_rect(Rect2(x, top + 3, w, BAR_H - 3), Color(0, 0, 0, 0.22))
		draw_rect(Rect2(x + w - 2, top + 3, 2, BAR_H - 3), Color(0.15, 0.0, 0.06, 0.9))
		draw_rect(Rect2(x + w - 3, top + 3, 1, BAR_H - 3), Color(1, 0.6, 0.6, 0.4))
	var wp := player.weapons
	var d := wp.cur()
	# AMMO
	var ax: float = segs[0][0] * k
	var aw: float = segs[0][1] * k
	if String(d["style"]) == "heat":
		_big(ax, aw, str(wp.reserve()), H)
	else:
		_big(ax, aw, str(wp.mag_count()), H, Color(1, 0.4, 0.3) if wp.mag_count() == 0 else Color.WHITE)
		UI.text(self, "small", Vector2(ax + aw - 34, top + 22), "/%d" % wp.reserve(), UI.BONE, 8, true)
	_seg(ax, aw, "AMMO", H)
	if wp.state == "reload":
		UI.text_centered(self, "small_bold", ax + aw * 0.5, top - 12, "RELOADING", UI.ACID, 8, true)
	# HEALTH
	var hc := Color.WHITE if player.health > 30 else Color(1, 0.3, 0.2)
	_big(segs[1][0] * k, segs[1][1] * k, "%d%%" % player.health, H, hc)
	_seg(segs[1][0] * k, segs[1][1] * k, "HEALTH", H)
	# ARMS
	var sx: float = segs[2][0] * k
	var sw: float = segs[2][1] * k
	for i in 6:
		var wn: String = Weapons.ORDER[i]
		var owned := wp.owned.has(wn)
		var cx := sx + 8 + (i % 3) * (sw - 16) / 3.0 + 6
		var cy := top + 5 + (i / 3) * 12
		var col := UI.ACID if wn == wp.current else (UI.BONE if owned else Color(0.2, 0.3, 0.3))
		UI.text(self, "small_bold", Vector2(cx, cy), str(i + 1), col, 8, owned)
	UI.text_centered(self, "small", sx + sw * 0.5, top + 29, String(d["name"]).split(" ")[0], UI.BONE, 8, true)
	# FACE
	_draw_face(Rect2(segs[3][0] * k + 2, top + 4, segs[3][1] * k - 4, BAR_H - 6))
	# ARMOR
	var arc := Color(0.5, 0.9, 1.0) if player.armor_type == 2 else Color.WHITE
	_big(segs[4][0] * k, segs[4][1] * k, "%d%%" % player.armor, H, arc)
	_seg(segs[4][0] * k, segs[4][1] * k, "ARMOR", H)
	# KEYS
	var kx: float = segs[5][0] * k
	var kcols := {"red": Color(1, 0.15, 0.2), "blue": Color(0.25, 0.45, 1), "yellow": Color(1, 0.9, 0.15)}
	var ky := top + 6
	for kn in ["red", "blue", "yellow"]:
		var r := Rect2(kx + 10, ky, 18 * k, 9)
		if player.has_key(kn):
			draw_rect(r, kcols[kn])
			draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(4, 2)), Color(1, 1, 1))
		draw_rect(r, Color(0, 0, 0, 0.6), false, 1.0)
		ky += 12
	# STATS
	var stx: float = segs[6][0] * k + 8
	var st := level.stats
	UI.text(self, "small_bold", Vector2(stx, top + 6), "KILLS  %d/%d" % [st["kills"], st["kills_total"]], UI.BONE, 8, true)
	UI.text(self, "small_bold", Vector2(stx, top + 17), "ITEMS  %d/%d" % [st["items"], st["items_total"]], UI.BONE, 8, true)
	UI.text(self, "small_bold", Vector2(stx, top + 28), "SECRET %d/%d" % [st["secrets"], st["secrets_total"]], UI.BONE, 8, true)


func _draw_face(r: Rect2) -> void:
	draw_rect(r, Color(0.05, 0.02, 0.06))
	var c := r.get_center() + Vector2(0, 1)
	var rad := minf(r.size.x, r.size.y) * 0.42
	var hp := player.health
	var col := Color(0.5, 0.95, 0.2)
	if hp < 40:
		col = Color(0.75, 0.85, 0.2)
	if hp < 15:
		col = Color(0.85, 0.6, 0.25)
	if player.dead:
		col = Color(0.4, 0.4, 0.4)
	var hurt := player.hurt_t > 0.0
	var bob := sin(Time.get_ticks_msec() * 0.004) * 0.6
	c.y += bob
	draw_circle(c, rad + 1, Color(0.05, 0.1, 0.02))
	draw_circle(c, rad, col)
	draw_circle(c + Vector2(-rad * 0.3, -rad * 0.35), rad * 0.35, col.lightened(0.25))
	# sprout
	draw_line(c + Vector2(0, -rad), c + Vector2(1, -rad - 4), col.darkened(0.4), 2.0)
	# eyes
	var look := face_look
	if hurt and player.hurt_dir != Vector3.ZERO:
		var local := player.hurt_dir.rotated(Vector3.UP, -player.yaw)
		look = clampf(-local.x * 2.0, -1.0, 1.0)
	for sx in [-1.0, 1.0]:
		var e := c + Vector2(rad * 0.36 * sx, -rad * 0.12)
		if player.dead:
			draw_line(e + Vector2(-2, -2), e + Vector2(2, 2), Color.BLACK, 1.5)
			draw_line(e + Vector2(-2, 2), e + Vector2(2, -2), Color.BLACK, 1.5)
			continue
		draw_circle(e, rad * 0.26, Color(1, 1, 0.95))
		var pr := rad * (0.15 if not hurt else 0.09)
		draw_circle(e + Vector2(look * rad * 0.1, 0), pr, Color.BLACK)
	# mouth
	var my := c.y + rad * 0.42
	var mw := rad * 0.5
	if player.dead:
		draw_rect(Rect2(c.x - mw * 0.6, my - 1, mw * 1.2, 2), Color(0.2, 0, 0))
	elif hurt or hp < 15:
		draw_circle(Vector2(c.x, my), rad * 0.22, Color(0.3, 0.0, 0.05))
	elif grin_t > 0.0 or hp >= 70:
		var pts := PackedVector2Array()
		for i in 9:
			var t := float(i) / 8.0
			pts.append(Vector2(c.x - mw + t * mw * 2.0, my - 2 + sin(t * PI) * (4.0 if grin_t > 0.0 else 2.5)))
		draw_polyline(pts, Color(0.3, 0.0, 0.05), 2.0)
		if grin_t > 0.0:
			draw_rect(Rect2(c.x - mw * 0.6, my - 1, mw * 1.2, 2), Color(1, 1, 1))
	elif hp >= 40:
		draw_line(Vector2(c.x - mw, my), Vector2(c.x + mw, my), Color(0.3, 0.0, 0.05), 2.0)
	else:
		var pts2 := PackedVector2Array()
		for i in 9:
			var t := float(i) / 8.0
			pts2.append(Vector2(c.x - mw + t * mw * 2.0, my + 2 - sin(t * PI) * 2.5))
		draw_polyline(pts2, Color(0.3, 0.0, 0.05), 2.0)
		draw_circle(c + Vector2(rad * 0.75, -rad * 0.4), 1.8, Color(0.5, 0.8, 1.0))
	# frame
	draw_rect(r, Color(0.95, 0.5, 0.55), false, 1.0)


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
	UI.text(self, "small_bold", Vector2(area.position.x + 6, area.end.y - 14), level.data.get("name", ""), UI.BONE, 8, true)
