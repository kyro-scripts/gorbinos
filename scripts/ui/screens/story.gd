extends Control
## Between-level story text, typed out over a scrolling texture.

var text := ""
var title := ""
var cb: Callable
var t := 0.0
var shown := 0.0
var lines := PackedStringArray()
var bg: Texture2D
var done := false


func setup(p_text: String, p_title: String, p_cb: Callable) -> void:
	text = p_text
	title = p_title
	cb = p_cb


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg = load("res://assets/textures/d_flesh.png") if title.contains("SNIRBY DIM") else load("res://assets/textures/v_brick.png")
	Audio.play_music("intermission")
	if text == "":
		_finish()


func _finish() -> void:
	if done:
		return
	done = true
	cb.call()


func _process(delta: float) -> void:
	t += delta
	shown += delta * 55.0
	if Game.autoplay and t > 0.3:
		_finish()
	if lines.is_empty() and size.x > 0:
		lines = UI.wrap("small", text, minf(size.x - 80, 480))
	queue_redraw()


func _input(event: InputEvent) -> void:
	if done or t < 0.4:
		return
	var pressed: bool = (event is InputEventKey or event is InputEventMouseButton) and event.pressed and not event.is_echo()
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if shown < text.length():
		shown = text.length() + 1
	else:
		Audio.play("menu_select", -4.0)
		_finish()


func _draw() -> void:
	draw_texture_rect_region(bg, Rect2(Vector2.ZERO, size), Rect2(Vector2(t * 6.0, t * 3.0), size / 3.0), Color(0.45, 0.4, 0.5))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	UI.text_centered(self, "small_bold", size.x * 0.5, 22, "NOW ENTERING", UI.ACID, 8, true)
	UI.text_centered(self, "big", size.x * 0.5, 36, title, Color.WHITE)
	var y := 92.0
	var remaining := int(shown)
	for ln in lines:
		if remaining <= 0:
			break
		var part := ln.substr(0, remaining)
		remaining -= ln.length() + 1
		UI.text_centered(self, "small", size.x * 0.5, y, part, UI.BONE, 8, true)
		y += 13
	if shown >= text.length() and fmod(t, 1.0) < 0.7:
		UI.text_centered(self, "menu", size.x * 0.5, size.y - 40, "PRESS ANY KEY", Color.WHITE)
