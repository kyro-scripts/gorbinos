class_name PixelLayer
extends SubViewportContainer
## Draws whatever is put in it at the game's low HUD resolution and scales
## it up in chunky pixels, through the same cheap-print look as the game
## (plates off register, dithered colour, grain), so the menus look like
## part of the game rather than pasted over it.

var vp: SubViewport
var _mat: ShaderMaterial


func _init() -> void:
	stretch = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.handle_input_locally = true
	vp.gui_snap_controls_to_pixels = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/ui_print.gdshader")
	material = _mat


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	Settings.changed.connect(_apply)
	resized.connect(_apply)
	_apply()


func add(n: Node) -> void:
	vp.add_child(n)


func _apply() -> void:
	_mat.set_shader_parameter("src_size", Vector2(maxi(vp.size.x, 1), maxi(vp.size.y, 1)))
	_mat.set_shader_parameter("levels", Settings.color_levels())
	_mat.set_shader_parameter("zine", 1.0 if Collage.enabled() else 0.0)
