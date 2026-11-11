class_name MenuView
extends Control
## Old-school stacked menu: big bitmap font items, a blinking Gorbino head
## as the cursor, sliders / toggles / choices / key binding rows. In the
## game's pause and death menus, a photo-real trout nibbles at the choice.

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
var _rows: Array = []            # [rect, item_index]
var _flash := ""
var _flash_t := 0.0
var trout := false               # a trout cursor nibbling at the chosen item
var _fx: Control
var _fish: Texture2D
var _sel_rect := Rect2()
var _sel_t := 0.0


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
				if _is_tiles():
					_move(-1)
				else:
					_adjust(-1)
			KEY_RIGHT, KEY_D:
				if _is_tiles():
					_move(1)
				else:
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


var _tex_cache := {}


func _tex(n: String) -> Texture2D:
	if not _tex_cache.has(n):
		var p := "res://assets/ui/%s.png" % n
		_tex_cache[n] = load(p) if ResourceLoader.exists(p) else null
	return _tex_cache[n]


func _is_tiles() -> bool:
	return page().get("tiles", false)



func _draw() -> void:
	_rows.clear()
	_sel_rect = Rect2()
	if stack.is_empty():
		return
	var p := page()
	var cx := size.x * 0.5 + (0.0 if p.get("wide", false) else center_offset)
	var y := top_y
	if show_title and p.has("title") and String(p["title"]) != "":
		UI.text_centered(self, "big", cx, y - 56, String(p["title"]), Color.WHITE)
	if _is_tiles():
		_draw_tiles(cx, y)
	else:
		_draw_list(p, cx, y)
	if p.has("footer"):
		var fw := UI.text_width("term", String(p["footer"]), 16)
		draw_rect(Rect2(cx - fw * 0.5 - 6, size.y - 26, fw + 12, 18), Color(0, 0, 0, 0.75))
		UI.text_centered(self, "term", cx, size.y - 26, String(p["footer"]), UI.BONE, 16)
	if _flash_t > 0.0:
		UI.text_centered(self, "menu_hi", cx, size.y - 56, _flash, Color(UI.ACID, clampf(_flash_t, 0, 1)))
	if waiting_bind != "":
		UI.text_centered(self, "term", cx, size.y - 44, "PRESS A KEY OR MOUSE BUTTON. ESC TO CANCEL.", UI.ACID, 16)


## The big menus (title, pause, death): a stack of clay sculpture buttons,
## each a lumpy slab with its icon and its name in the logo's clay letters.
## The chosen one lights up pink with a lime rim and lifts a little.
func _draw_tiles(cx: float, y: float) -> void:
	var items := _items()
	if items.is_empty():
		return
	# even spacing: buttons as big as the room allows, up to a comfortable size
	var gap := 8.0
	var room := size.y - y - 40.0
	var bh := clampf((room - gap * (items.size() - 1)) / items.size(), 26.0, 36.0)
	for k in items.size():
		var it: Dictionary = items[k]
		var key := String(it.get("icon", "")).replace("tile_", "btn_")
		var en := _selectable(it)
		var is_sel := k == sel and en
		var tex := _tex(key + ("_on" if is_sel else ""))
		var bw := bh * (tex.get_width() / float(tex.get_height())) if tex else bh * 4.2
		var rect := Rect2(cx - bw * 0.5, y + k * (bh + gap), bw, bh)
		_rows.append([rect, k])
		var drawn := rect
		if is_sel:
			var lift := minf(_sel_t * 10.0, 1.0)
			drawn = Rect2(rect.get_center() - rect.size * (0.5 + 0.04 * lift), rect.size * (1.0 + 0.08 * lift))
			drawn.position += Vector2(6.0 * lift, sin(anim_t * 3.0) * 0.8)
			_sel_rect = drawn
		var mod := Color(1, 1, 1) if en else Color(0.4, 0.36, 0.4, 0.8)
		if tex:
			draw_texture_rect(tex, drawn, false, mod)
		else:
			draw_rect(drawn, Color(0.2, 0.1, 0.15))
			UI.text_centered(self, "menu", drawn.get_center().x, drawn.get_center().y - 12, String(it.get("label", "")))
	if sel < items.size() and _selectable(items[sel]):
		var desc := String(items[sel].get("desc", ""))
		if desc != "":
			var dy := y + items.size() * (bh + gap) - gap + 6.0
			for ln in UI.wrap("term", desc, 230.0, 16):
				var dw := UI.text_width("term", ln, 16)
				draw_rect(Rect2(cx - dw * 0.5 - 5, dy - 1, dw + 10, 17), Color(0, 0, 0, 0.6))
				UI.text_centered(self, "term", cx, dy, ln, UI.BONE, 16)
				dy += 16.0


func _draw_list(p: Dictionary, cx: float, y: float) -> void:
	var items := _items()
	var wide: bool = p.get("wide", false)
	var fsz := 22 if not p.get("small", false) else 18
	var rh := row_h + 2.0 if not p.get("small", false) else 21.0
	var visible_rows := int((size.y - y - 34) / rh)
	if sel < scroll:
		scroll = sel
	if sel >= scroll + visible_rows:
		scroll = sel - visible_rows + 1
	scroll = clampi(scroll, 0, maxi(0, items.size() - visible_rows))
	var row_w := 520.0 if wide else 300.0
	if scroll > 0:
		UI.text_centered(self, "term", cx, y - 18, "- MORE -", UI.DIM, 16)
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
		var r := Rect2(cx - row_w * 0.5, y - 1, row_w, rh - 3)
		_rows.append([r, k])
		if is_sel:
			_sel_rect = r
		# hard blocks: dark strip, inverted lime when selected
		draw_rect(Rect2(r.position + Vector2(4, 4), r.size), Color(0, 0, 0, 0.5))
		draw_rect(r, UI.ACID if is_sel else Color(0.07, 0.03, 0.06, 0.85))
		if not is_sel:
			draw_rect(Rect2(r.position, Vector2(4, r.size.y)), Color(0.9, 0.3, 0.45) if en else Color(0.3, 0.25, 0.3))
		var tc := Color(0.04, 0.02, 0.03) if is_sel else (UI.BONE if en else Color(0.45, 0.4, 0.45))
		var f := UI.font("anton")
		var asc := f.get_ascent(fsz)
		var ty := y + (rh - 3 - f.get_height(fsz)) * 0.5 - 1 + asc
		if wide:
			draw_string(f, Vector2(r.position.x + 12, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, tc)
			var vt := _value_text(it)
			if vt != "":
				draw_string(f, Vector2(r.position.x + row_w * 0.55, ty), vt, HORIZONTAL_ALIGNMENT_LEFT, row_w * 0.43, fsz, tc)
		else:
			var vt2 := _value_text(it)
			var full := label if vt2 == "" else "%s   %s" % [label, vt2]
			draw_string(f, Vector2(r.position.x, ty), full, HORIZONTAL_ALIGNMENT_CENTER, row_w, fsz, tc)
		y += rh
	if items.size() > scroll + visible_rows:
		UI.text_centered(self, "term", cx, y, "- MORE -", UI.DIM, 16)
	elif sel < items.size() and String(items[sel].get("desc", "")) != "":
		UI.text_centered(self, "term", cx, y + 4, String(items[sel]["desc"]), UI.BONE, 16)


## The trout cursor: nosing at the right-hand edge of the choice.
func _draw_fish() -> void:
	if not trout or _sel_rect.size.x <= 0.0 or _fish == null or waiting_bind != "":
		return
	var h := clampf(_sel_rect.size.y * 0.3, 16.0, 26.0) if _is_tiles() else clampf(_sel_rect.size.y * 1.1, 18.0, 30.0)
	var w := h * _fish.get_width() / _fish.get_height()
	var nib := sin(_sel_t * 9.0) * 2.0
	var c := Vector2(_sel_rect.end.x + w * 0.5 - 6.0 + nib, _sel_rect.get_center().y + sin(_sel_t * 2.3) * 1.5)
	# the photo's fish faces left, toward the choice
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
