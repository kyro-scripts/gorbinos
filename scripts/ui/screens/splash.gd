extends Control
## Publisher splash: "GLANDCORE SOFTWARE presents".

var t := 0.0
var logo: Texture2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logo = load("res://assets/ui/publisher.png")
	Audio.play("tally_done", -4.0, 0.6)


func _process(delta: float) -> void:
	t += delta
	if t > 2.2:
		Game.main.show_menu()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if t > 0.3 and (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		Game.main.show_menu()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0))
	var a := clampf(t * 2.0, 0.0, 1.0) * clampf((2.2 - t) * 2.0, 0.0, 1.0)
	var s := logo.get_size()
	draw_texture(logo, (size * 0.5 - s * 0.5 - Vector2(0, 20)).round(), Color(1, 1, 1, a))

