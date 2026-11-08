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

## which ammo a pickup gives, and the colour it glows in the world and on the HUD
const AMMO_KIND := {"bullets": "bullets", "bullets_box": "bullets", "shells": "shells", "shells_box": "shells",
	"rocket": "rockets", "rockets_box": "rockets", "cells": "cells", "cells_box": "cells", "backpack": "all"}
const AMMO_COLOR := {"bullets": Color(1.0, 0.82, 0.2), "shells": Color(1.0, 0.32, 0.2),
	"rockets": Color(0.45, 1.0, 0.3), "cells": Color(0.3, 0.9, 1.0), "all": Color(1, 1, 1)}

var ptype := ""
var spawn_id := -1
var dropped := false
var counts_as_item := false
var model: Node3D
var _t := 0.0
var _base_y := 0.0
var _ring: Node3D
var _marker: Node3D


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
	if AMMO_KIND.has(t):
		_add_beacon(AMMO_COLOR[AMMO_KIND[t]])


## Ammo is hard to miss: bigger, a glowing ring on the floor and a
## spinning diamond over it, in the ammo's HUD colour.
func _add_beacon(c: Color) -> void:
	model.scale = Vector3.ONE * 1.5
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.1, 1.1)
	_ring = Models.mi(pm, Mat.make("beacon", {"tint": c, "fullbright": 1.0, "alpha_cut": 0.3}), Vector3(0, 0.035, 0))
	add_child(_ring)
	_marker = Models.pivot(Vector3(0, 1.0, 0))
	add_child(_marker)
	var mm := Mat.make("white", {"tint": c, "fullbright": 1.0})
	_marker.add_child(Models.mi(Models.cyl(0.0, 0.1, 0.14, 4), mm, Vector3(0, -0.07, 0), Vector3(180, 0, 0)))
	_marker.add_child(Models.mi(Models.cyl(0.0, 0.1, 0.08, 4), mm, Vector3(0, 0.04, 0)))


func message() -> String:
	return INFO.get(ptype, {}).get("msg", ptype.to_upper())


func sound() -> String:
	return INFO.get(ptype, {}).get("snd", "pickup_item")


func _process(delta: float) -> void:
	_t += delta
	model.rotation.y = _t * 2.0
	model.position.y = _base_y + sin(_t * 3.0) * 0.08
	if _ring:
		_ring.scale = Vector3.ONE * (1.0 + 0.12 * sin(_t * 4.0))
		_marker.position.y = 1.0 + sin(_t * 3.0) * 0.07
		_marker.rotation.y = _t * 3.0


func collected() -> void:
	queue_free()
