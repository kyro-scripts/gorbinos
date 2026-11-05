extends Control
## Title screen: scrolling clashing backdrop, the logo, a turntable with a
## Gorbino and a Snirby, and the main menu.

const QUIT_LINES := [
	"ARE YOU SURE? THE GORBINOS WILL WIN.",
	"LEAVING ALREADY? GORBINO IS DISAPPOINTED.",
	"THE SNIRBIES CAN SMELL YOUR FEAR. QUIT?",
	"YOU CAN'T QUIT. GORB IS ETERNAL. (JUST KIDDING, YOU CAN.)",
	"GO AHEAD AND LEAVE. SEE IF THE GORB CARES.",
]

var bg: Texture2D
var logo: Texture2D
var menu: MenuView
var t := 0.0
var vp: SubViewport
var stage: Node3D
var gorb: Node3D
var snirb: Node3D
var preview: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg = load("res://assets/ui/menu_bg.png")
	logo = load("res://assets/ui/logo.png")
	_build_stage()
	menu = MenuView.new()
	menu.top_y = 196.0
	menu.show_title = false
	menu.allow_empty_back = false
	menu.center_offset = -70.0
	add_child(menu)
	menu.push(_root_page())
	Audio.play_music("menu")
	Audio.stop_ambience()


func _root_page() -> Dictionary:
	return {"items": [
		{"label": "NEW QUEST", "cb": func(): menu.push(_difficulty_page())},
		{"label": "CONTINUE QUEST", "enabled": func(): return Game.has_any_save(), "cb": func(): menu.push(MenuView.load_page(menu, func(d): Game.load_from_save(d)))},
		{"label": "OPTIONS", "cb": func(): menu.push(MenuView.options_page(menu))},
		{"label": "EXIT", "cb": func(): menu.push(_quit_page())},
	], "back": func(): menu.push(_quit_page()),
	"footer": "V1.9.6  (C) 1996 GLANDCORE SOFTWARE.  GORBINO IS A TRADEMARK OF NOBODY."}


func _difficulty_page() -> Dictionary:
	var items := []
	for i in Game.DIFFICULTIES.size():
		var d: Dictionary = Game.DIFFICULTIES[i]
		var idx := i
		items.append({"label": d["name"], "cb": func(): Game.new_game(idx)})
	items.append({"type": "info", "label": " "})
	items.append({"label": "BACK", "cb": func(): menu.pop()})
	var p := {"title": "", "items": items}
	p["footer"] = "CHOOSE HOW MUCH GORB YOU CAN HANDLE."
	return p


func _quit_page() -> Dictionary:
	return {"items": [
		{"type": "info", "label": QUIT_LINES[randi() % QUIT_LINES.size()], "color": UI.ACID},
		{"label": "YES, QUIT", "cb": func(): get_tree().quit()},
		{"label": "NO", "cb": func(): menu.pop()},
	]}


func _build_stage() -> void:
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(180, 180)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	stage = Node3D.new()
	vp.add_child(stage)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.3, 4.6)
	cam.fov = 45
	cam.current = true
	vp.add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0))
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var ped := Models.mi(Models.cyl(1.5, 1.6, 0.3, 12), Mat.world("v_cobble", {"origin": true}), Vector3(0, -0.15, 0))
	stage.add_child(ped)
	gorb = Models.gorbino(Color(0.45, 0.95, 0.15))
	gorb.position = Vector3(-0.6, 0, 0.2)
	gorb.rotation.y = PI + 0.3
	stage.add_child(gorb)
	snirb = Models.snirby()
	snirb.position = Vector3(0.75, 0, -0.1)
	snirb.rotation.y = PI - 0.4
	stage.add_child(snirb)
	preview = TextureRect.new()
	preview.texture = vp.get_texture()
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview)


func _process(delta: float) -> void:
	t += delta
	stage.rotation.y = sin(t * 0.4) * 0.6
	var gp: Dictionary = gorb.get_meta("parts")
	gp["body"].position.y = 0.32 + abs(sin(t * 3.0)) * 0.05
	gp["mouth"].scale.y = 1.0 + max(0.0, sin(t * 1.3)) * 1.2
	gp["arms"][0].rotation.x = sin(t * 3.0) * 0.4
	gp["arms"][1].rotation.x = -1.2 - sin(t * 3.0) * 0.4
	gp["sprout"].rotation.z = sin(t * 5.0) * 0.3
	var blink := fmod(t, 3.1) < 0.12
	for e in gp["eyes"]:
		e.scale.y = 0.12 if blink else 1.0
	var sp: Dictionary = snirb.get_meta("parts")
	sp["body"].position.y = 0.55 + abs(sin(t * 4.0)) * 0.06
	sp["nose"].scale = Vector3.ONE * (1.0 + (0.4 * abs(sin(t * 30.0)) if fmod(t, 2.0) < 0.5 else 0.0))
	sp["ears"].rotation.x = sin(t * 2.0) * 0.2
	sp["head"].rotation.y = sin(t * 0.7) * 0.5
	sp["arms"][0].rotation.x = sin(t * 2.3) * 0.3
	sp["arms"][1].rotation.x = -sin(t * 2.3) * 0.3
	preview.visible = not menu.page().get("wide", false)
	var side := minf(size.y * 0.62, size.x * 0.36)
	preview.position = Vector2(size.x - side - 18, size.y - side - 26)
	preview.size = Vector2(side, side)
	queue_redraw()


func _draw() -> void:
	var off := Vector2(t * 14.0, t * 7.0)
	draw_texture_rect_region(bg, Rect2(Vector2.ZERO, size), Rect2(off, size / 2.0), Color(0.75, 0.75, 0.8))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	# clashing stripe behind the menu
	draw_rect(Rect2(0, 182, size.x, 4), UI.PINK)
	draw_rect(Rect2(0, 188, size.x, 1), UI.ACID)
	var ls := logo.get_size() * 0.62
	var lp := Vector2(size.x * 0.5 - ls.x * 0.5, 14 + sin(t * 1.4) * 3.0)
	draw_texture_rect(logo, Rect2(lp.round(), ls.round()), false)
	UI.text_centered(self, "small_bold", size.x * 0.5, lp.y + ls.y + 4, "THE FIRST-PERSON GORB EXPERIENCE", UI.ACID, 8, true)
	if menu.stack.size() > 0 and menu.stack[-1].get("items", []).size() > 0:
		var p: Dictionary = menu.stack[-1]
		if p.get("footer", "") == "CHOOSE HOW MUCH GORB YOU CAN HANDLE.":
			var sel: int = menu.sel
			if sel < Game.DIFFICULTIES.size():
				UI.text_centered(self, "small", size.x * 0.5 - 70, size.y - 38, Game.DIFFICULTIES[sel]["desc"], UI.BONE, 8, true)
