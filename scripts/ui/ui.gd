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
		"menu", "menu_hi", "menu_dim", "big", "hud":
			var file: String = {"menu": "menufont", "menu_hi": "menufont_hi", "menu_dim": "menufont_dim", "big": "bigfont", "hud": "hudfont"}[fname]
			f = load("res://assets/fonts/%s.fnt" % file)
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


static func _pixel_ttf(path: String) -> Font:
	var f: FontFile = load(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


static func native_size(fname: String) -> int:
	return {"menu": 20, "menu_hi": 20, "menu_dim": 20, "big": 32, "hud": 28, "small": 8, "small_bold": 8, "term": 16}.get(fname, 16)


static func text_width(fname: String, text: String, size := -1) -> float:
	var s := size if size > 0 else native_size(fname)
	return font(fname).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x


## Draws text; pos is the top-left of the text box.
static func text(ci: CanvasItem, fname: String, pos: Vector2, s: String, color := Color.WHITE, size := -1, shadow := false) -> void:
	var f := font(fname)
	var fs := size if size > 0 else native_size(fname)
	var asc := f.get_ascent(fs)
	if shadow:
		ci.draw_string(f, pos + Vector2(1, 1 + asc), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, color.a * 0.8))
	ci.draw_string(f, pos + Vector2(0, asc), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


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
