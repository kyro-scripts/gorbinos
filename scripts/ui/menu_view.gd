class_name MenuView
extends Control
## Stacked menu, cut and pasted: every option is a torn strip of paper with
## the words on it, the chosen one lit up and pulled out, with a photo-real
## trout nibbling at it. Title in ransom-note letters. Sliders / toggles /
## choices / key binding rows.

signal emptied

var stack: Array = []           # pages
var sel := 0
var scroll := 0
var waiting_bind := ""
var anim_t := 0.0
var row_h := 24.0
var top_y := 70.0
var allow_empty_back := true
var show_title := true
var center_offset := 0.0
var left_x := -1.0              # >= 0: strips line up on the left at this x, not centred
var _rows: Array = []            # [rect, item_index]
var _fx: Control                 # the trout, drawn smooth on top
var _fish: Texture2D
var _sel_rect := Rect2()
var _sel_t := 0.0
var _flash := ""
var _flash_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_fish = load("res://assets/sprites/hr_fish.png")
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_fx)
	_fx.draw.connect(_draw_fish)


func page() -> Dictionary:
	return stack[-1] if stack.size() > 0 else {}


func push(p: Dictionary) -> void:
	stack.append(p)
	sel = 0
	_sel_t = 0.0
	scroll = 0
	_skip_disabled(1)
	queue_redraw()


func replace(p: Dictionary) -> void:
	if stack.size() > 0:
		stack.pop_back()
	push(p)


func pop() -> void:
	if stack.size() <= 1 and not allow_empty_back:
		return
	Audio.play("menu_back", -4.0)
	stack.pop_back()
	sel = 0
	scroll = 0
	if stack.is_empty():
		emptied.emit()
	else:
		_skip_disabled(1)
	queue_redraw()


func flash(msg: String) -> void:
	_flash = msg
	_flash_t = 1.6


func _items() -> Array:
	return page().get("items", [])


func _selectable(it: Dictionary) -> bool:
	if it.get("type", "button") == "info":
		return false
	var en = it.get("enabled", true)
	if en is Callable:
		en = en.call()
	return bool(en)


func _skip_disabled(dir: int) -> void:
	var items := _items()
	if items.is_empty():
		return
	for k in items.size():
		if _selectable(items[sel]):
			return
		sel = (sel + dir + items.size()) % items.size()


func _move(dir: int) -> void:
	var items := _items()
	if items.is_empty():
		return
	for k in items.size():
		sel = (sel + dir + items.size()) % items.size()
		if _selectable(items[sel]):
			break
	_sel_t = 0.0
	Audio.play("menu_move", -6.0)
	queue_redraw()


func _process(delta: float) -> void:
	anim_t += delta
	_sel_t += delta
	if _flash_t > 0.0:
		_flash_t -= delta
	queue_redraw()
	_fx.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or stack.is_empty():
		return
	if waiting_bind != "":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				waiting_bind = ""
			else:
				Settings.set_bind(waiting_bind, Settings.code_from_event(event))
				waiting_bind = ""
				Audio.play("menu_select", -4.0)
			accept_event_safe()
			return
		if event is InputEventMouseButton and event.pressed:
			Settings.set_bind(waiting_bind, Settings.code_from_event(event))
			waiting_bind = ""
			Audio.play("menu_select", -4.0)
			accept_event_safe()
			return
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP, KEY_W:
				_move(-1)
			KEY_DOWN, KEY_S:
				_move(1)
			KEY_LEFT, KEY_A:
				_adjust(-1)
			KEY_RIGHT, KEY_D:
				_adjust(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if not event.echo:
					_activate()
			KEY_ESCAPE, KEY_BACKSPACE:
				if not event.echo:
					var b = page().get("back")
					if b is Callable:
						b.call()
					else:
						pop()
			_:
				return
		accept_event_safe()
	elif event is InputEventMouseMotion:
		var idx := _row_at(event.position)
		if idx >= 0 and idx != sel and _selectable(_items()[idx]):
			sel = idx
			_sel_t = 0.0
			Audio.play("menu_move", -10.0)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_move(-1)
			accept_event_safe()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_move(1)
			accept_event_safe()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var idx := _row_at(event.position)
			if idx >= 0 and _selectable(_items()[idx]):
				sel = idx
				var it: Dictionary = _items()[idx]
				var t: String = it.get("type", "button")
				if t in ["slider", "choice"]:
					var local_x: float = _to_local(event.position).x
					_adjust(-1 if local_x < size.x * 0.5 + 120 else 1)
				else:
					_activate()
				accept_event_safe()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var b = page().get("back")
			if b is Callable:
				b.call()
			else:
				pop()
			accept_event_safe()


func accept_event_safe() -> void:
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()


func _to_local(p: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * p


func _row_at(p: Vector2) -> int:
	var lp := _to_local(p)
	for r in _rows:
		if (r[0] as Rect2).has_point(lp):
			return r[1]
	return -1


func _activate() -> void:
	var items := _items()
	if items.is_empty() or not _selectable(items[sel]):
		return
	var it: Dictionary = items[sel]
	match String(it.get("type", "button")):
		"button":
			Audio.play("menu_select", -4.0)
			var cb = it.get("cb")
			if cb is Callable:
				cb.call()
		"toggle":
			Settings.set_v(it["key"], not bool(Settings.get_v(it["key"])))
			Settings.save_settings()
			Audio.play("menu_select", -6.0)
			_after_change(it)
		"choice", "slider":
			_adjust(1)
		"bind":
			waiting_bind = it["action"]
			Audio.play("menu_select", -6.0)


func _adjust(dir: int) -> void:
	var items := _items()
	if items.is_empty():
		return
	var it: Dictionary = items[sel]
	match String(it.get("type", "button")):
		"slider":
			var v := float(Settings.get_v(it["key"]))
			v = clampf(snappedf(v + dir * float(it["step"]), float(it["step"])), float(it["min"]), float(it["max"]))
			Settings.set_v(it["key"], v)
			Settings.save_settings()
			Audio.play("menu_move", -6.0)
			_after_change(it)
		"choice":
			var opts: Array = it["options"]
			var v := (int(Settings.get_v(it["key"])) + dir + opts.size()) % opts.size()
			Settings.set_v(it["key"], v)
			Settings.save_settings()
			Audio.play("menu_move", -6.0)
			_after_change(it)
		"toggle":
			Settings.set_v(it["key"], not bool(Settings.get_v(it["key"])))
			Settings.save_settings()
			Audio.play("menu_move", -6.0)
			_after_change(it)


func _after_change(it: Dictionary) -> void:
	var cb = it.get("on_change")
	if cb is Callable:
		cb.call()


func _value_text(it: Dictionary) -> String:
	match String(it.get("type", "button")):
		"slider":
			var v := float(Settings.get_v(it["key"]))
			if it.has("fmt"):
				return (it["fmt"] as Callable).call(v)
			var n := int(round((v - float(it["min"])) / (float(it["max"]) - float(it["min"])) * 10.0))
			return "|".repeat(n) + ".".repeat(10 - n)
		"toggle":
			return "ON" if Settings.get_v(it["key"]) else "OFF"
		"choice":
			var opts: Array = it["options"]
			return "< %s >" % String(opts[clampi(int(Settings.get_v(it["key"])), 0, opts.size() - 1)])
		"bind":
			if waiting_bind == it["action"]:
				return "PRESS A KEY..." if fmod(anim_t, 0.6) < 0.4 else ""
			return Settings.bind_label(it["action"])
		"button":
			if it.has("value"):
				var v = it["value"]
				return v.call() if v is Callable else str(v)
	return ""


const PAPER := Color(0.96, 0.94, 0.86)
const INK := Color(0.08, 0.03, 0.08)
const SHADOW := Color(0.08, 0.0, 0.1, 0.6)


func _draw() -> void:
	_rows.clear()
	_sel_rect = Rect2()
	if stack.is_empty():
		return
	var p := page()
	var big: bool = p.get("tiles", false)
	var wide: bool = p.get("wide", false)
	var row_w := 520.0 if wide else (250.0 if big else 300.0)
	var cx := size.x * 0.5 + (0.0 if wide else center_offset)
	if left_x >= 0.0 and not wide:
		cx = left_x + row_w * 0.5
	var y := top_y
	if show_title and p.has("title") and String(p["title"]) != "":
		var title := String(p["title"])
		if Collage.enabled():
			UI.ransom(self, cx, y - 56, title, 30.0)
		else:
			UI.text_centered(self, "big", cx, y - 56, title, Color.WHITE)
	_draw_list(p, cx, y, row_w, big)
	if p.has("footer"):
		# a strip of masking tape along the bottom
		var fw := UI.text_width("term", String(p["footer"]), 16)
		var fr := Rect2(cx - fw * 0.5 - 10, size.y - 27, fw + 20, 19)
		draw_rect(fr, Color(0.93, 0.88, 0.66, 0.92))
		UI.text_centered(self, "term", cx, size.y - 27, String(p["footer"]), INK, 16)
	if _flash_t > 0.0:
		UI.text_centered(self, "menu_hi", cx, size.y - 56, _flash, Color(UI.ACID, clampf(_flash_t, 0, 1)))
	if waiting_bind != "":
		UI.text_centered(self, "term", cx, size.y - 44, "PRESS A KEY OR MOUSE BUTTON. ESC TO CANCEL.", UI.ACID, 16)


## A torn strip of paper: straight along the top and bottom, ragged at the
## ends where it was ripped off the roll.
func _strip_points(r: Rect2, k: int) -> PackedVector2Array:
	var h := hash(k * 7919 + 101)
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y)])
	for i in range(1, 4):
		pts.append(Vector2(r.end.x + float((h >> (i * 3)) % 5) - 2.0, r.position.y + r.size.y * i / 4.0))
	pts.append(r.end)
	pts.append(Vector2(r.position.x, r.end.y))
	for i in range(3, 0, -1):
		pts.append(Vector2(r.position.x + float((h >> (i * 3 + 11)) % 5) - 2.0, r.position.y + r.size.y * i / 4.0))
	return pts


func _draw_list(p: Dictionary, cx: float, y: float, row_w: float, big: bool) -> void:
	var items := _items()
	var wide: bool = p.get("wide", false)
	var small: bool = p.get("small", false)
	var fsz := 26 if big else (16 if small else 20)
	var rh := 36.0 if big else (23.0 if small else 30.0)
	var visible_rows := int((size.y - y - 34) / rh)
	if sel < scroll:
		scroll = sel
	if sel >= scroll + visible_rows:
		scroll = sel - visible_rows + 1
	scroll = clampi(scroll, 0, maxi(0, items.size() - visible_rows))
	if scroll > 0:
		UI.text_centered(self, "term", cx, y - 18, "- MORE -", UI.DIM, 16)
	var f := UI.font("anton")
	for k in range(scroll, mini(items.size(), scroll + visible_rows)):
		var it: Dictionary = items[k]
		var en := _selectable(it)
		var is_sel := k == sel and en
		var label: String = it.get("label", "")
		var t: String = it.get("type", "button")
		if t == "info":
			for ln in UI.wrap("term", label, size.x * 0.7, 16):
				UI.text_centered(self, "term", cx, y + 2, ln, it.get("color", UI.BONE), 16)
				y += 16
			y += 4
			continue
		var r := Rect2(cx - row_w * 0.5, y, row_w, rh - 5)
		_rows.append([r, k])
		# each strip sits a little crooked; the chosen one straightens and slides out
		var hk := hash(k * 31 + 7)
		var rot := (float(hk % 100) / 100.0 - 0.5) * (0.018 if small or wide else 0.045)
		var slide := 0.0
		if is_sel:
			rot = sin(_sel_t * 3.0) * 0.012
			slide = 12.0 * minf(_sel_t * 8.0, 1.0)
			_sel_rect = Rect2(r.position + Vector2(slide, 0), r.size)
		var c := r.get_center() + Vector2(slide, 0)
		var local := Rect2(-r.size * 0.5, r.size)
		var pts := _strip_points(local, k)
		draw_set_transform(c + Vector2(3, 4), rot, Vector2.ONE)
		draw_colored_polygon(pts, SHADOW)
		draw_set_transform(c, rot, Vector2.ONE)
		var col := PAPER
		if is_sel:
			col = UI.ACID
		elif not en:
			col = Color(PAPER, 0.35)
		draw_colored_polygon(pts, col)
		var tc := INK if en else Color(0.25, 0.2, 0.25)
		var asc := f.get_ascent(fsz)
		var ty := local.position.y + (local.size.y - f.get_height(fsz)) * 0.5 + asc
		var x0 := local.position.x + 12.0
		var vt := _value_text(it)
		draw_string(f, Vector2(x0, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, tc)
		if vt != "":
			if wide:
				draw_string(f, Vector2(local.position.x + row_w * 0.55, ty), vt, HORIZONTAL_ALIGNMENT_LEFT, row_w * 0.43, fsz, tc)
			else:
				draw_string(f, Vector2(x0, ty), vt, HORIZONTAL_ALIGNMENT_RIGHT, local.size.x - 24.0, fsz, tc)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		y += rh
	if items.size() > scroll + visible_rows:
		UI.text_centered(self, "term", cx, y, "- MORE -", UI.DIM, 16)
	elif sel < items.size() and String(items[sel].get("desc", "")) != "":
		var desc := String(items[sel]["desc"])
		var dw := UI.text_width("term", desc, 16)
		draw_rect(Rect2(cx - dw * 0.5 - 6, y + 3, dw + 12, 18), Color(0, 0, 0, 0.6))
		UI.text_centered(self, "term", cx, y + 4, desc, UI.BONE, 16)


## The cursor: a trout nosing at the end of the chosen strip.
func _draw_fish() -> void:
	if _sel_rect.size.x <= 0.0 or _fish == null or waiting_bind != "":
		return
	var h := clampf(_sel_rect.size.y * 1.15, 22.0, 40.0)
	var w := h * _fish.get_width() / _fish.get_height()
	var nib := sin(_sel_t * 9.0) * 2.5
	var c := Vector2(_sel_rect.end.x + w * 0.5 - 4.0 + nib, _sel_rect.get_center().y + sin(_sel_t * 2.3) * 1.5)
	# the photo's fish faces left, toward the strip
	_fx.draw_set_transform(c, sin(_sel_t * 4.0) * 0.05, Vector2.ONE)
	_fx.draw_texture_rect(_fish, Rect2(-w * 0.5, -h * 0.5, w, h), false)
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ shared pages
static func options_page(view: MenuView, on_video_change: Callable = Callable()) -> Dictionary:
	return {"title": "OPTIONS", "items": [
		{"label": "AUDIO", "cb": func(): view.push(audio_page(view))},
		{"label": "VIDEO", "cb": func(): view.push(video_page(view, on_video_change))},
		{"label": "CONTROLS", "cb": func(): view.push(controls_page(view))},
		{"label": "GAMEPLAY", "cb": func(): view.push(gameplay_page(view))},
		{"label": "BACK", "cb": func(): view.pop()},
	]}


static func audio_page(view: MenuView) -> Dictionary:
	return {"title": "AUDIO", "wide": true, "items": [
		{"type": "slider", "label": "MASTER VOLUME", "key": "master_volume", "min": 0.0, "max": 1.0, "step": 0.1},
		{"type": "slider", "label": "MUSIC VOLUME", "key": "music_volume", "min": 0.0, "max": 1.0, "step": 0.1},
		{"type": "slider", "label": "EFFECTS VOLUME", "key": "sfx_volume", "min": 0.0, "max": 1.0, "step": 0.1,
			"on_change": func(): Audio.play("pickup_item", -4.0)},
		{"label": "BACK", "cb": func(): view.pop()},
	]}


static func video_page(view: MenuView, on_change: Callable) -> Dictionary:
	var sizes := []
	for s in Settings.WINDOW_SIZES:
		sizes.append("%dX%d" % [s.x, s.y])
	var cb := func():
		if on_change.is_valid():
			on_change.call()
	return {"title": "VIDEO", "wide": true, "small": true, "items": [
		{"type": "choice", "label": "WINDOW MODE", "key": "window_mode", "options": Settings.WINDOW_MODES},
		{"type": "choice", "label": "RESOLUTION", "key": "window_size", "options": sizes},
		{"type": "choice", "label": "PIXEL CRUNCH", "key": "pixel_scale", "options": ["OFF (NATIVE)", "1/2", "1/3", "1/4", "1/5", "1/6"], "on_change": cb},
		{"type": "choice", "label": "COLOR DEPTH", "key": "color_depth", "options": Settings.COLOR_DEPTHS, "on_change": cb},
		{"type": "slider", "label": "FIELD OF VIEW", "key": "fov", "min": 70.0, "max": 120.0, "step": 5.0,
			"fmt": func(v): return "%d" % int(v), "on_change": cb},
		{"type": "slider", "label": "BRIGHTNESS", "key": "gamma", "min": 0.6, "max": 1.6, "step": 0.1, "on_change": cb},
		{"type": "toggle", "label": "COLLAGE FX", "key": "collage", "on_change": cb},
		{"type": "toggle", "label": "VSYNC", "key": "vsync"},
		{"type": "choice", "label": "FPS LIMIT", "key": "max_fps", "options": ["UNLIMITED", "60", "120", "144", "240"]},
		{"label": "BACK", "cb": func(): view.pop()},
	]}


static func controls_page(view: MenuView) -> Dictionary:
	return {"title": "CONTROLS", "wide": true, "items": [
		{"type": "slider", "label": "MOUSE SPEED", "key": "mouse_sens", "min": 0.05, "max": 1.0, "step": 0.05},
		{"type": "toggle", "label": "INVERT MOUSE", "key": "invert_y"},
		{"label": "KEY BINDINGS", "cb": func(): view.push(binds_page(view))},
		{"label": "BACK", "cb": func(): view.pop()},
	]}


static func binds_page(view: MenuView) -> Dictionary:
	var items := []
	for a in Settings.ACTIONS:
		items.append({"type": "bind", "label": a[1], "action": a[0]})
	items.append({"label": "RESET TO DEFAULTS", "cb": func():
		Settings.reset_binds()
		view.flash("BINDINGS RESET")})
	items.append({"label": "BACK", "cb": func(): view.pop()})
	return {"title": "KEY BINDINGS", "wide": true, "small": true, "items": items,
		"footer": "ENTER: REBIND   ESC: BACK"}


static func gameplay_page(view: MenuView) -> Dictionary:
	return {"title": "GAMEPLAY", "wide": true, "items": [
		{"type": "toggle", "label": "HEAD BOB", "key": "head_bob"},
		{"type": "choice", "label": "CROSSHAIR", "key": "crosshair", "options": ["CIRCLE", "DOT", "CROSS", "NONE"]},
		{"type": "toggle", "label": "AUTO RELOAD", "key": "auto_reload"},
		{"type": "toggle", "label": "SHOW FPS", "key": "show_fps"},
		{"label": "BACK", "cb": func(): view.pop()},
	]}


static func load_page(view: MenuView, on_load: Callable) -> Dictionary:
	var items := []
	var names := {"auto": "AUTOSAVE", "quick": "QUICKSAVE", "slot1": "SLOT 1", "slot2": "SLOT 2", "slot3": "SLOT 3"}
	for slot in ["auto", "quick", "slot1", "slot2", "slot3"]:
		var d = Game.read_save(slot)
		if d == null:
			items.append({"label": names[slot] + " - EMPTY -", "enabled": false})
		else:
			var lbl := "%s: %s" % [names[slot], String(d.get("label", "?"))]
			var dd: Dictionary = d
			items.append({"label": lbl, "cb": func(): on_load.call(dd), "value": _save_time(dd)})
	items.append({"label": "BACK", "cb": func(): view.pop()})
	return {"title": "LOAD QUEST", "small": true, "items": items}


static func save_page(view: MenuView, on_save: Callable) -> Dictionary:
	var items := []
	for k in 3:
		var slot := "slot%d" % (k + 1)
		var d = Game.read_save(slot)
		var lbl := "SLOT %d: %s" % [k + 1, "- EMPTY -" if d == null else String(d.get("label", "?"))]
		items.append({"label": lbl, "cb": func():
			on_save.call(slot)
			view.flash("QUEST SAVED")
			view.replace(save_page(view, on_save))})
	items.append({"label": "BACK", "cb": func(): view.pop()})
	return {"title": "SAVE QUEST", "small": true, "items": items}


static func _save_time(d: Dictionary) -> String:
	var t := int(d.get("time", 0))
	if t <= 0:
		return ""
	var dt := Time.get_datetime_dict_from_unix_time(t)
	return "%04d-%02d-%02d %02d:%02d" % [dt["year"], dt["month"], dt["day"], dt["hour"], dt["minute"]]
