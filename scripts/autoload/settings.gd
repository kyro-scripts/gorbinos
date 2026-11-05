extends Node
## Persistent user settings: audio, video, mouse, gameplay and key bindings.

const PATH := "user://settings.cfg"

const ACTIONS := [
	["move_forward", "MOVE FORWARD"], ["move_back", "MOVE BACK"], ["move_left", "STRAFE LEFT"],
	["move_right", "STRAFE RIGHT"], ["jump", "JUMP"], ["sprint", "SPRINT"], ["fire", "FIRE"],
	["use", "USE / OPEN"], ["reload", "RELOAD"], ["weapon_next", "NEXT WEAPON"],
	["weapon_prev", "PREV WEAPON"], ["weapon_last", "LAST WEAPON"], ["weapon_1", "PISTOL"],
	["weapon_2", "SHOTGUN"], ["weapon_3", "DOUBLE SHOTGUN"], ["weapon_4", "MACHINE GUN"],
	["weapon_5", "ROCKET LAUNCHER"], ["weapon_6", "PLASMA"], ["automap", "AUTOMAP"],
	["quicksave", "QUICK SAVE"], ["quickload", "QUICK LOAD"], ["pause", "PAUSE MENU"],
]

# default bindings: "k:<keycode>" for keys, "m:<button>" for mouse buttons
const DEFAULT_BINDS := {
	"move_forward": ["k:%d" % KEY_W, "k:%d" % KEY_UP],
	"move_back": ["k:%d" % KEY_S, "k:%d" % KEY_DOWN],
	"move_left": ["k:%d" % KEY_A],
	"move_right": ["k:%d" % KEY_D],
	"jump": ["k:%d" % KEY_SPACE],
	"sprint": ["k:%d" % KEY_SHIFT],
	"fire": ["m:%d" % MOUSE_BUTTON_LEFT, "k:%d" % KEY_CTRL],
	"use": ["k:%d" % KEY_E, "m:%d" % MOUSE_BUTTON_RIGHT],
	"reload": ["k:%d" % KEY_R],
	"weapon_next": ["m:%d" % MOUSE_BUTTON_WHEEL_DOWN],
	"weapon_prev": ["m:%d" % MOUSE_BUTTON_WHEEL_UP],
	"weapon_last": ["k:%d" % KEY_Q],
	"weapon_1": ["k:%d" % KEY_1],
	"weapon_2": ["k:%d" % KEY_2],
	"weapon_3": ["k:%d" % KEY_3],
	"weapon_4": ["k:%d" % KEY_4],
	"weapon_5": ["k:%d" % KEY_5],
	"weapon_6": ["k:%d" % KEY_6],
	"automap": ["k:%d" % KEY_TAB],
	"quicksave": ["k:%d" % KEY_F5],
	"quickload": ["k:%d" % KEY_F9],
	"pause": ["k:%d" % KEY_ESCAPE],
}

const WINDOW_SIZES := [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const WINDOW_MODES := ["WINDOWED", "FULLSCREEN", "BORDERLESS"]
const COLOR_DEPTHS := ["8-BIT DITHER", "12-BIT DITHER", "TRUE COLOR"]
const COLOR_LEVELS := [7.0, 16.0, 256.0]

var values := {
	"master_volume": 0.8,
	"music_volume": 0.6,
	"sfx_volume": 0.8,
	"mouse_sens": 0.4,          # 0..1 mapped to degrees per pixel
	"invert_y": false,
	"fov": 90.0,
	"window_mode": 0,
	"window_size": 1,
	"pixel_scale": 2,           # 0 = native, bigger = crunchier
	"color_depth": 1,
	"vsync": true,
	"max_fps": 0,
	"head_bob": true,
	"crosshair": 0,
	"show_fps": false,
	"auto_reload": true,
	"gamma": 1.0,
}
var binds := {}

signal changed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in DEFAULT_BINDS.keys():
		binds[a] = DEFAULT_BINDS[a].duplicate()
	load_settings()
	apply_binds()
	_setup_audio_buses()
	apply_audio()
	call_deferred("apply_video")


func _setup_audio_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")


func get_v(key: String):
	return values.get(key)


func set_v(key: String, v) -> void:
	values[key] = v
	match key:
		"master_volume", "music_volume", "sfx_volume":
			apply_audio()
		"window_mode", "window_size", "vsync", "max_fps":
			apply_video()
	changed.emit()


func mouse_degrees_per_pixel() -> float:
	return lerpf(0.02, 0.4, pow(float(values["mouse_sens"]), 1.5))


func color_levels() -> float:
	return COLOR_LEVELS[clampi(int(values["color_depth"]), 0, COLOR_LEVELS.size() - 1)]


func _db(v: float) -> float:
	return linear_to_db(maxf(v, 0.0001))


func apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, _db(values["master_volume"]))
	var m := AudioServer.get_bus_index("Music")
	var s := AudioServer.get_bus_index("SFX")
	if m >= 0:
		AudioServer.set_bus_volume_db(m, _db(values["music_volume"]))
	if s >= 0:
		AudioServer.set_bus_volume_db(s, _db(values["sfx_volume"]))


func apply_video() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values["vsync"] else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = [0, 60, 120, 144, 240][clampi(int(values["max_fps"]), 0, 4)]
	var mode := int(values["window_mode"])
	var win := get_window()
	if mode == 1:
		win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	elif mode == 2:
		win.mode = Window.MODE_FULLSCREEN
	else:
		win.mode = Window.MODE_WINDOWED
		var sz: Vector2i = WINDOW_SIZES[clampi(int(values["window_size"]), 0, WINDOW_SIZES.size() - 1)]
		var screen := DisplayServer.screen_get_size()
		if screen.x > 0 and (sz.x > screen.x or sz.y > screen.y):
			sz = Vector2i(int(screen.x * 0.9), int(screen.y * 0.9))
		win.size = sz
		if screen.x > 0:
			win.position = (screen - sz) / 2


# ------------------------------------------------------------------ binds
func event_from_code(code: String) -> InputEvent:
	var parts := code.split(":")
	if parts.size() != 2:
		return null
	if parts[0] == "k":
		var ev := InputEventKey.new()
		ev.physical_keycode = int(parts[1]) as Key
		return ev
	elif parts[0] == "m":
		var mb := InputEventMouseButton.new()
		mb.button_index = int(parts[1]) as MouseButton
		return mb
	return null


func code_from_event(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return "k:%d" % k
	if ev is InputEventMouseButton:
		return "m:%d" % ev.button_index
	return ""


func code_name(code: String) -> String:
	var parts := code.split(":")
	if parts.size() != 2:
		return "---"
	if parts[0] == "k":
		return OS.get_keycode_string(int(parts[1])).to_upper()
	match int(parts[1]):
		MOUSE_BUTTON_LEFT: return "MOUSE 1"
		MOUSE_BUTTON_RIGHT: return "MOUSE 2"
		MOUSE_BUTTON_MIDDLE: return "MOUSE 3"
		MOUSE_BUTTON_WHEEL_UP: return "WHEEL UP"
		MOUSE_BUTTON_WHEEL_DOWN: return "WHEEL DOWN"
		MOUSE_BUTTON_XBUTTON1: return "MOUSE 4"
		MOUSE_BUTTON_XBUTTON2: return "MOUSE 5"
	return "MOUSE %s" % parts[1]


func apply_binds() -> void:
	for a in binds.keys():
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
		InputMap.action_erase_events(a)
		for code in binds[a]:
			var ev := event_from_code(code)
			if ev:
				InputMap.action_add_event(a, ev)


func set_bind(action: String, code: String) -> void:
	# a key can only be bound to one action: remove it elsewhere
	for a in binds.keys():
		if a != action and binds[a].has(code):
			binds[a].erase(code)
	binds[action] = [code]
	apply_binds()
	save_settings()


func reset_binds() -> void:
	for a in DEFAULT_BINDS.keys():
		binds[a] = DEFAULT_BINDS[a].duplicate()
	apply_binds()
	save_settings()


func bind_label(action: String) -> String:
	var arr: Array = binds.get(action, [])
	if arr.is_empty():
		return "---"
	var names := []
	for c in arr:
		names.append(code_name(c))
	return " / ".join(names)


# ------------------------------------------------------------------ persistence
func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in values.keys():
		cf.set_value("settings", k, values[k])
	for a in binds.keys():
		cf.set_value("binds", a, binds[a])
	cf.save(PATH)


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in values.keys():
		if cf.has_section_key("settings", k):
			values[k] = cf.get_value("settings", k)
	for a in binds.keys():
		if cf.has_section_key("binds", a):
			var v = cf.get_value("binds", a)
			if v is Array:
				binds[a] = v
