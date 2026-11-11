class_name MenuBackdrop
extends Control
## Behind the menus: cheap printed paper (or, over a paused game, a dark
## wash) with big halftone dots drifting through it, and a few photo-real
## trout slowly swimming past.

var opaque := true
var fish_count := 2
var t := 0.0
var _fish: Texture2D
var _swim: Array = []        # [x (0..1), y (0..1), speed, size, dir, phase]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_fish = load("res://assets/sprites/hr_fish.png")
	for k in fish_count:
		_swim.append(_new_fish(randf()))


func _new_fish(x: float) -> Array:
	var dir := 1.0 if randf() < 0.5 else -1.0
	return [x if dir > 0.0 else 1.0 - x, randf_range(0.1, 0.9), randf_range(0.01, 0.025), randf_range(45.0, 85.0), dir, randf() * TAU]


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	t += delta
	for f in _swim:
		f[0] += f[2] * f[4] * delta
		if f[0] > 1.25 or f[0] < -0.25:
			var nf := _new_fish(-0.2)
			for k in nf.size():
				f[k] = nf[k]
	queue_redraw()


func _draw() -> void:
	var W := size.x
	var H := size.y
	if opaque:
		# printed paper, a deep magenta-black going to plum at the bottom
		var top := Color(0.07, 0.01, 0.08)
		var bot := Color(0.2, 0.03, 0.14)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(W, 0), Vector2(W, H), Vector2(0, H)]),
			PackedColorArray([top, top, bot, bot]))
	else:
		draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.0, 0.05, 0.74))
	# halftone dots on a 45 degree screen, swelling and shrinking in slow waves
	var cell := 14.0
	var dot := Color(0.98, 0.12, 0.5, 0.16 if opaque else 0.09)
	var off := Vector2(fmod(t * 4.0, cell), fmod(t * 2.0, cell))
	var rows := int(H / cell) + 3
	var cols := int(W / cell) + 3
	for j in rows:
		for i in cols:
			var p := Vector2(i * cell + (j % 2) * cell * 0.5, j * cell) - Vector2(cell, cell) + off
			var w := 0.5 + 0.5 * sin(p.x * 0.012 + p.y * 0.017 + t * 0.6)
			var r := cell * 0.42 * w * (0.4 + 0.6 * p.y / maxf(H, 1.0))
			if r > 0.6:
				draw_circle(p, r, dot)
	# trout, drifting past like it's an aquarium
	if _fish:
		var fs := _fish.get_size()
		for f in _swim:
			var w: float = f[3]
			var h: float = w * fs.y / fs.x
			var c := Vector2(f[0] * W, f[1] * H + sin(t * 1.3 + f[5]) * 6.0)
			var tilt: float = sin(t * 2.1 + f[5]) * 0.06
			draw_set_transform(c, tilt, Vector2(-f[4], 1.0))
			draw_texture_rect(_fish, Rect2(-w * 0.5, -h * 0.5, w, h), false, Color(1, 1, 1, 0.6 if opaque else 0.4))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# vignette
	for k in 6:
		draw_rect(Rect2(Vector2.ZERO, size).grow(-k * 12), Color(0, 0, 0, 0.1 * (6 - k) / 6.0), false, 12.0)
