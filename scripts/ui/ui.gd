class_name UI
extends RefCounted
## Shared fonts, colours and drawing helpers for every screen.

const ACID := Color(0.75, 1.0, 0.1)
const PINK := Color(1.0, 0.35, 0.75)
const BONE := Color(0.95, 0.93, 0.85)
const BLOOD := Color(1.0, 0.1, 0.15)
const DIM := Color(0.6, 0.55, 0.7)
const INK := Color(0.06, 0.02, 0.07)

static var _fonts := {}


static func font(fname: String) -> Font:
	if _fonts.has(fname):
		return _fonts[fname]
	var f: Font
	match fname:
		"menu", "menu_hi", "menu_dim", "big", "hud", "anton":
			f = load("res://assets/fonts/Anton-Regular.ttf")
		"small":
			f = _pixel_ttf("res://assets/fonts/Silkscreen-Regular.ttf")
		"small_bold":
			f = _pixel_ttf("res://assets/fonts/Silkscreen-Bold.ttf")
		"term":
			f = _pixel_ttf("res://assets/fonts/VT323-Regular.ttf")
		_:
			f = ThemeDB.fallback_font
	_fonts[fname] = f
	return f


## Default colours for the named styles (used when a caller passes WHITE).
static func style_color(fname: String, c: Color) -> Color:
	if c != Color.WHITE:
		return c
	match fname:
		"menu_hi":
			return ACID
		"menu_dim":
			return Color(0.5, 0.45, 0.5)
		"menu", "big", "hud", "anton":
			return BONE
	return c


static func is_heavy(fname: String) -> bool:
	return fname in ["menu", "menu_hi", "menu_dim", "big", "hud", "anton"]


static func _pixel_ttf(path: String) -> Font:
	var f: FontFile = load(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


static func native_size(fname: String) -> int:
	return {"menu": 22, "menu_hi": 22, "menu_dim": 22, "big": 40, "hud": 32, "anton": 22, "small": 8, "small_bold": 8, "term": 16}.get(fname, 16)


static func text_width(fname: String, text: String, size := -1) -> float:
	var s := size if size > 0 else native_size(fname)
	return font(fname).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x


## Draws text; pos is the top-left of the text box.
static func text(ci: CanvasItem, fname: String, pos: Vector2, s: String, color := Color.WHITE, size := -1, shadow := false) -> void:
	var f := font(fname)
	var fs := size if size > 0 else native_size(fname)
	var asc := f.get_ascent(fs)
	var c := style_color(fname, color)
	if is_heavy(fname):
		# heavy condensed type with a hard dark outline and offset shadow
		ci.draw_string_outline(f, pos + Vector2(2, 2 + asc), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, fs / 7), Color(0, 0, 0, c.a * 0.85))
		ci.draw_string_outline(f, pos + Vector2(0, asc), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, fs / 7), Color(0.05, 0.0, 0.03, c.a))
	elif shadow:
		ci.draw_string(f, pos + Vector2(1, 1 + asc), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, c.a * 0.8))
	ci.draw_string(f, pos + Vector2(0, asc), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


static func text_centered(ci: CanvasItem, fname: String, center_x: float, y: float, s: String, color := Color.WHITE, size := -1, shadow := false) -> void:
	var w := text_width(fname, s, size)
	text(ci, fname, Vector2(round(center_x - w * 0.5), y), s, color, size, shadow)


static func tile(ci: CanvasItem, tex: Texture2D, rect: Rect2, offset := Vector2.ZERO, modulate := Color.WHITE) -> void:
	ci.draw_texture_rect_region(tex, rect, Rect2(offset, rect.size), modulate)


## Word-wraps text into lines that fit max_w.
static func wrap(fname: String, s: String, max_w: float, size := -1) -> PackedStringArray:
	var out := PackedStringArray()
	for para in s.split("\n"):
		if para.strip_edges() == "":
			out.append("")
			continue
		var line := ""
		for word in para.split(" "):
			var cand := word if line == "" else line + " " + word
			if text_width(fname, cand, size) > max_w and line != "":
				out.append(line)
				line = word
			else:
				line = cand
		out.append(line)
	return out


static func frame(ci: CanvasItem, r: Rect2, fill := Color(0.05, 0.02, 0.07, 0.92), edge := Color(1.0, 0.35, 0.75), w := 2.0) -> void:
	ci.draw_rect(r, fill)
	ci.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(0, 0, 0, 0.5), false, w)
	ci.draw_rect(r, edge, false, w)


const RANSOM_CHIPS := [Color(0.98, 0.12, 0.5), Color(1.0, 0.9, 0.08), Color(0.08, 0.78, 1.0), Color(0.1, 0.08, 0.1),
	Color(0.97, 0.95, 0.88), Color(0.47, 1.0, 0.24), Color(1.0, 0.43, 0.08), Color(0.59, 0.24, 1.0), Color(0.9, 0.08, 0.12)]
const RANSOM_FONTS := ["anton", "big", "term", "small_bold"]


## Ransom-note lettering: every letter cut out of a different magazine, on
## its own chip of coloured paper, tilted, and twitching a few times a
## second. Centred on center_x; y is the top.
static func ransom(ci: CanvasItem, center_x: float, y: float, s: String, size := 26.0, alpha := 1.0) -> void:
	var seed := hash(s)
	var boil := int(Time.get_ticks_msec() / 160)
	var glyphs := []
	var total := 0.0
	for k in s.length():
		var ch := s.substr(k, 1)
		if ch == " ":
			glyphs.append(null)
			total += size * 0.4
			continue
		var h := hash(seed + k * 7919)
		var fname: String = RANSOM_FONTS[h % RANSOM_FONTS.size()]
		var fs := int(size * [1.0, 0.9, 1.15, 0.7][h % 4] * (0.9 + float((h >> 5) % 5) * 0.05))
		var w := text_width(fname, ch, fs) + 6.0
		glyphs.append([ch, fname, fs, w, h])
		total += w - 1.0
	var x := center_x - total * 0.5
	for g in glyphs:
		if g == null:
			x += size * 0.4
			continue
		var h: int = g[4]
		var fs: int = g[2]
		var w: float = g[3]
		var bg: Color = RANSOM_CHIPS[(h >> 3) % RANSOM_CHIPS.size()]
		var fg := Color(0.06, 0.03, 0.06) if bg.get_luminance() > 0.55 else Color(0.98, 0.96, 0.9)
		var twitch := float(hash(h + boil) % 100) / 100.0 - 0.5
		var rot := (float((h >> 7) % 100) / 100.0 - 0.5) * 0.3 + twitch * 0.06
		var hh := fs * 1.15
		var oy := y + (float((h >> 9) % 7) - 3.0) + twitch * 1.5
		ci.draw_set_transform(Vector2(x + w * 0.5, oy + hh * 0.5), rot, Vector2.ONE)
		var r := Rect2(-w * 0.5, -hh * 0.5, w, hh)
		ci.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(0.08, 0.0, 0.1, 0.7 * alpha))
		ci.draw_rect(r.grow(2.0), Color(0.97, 0.95, 0.88, alpha))
		ci.draw_rect(r, Color(bg, alpha))
		var f := font(String(g[1]))
		var asc := f.get_ascent(fs)
		var tw := f.get_string_size(String(g[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		ci.draw_string(f, Vector2(-tw.x * 0.5, -hh * 0.5 + (hh - tw.y) * 0.5 + asc), String(g[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(fg, alpha))
		x += w - 1.0
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
