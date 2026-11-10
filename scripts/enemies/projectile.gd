class_name Projectile
extends Node3D
## Enemy and player projectiles. Moved manually with ray sweeps so fast
## projectiles never tunnel through walls.

const KINDS := {
	"green": {"tex": "proj_green", "size": 0.7, "light": Color(0.5, 1.0, 0.2), "hit": "explosion_small", "fx": "green"},
	"ice": {"tex": "proj_ice", "size": 0.6, "light": Color(0.3, 0.5, 1.0), "hit": "explosion_small", "fx": "ice"},
	"purple": {"tex": "proj_purple", "size": 0.8, "light": Color(1.0, 0.2, 0.8), "hit": "explosion_small", "fx": "purple"},
	"fire": {"tex": "proj_fire", "size": 1.0, "light": Color(1.0, 0.5, 0.1), "hit": "explosion", "fx": "fire"},
	"spit": {"tex": "proj_spit", "size": 0.5, "light": Color(0.7, 0.4, 1.0), "hit": "hit_flesh", "fx": "spit"},
	"plasma": {"tex": "proj_plasma", "size": 0.55, "light": Color(0.2, 0.8, 1.0), "hit": "explosion_small", "fx": "plasma"},
	"rocket": {"tex": "", "size": 0.0, "light": Color(1.0, 0.6, 0.2), "hit": "explosion", "fx": "rocket"},
}

var level: Level
var shooter: Node
var vel := Vector3.ZERO
var kind := "green"
var damage := 10.0
var splash := 0.0
var splash_r := 0.0
var homing := 0.0
var target: Node = null
var from_player := false
var ttl := 8.0
var light_id := -1
var sprite: Sprite3D
var _frame_t := 0.0
var _trail_t := 0.0
var _exclude: Array = []


func launch(lvl: Level, p_shooter: Node, pos: Vector3, p_vel: Vector3, p_kind: String, dmg: float, player_owned: bool) -> void:
	level = lvl
	shooter = p_shooter
	global_position = pos
	vel = p_vel
	kind = p_kind
	damage = dmg
	from_player = player_owned
	if shooter is CollisionObject3D:
		_exclude = [shooter.get_rid()]
	var k: Dictionary = KINDS.get(kind, KINDS["green"])
	if kind == "rocket":
		var m := Node3D.new()
		m.add_child(Models.mi(Models.cyl(0.07, 0.07, 0.5, 8), Mat.world("gun_green", {"origin": true}), Vector3.ZERO, Vector3(90, 0, 0)))
		m.add_child(Models.mi(Models.cyl(0.0, 0.07, 0.18, 8), Mat.world("gun_red", {"origin": true}), Vector3(0, 0, -0.34), Vector3(-90, 0, 0)))
		m.add_child(Models.mi(Models.sphere(0.09, 6, 4), Mat.world("white", {"tint": Color(1, 0.8, 0.3), "fullbright": 1.0}), Vector3(0, 0, 0.28)))
		add_child(m)
		look_at(global_position + vel, Vector3.UP if abs(vel.normalized().y) < 0.99 else Vector3.RIGHT)
	else:
		sprite = Fx.make_sprite(String(k["tex"]), float(k["size"]))
		add_child(sprite)
	light_id = Fx.light(level, global_position, k["light"], 5.0, 1.4, -1.0, self)


func _physics_process(delta: float) -> void:
	ttl -= delta
	if ttl <= 0.0:
		queue_free()
		return
	if homing > 0.0 and target and is_instance_valid(target) and not target.get("dead"):
		var want: Vector3 = (target.center_point() - global_position).normalized() * vel.length()
		vel = vel.lerp(want, clampf(homing * delta * 0.5, 0.0, 1.0))
	var from := global_position
	var to := from + vel * delta
	var mask := (1 | 4 | 8 | 32) if from_player else (1 | 2 | 8 | 32)
	var hit := level.ray(from, to, mask, _exclude, from_player)
	if not hit.is_empty():
		_impact(hit)
		return
	global_position = to
	if sprite:
		_frame_t += delta * 10.0
		sprite.frame = int(_frame_t) % maxi(1, sprite.hframes)
	if kind == "rocket":
		look_at(global_position + vel, Vector3.UP if abs(vel.normalized().y) < 0.99 else Vector3.RIGHT)
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.03
			Fx.smoke(level, global_position - vel.normalized() * 0.35)


func _impact(hit: Dictionary) -> void:
	var p: Vector3 = hit["position"]
	var n: Vector3 = hit["normal"]
	var col = hit["collider"]
	var k: Dictionary = KINDS.get(kind, KINDS["green"])
	var direct_target: Node = null
	if col and col.has_method("take_damage"):
		direct_target = col
		col.take_damage(damage, shooter, vel.normalized(), "explosion" if kind == "rocket" else "proj")
	if splash > 0.0:
		level.radius_damage(p + n * 0.3, splash_r, splash, shooter, "explosion")
	match String(k["fx"]):
		"rocket", "fire":
			Fx.explosion(level, p + n * 0.3, kind == "rocket")
		"plasma":
			Fx.anim(level, "explosion_plasma", p + n * 0.2, 0.9, 24.0)
			Fx.light(level, p + n * 0.3, Color(0.3, 0.8, 1.0), 4.0, 1.5, 0.12)
			Audio.play_at("explosion_small", p, -6.0, 1.6)
			if direct_target == null:
				Fx.decal(level, p, n, "bullethole", 0.35, Color(0.2, 0.8, 1.0))
		_:
			Fx.anim(level, "explosion_plasma" if kind == "purple" else "puff", p + n * 0.2, float(k["size"]) * 1.4, 18.0)
			Fx.light(level, p + n * 0.3, k["light"], 4.0, 1.2, 0.12)
			Audio.play_at(String(k["hit"]), p, -4.0, randf_range(1.1, 1.4))
			if direct_target == null and kind == "spit":
				Fx.decal(level, p, n, "splat", 0.6, Color(0.6, 0.3, 0.9))
	queue_free()


func _exit_tree() -> void:
	if level and light_id >= 0:
		Fx.remove_light(level, light_id)
