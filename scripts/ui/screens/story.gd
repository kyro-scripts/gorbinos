extends Control
## Between-level story text, typed out over a scrolling texture, then the
## contract dossier for the level: the target turning in a portrait window,
## the offence, the client and the payout.

var text := ""
var title := ""
var cb: Callable
var t := 0.0
var shown := 0.0
var lines := PackedStringArray()
var bg: Texture2D
var done := false
var contract := {}
var page := 0                 # 0 story, 1 dossier
var page_t := 0.0
var vp: SubViewport
var model: Node3D
var crime_lines := PackedStringArray()


func setup(p_text: String, p_title: String, p_cb: Callable) -> void:
	text = p_text
	title = p_title
	cb = p_cb


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg = load("res://assets/textures/d_flesh.png") if title.contains("SNIRBY DIM") else load("res://assets/textures/v_brick.png")
	Audio.play_music("intermission")
	contract = Contracts.for_level(Game.level_data(Game.level_index))
	if text == "":
		if contract.is_empty():
			_finish()
		else:
			_dossier()


func _dossier() -> void:
	page = 1
	page_t = 0.0
	Audio.play("contract_fax", -6.0)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(150, 150)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	var big := String(contract["type"]) == "boss"
	cam.position = Vector3(0, 1.1, 3.2) * (2.6 if big else 1.0)
	cam.fov = 40
	cam.current = true
	vp.add_child(cam)
	cam.look_at(Vector3(0, 0.75 * (2.6 if big else 1.0), 0))
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	model = Contracts.portrait_model(contract)
	if big:
		model.scale = Vector3.ONE * 2.6
	model.rotation.y = PI
	vp.add_child(model)


func _finish() -> void:
	if page == 0 and not contract.is_empty() and not done:
		_dossier()
		return
	if done:
		return
	done = true
	cb.call()


func _process(delta: float) -> void:
	t += delta
	page_t += delta
	shown += delta * 55.0
	if Game.autoplay and page_t > 0.3:
		_finish()
	if model:
		model.rotation.y = PI + sin(t * 0.7) * 0.6
		Creatures.animate(model, t, delta, {"move": 0.0, "blink": fmod(t, 2.7) < 0.1, "windup": fmod(t, 5.0) > 4.3})
	if lines.is_empty() and size.x > 0:
		lines = UI.wrap("term", text, minf(size.x - 80, 480), 18)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if done or page_t < 0.4:
		return
	var pressed: bool = (event is InputEventKey or event is InputEventMouseButton) and event.pressed and not event.is_echo()
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if page == 0 and shown < text.length():
		shown = text.length() + 1
	else:
		Audio.play("menu_select", -4.0)
		_finish()


func _draw() -> void:
	draw_texture_rect_region(bg, Rect2(Vector2.ZERO, size), Rect2(Vector2(t * 6.0, t * 3.0), size / 3.0), Color(0.45, 0.4, 0.5))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	if page == 1:
		_draw_dossier()
		return
	UI.text_centered(self, "term", size.x * 0.5, 18, "NOW ENTERING", UI.ACID, 16)
	UI.text_centered(self, "big", size.x * 0.5, 36, title, Color.WHITE)
	var y := 92.0
	var remaining := int(shown)
	for ln in lines:
		if remaining <= 0:
			break
		var part := ln.substr(0, remaining)
		remaining -= ln.length() + 1
		UI.text_centered(self, "term", size.x * 0.5, y, part, UI.BONE, 18)
		y += 18
	if shown >= text.length() and fmod(t, 1.0) < 0.7:
		UI.text_centered(self, "term", size.x * 0.5, size.y - 34, "PRESS ANY KEY", UI.BONE, 18)


func _draw_dossier() -> void:
	var W := size.x
	var H := size.y
	var r := Rect2(W * 0.5 - 290, 26, 580, H - 70)
	# slide in like a sheet out of a fax
	var k := clampf(page_t * 3.0, 0.0, 1.0)
	r.position.y -= (1.0 - k * (2.0 - k)) * 60.0
	UI.frame(self, r, Color(0.92, 0.89, 0.8, 0.97), Color(0.2, 0.15, 0.15), 2.0)
	var ink := Color(0.12, 0.08, 0.1)
	var red := Color(0.75, 0.05, 0.1)
	var x0 := r.position.x + 14
	var y0 := r.position.y + 10
	UI.text(self, "term", Vector2(x0, y0), "CONTRACT #" + String(contract.get("id", "0000")), red, 18)
	UI.text(self, "term", Vector2(x0 + 200, y0), "CLIENT: " + String(contract.get("client", "")), ink, 16)
	draw_rect(Rect2(x0, y0 + 22, r.size.x - 28, 2), ink)
	# portrait
	var pr := Rect2(x0, y0 + 32, 150, 150)
	draw_rect(pr.grow(3), ink)
	draw_rect(pr, Color(0.25, 0.3, 0.32))
	if vp:
		draw_texture_rect(vp.get_texture(), pr, false)
	for yy in range(int(pr.position.y), int(pr.end.y), 3):
		draw_rect(Rect2(pr.position.x, yy, pr.size.x, 1), Color(0, 0, 0, 0.12))
	UI.text_centered(self, "term", pr.get_center().x, pr.end.y + 4, "TARGET", red, 16)
	# details
	var tx := pr.end.x + 18
	var ty := y0 + 30
	_ink(String(contract.get("name", "")), Vector2(tx, ty), 30, ink)
	ty += 40
	UI.text(self, "term", Vector2(tx, ty), "OFFENCE", red, 16)
	ty += 16
	if crime_lines.is_empty():
		crime_lines = UI.wrap("term", String(contract.get("crime", "")), r.end.x - tx - 14, 16)
	for ln in crime_lines:
		UI.text(self, "term", Vector2(tx, ty), ln, ink, 16)
		ty += 15
	ty += 8
	UI.text(self, "term", Vector2(tx, ty), "TERMS", red, 16)
	ty += 16
	UI.text(self, "term", Vector2(tx, ty), "TERMINATE THE TARGET. EXTRACT.", ink, 16)
	ty += 15
	UI.text(self, "term", Vector2(tx, ty), "GUTTED TARGETS PAY DOUBLE.", ink, 16)
	ty += 22
	UI.text(self, "term", Vector2(tx, ty), "PAYOUT", red, 16)
	_ink("$" + _money(int(contract.get("pay", 0))), Vector2(tx + 62, ty - 5), 22, ink)
	# a stamp across the corner
	draw_set_transform(Vector2(r.end.x - 90, r.end.y - 36), -0.2, Vector2.ONE)
	var cw := UI.text_width("anton", "CONFIDENTIAL", 22)
	_ink("CONFIDENTIAL", Vector2(-cw * 0.5, -14), 22, Color(red, 0.55))
	draw_rect(Rect2(-cw * 0.5 - 6, -16, cw + 12, 30), Color(red, 0.45), false, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if page_t > 0.6 and fmod(t, 1.0) < 0.7:
		UI.text_centered(self, "term", W * 0.5, H - 34, "PRESS ANY KEY TO ACCEPT", UI.BONE, 18)


## Plain condensed type, no outline (it sits on paper).
func _ink(s: String, pos: Vector2, fs: int, c: Color) -> void:
	var f := UI.font("anton")
	draw_string(f, pos + Vector2(0, f.get_ascent(fs)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


static func _money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out
