extends Node3D
## Slowly spins a child node (checkpoint heads, exit signs).

var spin_node: Node3D
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if spin_node:
		spin_node.rotation.y = _t * 1.5
		spin_node.position.y = (spin_node.position.y * 0.0) + (1.4 if spin_node.scale.x < 0.5 else 2.2) + sin(_t * 2.0) * 0.08
