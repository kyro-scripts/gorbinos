class_name Pickup
extends Node3D
## Rotating, bobbing collectible. The player decides whether it can be taken.

const INFO := {
	"juice": {"msg": "GORB JUICE (+10 HEALTH)", "snd": "pickup_health", "item": true},
	"medkit": {"msg": "MEDIGORB KIT (+25 HEALTH)", "snd": "pickup_health", "item": true},
	"mega": {"msg": "THE GORB ORB! (+100 HEALTH)", "snd": "pickup_mega", "item": true},
	"armor_bonus": {"msg": "ARMOR SHARD (+5)", "snd": "pickup_armor", "item": true},
	"armor_green": {"msg": "HAZMAT VEST (100 ARMOR)", "snd": "pickup_armor", "item": true},
	"armor_blue": {"msg": "EXECUTIVE PLATE (200 ARMOR)", "snd": "pickup_armor", "item": true},
	"bullets": {"msg": "A CLIP OF BULLETS", "snd": "pickup_ammo", "item": false},
	"bullets_box": {"msg": "A BOX OF BULLETS", "snd": "pickup_ammo", "item": false},
	"shells": {"msg": "SOME SHELLS", "snd": "pickup_ammo", "item": false},
	"shells_box": {"msg": "A BOX OF SHELLS", "snd": "pickup_ammo", "item": false},
	"rocket": {"msg": "A ROCKET", "snd": "pickup_ammo", "item": false},
	"rockets_box": {"msg": "A CRATE OF ROCKETS", "snd": "pickup_ammo", "item": false},
	"cells": {"msg": "A SNIRB CELL", "snd": "pickup_ammo", "item": false},
	"cells_box": {"msg": "A SNIRB CELL PACK", "snd": "pickup_ammo", "item": false},
	"backpack": {"msg": "A BACKPACK FULL OF AMMO!", "snd": "pickup_weapon", "item": true},
	"w_shotgun": {"msg": "YOU GOT THE PUMPER SHOTGUN!", "snd": "pickup_weapon", "item": false},
	"w_ssg": {"msg": "YOU GOT THE GORBINATOR DOUBLE SHOTGUN!", "snd": "pickup_weapon", "item": false},
	"w_mg": {"msg": "YOU GOT THE GORB-O-MATIC MACHINE GUN!", "snd": "pickup_weapon", "item": false},
	"w_rocket": {"msg": "YOU GOT THE GORB-POPPER ROCKET LAUNCHER!", "snd": "pickup_weapon", "item": false},
	"w_plasma": {"msg": "YOU GOT THE SNIRB-O-TRON PLASMA RIFLE!", "snd": "pickup_weapon", "item": false},
	"key_red": {"msg": "PICKED UP THE RED KEYCARD", "snd": "pickup_key", "item": false},
	"key_blue": {"msg": "PICKED UP THE BLUE KEYCARD", "snd": "pickup_key", "item": false},
	"key_yellow": {"msg": "PICKED UP THE YELLOW KEYCARD", "snd": "pickup_key", "item": false},
}

var ptype := ""
var spawn_id := -1
var dropped := false
var counts_as_item := false
var model: Node3D
var _t := 0.0
var _base_y := 0.0


func setup(t: String, pos: Vector3) -> void:
	ptype = t
	counts_as_item = INFO.get(t, {}).get("item", false) and spawn_id >= 0
	model = Models.pickup(t)
	add_child(model)
	global_position = pos
	_base_y = 0.05
	_t = randf() * 10.0
	if t.begins_with("key_"):
		var c: Color = {"key_red": Color(1, 0.2, 0.2), "key_blue": Color(0.3, 0.5, 1), "key_yellow": Color(1, 0.9, 0.2)}[t]
		Fx.light(get_parent().get_parent(), pos + Vector3(0, 0.6, 0), c, 3.5, 1.0, -1.0, self)
	elif t == "mega":
		Fx.light(get_parent().get_parent(), pos + Vector3(0, 0.6, 0), Color(1, 0.3, 0.9), 4.0, 1.2, -1.0, self)


func message() -> String:
	return INFO.get(ptype, {}).get("msg", ptype.to_upper())


func sound() -> String:
	return INFO.get(ptype, {}).get("snd", "pickup_item")


func _process(delta: float) -> void:
	_t += delta
	model.rotation.y = _t * 2.0
	model.position.y = _base_y + sin(_t * 3.0) * 0.08


func collected() -> void:
	queue_free()
