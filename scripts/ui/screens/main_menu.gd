extends Control
## Title screen, drawn like the game itself (low resolution, cheap print,
## the screen's jittering noise border): a tile in the style of THE GORB
## PIT (purple flesh, lime streaks, staring eyes) scrolling behind
## everything, the name made of trout skin, buttons made of the levels'
## meat, and a turntable with a Gorbino, a Snirby and a snotling.

const BG_SCALE := 2.0            # screen units per texel of the background tile
const BG_SPEED := Vector2(14.0, 9.0)

var layer: PixelLayer
var frame: Control
var bg: Texture2D
var bg_layer: Control
var title: Control
var title_tex: Texture2D
var menu: MenuView
var t := 0.0
var vp: SubViewport
var stage: Node3D
var gorb: Node3D
var snirb: Node3D
var snot: Node3D
var preview: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer = PixelLayer.new()
	add_child(layer)
	bg = load("res://assets/ui/menu_pit.png")
	bg_layer = Control.new()
	bg_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add(bg_layer)
	bg_layer.draw.connect(_draw_bg)
	_build_stage()
	title_tex = load("res://assets/ui/title_fish.png")
	title = Control.new()
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	layer.add(title)
	title.draw.connect(_draw_title)
	menu = MenuView.new()
	menu.top_y = 150.0
	menu.show_title = true
	menu.allow_empty_back = false
	menu.left_x = 34.0
	layer.add(menu)
	frame = Control.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add(frame)
	frame.draw.connect(_draw_frame)
	menu.push(_root_page())
	Audio.play_music("menu")
	Audio.stop_ambience()


func _root_page() -> Dictionary:
	return {"title": "", "tiles": true, "cols": 3, "items": [
		{"label": "NEW QUEST", "icon": "tile_new", "cb": func(): menu.push(_difficulty_page())},
		{"label": "CONTINUE QUEST", "icon": "tile_continue", "enabled": func(): return Game.has_any_save(),
			"cb": func(): menu.push(MenuView.load_page(menu, func(d): Game.load_from_save(d)))},
		{"label": "ENDLESS", "icon": "tile_endless", "desc": "THE GORB PIT. WAVE AFTER WAVE. HOW LONG CAN YOU LAST?",
			"cb": func(): menu.push(_difficulty_page(true))},
		{"label": "OPTIONS", "icon": "tile_options", "cb": func(): menu.push(MenuView.options_page(menu))},
		{"label": "EXIT", "icon": "tile_exit", "cb": func(): menu.push(_quit_page())},
	], "back": func(): menu.push(_quit_page())}


func _difficulty_page(endless := false) -> Dictionary:
	var items := []
	for i in Game.DIFFICULTIES.size():
		var d: Dictionary = Game.DIFFICULTIES[i]
		var idx := i
		items.append({"label": d["name"], "desc": d["desc"], "cb": func(): (Game.start_endless(idx) if endless else Game.new_game(idx))})
	items.append({"label": "BACK", "cb": func(): menu.pop()})
	return {"title": "DIFFICULTY", "items": items}


func _quit_page() -> Dictionary:
	return {"title": "QUIT?", "items": [
		{"label": "YES", "cb": func(): get_tree().quit()},
		{"label": "NO", "cb": func(): menu.pop()},
	]}


func _build_stage() -> void:
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(200, 200)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	stage = Node3D.new()
	vp.add_child(stage)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.25, 4.4)
	cam.fov = 45
	cam.current = true
	vp.add_child(cam)
	cam.look_at(Vector3(0, 0.75, 0))
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	stage.add_child(Models.mi(Models.cyl(1.5, 1.6, 0.3, 12), Mat.world("d_meat", {"origin": true}), Vector3(0, -0.15, 0)))
	gorb = Models.gorbino(Color(0.12, 0.19, 0.06))
	gorb.position = Vector3(-0.65, 0, 0.15)
	gorb.rotation.y = PI + 0.35
	stage.add_child(gorb)
	snirb = Models.snirby()
	snirb.position = Vector3(0.7, 0, -0.3)
	snirb.rotation.y = PI + 0.85
	stage.add_child(snirb)
	snot = Models.snotling()
	snot.scale = Vector3.ONE * 0.55
	snot.position = Vector3(0.12, 0, 0.95)
	snot.rotation.y = PI - 0.2
	stage.add_child(snot)
	preview = TextureRect.new()
	preview.texture = vp.get_texture()
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add(preview)


func _process(delta: float) -> void:
	t += delta
	stage.rotation.y = sin(t * 0.4) * 0.5
	Creatures.animate(gorb, t, delta, {"move": 0.25, "blink": fmod(t, 3.1) < 0.12, "windup": fmod(t, 6.0) > 5.2, "look": Vector3(1.5, 1.2, -4.0)})
	Creatures.animate(snirb, t + 1.3, delta, {"move": 0.0, "windup": fmod(t + 2.0, 5.0) > 4.4})
	Creatures.animate(snot, t + 0.6, delta, {"move": 0.0, "blink": fmod(t + 1.0, 4.3) < 0.12})
	var root := menu.stack.size() <= 1
	menu.top_y = 146.0 if root else 150.0
	preview.visible = not menu.page().get("wide", false)
	var side := minf(size.y * 0.7, size.x * 0.42)
	preview.position = Vector2(size.x - side - 6, size.y - side - 10)
	preview.size = Vector2(side, side)
	bg_layer.queue_redraw()
	title.queue_redraw()
	frame.queue_redraw()


## The Gorb Pit tile, scrolling down and to the right, darkened toward the
## left where the buttons are so they stay easy to read.
func _draw_bg() -> void:
	var off := Vector2(fmod(t * BG_SPEED.x, bg.get_width() * BG_SCALE), fmod(t * BG_SPEED.y, bg.get_height() * BG_SCALE))
	bg_layer.draw_texture_rect_region(bg, Rect2(Vector2.ZERO, size), Rect2(-off / BG_SCALE, size / BG_SCALE))
	var w := size.x
	var h := size.y
	var dark := Color(0.02, 0.0, 0.04, 0.55)
	var clear := Color(0.02, 0.0, 0.04, 0.12)
	bg_layer.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([dark, clear, clear, dark]))
	for k in 6:
		bg_layer.draw_rect(Rect2(Vector2.ZERO, size).grow(-k * 12), Color(0, 0, 0, 0.12 * (6 - k) / 6.0), false, 12.0)


## The game screen's border: coloured noise that jitters.
func _draw_frame() -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = int(t / 0.07)
	var cols := MenuView.NOISE_COLS
	var W := frame.size.x
	var H := frame.size.y
	var x := 0.0
	while x < W:
		frame.draw_rect(Rect2(x, 0, 4, rnd.randi_range(1, 3)), cols[rnd.randi() % cols.size()])
		frame.draw_rect(Rect2(x, H - 3, 4, rnd.randi_range(1, 3)), cols[rnd.randi() % cols.size()])
		x += 4.0
	var y := 0.0
	while y < H:
		frame.draw_rect(Rect2(0, y, rnd.randi_range(1, 3), 4), cols[rnd.randi() % cols.size()])
		frame.draw_rect(Rect2(W - 3, y, rnd.randi_range(1, 3), 4), cols[rnd.randi() % cols.size()])
		y += 4.0


## The name, made of trout skin; it shrinks away up the corner once you're
## in a sub-page.
func _draw_title() -> void:
	var root := menu.stack.size() <= 1
	var w := 200.0 if root else 105.0
	var sz := Vector2(w, w * title_tex.get_height() / title_tex.get_width())
	var p := Vector2(30.0, 8.0 + sin(t * 1.3) * 1.5)
	title.draw_texture_rect(title_tex, Rect2(p, sz), false)
	UI.text(title, "term", Vector2(8, size.y - 20), "V1.9.6", Color(0.75, 0.65, 0.7), 16)
