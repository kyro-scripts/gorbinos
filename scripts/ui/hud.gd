class_name HUD
extends Control
## In-game overlay: health (top left: a photo of your eye that flinches,
## blinks, looks toward whatever hurt you and goes bloodshot as you weaken,
## your HP, and a strip of raw meat that tears shorter; bone for armor and
## fish skin for the frenzy meter underneath), ammo (bottom right),
## keys, crosshair, a jittering noise border, messages, boss bar, automap.

var player: Player
var level: Level
var messages: Array = []         # [text, time]
var center_msg := ""
var center_t := 0.0
var boss: Node = null
var show_map := false
var _photo: Control              # the photo bits (eye, meat, bone, fish skin), drawn smooth on top
var _eye_tex: Texture2D
var _sore_tex: Texture2D
var _meat: Texture2D
var _scales: Texture2D
var _bone: Texture2D
var _eye_t := 0.0
var _eye_blink := -1.0
var _eye_blink_t := 3.0
var _eye_look := 0
var _eye_look_t := 2.0
var _eye_shut_t := 0.0
var _eye_wide_t := 0.0
var _tear_t := 0.0
var _stack_y := 90.0              # where the keys and frenzy meter go, under the card
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
var _stickers: Array = []         # collage stickers: [word, burst, world pos, t, rot, big]
var _say_who := ""                # subtitles
var _say_text := ""
var _say_t := 0.0
var _say_lines := PackedStringArray()

const BORDER_COLS := [Color(1, 0.2, 0.3), Color(0.25, 1, 0.3), Color(0.3, 0.4, 1), Color(1, 0.9, 0.2), Color(0.05, 0.05, 0.05)]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_eye_tex = load("res://assets/sprites/hr_eye.png")
	_sore_tex = load("res://assets/sprites/hr_eye_sore.png")
	_meat = load("res://assets/ui/hud_meat.png")
	_scales = load("res://assets/ui/hud_scales.png")
	_bone = load("res://assets/ui/hud_bone.png")
	_death_tex = load("res://assets/ui/death.png")
	_photo = Control.new()
	_photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_photo)
	_photo.draw.connect(_draw_photos)


## Ticks round the crosshair when a shot lands; a bigger red X on a kill.
func hit_marker(kill: bool) -> void:
	if kill or not _hm_kill or _hm_t <= 0.0:
		_hm_kill = kill
		_hm_t = 0.32 if kill else 0.12


## A face, for a couple of frames.
func flash_face(dur := 0.07) -> void:
	_face_t = dur
	_face_kind = randi() % 2


func sticker(word: Texture2D, burst: Texture2D, pos: Vector3, big: bool) -> void:
	_stickers.append([word, burst, pos, 0.0, randf_range(-0.35, 0.35), big])
	if _stickers.size() > 8:
		_stickers.pop_front()


func subtitle_busy() -> bool:
	return _say_t > 0.3


func say(who: String, text: String) -> void:
	_say_who = who
	_say_text = text
	_say_t = 2.5 + text.length() * 0.05
	_say_lines = PackedStringArray()


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
		_shown_hp = move_toward(_shown_hp, hp, delta * (60.0 if _shown_hp > hp else 160.0))
		if player.health < _last_hp:
			_hit_t = 0.25
			_eye_hit()
		_last_hp = player.health
		_tick_eye(delta, hp)
	_hit_t -= delta
	_face_t -= delta
	if _photo:
		_photo.queue_redraw()
	_hm_t -= delta
	_say_t -= delta
	for st in _stickers:
		st[3] += delta
	_stickers = _stickers.filter(func(st): return st[3] < 1.1)
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
	_draw_frenzy(W, H)
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
		if Collage.enabled():
			UI.ransom(self, W * 0.5, H * 0.22, center_msg, 26.0, a)
		else:
			UI.text_centered(self, "anton", W * 0.5, H * 0.26, center_msg, Color(UI.BONE, a), 30)
	if boss and is_instance_valid(boss) and not boss.dead:
		var bw := W * 0.5
		var r := Rect2(W * 0.25, 22, bw, 8)
		draw_rect(r.grow(2), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(r.position, Vector2(bw * clampf(boss.hp / boss.max_hp, 0, 1), 8)), Color(0.85, 0.25, 0.35))
		UI.text_centered(self, "term", W * 0.5, 4, String(boss.def["name"]), UI.BONE, 16)
	_draw_stickers(W, H)
	_draw_subtitle(W, H)
	_draw_endless(W, H)
	if Settings.get_v("show_fps"):
		UI.text(self, "term", Vector2(W - 70, 8), "FPS %d" % Engine.get_frames_per_second(), UI.ACID, 16)
	if _face_t > 0.0:
		_draw_face(W, H)
	if player.dead and _dead_t > 0.3:
		var k := clampf((_dead_t - 0.3) * 3.0, 0.0, 1.0)
		var s := _death_tex.get_size() * 0.62 * lerpf(2.2, 1.0, k * k)
		var c := Vector2(W * 0.5, 92) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (1.0 - k) * 6.0
		draw_texture_rect(_death_tex, Rect2(c - s * 0.5, s), false, Color(1, 1, 1, k))


## The frenzy meter's label (the fish-skin strip itself is drawn with the photos).
func _draw_frenzy(W: float, H: float) -> void:
	if player.dead or player.frenzy <= 0.0:
		return
	UI.text(self, "term", Vector2(BAR.end.x + 5, _frenzy_y - 7), "FRENZY", Color.from_hsv(fmod(Time.get_ticks_msec() / 300.0, 1.0), 0.8, 1.0), 16)


func _draw_stickers(W: float, H: float) -> void:
	if _stickers.is_empty() or player == null:
		return
	var cam: Camera3D = player.camera
	var vsize := cam.get_viewport().get_visible_rect().size
	if vsize.x <= 0:
		return
	var k := Vector2(W, H) / vsize
	for st in _stickers:
		var p: Vector3 = st[2]
		if cam.is_position_behind(p):
			continue
		var t: float = st[3]
		var sp := cam.unproject_position(p) * k
		# slap on, hold, then drift up and fade
		var sc := 0.0
		if t < 0.08:
			sc = lerpf(0.2, 1.25, t / 0.08)
		elif t < 0.15:
			sc = lerpf(1.25, 1.0, (t - 0.08) / 0.07)
		else:
			sc = 1.0
		var a := clampf((1.1 - t) / 0.45, 0.0, 1.0)
		sp.y -= maxf(0.0, t - 0.6) * 60.0
		var base := 0.5 if st[5] else 0.36
		draw_set_transform(sp, st[4], Vector2.ONE * sc * base)
		if st[1] != null:
			var bt: Texture2D = st[1]
			draw_texture(bt, -bt.get_size() * 0.5 + Vector2(-30, 6), Color(1, 1, 1, a))
		var wt: Texture2D = st[0]
		draw_texture(wt, -wt.get_size() * 0.5, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## ENDLESS: the wave and how many are left, and your best.
func _draw_endless(W: float, H: float) -> void:
	var w = player.world
	if w == null or w.endless == null:
		return
	var e: Endless = w.endless
	var s := e.status()
	var tw := UI.text_width("anton", s, 22)
	draw_rect(Rect2(W * 0.5 - tw * 0.5 - 8, 6, tw + 16, 28), Color(0, 0, 0, 0.6))
	UI.text_centered(self, "anton", W * 0.5, 6, s, UI.ACID if e.state == "rest" else UI.BONE, 22)
	UI.text_centered(self, "term", W * 0.5, 34, "BEST: WAVE %d" % int(e.best.get("wave", 0)), UI.DIM, 16)


func _draw_subtitle(W: float, H: float) -> void:
	if _say_t <= 0.0 or _say_text == "":
		return
	if _say_lines.is_empty():
		_say_lines = UI.wrap("term", _say_who + ": " + _say_text, minf(W * 0.6, 380.0), 16)
	var a := clampf(_say_t * 3.0, 0.0, 1.0)
	var h := _say_lines.size() * 15.0 + 6.0
	var y := H - 92.0 - h
	var w := 0.0
	for ln in _say_lines:
		w = maxf(w, UI.text_width("term", ln, 16))
	draw_rect(Rect2(W * 0.5 - w * 0.5 - 6, y, w + 12, h), Color(0, 0, 0, 0.6 * a))
	for k in _say_lines.size():
		var ln: String = _say_lines[k]
		var x0 := W * 0.5 - w * 0.5
		if k == 0 and ln.begins_with(_say_who):
			UI.text(self, "term", Vector2(x0, y + 2), _say_who + ":", Color(UI.ACID, a), 16)
			UI.text(self, "term", Vector2(x0 + UI.text_width("term", _say_who + ": ", 16), y + 2), ln.substr(_say_who.length() + 2), Color(UI.BONE, a), 16)
		else:
			UI.text(self, "term", Vector2(x0, y + 2 + k * 15), ln, Color(UI.BONE, a), 16)


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


const EYE := {"center": 0, "left": 1, "right": 2, "up": 3, "half": 4, "shut": 5, "wide": 6}
const EYE_FRAMES := 7
const EYE_RECT := Rect2(4, 3, 60, 34.6)
const BAR := Rect2(8, 42, 100, 7)
const STRIP_H := 5.0
var _armor_y := 0.0
var _frenzy_y := 0.0


func _shake() -> Vector2:
	return Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (1.5 if _hit_t > 0.0 else 0.0)


## When you're hit: the eye squeezes shut, then stares, toward the hit.
func _eye_hit() -> void:
	_eye_shut_t = 0.09
	_eye_wide_t = 0.5
	if player.hurt_dir != Vector3.ZERO:
		var side: float = player.camera.global_basis.x.dot(-player.hurt_dir)
		_eye_look = 1 if side > 0.25 else (-1 if side < -0.25 else 0)
		_eye_look_t = 1.6


func _tick_eye(delta: float, hp: float) -> void:
	_eye_t += delta
	_eye_blink_t -= delta
	if _eye_blink_t <= 0.0 and _eye_blink < 0.0:
		_eye_blink = 0.0
		_eye_blink_t = randf_range(2.5, 7.0) * (0.5 if hp < 35.0 else 1.0)
	if _eye_blink >= 0.0:
		_eye_blink += delta
		if _eye_blink > 0.2:
			_eye_blink = -1.0
	_eye_shut_t -= delta
	_eye_wide_t -= delta
	_eye_look_t -= delta
	if _eye_look_t <= 0.0:
		# the odd glance about, now and then
		_eye_look_t = randf_range(3.0, 7.0)
		_eye_look = [0, 0, 0, 0, -1, 1][randi() % 6]
	_tear_t = _tear_t + delta if hp < 30.0 and hp > 0.0 else 0.0


func _eye_frame() -> int:
	var hp := player.health
	if player.dead:
		return EYE["up"]
	if _eye_shut_t > 0.0:
		return EYE["shut"]
	if _eye_blink >= 0.0:
		return EYE["half"] if _eye_blink < 0.05 or _eye_blink > 0.15 else EYE["shut"]
	if _eye_wide_t > 0.0 or player.frenzy > 0.0 or hp > 100:
		return EYE["wide"]
	if hp < 30 and fmod(_eye_t, 3.2) < 1.3:
		return EYE["half"]      # can barely keep it open
	return EYE["right"] if _eye_look > 0 else (EYE["left"] if _eye_look < 0 else EYE["center"])


func _eye_src(t: Texture2D, f: int) -> Rect2:
	var w := float(t.get_width()) / EYE_FRAMES
	return Rect2(w * f, 0, w, t.get_height())


## The HP and armor numbers (the photos go on top, in _draw_photos), and
## where the strips under the meat bar go.
func _draw_health() -> void:
	var hp := player.health
	var num := str(int(round(_shown_hp)))
	var col := UI.BONE
	if hp <= 25:
		col = Color(1, 0.3, 0.25)
	elif hp > 100:
		col = Color(0.55, 1.0, 0.8)
	var at := Vector2(EYE_RECT.end.x + 3, 4) + _shake()
	UI.text(self, "anton", at + Vector2(2, 2), num, Color(0, 0, 0, 0.7), 30)
	UI.text(self, "anton", at, num, col, 30)
	var y := BAR.end.y + 3.0
	_armor_y = -1.0
	if player.armor > 0:
		_armor_y = y
		# the armor count sits beside your HP, the bone strip under the meat
		var ac := Color(0.6, 0.85, 1.0) if player.armor_type == 2 else Color(0.8, 0.95, 0.6)
		var ap := at + Vector2(UI.text_width("anton", num, 30) + 5, 15)
		UI.text(self, "term", ap + Vector2(1, 1), "%d ARMOR" % player.armor, Color(0, 0, 0, 0.7), 16)
		UI.text(self, "term", ap, "%d ARMOR" % player.armor, ac, 16)
		y += STRIP_H + 3.0
	_frenzy_y = -1.0
	if not player.dead and (player.frenzy > 0.0 or player.frenzy_meter > 0.0):
		_frenzy_y = y
		y += STRIP_H + 3.0
	_stack_y = y + 4.0


## A textured strip that tears off at the end (the meat, bone and fish skin).
func _strip(ci: CanvasItem, tex: Texture2D, r: Rect2, frac: float, mod: Color) -> void:
	ci.draw_rect(r.grow(1.0), Color(0.0, 0.0, 0.0, 0.5))
	if frac <= 0.0:
		return
	var x0 := r.position.x
	var xe := x0 + r.size.x * frac
	var y0 := r.position.y
	var h := r.size.y
	var pts := PackedVector2Array([Vector2(x0, y0), Vector2(xe, y0), Vector2(xe + 1.5, y0 + h * 0.25), Vector2(xe - 1.0, y0 + h * 0.5),
		Vector2(xe + 1.2, y0 + h * 0.75), Vector2(xe, y0 + h), Vector2(x0, y0 + h)])
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append(Vector2((p.x - x0) / r.size.x * 0.7, (p.y - y0) / h))
	ci.draw_colored_polygon(pts, mod, uvs, tex)


## Smooth-filtered layer on top: your eye, the meat, the bone, the fish skin.
func _draw_photos() -> void:
	if player == null or show_map:
		return
	var ci := _photo
	var hp := player.health
	var sh := _shake()
	var f := _eye_frame()
	var er := Rect2(EYE_RECT.position + sh, EYE_RECT.size)
	ci.draw_texture_rect_region(_eye_tex, er, _eye_src(_eye_tex, f), Color(0.55, 0.5, 0.5) if player.dead else Color(1, 1, 1))
	# bloodshot and puffy as you weaken
	var sore := clampf((70.0 - float(hp)) / 50.0, 0.0, 1.0)
	if sore > 0.0 and not player.dead:
		ci.draw_texture_rect_region(_sore_tex, er, _eye_src(_sore_tex, f), Color(1, 1, 1, sore))
	# a tear of blood when it's bad
	if _tear_t > 0.0:
		var k := fmod(_tear_t, 2.4) / 2.4
		var a := er.position + Vector2(er.size.x * 0.42, er.size.y * 0.74)
		var b := a + Vector2(1.0, 3.0 + 14.0 * k)
		ci.draw_line(a, b, Color(0.5, 0.0, 0.03, 0.9), 1.8)
		ci.draw_circle(b, 1.5, Color(0.55, 0.0, 0.03, 0.95))
	# the meat tears shorter as you lose health; the chunk just lost flashes
	var bar := Rect2(BAR.position + sh, BAR.size)
	var frac := clampf(float(hp) / 100.0, 0.0, 1.0)
	var shown := clampf(_shown_hp / 100.0, 0.0, 1.0)
	var mod := Color(1, 1, 1)
	if hp > 100:
		mod = Color(1.0, 1.0, 0.75).lerp(Color(0.8, 1.2, 0.8), 0.5 + 0.5 * sin(_eye_t * 6.0))
	elif player.dead:
		mod = Color(0.45, 0.4, 0.4)
	_strip(ci, _meat, bar, frac, mod)
	if shown > frac:
		ci.draw_rect(Rect2(bar.position.x + bar.size.x * frac + 1.5, bar.position.y, bar.size.x * (shown - frac), bar.size.y), Color(1.0, 0.86, 0.82, 0.85))
	if _armor_y >= 0.0:
		var am := 200.0 if player.armor_type == 2 else 100.0
		var tint := Color(0.85, 0.95, 1.15) if player.armor_type == 2 else Color(1.0, 1.0, 0.9)
		_strip(ci, _bone, Rect2(BAR.position.x, _armor_y, BAR.size.x, STRIP_H), clampf(float(player.armor) / am, 0.0, 1.0), tint)
	if _frenzy_y >= 0.0:
		var on: bool = player.frenzy > 0.0
		var k: float = player.frenzy / Player.FRENZY_TIME if on else player.frenzy_meter
		# the fish skin shimmers through every colour during a frenzy
		var gm := Color.from_hsv(fmod(_eye_t * 1.5, 1.0), 0.6, 1.3) if on else Color(1, 1, 1)
		_strip(ci, _scales, Rect2(BAR.position.x, _frenzy_y, BAR.size.x, STRIP_H), clampf(k, 0.0, 1.0), gm)


func _draw_keys() -> void:
	var kcols := {"red": Color(1, 0.15, 0.2), "blue": Color(0.25, 0.45, 1), "yellow": Color(1, 0.9, 0.15)}
	var x := 14.0
	for kn in ["red", "blue", "yellow"]:
		if player.has_key(kn):
			var r := Rect2(x, _stack_y, 16, 10)
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
	var no_mag := String(d["style"]) in ["heat", "flame"]
	if no_mag:
		big = str(wp.reserve())
	else:
		big = str(wp.mag_count())
		small = "/%d" % wp.reserve()
	var bw := UI.text_width("anton", big, 40)
	var sw := UI.text_width("anton", small, 20) if small != "" else 0.0
	var col := Color(1, 0.3, 0.25) if ((not no_mag and wp.mag_count() == 0) or (no_mag and wp.reserve() == 0)) else UI.BONE
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
	if f == null or f.active() or f.whip_phase != "" or player.dead or show_map:
		return
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.012)
	var key := Settings.bind_label("melee").split(" / ")[0]
	if f.available != null:
		UI.text_centered(self, "anton", W * 0.5, H * 0.5 + 18, "[%s] GUT" % key, Color(1, 0.12, 0.08, pulse), 24)
	elif f.whip_available != null:
		UI.text_centered(self, "term", W * 0.5, H * 0.5 + 16, "[%s] YANK" % key, Color(1, 0.5, 0.85, 0.55), 16)


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
