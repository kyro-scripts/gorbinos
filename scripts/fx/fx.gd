class_name Fx
extends RefCounted
## Visual effects: animated sprites, explosions, blood, gibs, decals and
## the dynamic light registry fed to the world shader.

const MAX_DECALS := 90
const MAX_GIBS := 70

static var _next_light := 0


static func make_sprite(tname: String, size: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = Mat.tex(tname)
	s.hframes = Mat.sprite_frames(tname)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.pixel_size = size / float(s.texture.get_height())
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return s


## Plays an animated sprite strip once at pos.
static func anim(level: Node, tname: String, pos: Vector3, size: float, fps: float) -> Node3D:
	if level == null:
		return null
	var s := make_sprite(tname, size)
	var holder := AnimSprite.new()
	holder.sprite = s
	holder.fps = fps
	holder.add_child(s)
	level.fx_root().add_child(holder)
	holder.global_position = pos
	return holder


static func explosion(level: Node, pos: Vector3, big := true) -> void:
	anim(level, "explosion", pos, 3.6 if big else 2.4, 16.0)
	light(level, pos, Color(1.0, 0.55, 0.15), 9.0 if big else 6.0, 2.2, 0.35)
	Audio.play_at("explosion", pos, 3.0 if big else 0.0, randf_range(0.9, 1.1))
	debris(level, pos, Color(0.25, 0.2, 0.18), 8)
	if level.player and is_instance_valid(level.player):
		var d: float = level.player.global_position.distance_to(pos)
		level.player.shake(clampf(1.0 - d / 18.0, 0.0, 1.0) * (0.6 if big else 0.35))


static func puff(level: Node, pos: Vector3, normal: Vector3) -> void:
	anim(level, "puff", pos + normal * 0.08, 0.5, 20.0)
	anim(level, "spark", pos + normal * 0.05, 0.35, 24.0)
	decal(level, pos, normal, "bullethole", 0.22, Color(1, 1, 1))
	if randf() < 0.25:
		Audio.play_at("ricochet", pos, -10.0, randf_range(0.8, 1.3))
	else:
		Audio.play_at("hit_wall", pos, -8.0, randf_range(0.8, 1.2))


static func smoke(level: Node, pos: Vector3) -> void:
	anim(level, "puff", pos, 0.6, 12.0)


static func telefog(level: Node, pos: Vector3) -> void:
	anim(level, "telefog", pos, 2.6, 14.0)
	light(level, pos, Color(0.3, 1.0, 0.8), 6.0, 1.6, 0.4)


## Spurt of coloured chunks (blood). Gorbinos bleed orange goo, Snirbies blue.
static func blood(level: Node, pos: Vector3, color: Color, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(amount * 2, 4)
	p.lifetime = 0.7
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -16, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.09)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = mat
	p.mesh = qm
	level.fx_root().add_child(p)
	p.global_position = pos
	p.emitting = true
	var t := level.get_tree().create_timer(1.2)
	t.timeout.connect(p.queue_free)
	# floor splat under the hit
	var hit: Dictionary = level.ray(pos, pos + Vector3(randf_range(-0.6, 0.6), -4.0, randf_range(-0.6, 0.6)), 1)
	if not hit.is_empty() and randf() < 0.7:
		decal(level, hit["position"], hit["normal"], "splat", randf_range(0.6, 1.2), color.darkened(0.15))


static func gibs(level: Node, pos: Vector3, skin: Color, goo: Color, n: int) -> void:
	blood(level, pos, goo, 14)
	for k in n:
		var g := Gib.new()
		var sz := randf_range(0.12, 0.3)
		var mat := Mat.make("gorbino_skin", {"tint": skin if k % 3 != 0 else goo, "origin": true})
		g.add_child(Models.mi(Models.box(sz, sz * randf_range(0.6, 1.2), sz), mat))
		level.fx_root().add_child(g)
		g.global_position = pos + Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.4), randf_range(-0.3, 0.3))
		g.vel = Vector3(randf_range(-5, 5), randf_range(3, 8), randf_range(-5, 5))
		g.spin = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
		g.level = level
		g.add_to_group("gibs")
	var all := level.get_tree().get_nodes_in_group("gibs")
	if all.size() > MAX_GIBS:
		for k in all.size() - MAX_GIBS:
			all[k].queue_free()


static func debris(level: Node, pos: Vector3, color: Color, n: int) -> void:
	for k in n:
		var g := Gib.new()
		var sz := randf_range(0.05, 0.12)
		g.add_child(Models.mi(Models.box(sz, sz, sz), Mat.world("white", {"tint": color, "origin": true})))
		level.fx_root().add_child(g)
		g.global_position = pos
		g.vel = Vector3(randf_range(-7, 7), randf_range(2, 9), randf_range(-7, 7))
		g.spin = Vector3(randf_range(-15, 15), randf_range(-15, 15), 0)
		g.level = level
		g.life = randf_range(0.8, 1.6)


static func decal(level: Node, pos: Vector3, normal: Vector3, tname: String, size: float, color: Color) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	m.mesh = q
	var frames := Mat.sprite_frames(tname)
	var mat := Mat.make(tname, {"tint": color, "alpha_cut": 0.5, "uv": Vector2(1.0 / frames, 1.0)})
	if frames > 1:
		mat.set_shader_parameter("scroll", Vector2.ZERO)
		# pick a random frame via uv offset: emulate with a separate uv shift
		mat.set_shader_parameter("uv_scale", Vector2(1.0 / frames, 1.0))
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.fx_root().add_child(m)
	m.add_to_group("decals")
	var n := normal.normalized()
	m.global_position = pos + n * (0.012 + randf() * 0.006)
	var up := Vector3.UP if abs(n.y) < 0.95 else Vector3.FORWARD
	m.look_at(m.global_position - n, up)
	m.rotate_object_local(Vector3.FORWARD, randf() * TAU)
	var all := level.get_tree().get_nodes_in_group("decals")
	if all.size() > MAX_DECALS:
		all[0].queue_free()


# ------------------------------------------------------------------ dynamic lights
## Registers a light; ttl < 0 means it lives until removed / follow node dies.
static func light(level: Node, pos: Vector3, color: Color, radius: float, energy: float, ttl: float, follow: Node = null) -> int:
	if level == null or not ("dyn_lights" in level):
		return -1
	_next_light += 1
	level.dyn_lights.append({"id": _next_light, "pos": pos, "color": color, "radius": radius, "energy": energy,
		"ttl": ttl, "max_ttl": ttl, "follow": follow})
	return _next_light


static func remove_light(level: Node, id: int) -> void:
	if level == null or not ("dyn_lights" in level):
		return
	for k in range(level.dyn_lights.size() - 1, -1, -1):
		if level.dyn_lights[k]["id"] == id:
			level.dyn_lights.remove_at(k)


static func update_lights(level: Node, cam_pos: Vector3, delta: float) -> void:
	var arr: Array = level.dyn_lights
	for k in range(arr.size() - 1, -1, -1):
		var L: Dictionary = arr[k]
		var f = L["follow"]
		if f != null:
			if not is_instance_valid(f) or not f.is_inside_tree():
				arr.remove_at(k)
				continue
			L["pos"] = f.global_position
		if float(L["ttl"]) >= 0.0:
			L["ttl"] = float(L["ttl"]) - delta
			if float(L["ttl"]) <= 0.0:
				arr.remove_at(k)
	var scored := []
	for L in arr:
		var d := cam_pos.distance_to(L["pos"])
		if d > 45.0:
			continue
		scored.append([float(L["energy"]) * float(L["radius"]) / (1.0 + d), L])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	for i in 6:
		var pn := "dl_p%d" % i
		var cn := "dl_c%d" % i
		if i < scored.size():
			var L: Dictionary = scored[i][1]
			var e := float(L["energy"])
			if float(L["max_ttl"]) > 0.0:
				e *= clampf(float(L["ttl"]) / float(L["max_ttl"]) * 1.5, 0.0, 1.0)
			var p: Vector3 = L["pos"]
			var c: Color = L["color"]
			RenderingServer.global_shader_parameter_set(pn, Vector4(p.x, p.y, p.z, float(L["radius"])))
			RenderingServer.global_shader_parameter_set(cn, Vector4(c.r, c.g, c.b, e))
		else:
			RenderingServer.global_shader_parameter_set(pn, Vector4(0, -1000, 0, 0.001))
			RenderingServer.global_shader_parameter_set(cn, Vector4(0, 0, 0, 0))
