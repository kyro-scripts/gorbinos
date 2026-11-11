class_name MenuBackdrop
extends Control
## Behind the menus: murky deep water with light rippling through it. Over
## a paused game it's a see-through wash of the same water.

var opaque := true
var _rect: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/menu_water.gdshader")
	m.set_shader_parameter("opacity", 1.0 if opaque else 0.82)
	_rect.material = m
	add_child(_rect)
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	if _rect and size.y > 0.0:
		(_rect.material as ShaderMaterial).set_shader_parameter("aspect", Vector2(size.x / size.y, 1.0))
