extends Control
## The ending: final text, a credits roll and the totals.

const CREDITS := [
	["GORBINO'S QUEST", ""],
	["", ""],
	["DESIGN, CODE, ART", "THE GLANDCORE COLLECTIVE"],
	["GORBINO VOICE", "A DETUNED SAWTOOTH"],
	["SNIRBY VOICE", "A SLIGHTLY HIGHER SAWTOOTH"],
	["LEVEL DESIGN", "SIX VERY LONG NIGHTS"],
	["MUSIC", "THE GLANDCORE SOUND DEPT."],
	["QUALITY ASSURANCE", "ONE (1) GORBINO"],
	["", ""],
	["NO SNIRBIES WERE HARMED", "SEVERAL HUNDRED WERE"],
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
	gorb = load("res://assets/ui/gorb_big.png")
	Audio.play_music("ending")
	Audio.stop_ambience()


func _process(delta: float) -> void:
	t += delta
	if Game.autoplay:
		print("[bot] ENDING REACHED. totals=", Game.total_stats)
		get_tree().quit(0)
		return
	if lines.is_empty() and size.x > 0:
		lines = UI.wrap("small", Game.ENDING, minf(size.x - 80, 460))
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
		UI.text_centered(self, "big", cx, 20, "THE END?", Color.WHITE)
		var y := 70.0
		var shown := int(t * 30.0)
		for ln in lines:
			if shown <= 0:
				break
			UI.text_centered(self, "small", cx, y, ln.substr(0, shown), UI.BONE, 8, true)
			shown -= ln.length() + 1
			y += 13
		return
	var k := t - 30.0
	var y2 := size.y - k * 22.0
	draw_texture(gorb, Vector2(cx - 64, y2 - 150))
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
