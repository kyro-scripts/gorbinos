extends Node
## Test bot: plays a level through the real player physics. It paths over the
## grid to keys, switches and the exit, opens doors, rides lifts, jumps up
## ledges and shoots visible enemies. Used for automated playthrough tests:
##   godot --headless --fixed-fps 120 --path . -- --autoplay

var gw: Node
var level: Level
var player: Player
var want_fire := false
var path: Array = []
var goal := -1
var goal_kind := ""
var replan_t := 0.0
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var use_t := 0.0
var level_time := 0.0
var target_enemy: Node = null
var scan_t := 0.0
var failed_goals := {}
var log_t := 0.0
var strafe_t := 0.0
var strafe := 0.0


func setup(p_gw: Node) -> void:
	gw = p_gw
	level = gw.level
	player = gw.player
	player.autopilot = self
	Game.cheats["god"] = true


var _shot_t := 3.0
var _shot_n := 0


func _physics_process(delta: float) -> void:
	if player == null or player.dead or level.finished:
		return
	level_time += delta
	if OS.get_cmdline_user_args().has("--botshots"):
		_shot_t -= delta
		if _shot_t <= 0.0 and _shot_n < 30:
			_shot_t = 2.0
			_shot_n += 1
			DirAccess.make_dir_recursive_absolute("user://shots")
			get_viewport().get_texture().get_image().save_png("user://shots/bot_%02d.png" % _shot_n)
	log_t -= delta
	if log_t <= 0.0:
		log_t = 10.0
		print("[bot] t=%.0f pos=%s cell=%s goal=%s(%s) kills=%d/%d keys=%s" % [level_time, player.global_position.snapped(Vector3.ONE * 0.1),
			level.cell_of(player.global_position), goal_kind, goal, level.stats["kills"], level.stats["kills_total"], player.keys.keys()])
	if level_time > 900.0:
		print("[bot] TIMEOUT on level ", level.data.get("name"))
		get_tree().quit(2)
		return
	_combat(delta)
	# test harness only: the bot never hunts for ammo, so keep it topped up
	if int(level_time) % 5 == 0:
		for t in ["bullets", "shells", "rockets", "cells"]:
			if int(player.weapons.ammo[t]) < 20:
				player.weapons.give_ammo(t, 20)
		if not player.weapons.owned.has("shotgun"):
			player.weapons.owned.append("shotgun")
			player.weapons.mags["shotgun"] = 6
	replan_t -= delta
	if replan_t <= 0.0 or path.is_empty():
		replan_t = 0.4
		_plan()
	_steer(delta)
	_unstick(delta)


func _tags() -> Dictionary:
	var t := {}
	for tag in level.tagged.keys():
		for m in level.tagged[tag]:
			if m.state != 0:
				t[tag] = true
	if level.boss == null or level.boss.dead:
		t[99] = t.get(99, false) or level.boss == null
	return t


func _plan() -> void:
	var start := level.idx_of(level.cell_of(player.global_position))
	if start < 0:
		return
	var keys := player.keys
	var tags := _tags()
	var prev := {start: -1}
	var q := [start]
	var key_goal := -1
	var switch_goal := -1
	var switch_face := -1
	var exit_goal := -1
	var exit_face := -1
	var boss_alive: bool = level.boss != null and is_instance_valid(level.boss) and not level.boss.dead
	var key_cells := {}
	for pk in level.pickups:
		if is_instance_valid(pk) and pk.ptype.begins_with("key_"):
			key_cells[level.idx_of(level.cell_of(pk.global_position))] = true
	while q.size() > 0:
		var c: int = q.pop_front()
		if key_cells.has(c) and key_goal < 0 and not failed_goals.has(c):
			key_goal = c
		if level.exit_cells.has(c) and exit_goal < 0 and not boss_alive:
			exit_goal = c
		if level.teleports.has(c):
			var dst := level.idx_of(level.cell_of(level.teleports[c]))
			if not prev.has(dst):
				prev[dst] = c
				q.append(dst)
		var cx := c % level.W
		var cz := c / level.W
		for dv in Level.DIRS4:
			var n := level._idx(cx + dv.x, cz + dv.y)
			if n < 0 or prev.has(n):
				continue
			if level.use_cells.has(n):
				var u: Dictionary = level.use_cells[n]
				if not u["used"]:
					if u["use"] == "exit" and exit_goal < 0 and not boss_alive:
						exit_goal = c
						exit_face = n
					elif u["use"] == "switch" and switch_goal < 0 and not failed_goals.has(n):
						switch_goal = c
						switch_face = n
				continue
			if level.player_can_traverse(c, n, keys, tags):
				prev[n] = c
				q.append(n)
	var g := -1
	if exit_goal >= 0:
		g = exit_goal
		goal_kind = "exit"
		goal = exit_face if exit_face >= 0 else exit_goal
	elif key_goal >= 0:
		g = key_goal
		goal_kind = "key"
		goal = g
	elif switch_goal >= 0:
		g = switch_goal
		goal_kind = "switch"
		goal = switch_face
	elif boss_alive:
		g = level.idx_of(level.cell_of(level.boss.global_position))
		goal_kind = "boss"
		goal = g
		if not prev.has(g):
			g = -1
	if g < 0:
		goal_kind = "explore"
		path = []
		return
	path = []
	var c2 := g
	while c2 != -1:
		path.push_front(c2)
		c2 = prev.get(c2, -1)


func _steer(delta: float) -> void:
	player.auto_input = Vector2.ZERO
	player.auto_sprint = true
	if path.size() == 0:
		return
	var here := level.idx_of(level.cell_of(player.global_position))
	while path.size() > 1 and path[0] != here and path.find(here) > 0:
		path.pop_front()
	if path.size() > 0 and path[0] == here:
		path.pop_front()
	if path.is_empty():
		_at_goal()
		return
	var nxt: int = path[0]
	var tp := level.cell_center(Vector2i(nxt % level.W, nxt / level.W))
	# look ahead along straight segments
	if path.size() > 1:
		var n2: int = path[1]
		var tp2 := level.cell_center(Vector2i(n2 % level.W, n2 / level.W))
		if absf(tp2.y - tp.y) < 0.3 and level.has_los(player.eye_point(), tp2 + Vector3(0, 1.2, 0)):
			tp = tp.lerp(tp2, 0.5)
	var to := tp - player.global_position
	to.y = 0
	var want_yaw := atan2(-to.x, -to.z)
	if target_enemy == null:
		player.yaw = lerp_angle(player.yaw, want_yaw, clampf(delta * 8.0, 0.0, 1.0))
		player.pitch = lerpf(player.pitch, 0.0, clampf(delta * 4.0, 0.0, 1.0))
	# move relative to current yaw
	var local := to.normalized().rotated(Vector3.UP, -player.yaw)
	player.auto_input = Vector2(local.x, local.z).limit_length(1.0)
	var here_floor := player.global_position.y
	var nf := level.eff_floor(nxt)
	# doors / lifts
	if level.movers.has(nxt):
		var m: Mover = level.movers[nxt]
		if m.kind == "door" and not m.is_open():
			if to.length() < 2.6:
				_face_and_use(tp + Vector3(0, 1, 0))
				player.auto_input *= 0.2
		elif m.kind == "lift":
			if m.current_top() > here_floor + 0.6 and m.state == 0 and to.length() < 2.8:
				_face_and_use(tp + Vector3(0, m.current_top() - 0.4, 0))
				player.auto_input = Vector2.ZERO
			elif m.current_top() > here_floor + 0.6:
				player.auto_input = Vector2.ZERO
	if here >= 0 and level.movers.has(here) and level.movers[here].kind == "lift":
		var lm: Mover = level.movers[here]
		if nf > lm.current_top() + 0.6:
			player.auto_input = Vector2(0, -0.0)
			if lm.state == 0:
				_face_and_use(player.global_position + Vector3(0, -1, 0))
	if nf - here_floor > 0.5 and to.length() < 2.2:
		player.auto_jump = true


func _face_and_use(p: Vector3) -> void:
	if use_t > 0.0:
		return
	use_t = 0.6
	var to := p - player.eye_point()
	player.yaw = atan2(-to.x, -to.z)
	player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	player._update_head(1.0)
	player.camera.rotation = Vector3(player.pitch, 0, 0)
	gw.do_use()


func _at_goal() -> void:
	if goal_kind in ["switch", "exit"] and level.use_cells.has(goal):
		var c := Vector2i(goal % level.W, goal / level.W)
		var p := Vector3((c.x + 0.5) * Level.S, player.global_position.y + 1.2, (c.y + 0.5) * Level.S)
		use_t = 0.0
		_face_and_use(p)
		if level.use_cells[goal]["used"] == false:
			failed_goals[goal] = true


func _combat(delta: float) -> void:
	use_t -= delta
	scan_t -= delta
	if scan_t <= 0.0:
		scan_t = 0.2
		target_enemy = null
		var best := 32.0
		for e in level.enemies:
			if not is_instance_valid(e) or e.dead:
				continue
			var d: float = e.global_position.distance_to(player.global_position)
			if d < best and level.has_los(player.eye_point(), e.center_point()):
				best = d
				target_enemy = e
		_pick_weapon()
	want_fire = false
	if target_enemy and is_instance_valid(target_enemy) and not target_enemy.dead:
		var to: Vector3 = target_enemy.center_point() - player.eye_point()
		var wy := atan2(-to.x, -to.z)
		var wp := atan2(to.y, Vector2(to.x, to.z).length())
		player.yaw = lerp_angle(player.yaw, wy, clampf(delta * 12.0, 0.0, 1.0))
		player.pitch = lerpf(player.pitch, wp, clampf(delta * 12.0, 0.0, 1.0))
		var err := absf(angle_difference(player.yaw, wy)) + absf(player.pitch - wp)
		want_fire = err < 0.12
	else:
		target_enemy = null


func _pick_weapon() -> void:
	var w: Weapons = player.weapons
	for name in ["ssg", "plasma", "shotgun", "mg", "pistol"]:
		if not w.owned.has(name):
			continue
		var d: Dictionary = Weapons.DATA[name]
		if int(w.mags.get(name, 0)) > 0 or int(w.ammo[d["ammo"]]) > 0:
			if w.current != name:
				w.switch_to(name)
			return


func _unstick(delta: float) -> void:
	stuck_t += delta
	if stuck_t > 2.0:
		var moved := player.global_position.distance_to(last_pos)
		if moved < 0.4 and player.auto_input.length() > 0.1:
			player.auto_jump = true
			strafe = [-1.0, 1.0][randi() % 2]
			strafe_t = 0.6
			replan_t = 0.0
		last_pos = player.global_position
		stuck_t = 0.0
	if strafe_t > 0.0:
		strafe_t -= delta
		player.auto_input = Vector2(strafe, -0.3)
