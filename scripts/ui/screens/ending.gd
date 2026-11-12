extends Control
## The ending: final text, a credits roll and the totals.

const CREDITS := [
	["GORBINO'S QUEST", ""],
	["", ""],
	["A GLANDCORE SOFTWARE GAME", ""],
	["DESIGN, CODE, ART, MUSIC", "GLANDCORE SOFTWARE"],
	["ADDITIONAL VOICES AND WEAPON SOUNDS", "SUPPLIED BY THE PLAYER"],
	["", ""],
	["THANK YOU FOR PLAYING", ""],
]

var t := 0.0
var lines := PackedStringArray()
var bg: Texture2D
var gorb: Texture2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg = load("res://assets/textures/v_grass.png")
	gorb = load("res://assets/ui/app_icon_256.png")
	Audio.play_music("ending")
	Audio.stop_ambience()


func _process(delta: float) -> void:
	t += delta
	if Game.autoplay:
		print("[bot] ENDING REACHED. totals=", Game.total_stats)
		get_tree().quit(0)
		return
	if lines.is_empty() and size.x > 0:
		lines = UI.wrap("term", Game.ending_text(), minf(size.x - 80, 460), 18)
	queue_redraw()


func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey or event is InputEventMouseButton) and event.pressed and not event.is_echo()
	if pressed and t > 3.0:
		get_viewport().set_input_as_handled()
		if t < 30.0:
			t = 30.0
		else:
			Game.goto_menu()


func _draw() -> void:
	draw_texture_rect_region(bg, Rect2(Vector2.ZERO, size), Rect2(Vector2(0, -t * 4.0), size / 3.0), Color(0.45, 0.5, 0.4))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
	var cx := size.x * 0.5
	if t < 30.0:
		UI.text_centered(self, "big", cx, 20, "END", Color.WHITE)
		var y := 70.0
		var shown := int(t * 30.0)
		for ln in lines:
			if shown <= 0:
				break
			UI.text_centered(self, "term", cx, y, ln.substr(0, shown), UI.BONE, 18)
			shown -= ln.length() + 1
			y += 18
		return
	var k := t - 30.0
	var y2 := size.y - k * 22.0
	draw_texture_rect(gorb, Rect2(cx - 64, y2 - 150, 128, 128), false)
	for c in CREDITS:
		if c[0] != "":
			UI.text_centered(self, "menu", cx, y2, c[0], Color.WHITE)
		if c[1] != "":
			UI.text_centered(self, "small", cx, y2 + 24, c[1], UI.ACID, 8, true)
		y2 += 46
	y2 += 20
	var ts := Game.total_stats
	UI.text_centered(self, "menu_hi", cx, y2, "TOTALS", Color.WHITE)
	UI.text_centered(self, "small", cx, y2 + 28, "KILLS %d / %d    SECRETS %d / %d    TIME %s" % [ts["kills"], ts["kills_total"], ts["secrets"], ts["secrets_total"], Game.format_time(float(ts["time"]))], UI.BONE, 8, true)
	UI.text_centered(self, "small", cx, y2 + 44, "DIFFICULTY: %s" % Game.diff()["name"], UI.BONE, 8, true)
	if y2 < size.y * 0.5:
		UI.text_centered(self, "menu", cx, size.y - 40, "PRESS ANY KEY", Color(1, 1, 1, 0.5 + 0.5 * sin(t * 4.0)))
