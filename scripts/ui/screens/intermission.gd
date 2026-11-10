extends Control
## End-of-level tally with counting numbers and a rank stamp.

var level_index := 0
var stats := {}
var t := 0.0
var phase := 0
var shown := [0.0, 0.0, 0.0, 0.0]
var targets := [0.0, 0.0, 0.0, 0.0]
var par := 120.0
var rank := "C"
var rank_tex: Texture2D
var stamp_tex: Texture2D
var bg: Texture2D
var _tick := 0.0
var _rank_t := -1.0
var pay_lines := []           # [label, amount]
var pay_total := 0
var _pay_t := -1.0


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
	stamp_tex = load("res://assets/ui/stamp_cleared.png")
	Audio.play_music("intermission")
	_payout()


## The money: the contract fee, double for a gutted target, a tip for
## beating par, docked for every bystander you killed.
func _payout() -> void:
	var c := Contracts.for_level(Game.level_data(level_index))
	if c.is_empty():
		return
	var base := int(c.get("pay", 0)) if stats.get("target_down", true) else 0
	pay_lines.append(["CONTRACT: " + String(c["name"]), base])
	if stats.get("target_gutted", false):
		pay_lines.append(["GUTTED", base])
	if float(stats.get("time", 0.0)) <= par:
		pay_lines.append(["UNDER PAR", int(base * 0.1)])
	var civ := int(stats.get("civilians", 0))
	if civ > 0:
		pay_lines.append(["COLLATERAL x%d" % civ, -250 * civ])
	pay_total = 0
	for p in pay_lines:
		pay_total += int(p[1])
	pay_total = maxi(pay_total, 0)
	Game.record_contract(level_index, rank, float(stats.get("time", 0.0)), pay_total)


var _auto_done := false


func _process(delta: float) -> void:
	t += delta
	if Game.autoplay and t > 0.5 and not _auto_done:
		_auto_done = true
		print("[bot] intermission: ", Game.level_name(level_index), " stats=", stats, " rank=", rank)
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
		if _rank_t > 0.6 and _pay_t < 0.0 and not pay_lines.is_empty():
			_pay_t = 0.0
			Audio.play("contract_done", -6.0)
	if _pay_t >= 0.0:
		_pay_t += delta
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
	UI.text_centered(self, "big", cx, 14, Game.level_name(level_index), Color.WHITE)
	var ss := stamp_tex.get_size() * 0.6
	draw_texture_rect(stamp_tex, Rect2(Vector2(cx - ss.x * 0.5, 62), ss), false, Color(1, 1, 1, 1))
	var labels := ["KILLS", "ITEMS", "SECRETS", "TIME"]
	var y := 118.0
	for k in 4:
		if k > phase:
			break
		UI.text(self, "menu", Vector2(cx - 200, y), labels[k], Color.WHITE)
		var v: String
		if k < 3:
			v = "%d%%" % int(shown[k])
		else:
			v = Game.format_time(shown[k])
		UI.text(self, "menu", Vector2(cx + 30, y), v, Color.WHITE)
		if k == 3:
			UI.text(self, "term", Vector2(cx + 100, y + 6), "PAR %s" % Game.format_time(par), UI.BONE, 16)
		y += 30
	if _rank_t >= 0.0:
		var k := clampf(_rank_t * 5.0, 0.0, 1.0)
		var s := rank_tex.get_size() * lerpf(2.5, 1.0, k)
		var c := Vector2(cx + 170, 150)
		draw_texture_rect(rank_tex, Rect2(c - s * 0.5, s), false, Color(1, 1, 1, k))
		UI.text_centered(self, "term", c.x, 208, "RANK", UI.ACID, 16)
	if _pay_t >= 0.0:
		var py := 240.0
		for k in pay_lines.size():
			if _pay_t < k * 0.18:
				break
			var amt := int(pay_lines[k][1])
			var col := UI.BLOOD if amt < 0 else (UI.ACID if k > 0 else UI.BONE)
			UI.text(self, "term", Vector2(cx - 200, py), String(pay_lines[k][0]), col, 16)
			var sign := "-" if amt < 0 else ("+" if k > 0 else "")
			UI.text(self, "term", Vector2(cx + 30, py), sign + "$" + _money(absi(amt)), col, 16)
			py += 15
		if _pay_t > pay_lines.size() * 0.18:
			draw_rect(Rect2(cx - 200, py + 2, 330, 1), UI.BONE)
			UI.text(self, "term", Vector2(cx - 200, py + 4), "PAID", UI.BONE, 16)
			UI.text(self, "menu", Vector2(cx + 30, py), "$" + _money(pay_total), UI.ACID)
			UI.text(self, "term", Vector2(cx + 130, py + 4), "BANK $" + _money(int(Game.profile.get("bank", 0))), UI.DIM, 16)
	if phase >= 4 and fmod(t, 1.0) < 0.7:
		UI.text_centered(self, "term", cx, size.y - 20, "PRESS ANY KEY", UI.BONE, 18)


static func _money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out
