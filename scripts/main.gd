extends Node
## Root of the game. Owns the current screen and swaps between
## splash, menu, story, game, intermission and ending.

var current: Node = null
var layer: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.main = self
	if DisplayServer.get_name() != "headless":
		Input.set_custom_mouse_cursor(load("res://assets/ui/cursor_hand.png"), Input.CURSOR_ARROW, Vector2(13, 1))
	layer = CanvasLayer.new()
	add_child(layer)
	_set_neutral_globals()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--shot-after="):
			_shot_later(float(a.substr(13)), args)
	if args.has("--test"):
		var t = load("res://scripts/test/test_runner.gd").new()
		add_child(t)
		return
	if args.has("--endless"):
		Game.start_endless(1)
		return
	for a in args:
		if a.begins_with("--level="):
			Game.difficulty = 1
			Game.inventory = Game.new_inventory()
			if args.has("--arsenal"):
				Game.inventory["weapons"] = ["pistol", "shotgun", "ssg", "mg", "rocket", "plasma", "flamer", "trout"]
				Game.inventory["ammo"] = {"bullets": 200, "shells": 50, "rockets": 30, "cells": 300, "fuel": 200, "trout": 40}
				Game.inventory["mags"] = {"pistol": 12, "shotgun": 6, "ssg": 2, "mg": 60, "rocket": 4}
			if args.has("--lowammo"):
				Game.inventory["ammo"] = {"bullets": 0, "shells": 0, "rockets": 0, "cells": 0}
				Game.inventory["mags"] = {"pistol": 3}
			var lv := a.substr(8)
			if lv == "test":
				Game.level_override = load("res://scripts/levels/test_level.gd").DATA
				Game.start_level(0)
			else:
				Game.start_level(int(lv) - 1)
			return
	if Game.autoplay:
		var ep := 0
		for a in args:
			if a.begins_with("--episode="):
				ep = int(a.substr(10)) - 1
		Game.new_game(1, ep)
		return
	if args.has("--uitest"):
		_ui_test()
		return
	show_splash()


## Debug: cycle through every UI screen and save screenshots.
func _ui_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	var snap := func(n: String):
		await get_tree().create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://shots/ui_%s.png" % n)
	show_menu()
	var mm = current
	await snap.call("main")
	mm.menu.push(MenuView.options_page(mm.menu))
	await snap.call("options")
	mm.menu.push(MenuView.video_page(mm.menu, Callable()))
	await snap.call("video")
	mm.menu.push(MenuView.binds_page(mm.menu))
	await snap.call("binds")
	mm.menu.pop(); mm.menu.pop(); mm.menu.pop()
	mm.menu.push(mm._episode_page())
	await snap.call("episode")
	mm.menu.pop()
	mm.menu.push(mm._difficulty_page())
	await snap.call("difficulty")
	show_story(Game.STORY[1], Game.level_name(1), func(): pass)
	await get_tree().create_timer(6.0).timeout
	await snap.call("story")
	show_intermission(0, {"kills": 27, "kills_total": 32, "items": 9, "items_total": 12, "secrets": 2, "secrets_total": 3, "time": 201.0})
	await get_tree().create_timer(5.0).timeout
	await snap.call("intermission")
	show_ending()
	await get_tree().create_timer(9.0).timeout
	await snap.call("ending")
	get_tree().quit()


## The world shader samples a level light texture; outside of a level give it
## a neutral one so menu models render lit.
func _set_neutral_globals() -> void:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(0.9, 0, 0, 1))
	var tex := ImageTexture.create_from_image(img)
	RenderingServer.global_shader_parameter_set("level_light", tex)
	RenderingServer.global_shader_parameter_set("level_info", Vector4(1000.0, 1, 1, 0))
	RenderingServer.global_shader_parameter_set("fog_color", Vector4(0, 0, 0, 0))
	RenderingServer.global_shader_parameter_set("fog_params", Vector4(100, 200, 1.2, 0.0))
	for i in 6:
		RenderingServer.global_shader_parameter_set("dl_p%d" % i, Vector4(0, -1000, 0, 0.001))
		RenderingServer.global_shader_parameter_set("dl_c%d" % i, Vector4(0, 0, 0, 0))


func _swap(n: Node) -> void:
	get_tree().paused = false
	if current and is_instance_valid(current):
		current.queue_free()
	current = n
	layer.add_child(n)


func show_splash() -> void:
	_swap(load("res://scripts/ui/screens/splash.gd").new())


func show_menu() -> void:
	_set_neutral_globals()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_swap(load("res://scripts/ui/screens/main_menu.gd").new())


func show_story(text: String, title: String, cb: Callable) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var s = load("res://scripts/ui/screens/story.gd").new()
	s.setup(text, title, cb)
	_swap(s)


func show_game() -> void:
	_swap(GameWorld.new())


func show_intermission(level_index: int, stats: Dictionary) -> void:
	_set_neutral_globals()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var s = load("res://scripts/ui/screens/intermission.gd").new()
	s.setup(level_index, stats)
	_swap(s)


func show_ending() -> void:
	_set_neutral_globals()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_swap(load("res://scripts/ui/screens/ending.gd").new())


## Debug helper: save a screenshot after a delay, optionally pressing keys.
func _shot_later(sec: float, args: PackedStringArray) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	await RenderingServer.frame_post_draw
	var tag := "auto"
	for a in args:
		if a.begins_with("--shot-name="):
			tag = a.substr(12)
	get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % tag)
	if not args.has("--keep-running"):
		get_tree().quit()
