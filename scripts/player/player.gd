class_name Player
extends CharacterBody3D
## First-person player: movement, stairs, jumping, sprinting, look,
## damage, pickups, keys and inventory.

const RADIUS := 0.4
const HEIGHT := 1.75
const EYE := 1.55
const STEP := 0.56
const WALK := 10.5
const SPRINT := 15.0
const GROUND_ACCEL := 14.0
const AIR_ACCEL := 3.5
const FRICTION := 8.0
const STOP_SPEED := 2.0
const JUMP_V := 7.4
const GRAVITY := 23.0

var level: Level
var world: Node
var head: Node3D            # top-level camera rig
var camera: Camera3D
var weapons: Weapons
var offhand: Offhand
var finisher: Finisher
var gutting := false              # mid-finisher: locked in place and untouchable
var gut_move_to := Vector3.INF
var gut_crouch := 0.0
var gut_grace := 0.0              # a moment of safety after a gut ends
var fov_punch := 0.0              # brief zoom kicks (gutting)
var slide_t := 0.0                # > 0 while sliding along the floor
var slide_dir := Vector3.ZERO
var slide_dip := 0.0              # how far the eye has dropped for the slide
var _slide_cd := 0.0
var _slid_into := {}
var frenzy := 0.0                 # > 0: FRENZY seconds left
var frenzy_meter := 0.0           # 0..1, filled by kills
var _last_kill_t := 0.0
var yaw := 0.0
var pitch := 0.0
var health := 100
var armor := 0
var armor_type := 0
var keys := {}
var dead := false
var god := false
var inv := {}
var coyote := 0.0
var jump_buffer := 0.0
var bob_t := 0.0
var bob_amount := 0.0
var land_dip := 0.0
var step_offset := 0.0
var shake_amt := 0.0
var kick_pitch := 0.0
var roll := 0.0
var hurt_dir := Vector3.ZERO
var hurt_t := 0.0
var pain_snd_t := 0.0
var liquid_t := 0.0
var step_dist := 0.0
var death_t := 0.0
var flash_color := Color(0, 0, 0, 0)
var _prev_pos := Vector3.ZERO
var _cur_pos := Vector3.ZERO
var _air_time := 0.0
var _fall_speed := 0.0
var autopilot: Node = null       # test harness driver
var auto_input := Vector2.ZERO
var auto_jump := false
var auto_sprint := false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(46)
	floor_constant_speed = true
	safe_margin = 0.02
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	cs.shape = cap
	cs.position = Vector3(0, HEIGHT * 0.5, 0)
	add_child(cs)
	head = Node3D.new()
	head.name = "Head"
	head.top_level = true
	add_child(head)
	camera = Camera3D.new()
	camera.near = 0.02
	camera.far = 220.0
	camera.fov = float(Settings.get_v("fov"))
	camera.current = true
	head.add_child(camera)
	weapons = Weapons.new()
	weapons.player = self
	camera.add_child(weapons)
	offhand = Offhand.new()
	offhand.player = self
	camera.add_child(offhand)
	finisher = Finisher.new()
	finisher.player = self
	finisher.offhand = offhand
	add_child(finisher)


func setup(lvl: Level, p_world: Node, pos: Vector3, p_yaw: float, inventory: Dictionary) -> void:
	level = lvl
	world = p_world
	global_position = pos
	_prev_pos = pos
	_cur_pos = pos
	yaw = p_yaw
	set_inventory(inventory)
	_update_head(1.0)


func set_inventory(inventory: Dictionary) -> void:
	inv = inventory.duplicate(true)
	health = int(inv.get("health", 100))
	armor = int(inv.get("armor", 0))
	armor_type = int(inv.get("armor_type", 0))
	weapons.load_from(inv)


func get_inventory() -> Dictionary:
	weapons.save_to(inv)
	inv["health"] = health
	inv["armor"] = armor
	inv["armor_type"] = armor_type
	return inv.duplicate(true)


func center_point() -> Vector3:
	return global_position + Vector3(0, 1.0, 0)


func eye_point() -> Vector3:
	return global_position + Vector3(0, EYE, 0)


func aim_basis() -> Basis:
	return camera.global_transform.basis


func look(rel: Vector2) -> void:
	if dead or gutting:
		return
	var s := Settings.mouse_degrees_per_pixel()
	yaw -= deg_to_rad(rel.x * s)
	var inv_y := -1.0 if Settings.get_v("invert_y") else 1.0
	pitch = clampf(pitch - deg_to_rad(rel.y * s) * inv_y, deg_to_rad(-88), deg_to_rad(88))
	weapons.sway(rel)


func shake(a: float) -> void:
	shake_amt = maxf(shake_amt, a)


func has_key(k: String) -> bool:
	return keys.has(k)


func _input_vector() -> Vector2:
	if autopilot:
		return auto_input
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func _physics_process(delta: float) -> void:
	if level == null:
		return
	_prev_pos = _cur_pos
	if dead:
		death_t += delta
		velocity.x = move_toward(velocity.x, 0, 10 * delta)
		velocity.z = move_toward(velocity.z, 0, 10 * delta)
		velocity.y -= GRAVITY * delta
		move_and_slide()
		_cur_pos = global_position
		return
	if gutting:
		# the finisher holds the player: step to the creature, no input
		var to := Vector3.ZERO
		if gut_move_to != Vector3.INF:
			to = gut_move_to - global_position
			to.y = 0.0
		var sp := minf(to.length() * 8.0, 7.0)
		var dir := to.normalized() if to.length() > 0.02 else Vector3.ZERO
		velocity.x = dir.x * sp
		velocity.z = dir.z * sp
		velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
		move_and_slide()
		_cur_pos = global_position
		return
	var on_floor := is_on_floor()
	var iv := _input_vector()
	var yb := Basis(Vector3.UP, yaw)
	var wish := yb * Vector3(iv.x, 0, iv.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var sprinting := (Input.is_action_pressed("sprint") if autopilot == null else auto_sprint)
	var max_speed := (SPRINT if sprinting else WALK) * (1.15 if frenzy > 0.0 else 1.0)
	_slide_cd -= delta
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if autopilot == null and Input.is_action_just_pressed("slide") and on_floor and slide_t <= 0.0 and _slide_cd <= 0.0 and hspeed > 3.0:
		_start_slide()
	if slide_t > 0.0:
		_slide(delta, on_floor, wish)
	elif on_floor:
		coyote = 0.12
		_apply_friction(delta)
		_accelerate(wish, max_speed, GROUND_ACCEL, delta)
	else:
		coyote -= delta
		_accelerate(wish, max_speed, AIR_ACCEL, delta)
		velocity.y -= GRAVITY * delta
	# jumping
	var jp := Input.is_action_just_pressed("jump") if autopilot == null else auto_jump
	if autopilot:
		auto_jump = false
	if jp:
		jump_buffer = 0.14
	jump_buffer -= delta
	if jump_buffer > 0.0 and coyote > 0.0:
		if slide_t > 0.0:
			# jump out of a slide and keep the speed
			slide_t = 0.0
		velocity.y = JUMP_V
		jump_buffer = 0.0
		coyote = 0.0
		Audio.play("player_jump", -8.0, randf_range(0.95, 1.05))
	if not on_floor:
		_air_time += delta
		_fall_speed = minf(_fall_speed, velocity.y)
	_move_with_steps(delta, on_floor)
	if is_on_floor() and _air_time > 0.25:
		if _fall_speed < -7.0:
			land_dip = clampf(-_fall_speed * 0.012, 0.0, 0.25)
			Audio.play("player_land", -2.0)
		_air_time = 0.0
		_fall_speed = 0.0
	elif is_on_floor():
		_air_time = 0.0
		_fall_speed = 0.0
	# bump-open doors
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		if col is Mover and col.kind == "door" and col.key == "" and not col.secret and not col.remote:
			col.try_use(self)
	_cur_pos = global_position
	_hazards(delta)
	_footsteps(delta)
	_tick_frenzy(delta)


# ------------------------------------------------------------------ slide
func _start_slide() -> void:
	slide_t = 0.62
	_slide_cd = 0.75
	_slid_into.clear()
	var hv := Vector3(velocity.x, 0, velocity.z)
	slide_dir = hv.normalized() if hv.length() > 0.5 else -Basis(Vector3.UP, yaw).z
	var sp := maxf(hv.length() + 3.0, 14.0)
	velocity.x = slide_dir.x * sp
	velocity.z = slide_dir.z * sp
	Audio.play("slide", -2.0, randf_range(0.95, 1.05))
	fov_punch = 6.0


## Low and fast, a little steering, slowing as it goes. Anything you slide
## into gets kicked off its feet.
func _slide(delta: float, on_floor: bool, wish: Vector3) -> void:
	slide_t -= delta
	var hv := Vector3(velocity.x, 0, velocity.z)
	var sp := hv.length()
	sp = move_toward(sp, 7.0, delta * 12.0)
	var dir := hv.normalized() if hv.length() > 0.1 else slide_dir
	if wish.length() > 0.1:
		dir = dir.slerp(wish.normalized(), clampf(delta * 2.5, 0.0, 1.0))
	velocity.x = dir.x * sp
	velocity.z = dir.z * sp
	if on_floor:
		coyote = 0.12
		if randf() < delta * 20.0:
			Fx.puff(level, global_position + Vector3(randf_range(-0.3, 0.3), 0.05, randf_range(-0.3, 0.3)), Vector3.UP)
	else:
		velocity.y -= GRAVITY * delta
	for e in level.enemies:
		if not is_instance_valid(e) or e.dead or e.gutted or _slid_into.has(e):
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0.0
		if d.length() < RADIUS + float(e.radius) + 0.35:
			_slid_into[e] = true
			e.take_damage(14.0, self, (d.normalized() + Vector3.UP * 0.3).normalized(), "melee")
			if not e.dead and not e.def.get("boss", false):
				e.knock += (d.normalized() * 9.0 + Vector3.UP * 2.0)
			Audio.play_at("hit_flesh", e.center_point(), 0.0, 0.8)
			shake(0.15)
	if slide_t <= 0.0:
		slide_t = 0.0


# ------------------------------------------------------------------ frenzy
const FRENZY_TIME := 8.0
const FRENZY_SHOUTS := ["GORBTASTIC!", "MEAT PARADE!", "BLORPOCALYPSE!", "SPLATTERDAY!", "UNHINGED!",
	"FULL GORB!", "OOPS ALL GUTS!", "MEAT MEAT MEAT!"]


## A kill: fills the frenzy meter. Kills in quick succession fill it faster.
func on_kill(en: Node) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var chain := now - _last_kill_t < 3.0
	_last_kill_t = now
	if frenzy > 0.0:
		frenzy = minf(frenzy + 0.6, FRENZY_TIME)
		if randf() < 0.3 and world:
			world.hud.center(FRENZY_SHOUTS[randi() % FRENZY_SHOUTS.size()], 0.9)
		return
	frenzy_meter += 0.2 if chain else 0.12
	if en.def.get("boss", false):
		frenzy_meter = 1.0
	if frenzy_meter >= 1.0:
		_start_frenzy()


func _start_frenzy() -> void:
	frenzy = FRENZY_TIME
	frenzy_meter = 0.0
	Audio.play("frenzy_on", 2.0)
	Audio.play("gorb_talk_" + ["a", "c", "e"][randi() % 3], 4.0, 1.5)
	fov_punch = 12.0
	shake(0.3)
	if world:
		world.hud.center("FRENZY!", 1.6)


func _tick_frenzy(delta: float) -> void:
	if frenzy > 0.0:
		frenzy -= delta
		Audio.music_player.pitch_scale = move_toward(Audio.music_player.pitch_scale, 1.22, delta * 2.0)
		if frenzy <= 0.0:
			frenzy = 0.0
			if world:
				world.hud.message("THE FRENZY PASSES")
	else:
		Audio.music_player.pitch_scale = move_toward(Audio.music_player.pitch_scale, 1.0, delta * 1.0)
		if Time.get_ticks_msec() / 1000.0 - _last_kill_t > 4.0:
			frenzy_meter = maxf(0.0, frenzy_meter - delta * 0.06)


func _apply_friction(delta: float) -> void:
	var hv := Vector2(velocity.x, velocity.z)
	var sp := hv.length()
	if sp < 0.01:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var drop := maxf(sp, STOP_SPEED) * FRICTION * delta
	var ns := maxf(sp - drop, 0.0) / sp
	velocity.x *= ns
	velocity.z *= ns


func _accelerate(wish: Vector3, max_speed: float, accel: float, delta: float) -> void:
	if wish.length() < 0.001:
		return
	var wdir := wish.normalized()
	var wspeed := max_speed * wish.length()
	var cur := Vector3(velocity.x, 0, velocity.z).dot(wdir)
	var add := wspeed - cur
	if add <= 0.0:
		return
	var a := minf(accel * wspeed * delta, add)
	velocity.x += wdir.x * a
	velocity.z += wdir.z * a


func _move_with_steps(delta: float, was_on_floor: bool) -> void:
	# Stair climbing: probe just ahead of the capsule for a walkable ledge no
	# higher than STEP and lift the player onto it before sliding.
	var hvel := Vector3(velocity.x, 0, velocity.z)
	if hvel.length() > 0.4 and (was_on_floor or velocity.y < 1.5):
		var dir := hvel.normalized()
		var max_h := STEP if was_on_floor else STEP * 0.5
		for side in [0.0, 0.6, -0.6]:
			var d := dir.rotated(Vector3.UP, side)
			var probe := global_position + d * (RADIUS + 0.14)
			var hit := level.ray(probe + Vector3(0, max_h + 0.05, 0), probe + Vector3(0, 0.02, 0), 1 | 8, [get_rid()])
			if hit.is_empty() or hit["normal"].y < 0.7:
				continue
			var h: float = hit["position"].y - global_position.y
			if h > 0.03 and h <= max_h and not test_move(global_transform, Vector3(0, h + 0.03, 0)):
				global_position.y += h + 0.01
				step_offset -= h
				if velocity.y < 0.0:
					velocity.y = 0.0
				break
	move_and_slide()


func _hazards(delta: float) -> void:
	var dmg := level.damage_at(global_position)
	if dmg > 0.0 and is_on_floor():
		liquid_t -= delta
		if liquid_t <= 0.0:
			liquid_t = 0.9
			take_damage(dmg, null, Vector3.ZERO, "liquid")
			Audio.play("liquid_burn", -4.0)
	else:
		liquid_t = minf(liquid_t, 0.3)


func _footsteps(delta: float) -> void:
	if not is_on_floor():
		return
	var sp := Vector2(velocity.x, velocity.z).length()
	step_dist += sp * delta
	if step_dist > 2.4:
		step_dist = 0.0
		var cls := level.floor_class_at(global_position)
		match cls:
			"metal":
				Audio.play("step_metal", -10.0, randf_range(0.9, 1.1))
			"squish":
				Audio.play("step_squish", -10.0, randf_range(0.9, 1.1))
			"liquid":
				Audio.play("splash", -12.0, randf_range(0.9, 1.2))
			_:
				Audio.play("step%d" % (randi() % 3), -9.0, randf_range(0.9, 1.1))


func _process(delta: float) -> void:
	gut_grace = maxf(0.0, gut_grace - delta)
	var f := Engine.get_physics_interpolation_fraction()
	_update_head(f)
	_update_view_fx(delta)


func _update_head(f: float) -> void:
	var p := _prev_pos.lerp(_cur_pos, f)
	var eye := EYE
	if dead:
		eye = lerpf(EYE, 0.35, clampf(death_t * 2.5, 0.0, 1.0))
	if not gutting:
		gut_crouch = move_toward(gut_crouch, 0.0, get_process_delta_time() * 2.5)
	slide_dip = move_toward(slide_dip, 0.75 if slide_t > 0.0 else 0.0, get_process_delta_time() * (8.0 if slide_t > 0.0 else 4.0))
	head.global_position = p + Vector3(0, eye + step_offset - land_dip - gut_crouch - slide_dip, 0)
	head.rotation = Vector3(0, yaw, 0)


func _update_view_fx(delta: float) -> void:
	step_offset = move_toward(step_offset, 0.0, delta * 3.5)
	land_dip = move_toward(land_dip, 0.0, delta * 0.9)
	kick_pitch = move_toward(kick_pitch, 0.0, delta * 0.35 + abs(kick_pitch) * delta * 9.0)
	shake_amt = move_toward(shake_amt, 0.0, delta * 1.6)
	hurt_t = maxf(0.0, hurt_t - delta)
	var sp := Vector2(velocity.x, velocity.z).length()
	var on := is_on_floor() and not dead
	bob_amount = lerpf(bob_amount, clampf(sp / WALK, 0.0, 1.4) if on else 0.0, clampf(delta * 8.0, 0.0, 1.0))
	bob_t += delta * (6.5 + sp * 0.55)
	var bob := 0.0
	if Settings.get_v("head_bob"):
		bob = abs(sin(bob_t)) * 0.055 * bob_amount
	# strafe roll
	var right := Basis(Vector3.UP, yaw).x
	var side := Vector3(velocity.x, 0, velocity.z).dot(right)
	roll = lerpf(roll, -side * 0.0045, clampf(delta * 10.0, 0.0, 1.0))
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake_amt * 0.03
	camera.position = Vector3(0, bob, 0) + shake
	fov_punch = move_toward(fov_punch, 0.0, delta * (30.0 + absf(fov_punch) * 6.0))
	camera.fov = float(Settings.get_v("fov")) + fov_punch
	var death_roll := 0.0
	if dead:
		death_roll = lerpf(0.0, 0.8, clampf(death_t * 2.0, 0.0, 1.0))
	camera.rotation = Vector3(pitch + kick_pitch, 0, roll + death_roll + shake.x * 0.5)
	weapons.set_bob(bob_t, bob_amount)


func add_kick(deg: float) -> void:
	kick_pitch += deg_to_rad(deg)


func teleport_to(pos: Vector3) -> void:
	global_position = pos + Vector3(0, 0.05, 0)
	velocity = Vector3.ZERO
	_prev_pos = global_position
	_cur_pos = global_position


# ------------------------------------------------------------------ damage
func take_damage(amount: float, source: Node, dir: Vector3, kind := "bullet") -> void:
	# nothing touches you while you're gutting something, or just after
	if dead or gutting or gut_grace > 0.0:
		return
	if source != self and source != null:
		amount *= float(Game.diff()["dmg"])
	if god or Game.cheats.get("god", false):
		amount = 0.0
	# knockback (rocket jumping)
	if kind == "explosion":
		var push := dir * clampf(amount * 0.22, 0.0, 14.0)
		if source == self:
			push *= 1.6
		velocity += push
		if push.y > 0.5:
			global_position.y += 0.02
	elif dir != Vector3.ZERO:
		velocity += Vector3(dir.x, 0, dir.z) * minf(amount * 0.08, 3.0)
	var dmg := int(round(amount))
	if dmg <= 0:
		return
	if armor > 0:
		var absorb := dmg / 3 if armor_type == 1 else dmg / 2
		absorb = mini(absorb, armor)
		armor -= absorb
		dmg -= absorb
		if armor <= 0:
			armor_type = 0
	health -= dmg
	hurt_t = 0.6
	if dir != Vector3.ZERO:
		hurt_dir = dir
	flash_color = Color(1, 0, 0, clampf(0.12 + dmg * 0.015, 0.15, 0.6))
	shake(clampf(dmg * 0.02, 0.05, 0.4))
	if health <= 0:
		health = 0
		_die()
		return
	if pain_snd_t <= 0.0 or dmg > 20:
		Audio.play("player_pain" if randf() < 0.5 else "player_pain2", -2.0, randf_range(0.95, 1.05))
	pain_snd_t = 0.4


func _die() -> void:
	dead = true
	death_t = 0.0
	Audio.play("player_death")
	weapons.visible = false
	flash_color = Color(0.8, 0, 0, 0.6)
	if world:
		world.on_player_died()


# ------------------------------------------------------------------ pickups
func try_pickup(pk: Pickup) -> bool:
	var t := pk.ptype
	var amult := float(Game.diff()["ammo"])
	var took := false
	match t:
		"juice":
			if health < 200:
				health = mini(health + 10, 200)
				took = true
		"medkit":
			if health < 100:
				health = mini(health + 25, 100)
				took = true
		"mega":
			health = mini(health + 100, 200)
			took = true
		"armor_bonus":
			armor = mini(armor + 5, 200)
			if armor_type == 0:
				armor_type = 1
			took = true
		"armor_green":
			if armor < 100:
				armor = 100
				armor_type = 1
				took = true
		"armor_blue":
			if armor < 200:
				armor = 200
				armor_type = 2
				took = true
		"bullets":
			took = weapons.give_ammo("bullets", int(10 * amult))
		"bullets_box":
			took = weapons.give_ammo("bullets", int(50 * amult))
		"shells":
			took = weapons.give_ammo("shells", int(4 * amult))
		"shells_box":
			took = weapons.give_ammo("shells", int(20 * amult))
		"rocket":
			took = weapons.give_ammo("rockets", int(1 * amult))
		"rockets_box":
			took = weapons.give_ammo("rockets", int(5 * amult))
		"cells":
			took = weapons.give_ammo("cells", int(20 * amult))
		"cells_box":
			took = weapons.give_ammo("cells", int(100 * amult))
		"fuel":
			took = weapons.give_ammo("fuel", int(25 * amult))
		"fuel_box":
			took = weapons.give_ammo("fuel", int(80 * amult))
		"trout":
			took = weapons.give_ammo("trout", int(3 * amult))
		"trout_box":
			took = weapons.give_ammo("trout", int(10 * amult))
		"backpack":
			inv["backpack"] = true
			weapons.give_ammo("bullets", 10)
			weapons.give_ammo("shells", 4)
			weapons.give_ammo("rockets", 1)
			weapons.give_ammo("cells", 20)
			weapons.give_ammo("fuel", 25)
			weapons.give_ammo("trout", 2)
			took = true
		"key_red", "key_blue", "key_yellow":
			keys[t.substr(4)] = true
			took = true
		_:
			if t.begins_with("w_"):
				took = weapons.give_weapon(t.substr(2), pk.dropped)
	if took:
		Audio.play(pk.sound(), -1.0)
		if world:
			world.message(pk.message())
		flash_color = Color(1.0, 0.85, 0.2, 0.22) if not t.begins_with("key") else Color(0.6, 0.9, 1.0, 0.3)
	return took
