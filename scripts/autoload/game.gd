extends Node
## Global game flow: level progression, difficulty, persistent inventory,
## save / load and screen switching.

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 3

const LEVELS := [
	"res://scripts/levels/level1_village.gd",
	"res://scripts/levels/level2_industrial.gd",
	"res://scripts/levels/level3_mines.gd",
	"res://scripts/levels/level4_hq.gd",
	"res://scripts/levels/level5_facility.gd",
	"res://scripts/levels/level6_dimension.gd",
]

const DIFFICULTIES := [
	{"name": "BABY GORB", "desc": "FOR THOSE WHO FEAR THE GORB.", "dmg": 0.5, "ammo": 2.0, "speed": 0.85, "aggro": 0.7},
	{"name": "GORB ENJOYER", "desc": "THE WAY GORBINO INTENDED.", "dmg": 1.0, "ammo": 1.0, "speed": 1.0, "aggro": 1.0},
	{"name": "ULTRA-GORB", "desc": "THEY SHOOT FASTER. THEY HIT HARDER.", "dmg": 1.4, "ammo": 1.0, "speed": 1.12, "aggro": 1.3},
	{"name": "GORB HELL", "desc": "NOT EVEN REMOTELY FAIR.", "dmg": 2.0, "ammo": 0.8, "speed": 1.3, "aggro": 1.7},
]

# Text shown before each level (index = level about to start)
const STORY := [
	"THE GORBINOS HAVE TAKEN THE VILLAGE.\n\nNOBODY KNOWS WHERE THEY CAME FROM. NOBODY KNOWS WHAT THEY WANT. THEY JUST SAY \"GORB\".\n\nYOU HAVE A PISTOL, A PAIR OF HAZMAT GLOVES AND A BAD FEELING.\n\nFIND THE EXIT. CLEANSE GORBVILLE.",
	"THE VILLAGE IS QUIET NOW.\n\nTHE GORBINOS WERE NOT BORN. THEY WERE SHIPPED. EVERY CRATE IS STAMPED WITH THE SAME LOGO:\n\nSNIRBY INDUSTRIAL.\n\nTHE FACTORY STILL HUMS. SOMETHING IN THERE IS SNIFFING.",
	"THE COMPLEX WAS ONLY A PACKAGING PLANT.\n\nTHE RAW GORB IS DUG OUT OF THE EARTH, DEEP BELOW, WHERE THE CRYSTALS SING.\n\nTAKE THE LIFT DOWN. MIND THE SLUDGE.",
	"THE MINE CARTS ALL LEAD TO ONE PLACE.\n\nA TOWER OF GLASS AND CARPET. THE CONSUMER HEADQUARTERS.\n\nSOMEONE UP THERE SIGNS THE GORB INVOICES. THE BOARD MEETING IS IN SESSION.",
	"THE BOARD WAS EMPTY. JUST CHAIRS. JUST GORBINOS IN TIES.\n\nTHE ORDERS CAME FROM BELOW THE BASEMENT: A FACILITY THAT GROWS GORBINOS IN VATS, ONE UNIT AT A TIME, FOREVER.\n\nTHE ENDLESS GORBINO FACILITY. TURN IT OFF.",
	"THE VATS WERE FED THROUGH A TEAR IN THE WORLD.\n\nON THE OTHER SIDE, SOMETHING ENORMOUS IS SNIFFING THE AIR.\n\nIT SMELLS YOU.\n\nWELCOME TO THE SNIRBY DIMENSION.",
]

const ENDING := "THE GREAT SNIRBY FALLS.\n\nTHE TEAR CLOSES WITH A WET SOUND. THE VATS GO DARK. THE LAST GORBINO LOOKS AT YOU, SAYS \"GORB\", AND LIES DOWN.\n\nYOU WALK HOME THROUGH GORBVILLE. THE FLOWERS ARE GROWING BACK.\n\nSOMEWHERE, FAR BELOW, A SINGLE VAT BUBBLES.\n\nGORB."

var main: Node = null            # scripts/main.gd root, owns screens
var difficulty := 1
var level_index := 0
var inventory := {}
var level_start_inventory := {}
var total_stats := {"kills": 0, "kills_total": 0, "items": 0, "items_total": 0, "secrets": 0, "secrets_total": 0, "time": 0.0}
var pending_restore = null       # level state to restore after the level is built
var level_override = null        # test harness: level data used instead of LEVELS
var autoplay := false            # test harness: bot plays the game
var cheats := {"god": false}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var args := OS.get_cmdline_user_args()
	autoplay = args.has("--autoplay")


func diff() -> Dictionary:
	return DIFFICULTIES[clampi(difficulty, 0, DIFFICULTIES.size() - 1)]


func level_data(i: int) -> Dictionary:
	if level_override != null:
		return level_override
	var scr = load(LEVELS[i])
	return scr.DATA


func level_name(i: int) -> String:
	return level_data(i).get("name", "LEVEL %d" % (i + 1))


func new_inventory() -> Dictionary:
	return {
		"health": 100, "armor": 0, "armor_type": 0,
		"weapons": ["pistol"], "current": "pistol",
		"ammo": {"bullets": 40, "shells": 0, "rockets": 0, "cells": 0},
		"mags": {"pistol": 12},
		"backpack": false,
	}


# ------------------------------------------------------------------ flow
func new_game(diff_index: int) -> void:
	difficulty = diff_index
	inventory = new_inventory()
	total_stats = {"kills": 0, "kills_total": 0, "items": 0, "items_total": 0, "secrets": 0, "secrets_total": 0, "time": 0.0}
	level_index = 0
	show_story(0)


func show_story(i: int) -> void:
	main.show_story(STORY[i] if i < STORY.size() else "", level_name(i), func(): start_level(i))


func start_level(i: int, restore_state = null) -> void:
	level_index = i
	if restore_state == null:
		# entering fresh: clamp health like the classics (keep inventory)
		inventory["health"] = clampi(int(inventory.get("health", 100)), 1, 200)
		level_start_inventory = inventory.duplicate(true)
		pending_restore = null
	else:
		pending_restore = restore_state
	main.show_game()


func restart_level() -> void:
	inventory = level_start_inventory.duplicate(true)
	start_level(level_index)


func level_finished(stats: Dictionary, inv: Dictionary) -> void:
	inventory = inv.duplicate(true)
	if autoplay and OS.get_cmdline_user_args().has("--single"):
		print("[bot] LEVEL COMPLETE: ", level_name(level_index), " stats=", stats)
		get_tree().quit(0)
		return
	for k in ["kills", "kills_total", "items", "items_total", "secrets", "secrets_total"]:
		total_stats[k] += int(stats.get(k, 0))
	total_stats["time"] += float(stats.get("time", 0.0))
	main.show_intermission(level_index, stats)


func after_intermission() -> void:
	var nxt := level_index + 1
	if nxt >= LEVELS.size():
		main.show_ending()
	else:
		level_index = nxt
		show_story(nxt)
		# autosave at the start of each new level
		save_level_start(nxt)


func save_level_start(i: int) -> void:
	var data := {
		"version": SAVE_VERSION, "label": level_name(i), "level": i, "difficulty": difficulty,
		"inventory": inventory.duplicate(true), "total_stats": total_stats.duplicate(true),
		"level_state": null, "time": Time.get_unix_time_from_system(),
	}
	write_save("auto", data)


func goto_menu() -> void:
	main.show_menu()


# ------------------------------------------------------------------ saves
func save_path(slot: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot]


func write_save(slot: String, data: Dictionary) -> bool:
	data["version"] = SAVE_VERSION
	data["slot"] = slot
	data["time"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(save_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


func read_save(slot: String):
	var p := save_path(slot)
	if not FileAccess.file_exists(p):
		return null
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return null
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY or int(d.get("version", 0)) != SAVE_VERSION:
		return null
	return d


func list_saves() -> Array:
	var out := []
	for slot in ["auto", "quick", "slot1", "slot2", "slot3"]:
		var d = read_save(slot)
		if d != null:
			out.append(d)
	return out


func latest_save():
	var best = null
	for d in list_saves():
		if best == null or float(d.get("time", 0)) > float(best.get("time", 0)):
			best = d
	return best


func has_any_save() -> bool:
	return latest_save() != null


func load_from_save(d: Dictionary) -> void:
	difficulty = int(d.get("difficulty", 1))
	inventory = _fix_inventory(d.get("inventory", new_inventory()))
	total_stats = d.get("total_stats", total_stats)
	var lvl := int(d.get("level", 0))
	var st = d.get("level_state", null)
	if st == null:
		start_level(lvl)
	else:
		level_start_inventory = _fix_inventory(d.get("level_start_inventory", inventory))
		start_level(lvl, st)


func _fix_inventory(inv: Dictionary) -> Dictionary:
	# JSON turns ints into floats; normalise
	var out := new_inventory()
	for k in inv.keys():
		out[k] = inv[k]
	for k in ["health", "armor", "armor_type"]:
		out[k] = int(out[k])
	var ammo := {}
	for k in out["ammo"].keys():
		ammo[k] = int(out["ammo"][k])
	out["ammo"] = ammo
	var mags := {}
	for k in out["mags"].keys():
		mags[k] = int(out["mags"][k])
	out["mags"] = mags
	var w := []
	for x in out["weapons"]:
		w.append(str(x))
	out["weapons"] = w
	return out


func format_time(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]
