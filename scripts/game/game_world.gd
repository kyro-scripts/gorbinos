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
var menu_bg: Control
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
	# must not swallow mouse events: look input is read in _input below
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var mb := MenuBackdrop.new()
	mb.opaque = false
	menu_bg = mb
	menu_bg.visible = false
	add_child(menu_bg)
	menu = MenuView.new()
	menu.visible = false
	menu.allow_empty_back = true
	menu.emptied.connect(_resume)
	add_child(menu)
	_death_stamp = load("res://assets/ui/death.png")
	var dr := Dread.new()
	dr.world = self
	dr.level = level
	dr.player = player
	add_child(dr)
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
	if level.data.get("endless", false):
		endless = Endless.new()
		add_child(endless)
		endless.setup(self)
	if Game.autoplay:
		autopilot = load("res://scripts/test/autopilot.gd").new()
		autopilot.setup(self)
		add_child(autopilot)
	if OS.get_cmdline_user_args().has("--lineup"):
		_debug_lineup()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--guttest"):
			_debug_guttest(a.substr(10) if a.length() > 10 else "green")
		elif a == "--facetest":
			hud.flash_face(100.0)
			_debug_shots("face", [2.0], true)
		elif a == "--armshots":
			_debug_shots("arm", [0.6, 1.2, 1.8, 2.4, 3.0, 3.6, 4.2, 4.8, 5.4, 6.0, 6.6, 7.2, 7.8, 8.4], true)
		elif a.begins_with("--gallery="):
			_debug_gallery(a.substr(10))
		elif a == "--gibtest" or a == "--deathtest":
			_debug_gibtest(a == "--deathtest")
		elif a == "--vmshots":
			_debug_viewmodels()
		elif a == "--ammolineup":
			player.weapons.visible = false
			player.offhand.visible = false
			player.offhand.set_process(false)
			var yaw := level.start_yaw
			var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
			var right := Vector3(cos(yaw), 0, -sin(yaw))
			for i in Pickup.AMMO.size():
				var pk := Pickup.new()
				level.entity_root().add_child(pk)
				var pp: Vector3 = level.player_start + fwd * (4.5 + (i / 4) * 1.6) + right * ((i % 4) - 1.5) * 1.3
				pk.setup(Pickup.AMMO[i], Vector3(pp.x, level.floor_at(pp), pp.z))
		elif a.begins_with("--armshots="):
			_debug_trick(a.substr(11))
		elif a == "--civshot":
			_debug_civshot()
		elif a == "--slidetest":
			get_tree().create_timer(0.6).timeout.connect(func():
				player.velocity = -Basis(Vector3.UP, player.yaw).z * 12.0
				player._start_slide()
				get_tree().create_timer(0.25).timeout.connect(func():
					print("SLIDE t=%.2f speed=%.1f dip=%.2f" % [player.slide_t, Vector2(player.velocity.x, player.velocity.z).length(), player.slide_dip])
					if not OS.get_cmdline_user_args().has("--shot-name=slide"):
						get_tree().quit()))
		elif a == "--frenzy":
			get_tree().create_timer(0.5).timeout.connect(func(): player._start_frenzy())
		elif a == "--flametest":
			_debug_flametest()
		elif a.begins_with("--whiptest"):
			_debug_whiptest(a.substr(11) if a.length() > 11 else "green")
		elif a.begins_with("--hp="):
			player.health = int(a.substr(5))
		elif a.begins_with("--armor="):
			player.armor = int(a.substr(8))
			player.armor_type = 1
		elif a == "--die":
			get_tree().create_timer(1.0).timeout.connect(func(): player.take_damage(999.0, null, Vector3.ZERO))
		elif a == "--pauseshot":
			_debug_pauseshot()
		elif a == "--fishtour":
			_debug_fishtour()
		elif a.begins_with("--peek="):
			var xz := a.substr(7).split(",")
			_debug_peek(Vector3(float(xz[0]), 0, float(xz[1])))


## Debug: put a creature in reach, gut it, and screenshot every phase.
func _debug_guttest(etype: String) -> void:
	var yaw := level.start_yaw
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var p: Vector3 = level.player_start + fwd * 1.9
	p.y = level.floor_at(p)
	var en := Enemy.new()
	level.entity_root().add_child(en)
	en.setup(etype, level, p, yaw + PI)
	level.enemies.append(en)
	if OS.get_cmdline_user_args().has("--gutfire"):
		# mortal, with two shooters already on the player: health must not move
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		for k in 2:
			var sp: Vector3 = level.player_start + fwd * 6.0 + right * (3.0 if k == 0 else -3.0)
			sp.y = level.floor_at(sp)
			var sh := Enemy.new()
			level.entity_root().add_child(sh)
			sh.setup("yellow" if k == 0 else "green", level, sp, yaw + PI)
			level.enemies.append(sh)
			sh.alert()
		await get_tree().create_timer(1.0).timeout
		var before: int = player.health
		player.finisher.start(en)
		var t := 0.0
		var after: int = player.health
		while player.finisher.active() or player.gut_grace > 0.0:
			# health as of the last frame that was still protected (a shot can
			# land in the same frame the grace runs out, and that one counts)
			after = player.health
			await get_tree().process_frame
			t += get_process_delta_time()
		print("GUTFIRE health before=%d after=%d (%.1fs)" % [before, after, t])
		await get_tree().create_timer(2.0).timeout
		print("GUTFIRE health 2s after the gut=%d (should drop: shooters are real)" % player.health)
		get_tree().quit()
		return
	Game.cheats["god"] = true
	await get_tree().create_timer(1.0).timeout
	player.finisher.start(en)
	_debug_shots("gut", [0.05, 0.3, 0.42, 0.65, 0.95, 1.25, 1.5, 1.8, 2.05, 2.3, 2.6, 3.2, 4.5], true)


## Debug: three Gorbinos down the hall, hold the flamethrower on them.
func _debug_flametest() -> void:
	Game.cheats["god"] = true
	var yaw := level.start_yaw
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	for k in 3:
		var p: Vector3 = level.player_start + fwd * (4.5 + k * 0.8) + right * (k - 1) * 1.4
		p.y = level.floor_at(p)
		var en := Enemy.new()
		level.entity_root().add_child(en)
		en.setup(["green", "yellow", "blue"][k], level, p, yaw + PI)
		level.enemies.append(en)
		en.set_physics_process(true)
	player.weapons.owned.append("flamer")
	player.weapons.ammo["fuel"] = 200
	player.weapons.switch_to("flamer")
	hud.center("", 0.0)
	await get_tree().create_timer(0.6).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	var shots := [0.3, 0.7, 1.2, 1.8, 2.6, 3.6]
	var t := 0.0
	var si := 0
	while si < shots.size():
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		if t < 1.4 and player.weapons.cooldown <= 0.0:
			player.weapons._try_fire()
		if t >= shots[si]:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("user://shots/flame_%d.png" % si)
			si += 1
	var burning := 0
	var dead := 0
	for e in level.enemies:
		if is_instance_valid(e):
			burning += 1 if e.burn_t > 0.0 else 0
			dead += 1 if e.dead else 0
	print("FLAME burning=%d dead=%d fuel=%d" % [burning, dead, int(player.weapons.ammo["fuel"])])
	get_tree().quit()


## Debug: put a creature down the hall, whip it in and screenshot the lot.
func _debug_whiptest(etype: String) -> void:
	Game.cheats["god"] = true
	var yaw := level.start_yaw
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var p: Vector3 = level.player_start + fwd * 8.0
	p.y = level.floor_at(p)
	var en := Enemy.new()
	level.entity_root().add_child(en)
	en.setup(etype, level, p, yaw + PI)
	level.enemies.append(en)
	hud.center("", 0.0)
	await get_tree().create_timer(0.8).timeout
	var eye: Vector3 = player.eye_point()
	var d: Vector3 = en.center_point() - eye
	print("WHIP target in sights: ", player.finisher.find_whip_target() == en, " dot=", (-player.camera.global_transform.basis.z).dot(d.normalized()),
		" dist=", d.length(), " los=", level.has_los(eye, en.center_point()), " dead=", en.dead, " gutted=", en.gutted)
	player.finisher._whip_start(en)
	_debug_shots("whip", [0.06, 0.13, 0.25, 0.38, 0.5, 0.9, 1.6, 2.6], true)


## Debug: stand at a spot and look all round it.
func _debug_peek(p: Vector3) -> void:
	Game.cheats["god"] = true
	for e in level.enemies:
		e.set_physics_process(false)
	hud.center("", 0.0)
	p.y = level.floor_at(p)
	player.teleport_to(p)
	DirAccess.make_dir_recursive_absolute("user://shots")
	for k in 4:
		player.yaw = k * PI * 0.5
		player.pitch = -0.35
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://shots/peek_%d.png" % k)
	get_tree().quit()


## Debug: screenshot the pause menu (and its options page).
func _debug_pauseshot() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	await get_tree().create_timer(1.5).timeout
	open_pause()
	for k in 2:
		for f in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://shots/pause_%d.png" % k)
		if k == 0:
			menu.push(MenuView.options_page(menu, _apply_settings))
	get_tree().quit()


## Debug: walk up to each trout pasted on the walls and screenshot it.
func _debug_fishtour() -> void:
	Game.cheats["god"] = true
	for e in level.enemies:
		e.set_physics_process(false)
		e.visible = false
	hud.center("", 0.0)
	DirAccess.make_dir_recursive_absolute("user://shots")
	var k := 0
	for q in level.wall_fish.get_children():
		var n: Vector3 = (q as Node3D).global_basis.z.normalized()
		var p: Vector3 = q.global_position + Vector3(n.x, 0, n.z).normalized() * 3.0
		p.y = level.floor_at(p)
		player.teleport_to(p)
		player.yaw = atan2(n.x, n.z)
		player.pitch = 0.0
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://shots/fish_%d.png" % k)
		k += 1
	get_tree().quit()


## Debug: go and listen to the locals: one talking to you, a pair chatting
## to each other, then a gunshot to scatter them.
func _debug_civshot() -> void:
	Game.cheats["god"] = true
	for e in level.enemies:
		e.set_physics_process(false)
		e.visible = false
	hud.center("", 0.0)
	print("CIV count %d" % level.civilians.size())
	DirAccess.make_dir_recursive_absolute("user://shots")
	var shots := 0
	for c in level.civilians:
		if shots >= 3:
			break
		var lead: bool = c.lead
		var dist := 6.0 if lead else 2.4
		var best := Vector3.INF
		for a in 12:
			var dir := Vector3(cos(a * TAU / 12.0), 0, sin(a * TAU / 12.0))
			var p: Vector3 = c.global_position + dir * dist
			var i := level.idx_of(level.cell_of(p))
			if i >= 0 and level.solid[i] == 0 and not level.exit_cells.has(i) and not level.teleports.has(i) \
					and level.has_los(p + Vector3(0, 1.5, 0), c.center_point()):
				best = p
				break
		if best == Vector3.INF:
			continue
		best.y = level.floor_at(best)
		player.teleport_to(best)
		var to: Vector3 = c.global_position - best
		player.yaw = atan2(-to.x, -to.z)
		player.pitch = -0.15
		c.talk_cd = 0.0
		c.chat_cd = 0.0
		await get_tree().create_timer(2.6 if lead else 1.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://shots/civ_%d.png" % shots)
		shots += 1
	level.noise_at(player.global_position, 22)
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shots/civ_3.png")
	get_tree().quit()


## Debug: line up every model of a group in front of the player and
## screenshot it from two angles (art review).
func _debug_gallery(group: String) -> void:
	player.weapons.visible = false
	player.offhand.visible = false
	player.offhand.set_process(false)
	var names: Array = []
	match group:
		"pickups":
			names = ["juice", "medkit", "mega", "armor_bonus", "armor_green", "armor_blue", "backpack",
				"key_red", "key_blue", "key_yellow", "bullets", "bullets_box", "shells", "shells_box",
				"rocket", "rockets_box", "cells", "cells_box"]
		"weapons":
			names = ["w_shotgun", "w_ssg", "w_mg", "w_rocket", "w_plasma"]
		"props":
			names = ["lamp", "statue", "tree", "machine", "checkpoint", "barrel"]
	var yaw := level.start_yaw
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var cols: int = {"pickups": 6, "props": 3}.get(group, 4)
	var gap: float = {"pickups": 1.0, "props": 3.2}.get(group, 2.0)
	for i in names.size():
		var row := i / cols
		var col := i % cols
		var p: Vector3 = level.player_start + fwd * ((6.5 if group == "props" else 3.0) + row * gap * 1.2) + right * (col - (cols - 1) * 0.5) * gap
		p.y = level.floor_at(p)
		var n: String = names[i]
		if group == "props":
			if n == "barrel":
				var b := Barrel.new()
				level.entity_root().add_child(b)
				b.setup(level, p)
			else:
				var pr := Props.make_prop(n, level, p)
				level.entity_root().add_child(pr)
		else:
			var pk := Pickup.new()
			level.entity_root().add_child(pk)
			pk.setup(n, p)
	player.pitch = deg_to_rad(-22.0)
	_debug_shots("gallery_" + group, [3.0, 3.6], true)


## Debug: kill a row of creatures in front of the player, half of them
## shot from the side (normal deaths), half blown apart.
func _debug_gibtest(normal_only := false) -> void:
	player.offhand.visible = false
	var yaw := level.start_yaw
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var ens := []
	var kinds := ["green", "snirby", "snotling", "green", "snirby", "snotling"]
	for k in kinds.size():
		var p: Vector3 = level.player_start + fwd * (4.0 if k < 3 else 6.5) + right * ((k % 3) - 1) * 1.8
		p.y = level.floor_at(p)
		var en := Enemy.new()
		level.entity_root().add_child(en)
		en.setup(kinds[k], level, p, yaw + PI)
		level.enemies.append(en)
		ens.append(en)
		en.process_mode = Node.PROCESS_MODE_DISABLED
	Game.cheats["god"] = true
	player.pitch = deg_to_rad(-16.0)
	await get_tree().create_timer(1.0).timeout
	for k in ens.size():
		var en: Enemy = ens[k]
		en.process_mode = Node.PROCESS_MODE_INHERIT
		if k < 3 or normal_only:
			en.take_damage(en.hp + 5.0, player, right * (1.0 if k % 2 == 0 else -1.0), "bullet")
		else:
			en.take_damage(400.0, player, fwd, "explosion")
	_debug_shots("gib", [0.1, 0.3, 0.6, 1.2, 3.5], true)


## Debug: screenshot the view model of every weapon.
func _debug_viewmodels() -> void:
	player.offhand.visible = false
	var order: Array = Weapons.ORDER
	var t := 1.5
	for w in order:
		await get_tree().create_timer(t).timeout
		t = 0.9
		player.weapons.switch_to(w)
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://shots/vm_%s.png" % w)
	get_tree().quit()


## Debug: force one knife trick and screenshot it frame by frame.
func _debug_trick(trick: String) -> void:
	await get_tree().create_timer(1.5).timeout
	var oh: Offhand = player.offhand
	oh.trick = trick
	oh.trick_t = 0.0
	oh._sounds = {}
	var dur: float = Offhand.TRICK_DUR[trick]
	var times := []
	for i in 10:
		times.append(dur * (i + 0.5) / 10.0)
	_debug_shots("trick_" + trick, times, true)


func _debug_shots(tag: String, times: Array, quit_after: bool) -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	hud.center("", 0.0)  # the level title would sit over the subject
	var t0 := 0.0
	for i in times.size():
		await get_tree().create_timer(float(times[i]) - t0).timeout
		t0 = float(times[i])
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://shots/%s_%02d.png" % [tag, i])
	if quit_after:
		get_tree().quit()


## Debug: stand one of every creature in front of the player, frozen, for screenshots.
func _debug_lineup() -> void:
	var yaw := level.start_yaw
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var turn := 0.0
	var near := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lineup-turn="):
			turn = float(a.substr(14))
		if a.begins_with("--lineup-near="):
			near = float(a.substr(14))
	var rows := [[4.6 * near, 1.5, ["snotling", "green", "snirby", "yellow", "red"]], [8.0, 2.4, ["blue", "skysnirby", "black", "purple"]]]
	for row in rows:
		var names: Array = row[2]
		for i in names.size():
			var p: Vector3 = level.player_start + fwd * float(row[0]) + right * (float(i) - (names.size() - 1) * 0.5) * float(row[1])
			p.y = level.floor_at(p)
			var en := Enemy.new()
			level.entity_root().add_child(en)
			en.setup(names[i], level, p, yaw + PI + turn)
			en.process_mode = Node.PROCESS_MODE_DISABLED


func _exit_tree() -> void:
	Audio.music_player.pitch_scale = 1.0
	Engine.time_scale = 1.0
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
	post.set_shader_parameter("zine", 1.0 if Collage.enabled() else 0.0)
	if level:
		for e in level.enemies:
			if is_instance_valid(e) and e.model:
				Collage.outline(e.model)
		if level.wall_fish:
			level.wall_fish.visible = Collage.enabled()
		for p in level.pickups:
			if is_instance_valid(p) and p.model:
				Collage.outline(p.model)
	if player:
		if player.weapons.vm:
			Collage.outline_viewmodel(player.weapons.vm)
		Collage.outline_viewmodel(player.offhand)
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
		_frenzy_fx = move_toward(_frenzy_fx, 1.0 if player.frenzy > 0.0 else 0.0, delta * 3.0)
		post.set_shader_parameter("frenzy", _frenzy_fx)
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
	pass


## Mouse look is handled before the GUI so no Control can swallow it.
func _input(event: InputEvent) -> void:
	if paused or player == null or player.dead or completed:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"
	if event is InputEventMouseMotion:
		if captured:
			player.look(event.screen_relative)
	elif event is InputEventMouseButton and event.pressed and not captured:
		_capture(true)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# regain the mouse when the window gets focus back (alt-tab etc.)
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and not paused and player and not player.dead:
		_capture(true)


func _unhandled_input(event: InputEvent) -> void:
	if paused or player == null:
		return
	if player.dead or completed:
		return
	if event is InputEventMouseMotion:
		return
	if event.is_action_pressed("pause"):
		open_pause()
	elif event.is_action_pressed("automap"):
		hud.show_map = not hud.show_map
	elif event.is_action_pressed("quicksave"):
		if player.gutting:
			return
		if endless:
			hud.message("NO SAVING IN THE PIT.")
			return
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
	var st := level.stats
	return {"title": "PAUSED", "tiles": true, "cols": 3, "items": [
		{"label": "RESUME", "icon": "tile_resume", "cb": func(): _resume()},
		{"label": "SAVE", "icon": "tile_save", "cb": func(): menu.push(MenuView.save_page(menu, func(slot): save_to(slot)))},
		{"label": "LOAD", "icon": "tile_load", "cb": func(): menu.push(MenuView.load_page(menu, func(d): _load(d)))},
		{"label": "OPTIONS", "icon": "tile_options", "cb": func(): menu.push(MenuView.options_page(menu, _apply_settings))},
		{"label": "RESTART LEVEL", "icon": "tile_retry", "cb": func(): _unpause(); Game.restart_level()},
		{"label": "QUIT TO MENU", "icon": "tile_quit", "cb": func(): _unpause(); Game.goto_menu()},
	], "footer": "%s   KILLS %d/%d   SECRETS %d/%d   %s" % [String(level.data.get("name", "")), st["kills"], st["kills_total"], st["secrets"], st["secrets_total"], Game.diff()["name"]]}


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
	menu.top_y = 180.0
	if endless:
		var b: Dictionary = endless.best
		var title := "SURVIVED %d WAVES   %d KILLS" % [maxi(endless.wave - 1, 0), endless.kills]
		hud.center("NEW BEST!" if endless.new_best else "BEST: WAVE %d" % int(b.get("wave", 0)), 999.0)
		menu.push({"title": title, "tiles": true, "cols": 2, "items": [
			{"label": "TRY AGAIN", "icon": "tile_retry", "cb": func(): Game.restart_level()},
			{"label": "QUIT TO MENU", "icon": "tile_quit", "cb": func(): Game.goto_menu()},
		], "back": func(): pass})
		return
	menu.push({"title": "", "tiles": true, "cols": 3, "items": [
		{"label": "RESTART LEVEL", "icon": "tile_retry", "cb": func(): Game.restart_level()},
		{"label": "LOAD LAST SAVE", "icon": "tile_load", "enabled": latest != null, "cb": func(): Game.load_from_save(Game.latest_save())},
		{"label": "QUIT TO MENU", "icon": "tile_quit", "cb": func(): Game.goto_menu()},
	], "back": func(): pass})


# ------------------------------------------------------------------ events
func on_player_died() -> void:
	dead_t = 0.0
	hud.center("", 0.0)


var _hitstop_token := 0
var _frenzy_fx := 0.0
var endless: Endless = null


## Freeze the world for a moment (real seconds). Skipped while gutting,
## which runs its own slow motion.
func hitstop(real_dur: float) -> void:
	if player.gutting or Engine.time_scale < 0.99 or Game.autoplay:
		return
	_hitstop_token += 1
	var tok := _hitstop_token
	Engine.time_scale = 0.08
	get_tree().create_timer(real_dur, true, false, true).timeout.connect(func():
		if tok == _hitstop_token and Engine.time_scale < 0.99:
			Engine.time_scale = 1.0)


## Someone says something: a subtitle at the bottom of the screen.
func say(who: String, text: String) -> void:
	hud.say(who, text)


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
	message("PROGRESS SAVED", true)


func boss_started(en: Node) -> void:
	hud.boss = en
	Audio.play_music("boss", 0.3)


func on_boss_killed() -> void:
	hud.boss = null
	Audio.play_music(String(level.data.get("music", "")))
	message("THE WAY OUT IS OPEN", true)
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
