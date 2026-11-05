class_name AnimSprite
extends Node3D
## Plays a horizontal sprite strip once, then frees itself.

var sprite: Sprite3D
var fps := 15.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta * fps
	var f := int(_t)
	if sprite == null or f >= sprite.hframes:
		queue_free()
		return
	sprite.frame = f
