class_name GameWorld
extends Control
## The in-game screen: low-resolution 3D view + post-process, HUD,
## pause / death menus, checkpoints, saving and level completion.

var vp: SubViewport
var view: TextureRect
var post: ShaderMaterial
var level: Level
var player: Player
var hud: HUD
var menu: MenuView
var menu_bg: ColorRect
var paused := false
var dead_t := -1.0
var death_menu_shown := false
var completed := false
var complete_t := 0.0
var _flash := Color(0, 0, 0, 0)
var _death_stamp: Texture2D
var autopilot: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.audio_listener_enable_3d = true
	vp.handle_input_locally = false
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.positional_shadow_atlas_size = 0
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(vp)
	view = TextureRect.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.texture = vp.get_texture()
	post = ShaderMaterial.new()
	post.shader = load("res://shaders/post.gdshader")
	view.material = post
	add_child(view)
	# level + player
	var data: Dictionary = get_meta("override_data") if has_meta("override_data") else Game.level_data(Game.level_index)
	level = Level.new()
	level.world = self
	level.load_data(data)
	vp.add_child(level)
	level.build()
	Audio.set_world(level)
	player = Player.new()
	player.name = "Player"
	vp.add_child(player)
	player.setup(level, self, level.player_start, level.start_yaw, Game.inventory)
	level.player = player
	# hud
	hud = HUD.new()
	hud.player = player
	hud.level = level
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud)
	menu_bg = ColorRect.new()
	menu_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_bg.color = Color(0.03, 0.0, 0.05, 0.72)
	menu_bg.visible = false
	menu_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_bg)
	menu = MenuView.new()
	menu.visible = false
	menu.allow_empty_back = true
	menu.emptied.connect(_resume)
	add_child(menu)
	_death_stamp = load("res://assets/ui/stamp_gorbed.png")
	if Game.pending_restore != null:
		_restore(Game.pending_restore)
		Game.pending_restore = null
	Audio.play_music(String(data.get("music", "")))
	Audio.play_ambience(String(data.get("ambience", "")))
	hud.center(String(data.get("name", "")), 3.0)
	Settings.changed.connect(_apply_settings)
	get_viewport().size_changed.connect(_apply_settings)
	_apply_settings()
	_capture(true)
	if Game.autoplay:
		autopilot = load("res://scripts/test/autopilot.gd").new()
		autopilot.setup(self)
		add_child(autopilot)


func _exit_tree() -> void:
	Audio.set_world(null)
	Audio.stop_ambience()
	get_tree().paused = false


func _capture(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _apply_settings() -> void:
	var win := get_window().size
	if DisplayServer.get_name() == "headless" or win.x <= 0:
		win = Vector2i(1280, 720)
	var div := int(Settings.get_v("pixel_scale")) + 1
	vp.size = Vector2i(maxi(160, win.x / div), maxi(90, win.y / div))
	post.set_shader_parameter("src_size", Vector2(vp.size))
	post.set_shader_parameter("levels", Settings.color_levels())
	post.set_shader_parameter("gamma", float(Settings.get_v("gamma")))
	if player:
		player.camera.fov = float(Settings.get_v("fov"))


func _process(delta: float) -> void:
	if player == null:
		return
	if not get_tree().paused:
		Fx.update_lights(level, player.camera.global_position, delta)
		# palette flash (damage red, pickup gold) decays
		var f := player.flash_color
		if f.a > 0.0:
			_flash = f
			player.flash_color = Color(0, 0, 0, 0)
		_flash.a = move_toward(_flash.a, 0.0, delta * 1.4)
		post.set_shader_parameter("flash_color", _flash)
	if player.dead:
		dead_t += delta
		if dead_t > 1.6 and not death_menu_shown:
			_show_death_menu()
	if completed:
		complete_t += delta
		if complete_t > 0.9:
			completed = false
			Game.level_finished(level.stats, player.get_inventory())
	queue_redraw()


func _draw() -> void:
	if player and player.dead and dead_t > 0.4:
		var k := clampf((dead_t - 0.4) * 2.0, 0.0, 1.0)
		var s := _death_stamp.get_size() * lerpf(3.0, 1.0, k)
		var c := Vector2(size.x * 0.5, size.y * 0.2 + 20)
		draw_texture_rect(_death_stamp, Rect2(c - s * 0.5, s), false, Color(1, 1, 1, k))


func _unhandled_input(event: InputEvent) -> void:
	if paused or player == null:
		return
	if player.dead or completed:
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			player.look(event.screen_relative)
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture(true)
		return
	if event.is_action_pressed("pause"):
		open_pause()
	elif event.is_action_pressed("automap"):
		hud.show_map = not hud.show_map
	elif event.is_action_pressed("quicksave"):
		save_to("quick")
		hud.message("QUICKSAVED.")
	elif event.is_action_pressed("quickload"):
		var d = Game.read_save("quick")
		if d != null:
			Game.load_from_save(d)
		else:
			hud.message("NO QUICKSAVE.")
	elif event.is_action_pressed("use"):
		do_use()


func do_use() -> void:
	var cam := player.camera
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * 2.8
	var hit := level.ray(from, to, 1, [player.get_rid()])
	if not hit.is_empty():
		level.use_at(hit, player)


func message(t: String, center := false) -> void:
	if center:
		hud.center(t, 2.5)
		hud.message(t)
	else:
		hud.message(t)


# ------------------------------------------------------------------ pause
func open_pause() -> void:
	paused = true
	get_tree().paused = true
	_capture(false)
	menu.stack.clear()
	menu.visible = true
	menu_bg.visible = true
	menu.push(_pause_page())
	Audio.play("menu_select", -6.0)


func _pause_page() -> Dictionary:
	return {"title": "PAUSED", "items": [
		{"label": "RESUME", "cb": func(): _resume()},
		{"label": "SAVE QUEST", "cb": func(): menu.push(MenuView.save_page(menu, func(slot): save_to(slot)))},
		{"label": "LOAD QUEST", "cb": func(): menu.push(MenuView.load_page(menu, func(d): _load(d)))},
		{"label": "OPTIONS", "cb": func(): menu.push(MenuView.options_page(menu, _apply_settings))},
		{"label": "RESTART LEVEL", "cb": func(): _unpause(); Game.restart_level()},
		{"label": "QUIT TO MENU", "cb": func(): _unpause(); Game.goto_menu()},
	], "footer": "%s  -  %s" % [String(level.data.get("name", "")), Game.diff()["name"]]}


func _resume() -> void:
	if player and player.dead:
		return
	_unpause()
	_capture(true)


func _unpause() -> void:
	paused = false
	get_tree().paused = false
	menu.visible = false
	menu_bg.visible = false
	menu.stack.clear()


func _load(d: Dictionary) -> void:
	_unpause()
	Game.load_from_save(d)


func _show_death_menu() -> void:
	death_menu_shown = true
	_capture(false)
	menu.stack.clear()
	menu.visible = true
	menu.allow_empty_back = false
	var latest = Game.latest_save()
	menu.top_y = 190.0
	menu.push({"title": "", "items": [
		{"label": "LOAD LAST SAVE", "enabled": latest != null, "cb": func(): Game.load_from_save(Game.latest_save())},
		{"label": "RESTART LEVEL", "cb": func(): Game.restart_level()},
		{"label": "QUIT TO MENU", "cb": func(): Game.goto_menu()},
	], "back": func(): pass, "footer": "THE GORBINOS SEND THEIR REGARDS."})


# ------------------------------------------------------------------ events
func on_player_died() -> void:
	dead_t = 0.0
	hud.center("", 0.0)


func level_complete() -> void:
	if completed:
		return
	completed = true
	complete_t = 0.0
	hud.center("LEVEL COMPLETE", 2.0)
	Audio.stop_music(0.8)


func checkpoint() -> void:
	save_to("auto", " (CHECKPOINT)")
	Audio.play("checkpoint")
	message("CHECKPOINT. YOUR GORB HAS BEEN SAVED.", true)


func boss_started(en: Node) -> void:
	hud.boss = en
	Audio.play_music("boss", 0.3)


func on_boss_killed() -> void:
	hud.boss = null
	Audio.play_music(String(level.data.get("music", "")))
	message("THE GREAT SNIRBY HAS FALLEN. THE WAY HOME IS OPEN.", true)
	level.fire_tag(99)


# ------------------------------------------------------------------ save
func serialize() -> Dictionary:
	return {
		"label": String(level.data.get("name", "")), "level": Game.level_index, "difficulty": Game.difficulty,
		"inventory": player.get_inventory(), "level_start_inventory": Game.level_start_inventory.duplicate(true),
		"total_stats": Game.total_stats.duplicate(true),
		"level_state": {"level": level.serialize(), "player": {
			"x": player.global_position.x, "y": player.global_position.y, "z": player.global_position.z,
			"yaw": player.yaw, "pitch": player.pitch, "keys": player.keys.keys()}},
	}


func save_to(slot: String, suffix := "") -> void:
	if player.dead:
		return
	var d := serialize()
	d["label"] = String(d["label"]) + suffix
	Game.write_save(slot, d)


func _restore(st: Dictionary) -> void:
	level.restore(st.get("level", {}))
	var p: Dictionary = st.get("player", {})
	if p.has("x"):
		player.teleport_to(Vector3(float(p["x"]), float(p["y"]), float(p["z"])))
		player.yaw = float(p.get("yaw", 0.0))
		player.pitch = float(p.get("pitch", 0.0))
	for k in p.get("keys", []):
		player.keys[String(k)] = true
