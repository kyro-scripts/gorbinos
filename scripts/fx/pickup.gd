class_name Pickup
extends Node3D
## Rotating, bobbing collectible. The player decides whether it can be taken.

const INFO := {
	"juice": {"msg": "+10 HEALTH", "snd": "pickup_health", "item": true},
	"medkit": {"msg": "+25 HEALTH", "snd": "pickup_health", "item": true},
	"mega": {"msg": "+100 HEALTH", "snd": "pickup_mega", "item": true},
	"armor_bonus": {"msg": "+5 ARMOR", "snd": "pickup_armor", "item": true},
	"armor_green": {"msg": "ARMOR", "snd": "pickup_armor", "item": true},
	"armor_blue": {"msg": "HEAVY ARMOR", "snd": "pickup_armor", "item": true},
	"bullets": {"msg": "BULLETS", "snd": "pickup_ammo", "item": false},
	"bullets_box": {"msg": "BOX OF BULLETS", "snd": "pickup_ammo", "item": false},
	"shells": {"msg": "SHELLS", "snd": "pickup_ammo", "item": false},
	"shells_box": {"msg": "BOX OF SHELLS", "snd": "pickup_ammo", "item": false},
	"rocket": {"msg": "ROCKET", "snd": "pickup_ammo", "item": false},
	"rockets_box": {"msg": "BOX OF ROCKETS", "snd": "pickup_ammo", "item": false},
	"cells": {"msg": "CELLS", "snd": "pickup_ammo", "item": false},
	"cells_box": {"msg": "CELL PACK", "snd": "pickup_ammo", "item": false},
	"backpack": {"msg": "BACKPACK", "snd": "pickup_weapon", "item": true},
	"w_shotgun": {"msg": "SHOTGUN", "snd": "pickup_weapon", "item": false},
	"w_ssg": {"msg": "DOUBLE SHOTGUN", "snd": "pickup_weapon", "item": false},
	"w_mg": {"msg": "MACHINE GUN", "snd": "pickup_weapon", "item": false},
	"w_rocket": {"msg": "ROCKET LAUNCHER", "snd": "pickup_weapon", "item": false},
	"w_plasma": {"msg": "PLASMA RIFLE", "snd": "pickup_weapon", "item": false},
	"key_red": {"msg": "RED KEYCARD", "snd": "pickup_key", "item": false},
	"key_blue": {"msg": "BLUE KEYCARD", "snd": "pickup_key", "item": false},
	"key_yellow": {"msg": "YELLOW KEYCARD", "snd": "pickup_key", "item": false},
}

const AMMO := ["bullets", "bullets_box", "shells", "shells_box", "rocket", "rockets_box", "cells", "cells_box"]

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
	if t in AMMO:
		# small real objects: blown up so they read from across a room
		model.scale = Vector3.ONE * (2.0 if t in ["bullets", "shells", "cells"] else 1.5)
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
