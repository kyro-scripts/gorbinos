class_name Collage
extends RefCounted
## The FISH x Cruelty Squad look: creatures and pickups snipped out of a
## magazine with a white paper border, and ransom-note stickers slapped over
## the action when things die. Everything here switches off with the
## COLLAGE FX option.

const STICKERS := ["stk_splort", "stk_gorb", "stk_blammo", "stk_squelch", "stk_byebye", "stk_oops", "stk_meat",
	"stk_lol", "stk_yum", "stk_pop", "stk_dead", "stk_wow"]
const BURSTS := ["stk_burst_0", "stk_burst_1", "stk_burst_2"]

static var _outline: ShaderMaterial
static var _outline_vm: ShaderMaterial
static var _tex := {}


static func enabled() -> bool:
	return bool(Settings.get_v("collage"))


static func outline_mat() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = load("res://shaders/outline.gdshader")
	return _outline


## A thinner border for the gun and knife arm, which sit right in front of
## the camera.
static func outline_mat_vm() -> ShaderMaterial:
	if _outline_vm == null:
		_outline_vm = ShaderMaterial.new()
		_outline_vm.shader = load("res://shaders/outline.gdshader")
		_outline_vm.set_shader_parameter("width", 0.0012)
		_outline_vm.set_shader_parameter("px_width", 0.009)
	return _outline_vm


## Give every sizeable mesh under root a paper cut-out border (or take it
## away again when the option is off).
static func outline(root: Node, on := true) -> void:
	var m: Material = outline_mat() if on and enabled() else null
	_outline_rec(root, m)


static func outline_viewmodel(root: Node) -> void:
	var m: Material = outline_mat_vm() if enabled() else null
	_outline_rec(root, m, 0.0)


## A cut-out burst (no word) over an explosion.
static func burst(level: Node, pos: Vector3) -> void:
	if not enabled() or level == null or level.world == null:
		return
	level.world.hud.sticker(texture(BURSTS[randi() % BURSTS.size()]), null, pos, true)


static func _outline_rec(n: Node, m: Material, min_size := 0.1) -> void:
	if n.has_meta("no_outline"):
		return
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			var sz := mi.mesh.get_aabb().size * mi.scale
			if maxf(sz.x, maxf(sz.y, sz.z)) > min_size:
				mi.material_overlay = m
	for c in n.get_children():
		_outline_rec(c, m, min_size)


static func _texture(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load("res://assets/sprites/%s.png" % name)
	return _tex[name]


## A ransom-note word (and sometimes a burst behind it) slapped onto the
## screen over a 3D position. Drawn by the HUD at full resolution, so the
## cut-out letters stay crisp over the crunchy world.
static func sticker(level: Node, pos: Vector3, big := false) -> void:
	if not enabled() or level == null or level.world == null:
		return
	var burst: Texture2D = null
	if randf() < 0.3:
		burst = Hyper.sticker_tex()          # a photo cut-out behind the word
	elif big or randf() < 0.45:
		burst = texture(BURSTS[randi() % BURSTS.size()])
	level.world.hud.sticker(texture(STICKERS[randi() % STICKERS.size()]), burst, pos, big)


static func texture(name: String) -> Texture2D:
	return _texture(name)


static func _sprite(t: Texture2D, px: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = t
	s.pixel_size = px
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.no_depth_test = true
	s.shaded = false
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	return s
