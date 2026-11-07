class_name Mat
extends RefCounted
## Texture and material cache. Every world surface uses shaders/world.gdshader.

static var _tex := {}
static var _mats := {}
static var _shader: Shader = null


static func shader() -> Shader:
	if _shader == null:
		_shader = load("res://shaders/world.gdshader")
	return _shader


static func tex(tname: String) -> Texture2D:
	if _tex.has(tname):
		return _tex[tname]
	var t: Texture2D = null
	for dir in ["textures", "sprites", "ui"]:
		var p := "res://assets/%s/%s.png" % [dir, tname]
		if ResourceLoader.exists(p):
			t = load(p)
			break
	if t == null:
		push_warning("missing texture: " + tname)
		t = load("res://assets/textures/white.png")
	_tex[tname] = t
	return t


## opts: tint (Color), fullbright (float), scroll (Vector2), origin (bool),
## wobble (float), cull (String "back"/"disabled"), alpha_cut (float), uv (Vector2)
static func world(tname: String, opts := {}) -> ShaderMaterial:
	var key := tname + str(opts)
	if _mats.has(key):
		return _mats[key]
	var m := make(tname, opts)
	_mats[key] = m
	return m


static func make(tname: String, opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader()
	m.set_shader_parameter("tex", tex(tname))
	if opts.has("tint"):
		m.set_shader_parameter("tint", opts["tint"])
	if opts.has("fullbright"):
		m.set_shader_parameter("fullbright", float(opts["fullbright"]))
	if opts.has("scroll"):
		m.set_shader_parameter("scroll", opts["scroll"])
	if opts.get("origin", false):
		m.set_shader_parameter("origin_light", 1.0)
	if opts.has("wobble"):
		m.set_shader_parameter("wobble", float(opts["wobble"]))
	if opts.has("alpha_cut"):
		m.set_shader_parameter("alpha_cut", float(opts["alpha_cut"]))
	if opts.has("uv"):
		m.set_shader_parameter("uv_scale", opts["uv"])
	if opts.has("shade"):
		m.set_shader_parameter("shade", float(opts["shade"]))
	if opts.has("gloss"):
		m.set_shader_parameter("gloss", float(opts["gloss"]))
	return m


static func sprite_frames(tname: String) -> int:
	var t := tex(tname)
	return maxi(1, int(round(float(t.get_width()) / float(t.get_height()))))
