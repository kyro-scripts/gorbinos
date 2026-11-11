extends Control
## Title screen: printed paper with trout drifting past, the name in big
## bold type, the options on torn paper strips, and a turntable
## with a Gorbino, a Snirby and a snotling.

var backdrop: MenuBackdrop
var title: Control
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
	backdrop = MenuBackdrop.new()
	add_child(backdrop)
	_build_stage()
	title = Control.new()
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	title.draw.connect(_draw_title)
	menu = MenuView.new()
	menu.top_y = 150.0
	menu.show_title = true
	menu.allow_empty_back = false
	menu.left_x = 34.0
	add_child(menu)
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
	add_child(preview)


func _process(delta: float) -> void:
	t += delta
	stage.rotation.y = sin(t * 0.4) * 0.5
	Creatures.animate(gorb, t, delta, {"move": 0.25, "blink": fmod(t, 3.1) < 0.12, "windup": fmod(t, 6.0) > 5.2, "look": Vector3(1.5, 1.2, -4.0)})
	Creatures.animate(snirb, t + 1.3, delta, {"move": 0.0, "windup": fmod(t + 2.0, 5.0) > 4.4})
	Creatures.animate(snot, t + 0.6, delta, {"move": 0.0, "blink": fmod(t + 1.0, 4.3) < 0.12})
	var root := menu.stack.size() <= 1
	menu.top_y = 142.0 if root else 150.0
	preview.visible = not menu.page().get("wide", false)
	var side := minf(size.y * 0.7, size.x * 0.42)
	preview.position = Vector2(size.x - side - 6, size.y - side - 10)
	preview.size = Vector2(side, side)
	title.queue_redraw()


## The name; it shrinks away up the corner once you're in a sub-page.
func _draw_title() -> void:
	var root := menu.stack.size() <= 1
	var k := 1.0 if root else 0.6
	var y := 8.0 + sin(t * 1.3) * 1.5
	MenuView.heading(title, 34.0, y, "GORBINO'S", int(round(48 * k)), true)
	MenuView.heading(title, 34.0, y + 50.0 * k, "QUEST", int(round(56 * k)), true)
	UI.text(title, "term", Vector2(8, size.y - 20), "V1.9.6", Color(0.75, 0.65, 0.7), 16)
