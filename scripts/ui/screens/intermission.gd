extends Control
## End-of-level tally with counting numbers, a rank stamp, your time against
## par with a clay medal, and your best time (NEW BEST! when you beat it).

var level_index := 0
var stats := {}
var t := 0.0
var phase := 0
var shown := [0.0, 0.0, 0.0, 0.0]
var targets := [0.0, 0.0, 0.0, 0.0]
var par := 120.0
var rank := "C"
var rank_tex: Texture2D
var stamp_tex: Texture2D        # loaded once: re-loading it every draw came out as a white box
var bg: Texture2D
var medal := ""
var medal_tex: Texture2D
var best := -1.0                 # your best before this run
var new_best := false
var _tick := 0.0
var _rank_t := -1.0


func setup(i: int, s: Dictionary) -> void:
	level_index = i
	stats = s


func _pct(a, b) -> float:
	return 100.0 if int(b) == 0 else float(a) * 100.0 / float(b)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg = load("res://assets/ui/menu_bg.png")
	var data := Game.level_data(level_index)
	par = float(data.get("par", 180))
	targets = [_pct(stats["kills"], stats["kills_total"]), _pct(stats["items"], stats["items_total"]),
		_pct(stats["secrets"], stats["secrets_total"]), float(stats["time"])]
	var score := (minf(targets[0], 100) + minf(targets[1], 100) * 0.5 + minf(targets[2], 100) * 0.5) / 2.0
	if targets[3] <= par:
		score += 15
	if score >= 105:
		rank = "S"
	elif score >= 85:
		rank = "A"
	elif score >= 65:
		rank = "B"
	elif score >= 40:
		rank = "C"
	else:
		rank = "D"
	rank_tex = load("res://assets/ui/rank_%s.png" % rank)
	medal = Game.medal_for(targets[3], par)
	if medal != "":
		medal_tex = load("res://assets/ui/medal_%s.png" % medal)
	var lname := Game.level_name(level_index)
	best = Game.best_time(lname)
	new_best = Game.record_finish(lname, targets[3], rank) and best >= 0.0
	stamp_tex = load("res://assets/ui/stamp_cleared.png")
	Audio.play_music("intermission")


var _auto_done := false


func _process(delta: float) -> void:
	t += delta
	if Game.autoplay and t > 0.5 and not _auto_done:
		_auto_done = true
		print("[bot] intermission: ", Game.level_name(level_index), " stats=", stats, " rank=", rank, " medal=", medal)
		Game.after_intermission()
		return
	if phase < 4 and t > 0.6:
		var rate := 90.0 if phase < 3 else maxf(targets[3], 1.0) * 1.2
		shown[phase] = move_toward(shown[phase], targets[phase], delta * rate)
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.06
			Audio.play("tally", -8.0)
		if shown[phase] >= targets[phase]:
			Audio.play("tally_done", -4.0)
			phase += 1
			if phase == 4:
				_rank_t = 0.0
				Audio.play("stamp", 0.0)
	if _rank_t >= 0.0:
		_rank_t += delta
	queue_redraw()


func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey or event is InputEventMouseButton) and event.pressed and not event.is_echo()
	if not pressed or t < 0.5:
		return
	get_viewport().set_input_as_handled()
	if phase < 4:
		for k in 4:
			shown[k] = targets[k]
		phase = 4
		_rank_t = 0.0
		Audio.play("stamp")
	else:
		Audio.play("menu_select", -4.0)
		set_process_input(false)
		Game.after_intermission()


func _draw() -> void:
	draw_texture_rect_region(bg, Rect2(Vector2.ZERO, size), Rect2(Vector2(t * 10, 0), size / 2.0), Color(0.6, 0.6, 0.6))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.4))
	var cx := size.x * 0.5
	if Collage.enabled():
		UI.ransom(self, cx, 14, Game.level_name(level_index), 30.0)
	else:
		UI.text_centered(self, "big", cx, 14, Game.level_name(level_index), Color.WHITE)
	var ss := stamp_tex.get_size() * 0.6
	draw_texture_rect(stamp_tex, Rect2(Vector2(cx - ss.x * 0.5, 62), ss), false, Color(1, 1, 1, 1))
	var labels := ["KILLS", "ITEMS", "SECRETS", "TIME"]
	var y := 118.0
	var lx := cx - 230
	var vx := cx - 10
	for k in 4:
		if k > phase:
			break
		UI.text(self, "menu", Vector2(lx, y), labels[k], Color.WHITE)
		var v: String
		if k < 3:
			v = "%d%%" % int(shown[k])
		else:
			v = Game.format_time(shown[k])
		UI.text(self, "menu", Vector2(vx, y), v, Color.WHITE)
		y += 30
	# par and best, under the time
	if phase >= 3:
		var pb := "PAR %s" % Game.format_time(par)
		if new_best:
			pb += "    BEST %s  (WAS %s)" % [Game.format_time(targets[3]), Game.format_time(best)]
		elif best >= 0.0:
			pb += "    BEST %s" % Game.format_time(best)
		else:
			pb += "    BEST %s  (FIRST CLEAR)" % Game.format_time(targets[3])
		UI.text(self, "term", Vector2(lx, y + 2), pb, UI.BONE, 16)
	if _rank_t >= 0.0:
		var k := clampf(_rank_t * 5.0, 0.0, 1.0)
		# the rank, and beside it the medal your time earned
		var s := rank_tex.get_size() * lerpf(2.5, 1.0, k) * 0.85
		var c := Vector2(cx + 140, 150)
		draw_texture_rect(rank_tex, Rect2(c - s * 0.5, s), false, Color(1, 1, 1, k))
		UI.text_centered(self, "term", c.x, 204, "RANK", UI.ACID, 16)
		if medal_tex:
			var mk := clampf((_rank_t - 0.35) * 5.0, 0.0, 1.0)
			if mk > 0.0:
				var ms := medal_tex.get_size() * lerpf(1.6, 0.62, mk)
				var mc := Vector2(cx + 238, 146)
				draw_texture_rect(medal_tex, Rect2(mc - ms * 0.5, ms), false, Color(1, 1, 1, mk))
				UI.text_centered(self, "term", mc.x, 204, medal.to_upper(), UI.ACID, 16)
		# a new best, slapped on in cut-out letters
		if new_best and _rank_t > 0.6:
			# the cut-out letters twitch by themselves
			if Collage.enabled():
				UI.ransom(self, cx - 120, y + 30, "NEW BEST!", 24.0)
			else:
				UI.text_centered(self, "menu_hi", cx - 120, y + 30, "NEW BEST!", UI.ACID)
	if phase >= 4 and fmod(t, 1.0) < 0.7:
		UI.text_centered(self, "term", cx, size.y - 34, "PRESS ANY KEY", UI.BONE, 18)
