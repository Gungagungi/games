class_name Nightmare
extends RefCounted
## Créature cauchemardesque, boss final du Chaos, et ses doubles. Comme le reste
## de `World`, tout se compte en frames de 1/60 s.
##
## Entre deux attaques, elle marche sur le héros et frappe au contact (brûlure
## et vol de vie de l'élément Chaos). Puis elle choisit l'une de ses attaques,
## toutes télégraphiées pour rester esquivables :
## - laser : l'œil vise le héros, se fige, puis tire un rayon qui balaie lentement ;
## - fouet : trois tentacules jaillissent vers le héros, à longue portée ;
## - balayage : cercle de tentacules autour d'elle, quand le héros est proche ;
## - ruée : charge en ligne droite ;
## - saut : elle bondit sur la position du héros, et l'atterrissage lance une
##   onde de choc en anneau, qu'on évite en étant loin ou déjà derrière le front ;
## - invocation : des mini-créatures, monstres de mêlée ordinaires.
## À 75, 50 et 25 % de PV, elle se dédouble : le double reprend ses attaques,
## sauf le laser, l'invocation et le dédoublement. Sa mort emporte doubles et
## mini-créatures.

const LASER_AIM := 60
## Dernières frames de visée : la direction est figée, le temps de s'écarter.
const LASER_LOCK := 20
const LASER_FIRE := 70
const LASER_LEN := 1400.0
## Demi-largeur touchante du rayon (le visuel est un peu plus large).
const LASER_HALF := 16.0
## Balayage du rayon vers le héros, en radians par frame : plus lent que ce que
## le héros parcourt à 300 px, il se distance en courant de côté.
const LASER_TURN := 0.006
const LASER_TICK := 8

const LASH_AIM := 32
const LASH_TIME := 26
const LASH_LEN := 330.0
const LASH_HALF := 12.0
const LASH_SPREAD := 0.38

const SWEEP_AIM := 26
const SWEEP_TIME := 14
const SWEEP_R := 115.0

const DASH_AIM := 40
const DASH_TIME := 18
const DASH_SPEED := 9.0

const JUMP_CROUCH := 22
const JUMP_AIR := 42
const JUMP_HEIGHT := 150.0
const WAVE_TIME := 34
const WAVE_R := 270.0
## Épaisseur du front de l'onde : on n'est touché qu'à son passage.
const WAVE_HALF := 16.0

const SUMMON_TIME := 36
const SUMMON_COUNT := 3
const MINIS_MAX := 6

const SPLIT_TIME := 40
const SPLIT_AT := [0.75, 0.5, 0.25]
const SLIDE_TIME := 16

## Le boss final ou l'un de ses doubles (pas les mini-créatures, qui suivent la
## logique des monstres ordinaires).
static func handles(e: Enemy) -> bool:
	return e.element == Data.CHAOS and (e.is_final or e.is_clone)

static func tick(w: World, e: Enemy) -> void:
	var p := w.player
	if e.attack_cooldown > 0:
		e.attack_cooldown -= 1
	if e.nm_slide_timer > 0:
		e.nm_slide_timer -= 1
		e.position = _clamp(e, e.position + e.nm_slide)

	var to := p.position - e.position
	var dist := maxf(to.length(), 1.0)
	var dir := to / dist
	if e.nm_attack != "":
		e.nm_timer -= 1
	match e.nm_attack:
		"":
			_idle(w, e, dir, dist)
		"laser_aim":
			if e.nm_timer > LASER_LOCK:
				e.nm_dir = (p.position - e.eye_position()).normalized()
			if e.nm_timer <= 0:
				_start(e, "laser", LASER_FIRE)
				Audio.sfx("boss_warning", 1.6)
		"laser":
			_laser(w, e)
		"lash_aim":
			if e.nm_timer > LASH_AIM / 2:
				e.nm_lash = [dir.rotated(-LASH_SPREAD), dir, dir.rotated(LASH_SPREAD)]
			if e.nm_timer <= 0:
				_start(e, "lash", LASH_TIME)
				Audio.sfx("attack", 0.55)
		"lash":
			_lash(w, e)
		"sweep_aim":
			if e.nm_timer <= 0:
				_start(e, "sweep", SWEEP_TIME)
				Audio.sfx("attack", 0.45)
				w.shake(4.0)
				if dist < SWEEP_R + p.radius:
					_hit(w, e, 1.3, true)
		"sweep":
			if e.nm_timer <= 0:
				_end(e)
		"dash_aim":
			e.charge_telegraph = e.nm_timer
			if e.nm_timer > 8:
				e.nm_dir = dir
			if e.nm_timer <= 0:
				_start(e, "dash", DASH_TIME)
				w.shake(3.0)
		"dash":
			e.position = _clamp(e, e.position + e.nm_dir * DASH_SPEED)
			if not e.nm_hit and dist < e.radius + p.radius:
				e.nm_hit = true
				_hit(w, e, 1.5, true)
			if e.nm_timer <= 0:
				e.charging = false
				_end(e)
		"jump_crouch":
			if e.nm_timer <= 0:
				e.nm_from = e.position
				e.nm_target = _clamp(e, p.position)
				_start(e, "jump", JUMP_AIR)
				Audio.sfx("throw", 0.5)
		"jump":
			var k := 1.0 - float(e.nm_timer) / JUMP_AIR
			e.position = e.nm_from.lerp(e.nm_target, k)
			e.nm_height = sin(k * PI) * JUMP_HEIGHT
			if e.nm_timer <= 0:
				e.nm_height = 0.0
				_start(e, "shockwave", WAVE_TIME)
				Audio.sfx("boss_charge", 0.6)
				Fx.puff(w.fx_layer, e.position, e.glow, 3.0)
				w.shake(9.0)
		"shockwave":
			var r := wave_radius(e)
			if not e.nm_hit and absf(dist - r) < WAVE_HALF + p.radius:
				e.nm_hit = true
				_hit(w, e, 1.4, false)
			if e.nm_timer <= 0:
				_end(e)
		"summon":
			if e.nm_timer <= 0:
				_summon(w, e)
				_end(e)
		"split":
			if e.nm_timer <= 0:
				_split(w, e)
				_end(e)

## Rayon actuel de l'onde de choc, partagé avec le visuel.
static func wave_radius(e: Enemy) -> float:
	return WAVE_R * (1.0 - float(e.nm_timer) / WAVE_TIME)

## Longueur actuelle des tentacules du fouet : sortie, maintien, retour.
static func lash_reach(e: Enemy) -> float:
	var k := 1.0 - float(e.nm_timer) / LASH_TIME
	if k < 0.4:
		return LASH_LEN * k / 0.4
	if k < 0.6:
		return LASH_LEN
	return LASH_LEN * (1.0 - k) / 0.4

static func _idle(w: World, e: Enemy, dir: Vector2, dist: float) -> void:
	var p := w.player
	e.face_left = p.position.x < e.position.x
	if e.is_final and e.nm_splits < SPLIT_AT.size() and e.hp <= e.max_hp * float(SPLIT_AT[e.nm_splits]):
		_start(e, "split", SPLIT_TIME)
		Audio.sfx("boss_charge", 1.3)
		return
	if dist > e.radius + p.radius:
		e.position += dir * e.speed
	elif e.attack_cooldown <= 0:
		e.attack_cooldown = 50
		_hit(w, e, 1.0, true)
	e.nm_cooldown -= 1
	if e.nm_cooldown <= 0:
		_choose(w, e, dist)

static func _choose(w: World, e: Enemy, dist: float) -> void:
	var options: Array[String] = []
	if dist < SWEEP_R + 40.0:
		options = ["sweep", "sweep", "jump", "dash"]
	else:
		options = ["lash", "lash", "dash", "jump"]
		if e.is_final:
			options.append_array(["laser", "laser"])
			if _minis(w) < MINIS_MAX:
				options.append("summon")
	var fresh := options.filter(func(o: String) -> bool: return o != e.nm_last)
	var pick: String = (fresh if not fresh.is_empty() else options).pick_random()
	e.nm_last = pick
	match pick:
		"laser":
			_start(e, "laser_aim", LASER_AIM)
			Audio.sfx("boss_charge", 1.5)
		"lash":
			_start(e, "lash_aim", LASH_AIM)
		"sweep":
			_start(e, "sweep_aim", SWEEP_AIM)
		"dash":
			_start(e, "dash_aim", DASH_AIM)
			e.charging = true
			Audio.sfx("boss_charge")
		"jump":
			_start(e, "jump_crouch", JUMP_CROUCH)
		"summon":
			_start(e, "summon", SUMMON_TIME)
			Audio.sfx("boss_warning", 1.2)

static func _start(e: Enemy, attack: String, frames: int) -> void:
	e.nm_attack = attack
	e.nm_timer = frames
	e.nm_hit = false

static func _end(e: Enemy) -> void:
	e.nm_attack = ""
	e.charge_telegraph = 0
	# Les doubles attaquent moins souvent que l'original.
	var base := 70 if e.is_final else 110
	e.nm_cooldown = base + randi() % 50

static func _hit(w: World, e: Enemy, mult: float, contact: bool) -> void:
	w.hit_player(e.dmg * mult)
	if contact:
		var elem: Dictionary = Data.ELEMENTS[e.element]
		var lifesteal: float = elem.get("lifesteal", 0.0)
		if lifesteal > 0.0:
			e.hp = minf(e.max_hp, e.hp + e.dmg * mult * lifesteal)
		if elem.get("burn", false):
			w.player.burn_timer = 120

static func _laser(w: World, e: Enemy) -> void:
	var p := w.player
	var eye := e.eye_position()
	var a := e.nm_dir.angle()
	a += clampf(angle_difference(a, (p.position - eye).angle()), -LASER_TURN, LASER_TURN)
	e.nm_dir = Vector2.from_angle(a)
	w.shake(1.5)
	if e.nm_timer % LASER_TICK == 0:
		var d := Geometry2D.get_closest_point_to_segment(p.position, eye, eye + e.nm_dir * LASER_LEN)
		if d.distance_to(p.position) < LASER_HALF + p.radius:
			_hit(w, e, 0.5, false)
	if e.nm_timer <= 0:
		_end(e)

static func _lash(w: World, e: Enemy) -> void:
	var p := w.player
	var reach := lash_reach(e)
	var root := e.position + e.tentacle_root()
	if not e.nm_hit:
		for d: Vector2 in e.nm_lash:
			var c := Geometry2D.get_closest_point_to_segment(p.position, root, root + d * reach)
			if c.distance_to(p.position) < LASH_HALF + p.radius:
				e.nm_hit = true
				_hit(w, e, 1.0, false)
				w.shake(3.0)
				break
	if e.nm_timer <= 0:
		_end(e)

static func _minis(w: World) -> int:
	var n := 0
	for o in w.enemies:
		if o.is_mini:
			n += 1
	return n

## Mini-créatures : monstres de mêlée ordinaires d'élément Chaos (brûlure et vol
## de vie), en cercle autour du boss.
static func _summon(w: World, e: Enemy) -> void:
	var n := mini(SUMMON_COUNT, MINIS_MAX - _minis(w))
	var a0 := randf() * TAU
	for i in n:
		var m := Enemy.new()
		m.position = _clamp(m, e.position + Vector2.from_angle(a0 + TAU * i / n) * 80.0)
		m.element = e.element
		m.is_mini = true
		m.radius = 14.0
		m.hp = e.max_hp * 0.025
		m.max_hp = m.hp
		m.dmg = e.dmg * 0.35
		m.speed = 1.9
		m.gold_value = 3
		m.attack_cooldown = 30
		w.queue_spawn(m)
		Fx.puff(w.fx_layer, m.position, e.glow, 1.5)
	w.shake(4.0)

static func _split(w: World, e: Enemy) -> void:
	e.nm_splits += 1
	var c := Enemy.new()
	c.position = e.position
	c.element = e.element
	c.is_clone = true
	c.radius = 30.0
	c.hp = e.max_hp * 0.12
	c.max_hp = c.hp
	c.dmg = e.dmg * 0.6
	c.speed = e.speed * 1.2
	c.gold_value = roundi(e.gold_value * 0.1)
	c.nm_cooldown = 60
	var side := Vector2.from_angle(randf() * TAU) * 6.0
	c.nm_slide = side
	c.nm_slide_timer = SLIDE_TIME
	e.nm_slide = -side
	e.nm_slide_timer = SLIDE_TIME
	w.queue_spawn(c)
	Fx.puff(w.fx_layer, e.position, e.glow, 3.0)
	Fx.float_text(w.fx_layer, e.position + Vector2(0, -e.top() - 20), "Elle se dédouble !", e.glow, true)
	Audio.sfx("boss_warning")
	w.shake(5.0)

static func _clamp(e: Enemy, pos: Vector2) -> Vector2:
	var margin := Vector2.ONE * e.radius
	return pos.clamp(margin, Data.ARENA - margin)
