class_name Mover
extends AnimatableBody3D
## A textured block occupying one grid cell that moves vertically.
## kind: "door" (rises into the ceiling), "lower" (sinks into the floor when
## its tag fires), "lift" (sinks, waits, rises back).

var kind := "door"
var cell := Vector2i.ZERO
var key := ""            # required key colour for doors
var tag := 0             # remote trigger tag (0 = none)
var secret := false
var remote := false      # cannot be opened by "use", only by a trigger
var y_closed := 0.0      # body origin y when closed / raised
var travel := 2.0        # distance moved
var speed := 3.2
var state := 0           # 0 closed/raised, 1 opening, 2 open/lowered, 3 closing
var t := 0.0             # 0..1 position along travel
var wait := 0.0
var level: Node = null
var bottom := 0.0        # world y of block bottom when closed
var top := 0.0           # world y of block top when closed
var _snd_cool := 0.0


func setup(p_level: Node, p_kind: String, p_cell: Vector2i, y0: float, y1: float, side_tex: String, top_tex: String, size: float, light_tex := "") -> void:
	level = p_level
	kind = p_kind
	cell = p_cell
	bottom = y0
	top = y1
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = false
	var h := maxf(y1 - y0, 0.05)
	travel = h if kind == "door" else h
	var mi := MeshInstance3D.new()
	var vb := -y0 / 2.0
	var vt := -y1 / 2.0
	if kind == "door" and not secret:
		vb = 1.0
		vt = 0.0
	mi.mesh = _box_mesh(size, h, side_tex, top_tex, vb, vt)
	add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size, h, size)
	cs.shape = bs
	cs.position = Vector3(0, h * 0.5, 0)
	add_child(cs)
	position = Vector3((cell.x + 0.5) * size, y0, (cell.y + 0.5) * size)
	y_closed = y0


func _box_mesh(s: float, h: float, side_tex: String, top_tex: String, vb: float, vt: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hs := s * 0.5
	# four sides; UV world-aligned (2m per texture)
	var sides := [
		[Vector3(-hs, 0, hs), Vector3(hs, 0, hs), Vector3(0, 0, 1)],
		[Vector3(hs, 0, -hs), Vector3(-hs, 0, -hs), Vector3(0, 0, -1)],
		[Vector3(hs, 0, hs), Vector3(hs, 0, -hs), Vector3(1, 0, 0)],
		[Vector3(-hs, 0, -hs), Vector3(-hs, 0, hs), Vector3(-1, 0, 0)],
	]
	for sd in sides:
		var a: Vector3 = sd[0]
		var b: Vector3 = sd[1]
		var n: Vector3 = sd[2]
		var w := s / 2.0
		var quad := [a, b, b + Vector3(0, h, 0), a + Vector3(0, h, 0)]
		var uvs := [Vector2(0, vb), Vector2(w, vb), Vector2(w, vt), Vector2(0, vt)]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(n)
			st.set_uv(uvs[idx])
			st.add_vertex(quad[idx])
	var mesh := st.commit()
	mesh.surface_set_material(0, Mat.world(side_tex))
	# top and bottom
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tq := [Vector3(-hs, h, -hs), Vector3(hs, h, -hs), Vector3(hs, h, hs), Vector3(-hs, h, hs)]
	var tu := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for idx in [0, 1, 2, 0, 2, 3]:
		st2.set_normal(Vector3.UP)
		st2.set_uv(tu[idx])
		st2.add_vertex(tq[idx])
	var bq := [Vector3(-hs, 0, -hs), Vector3(hs, 0, -hs), Vector3(hs, 0, hs), Vector3(-hs, 0, hs)]
	for idx in [0, 2, 1, 0, 3, 2]:
		st2.set_normal(Vector3.DOWN)
		st2.set_uv(tu[idx])
		st2.add_vertex(bq[idx])
	st2.commit(mesh)
	mesh.surface_set_material(1, Mat.world(top_tex))
	return mesh


func is_open() -> bool:
	if kind == "door":
		return state == 2 or (state == 1 and t > 0.85)
	return true


func is_closed_door() -> bool:
	return kind == "door" and not is_open()


func current_top() -> float:
	if kind == "door":
		return top
	return top - travel * t


## Called when the player presses use on it / bumps it. Returns message or "".
func try_use(user: Node) -> String:
	if remote:
		return ""
	if kind == "lift":
		if state == 0:
			_start(1)
		return ""
	if kind != "door":
		return ""
	if state == 2 or state == 1:
		return ""
	if key != "":
		if user == null or not user.has_method("has_key") or not user.has_key(key):
			if _snd_cool <= 0.0:
				Audio.play_at("door_locked", global_position + Vector3(0, 1, 0))
				_snd_cool = 0.6
			return "YOU NEED THE %s KEYCARD" % key.to_upper()
	_start(1)
	return ""


## enemies may open plain doors
func can_monster_open() -> bool:
	return kind == "door" and key == "" and not secret and not remote


func trigger() -> void:
	if state == 0:
		_start(1)


func _start(s: int) -> void:
	state = s
	if kind == "lift" and s == 1:
		wait = 2.5
	Audio.play_at("door_open", global_position + Vector3(0, 1.0, 0), -2.0, 0.9 if kind != "door" else 1.0)
	if secret and level and level.has_method("on_secret_door"):
		level.on_secret_door(self)


func _physics_process(delta: float) -> void:
	_snd_cool -= delta
	var target_t := t
	match state:
		1:
			t = minf(1.0, t + delta * speed / maxf(travel, 0.1))
			if t >= 1.0:
				state = 2
				if kind == "lift":
					wait = 2.5
		2:
			if kind == "lift":
				wait -= delta
				if wait <= 0.0:
					state = 3
					Audio.play_at("door_open", global_position + Vector3(0, 1.0, 0), -4.0, 0.8)
		3:
			# only lifts return
			t = maxf(0.0, t - delta * speed / maxf(travel, 0.1))
			if t <= 0.0:
				state = 0
	if target_t != t:
		var dir := 1.0 if kind == "door" else -1.0
		position.y = y_closed + dir * travel * t


func serialize() -> Dictionary:
	return {"s": state, "t": t}


func restore(d: Dictionary) -> void:
	state = int(d.get("s", 0))
	t = float(d.get("t", 0.0))
	if state == 1:
		state = 2
		t = 1.0
	if kind == "lift":
		state = 0
		t = 0.0
	var dir := 1.0 if kind == "door" else -1.0
	position.y = y_closed + dir * travel * t
