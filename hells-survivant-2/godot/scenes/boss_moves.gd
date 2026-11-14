class_name BossMoves
extends RefCounted
## Attaques spéciales des 7 boss d'élément et du Nécromancien Putréfié, en plus
## de leur logique commune de `World` (mêlée ou tir, charge). La Créature
## cauchemardesque a les siennes, dans `Nightmare`. Comme le reste de `World`,
## tout se compte en frames de 1/60 s.
##
## Toutes les attaques sont télégraphiées : le boss luit, et un repère au sol
## montre la zone touchée, le temps de s'écarter. Pendant une attaque, le boss
## ne marche, ne tire ni ne charge. Il en choisit une quand son compteur
## (`Enemy.sp_cooldown`) tombe à zéro, parmi celles dont le héros est à portée :
## - Chevalier de cendres : souffle de cendres en cône, qui suit lentement le héros ;
## - Golem de sang : morsure à distance (des mâchoires se referment sur le
##   héros et le soignent), et éclaboussures qui laissent des flaques brûlantes ;
## - Créature infernale : vague de feu qui déferle en ligne droite et enflamme ;
## - Mangeur de soldats : il bondit, saisit le héros, le croque trois fois puis
##   le projette à l'autre bout de l'arène ;
## - Soldat blessé : gerbe d'épées lancées, coup de bouclier qui repousse ;
## - Voix Putréfiée : arbres qui jaillissent du sol en ligne jusqu'au héros puis
##   le fouettent de leurs branches, et arbre qui pousse près de lui et s'abat ;
## - Sbire de l'ombre : coup de tête en ruée, qui repousse et étourdit ;
## - Nécromancien Putréfié : coup de bâton qui repousse, et invocation de
##   monstres ordinaires de n'importe quel élément (jamais de mini-créatures du
##   Chaos), qui meurent avec lui ; et trois âmes, monstres fragiles qui
##   traquent le héros et qu'il faut abattre.
## Dans le Conclave, rien de tout cela ne blesse ni ne déplace le héros
## (`World.harms_player`).

## Attaques de chaque boss, clé comme `Data.BOSS_ATTACKS`. Une attaque ajoutée
## ici doit aussi l'être là, sinon l'infobulle du Conclave ment.
const MOVES := {
	"cendres": ["breath"],
	"sang": ["bite", "splash"],
	"violence": ["swords", "shield"],
	"terre": ["roots", "treefall"],
	"feu": ["firewave"],
	"destruction": ["devour"],
	"ombre": ["headbutt"],
	"final_ombre": ["staff", "raise", "souls"],
}
## Distance au héros au-delà de laquelle une attaque n'est pas tentée.
const REACH := {
	"breath": 250.0, "bite": 420.0, "splash": 400.0, "firewave": 380.0,
	"devour": 300.0, "swords": 420.0, "shield": 130.0, "roots": 380.0,
	"treefall": 460.0, "headbutt": 300.0, "staff": 150.0, "raise": INF,
	"souls": 520.0,
}

const BREATH_AIM := 36
## Dernières frames de visée : la direction est figée.
const BREATH_LOCK := 12
const BREATH_TIME := 54
const BREATH_LEN := 250.0
## Demi-angle du cône, en radians.
const BREATH_HALF := 0.45
## Le souffle suit le héros, plus lentement qu'il ne court de côté.
const BREATH_TURN := 0.008
const BREATH_TICK := 12

const BITE_AIM := 48
const BITE_LOCK := 16
const BITE_SNAP := 12
const BITE_R := 46.0

const SPLASH_AIM := 24
const SPLASH_FLY := 34
const SPLASH_COUNT := 5
const SPLASH_SPREAD := 110.0
const PUDDLE_R := 32.0
const PUDDLE_TIME := 240
const PUDDLE_TICK := 20

const WAVE_AIM := 30
const WAVE_TIME := 60
const WAVE_SPEED := 7.0
## Demi-largeur du front : il s'élargit en avançant.
const WAVE_HALF_MIN := 40.0
const WAVE_HALF_MAX := 170.0
const WAVE_DEPTH := 18.0

const DEVOUR_AIM := 40
const DEVOUR_LUNGE := 20
const DEVOUR_SPEED := 10.0
const DEVOUR_HOLD := 54
## Un coup de dents toutes les `DEVOUR_BITE` frames pendant la prise.
const DEVOUR_BITE := 18
const DEVOUR_THROW_SPEED := 20.0

const SWORDS_AIM := 28
const SWORDS_COUNT := 5
const SWORDS_SPREAD := 0.2
const SWORD_SPEED := 5.5

const SHIELD_AIM := 22
const SHIELD_TIME := 12
const SHIELD_SPEED := 7.0
const SHIELD_KNOCK := 140.0

const ROOTS_AIM := 40
const ROOTS_COUNT := 5
## Écart entre deux arbres qui jaillissent, de proche en proche.
const ROOTS_STEP := 8
const ROOTS_STAND := 50
const ROOTS_SINK := 14
const ROOTS_R := 34.0
## Coup de branches, `ROOTS_WHIP` frames après le jaillissement.
const ROOTS_WHIP := 24
const ROOTS_WHIP_R := 80.0
const TREE_SCALE := 2.5

const FALL_GROW := 14
const FALL_AIM := 50
const FALL_DROP := 12
const FALL_LIE := 36
const FALL_SCALE := 4.0
## Zone touchée : le tronc (rectangle) et la ramure (disque au bout). Sur le
## sprite, la ramure est centrée 20 texels au-dessus du pied de l'arbre.
const FALL_TRUNK := 60.0
const FALL_HALF := 18.0
const FALL_CROWN := 20.0 * FALL_SCALE
const FALL_CROWN_R := 50.0

const HEAD_AIM := 34
const HEAD_LOCK := 10
const HEAD_TIME := 22
const HEAD_SPEED := 9.0
const HEAD_KNOCK := 150.0
const HEAD_STUN := 70

const STAFF_AIM := 26
const STAFF_TIME := 12
const STAFF_R := 150.0
const STAFF_HALF := 1.1
const STAFF_KNOCK := 190.0

const RAISE_TIME := 50
const RAISE_COUNT := 3
const RAISED_MAX := 6

## Âmes du Nécromancien : trois monstres fragiles qui traquent le héros, à
## abattre. Plus lentes que lui, elles se distancent en courant.
const SOULS_TIME := 44
const SOULS_COUNT := 3
const SOULS_MAX := 6
const SOUL_SPEED := 2.3
const SOUL_COLOR := Color(0.45, 1.0, 0.65)

## Mode smoke : nombre de fois où chaque attaque a été lancée.
static var played := {}

static func _key(e: Enemy) -> String:
	return ("final_" if e.is_final else "") + e.element

## Un boss qui a des attaques spéciales (pas la Créature cauchemardesque).
static func handles(e: Enemy) -> bool:
	return e.is_boss and MOVES.has(_key(e))

static func busy(e: Enemy) -> bool:
	return e.sp_attack != ""

## Le boss se prépare : contour lumineux, comme avant une charge.
static func telegraphing(e: Enemy) -> bool:
	match e.sp_attack:
		"":
			return false
		"raise", "souls":
			return true
		"roots":
			return e.sp_age < ROOTS_AIM
		"treefall":
			return e.sp_age < FALL_GROW + FALL_AIM
	return e.sp_attack.ends_with("_aim")

## Visuel des attaques : un calque au sol, sous les créatures, et un par-dessus.
static func attach_fx(w: World, e: Enemy) -> void:
	for ground in [true, false]:
		var fx := Visual.new()
		fx.enemy = e
		fx.player = w.player
		fx.ground = ground
		fx.material = Fx.unshaded()
		(w.ground_layer if ground else w.fx_layer).add_child(fx)

## Effets qui durent au-delà de l'attaque : les flaques de sang.
static func tick_hazards(w: World, e: Enemy) -> void:
	var p := w.player
	for i in range(e.puddles.size() - 1, -1, -1):
		var pd := e.puddles[i]
		pd.z -= 1.0
		if pd.z <= 0.0:
			e.puddles.remove_at(i)
			continue
		e.puddles[i] = pd
		if int(pd.z) % PUDDLE_TICK == 0 and Vector2(pd.x, pd.y).distance_to(p.position) < PUDDLE_R + p.radius * 0.5:
			_hurt(w, e, 0.2)

## Décompte jusqu'à la prochaine attaque et la lance ; vrai si une attaque
## commence (le boss ne fait rien d'autre ce tick).
static func try_start(w: World, e: Enemy, dist: float) -> bool:
	e.sp_cooldown -= 1
	if e.sp_cooldown > 0:
		return false
	var options: Array[String] = []
	for m: String in MOVES[_key(e)]:
		if dist <= float(REACH[m]) and (m != "raise" or _raised(w) < RAISED_MAX) \
				and (m != "souls" or _souls(w) < SOULS_MAX):
			options.append(m)
	if options.is_empty():
		# Héros hors de portée : on retente bientôt.
		e.sp_cooldown = 20
		return false
	var fresh := options.filter(func(o: String) -> bool: return o != e.sp_last)
	var pick: String = (fresh if not fresh.is_empty() else options).pick_random()
	e.sp_last = pick
	if Game.smoke_test:
		played[pick] = int(played.get(pick, 0)) + 1
	_begin(w, e, pick)
	return true

static func _begin(w: World, e: Enemy, move: String) -> void:
	var p := w.player
	var dir := (p.position - e.position).normalized()
	e.sp_dir = dir
	e.sp_points.clear()
	match move:
		"breath":
			_start(e, "breath_aim", BREATH_AIM)
			Audio.sfx("boss_charge", 0.7)
		"bite":
			e.sp_origin = p.position
			_start(e, "bite_aim", BITE_AIM)
			Audio.sfx("boss_charge", 1.4)
		"splash":
			_start(e, "splash_aim", SPLASH_AIM)
			Audio.sfx("boss_charge", 1.1)
		"firewave":
			_start(e, "firewave_aim", WAVE_AIM)
			Audio.sfx("boss_charge", 0.9)
		"devour":
			_start(e, "devour_aim", DEVOUR_AIM)
			Audio.sfx("boss_charge", 0.6)
		"swords":
			_start(e, "swords_aim", SWORDS_AIM)
			Audio.sfx("boss_charge", 1.2)
		"shield":
			_start(e, "shield_aim", SHIELD_AIM)
		"roots":
			# Une ligne d'arbres, du pied du boss jusqu'un peu au-delà du héros.
			var dist := e.position.distance_to(p.position)
			for i in ROOTS_COUNT:
				var d := lerpf(e.top() + 20.0, dist + 40.0, float(i) / (ROOTS_COUNT - 1))
				e.sp_points.append(_inside(e.position + dir * d, 20.0))
			_start(e, "roots", ROOTS_AIM + ROOTS_STEP * (ROOTS_COUNT - 1) + ROOTS_STAND + ROOTS_SINK)
			Audio.sfx("boss_charge", 0.5)
		"treefall":
			# L'arbre pousse à une longueur de tronc du héros, du côté où il tient
			# dans l'arène : sa ramure s'abattra sur lui.
			var base := p.position
			for _i in 12:
				var cand := p.position + Vector2.from_angle(randf() * TAU) * FALL_CROWN
				base = cand
				if cand == _inside(cand, 30.0):
					break
			base = _inside(base, 30.0)
			e.sp_origin = base
			e.sp_dir = (p.position - base).normalized() if p.position != base else Vector2.DOWN
			_start(e, "treefall", FALL_GROW + FALL_AIM + FALL_DROP + FALL_LIE)
		"headbutt":
			_start(e, "headbutt_aim", HEAD_AIM)
			Audio.sfx("boss_charge", 1.3)
		"staff":
			_start(e, "staff_aim", STAFF_AIM)
		"raise":
			var a0 := randf() * TAU
			for i in RAISE_COUNT:
				e.sp_points.append(_inside(e.position + Vector2.from_angle(a0 + TAU * i / RAISE_COUNT) * 90.0, 24.0))
			_start(e, "raise", RAISE_TIME)
			Audio.sfx("boss_warning", 0.8)
		"souls":
			# Les âmes sortent au-dessus de lui, en éventail vers le héros.
			for i in SOULS_COUNT:
				var d := dir.rotated((i - (SOULS_COUNT - 1) / 2.0) * 0.7)
				e.sp_points.append(_inside(e.position + Vector2(0, -e.top() * 0.4) + d * (e.radius + 30.0), 20.0))
			_start(e, "souls", SOULS_TIME)
			Audio.sfx("boss_charge", 1.6)

static func tick(w: World, e: Enemy) -> void:
	var p := w.player
	var to := p.position - e.position
	var dist := maxf(to.length(), 1.0)
	var dir := to / dist
	e.sp_timer -= 1
	e.sp_age += 1
	match e.sp_attack:
		"breath_aim":
			if e.sp_timer > BREATH_LOCK:
				e.sp_dir = dir
			if e.sp_timer <= 0:
				_start(e, "breath", BREATH_TIME)
				Audio.sfx("throw", 0.6)
		"breath":
			var a := e.sp_dir.angle()
			a += clampf(angle_difference(a, dir.angle()), -BREATH_TURN, BREATH_TURN)
			e.sp_dir = Vector2.from_angle(a)
			if e.sp_age % BREATH_TICK == 0 and _in_cone(e.position, e.sp_dir, BREATH_LEN, BREATH_HALF, p.position, p.radius):
				_hurt(w, e, 0.45)
			if e.sp_timer <= 0:
				_end(e)
		"bite_aim":
			# Les mâchoires suivent le héros avec un temps de retard, puis se figent.
			if e.sp_timer > BITE_LOCK:
				e.sp_origin = e.sp_origin.lerp(p.position, 0.12)
			if e.sp_timer <= 0:
				_start(e, "bite", BITE_SNAP)
				Audio.sfx("attack", 0.6)
				if p.position.distance_to(e.sp_origin) < BITE_R + p.radius * 0.5 and World.harms_player():
					_hurt(w, e, 1.2)
					e.hp = minf(e.max_hp, e.hp + e.dmg * 0.6)
					Fx.sparks(w.fx_layer, p.position, Color(0.85, 0.05, 0.1))
		"bite":
			if e.sp_timer <= 0:
				_end(e)
		"splash_aim":
			if e.sp_timer <= 0:
				e.sp_points.append(_inside(p.position, 20.0))
				for i in SPLASH_COUNT - 1:
					var off := Vector2.from_angle(randf() * TAU) * randf_range(40.0, SPLASH_SPREAD)
					e.sp_points.append(_inside(p.position + off, 20.0))
				e.sp_origin = e.position
				_start(e, "splash", SPLASH_FLY)
				Audio.sfx("throw", 0.7)
		"splash":
			if e.sp_timer <= 0:
				var hit := false
				for pt in e.sp_points:
					e.puddles.append(Vector3(pt.x, pt.y, PUDDLE_TIME))
					Fx.puff(w.fx_layer, pt, Color(0.75, 0.02, 0.08), 1.2)
					if not hit and pt.distance_to(p.position) < PUDDLE_R + p.radius:
						hit = true
						_hurt(w, e, 0.6)
				Audio.sfx("hit_enemy", 0.6)
				_end(e)
		"firewave_aim":
			if e.sp_timer > 8:
				e.sp_dir = dir
			if e.sp_timer <= 0:
				e.sp_origin = e.position
				_start(e, "firewave", WAVE_TIME)
				Audio.sfx("boss_warning", 0.8)
				w.shake(3.0)
		"firewave":
			if not e.sp_hit:
				var rel := p.position - (e.sp_origin + e.sp_dir * wave_dist(e))
				if absf(rel.dot(e.sp_dir)) < WAVE_DEPTH + p.radius and absf(rel.dot(e.sp_dir.orthogonal())) < wave_half(e) + p.radius * 0.5:
					e.sp_hit = true
					_hurt(w, e, 1.2)
					if World.harms_player():
						p.burn_timer = 120
			if e.sp_timer <= 0:
				_end(e)
		"devour_aim":
			if e.sp_timer > 8:
				e.sp_dir = dir
			if e.sp_timer <= 0:
				_start(e, "devour_lunge", DEVOUR_LUNGE)
				w.shake(3.0)
		"devour_lunge":
			e.position = _clamp(e, e.position + e.sp_dir * DEVOUR_SPEED)
			if dist < e.radius + p.radius + 12.0:
				# Dans le Conclave, il croque dans le vide : le héros reste libre.
				_start(e, "devour_hold", DEVOUR_HOLD)
				if World.harms_player() and p.held_by == null and p.knock_timer == 0:
					p.held_by = e
					Fx.float_text(w.fx_layer, p.position + Vector2(0, -p.radius - 30), "Saisi !", Color("#ff6040"))
			elif e.sp_timer <= 0:
				_end(e)
		"devour_hold":
			if p.held_by == e:
				p.position = e.position + mouth(e)
			if e.sp_age % DEVOUR_BITE == 0:
				Audio.sfx("hit_enemy", 0.5)
				w.shake(2.5)
				if p.held_by == e:
					_hurt(w, e, 0.5)
			if e.sp_timer <= 0:
				if p.held_by == e:
					p.held_by = null
					var away := mouth(e).normalized()
					var target := Nightmare.knock_target(e.position, p.position, away, p.radius)
					var frames := clampi(ceili(p.position.distance_to(target) / DEVOUR_THROW_SPEED * 2.0), 10, 60)
					_hurt(w, e, 0.6)
					w.knock_player(target, frames)
					w.shake(6.0)
				Audio.sfx("throw", 0.5)
				_end(e)
		"swords_aim":
			if e.sp_timer > 6:
				e.sp_dir = dir
			if e.sp_timer <= 0:
				for i in SWORDS_COUNT:
					var off := (i - (SWORDS_COUNT - 1) / 2.0) * SWORDS_SPREAD
					w.shoot(e.position, e.sp_dir.rotated(off) * SWORD_SPEED, e.dmg * 0.7, 9.0, false, true)
				Audio.sfx("throw", 1.3)
				_end(e)
		"shield_aim":
			if e.sp_timer > 6:
				e.sp_dir = dir
			if e.sp_timer <= 0:
				_start(e, "shield", SHIELD_TIME)
				Audio.sfx("attack", 0.5)
		"shield":
			e.position = _clamp(e, e.position + e.sp_dir * SHIELD_SPEED)
			if not e.sp_hit and dist < e.radius + p.radius + 22.0:
				e.sp_hit = true
				_hurt(w, e, 1.1)
				w.push_player(e.sp_dir, SHIELD_KNOCK, 14)
				w.shake(5.0)
			if e.sp_timer <= 0:
				_end(e)
		"roots":
			for i in e.sp_points.size():
				var pt := e.sp_points[i]
				var at := ROOTS_AIM + ROOTS_STEP * i
				if e.sp_age == at:
					Fx.puff(w.fx_layer, pt, Color(0.45, 0.28, 0.12), 1.4)
					w.shake(2.0)
					Audio.sfx("hit_enemy", 0.4)
					# Un seul jaillissement blesse : le héros pris dans la ligne
					# n'encaisse pas les cinq arbres.
					if not e.sp_hit and pt.distance_to(p.position) < ROOTS_R + p.radius:
						e.sp_hit = true
						_hurt(w, e, 0.9)
				elif e.sp_age == at + ROOTS_WHIP and pt.distance_to(p.position) < ROOTS_WHIP_R + p.radius:
					Audio.sfx("attack", 0.7)
					# Un seul coup de branches, lui aussi.
					if not e.sp_hit2:
						e.sp_hit2 = true
						_hurt(w, e, 0.7)
			if e.sp_timer <= 0:
				_end(e)
		"treefall":
			if e.sp_age == FALL_GROW:
				Audio.sfx("boss_charge", 0.6)
			if e.sp_age == FALL_GROW + FALL_AIM + FALL_DROP:
				w.shake(7.0)
				Audio.sfx("throw", 0.4)
				Fx.puff(w.fx_layer, e.sp_origin + e.sp_dir * FALL_CROWN, Color(0.5, 0.35, 0.15), 2.5)
				if tree_hits(e, p.position, p.radius):
					_hurt(w, e, 1.6)
			if e.sp_timer <= 0:
				_end(e)
		"headbutt_aim":
			if e.sp_timer > HEAD_LOCK:
				e.sp_dir = dir
			if e.sp_timer <= 0:
				_start(e, "headbutt", HEAD_TIME)
				Audio.sfx("attack", 0.5)
		"headbutt":
			e.position = _clamp(e, e.position + e.sp_dir * HEAD_SPEED)
			if not e.sp_hit and dist < e.radius + p.radius + 8.0:
				e.sp_hit = true
				_hurt(w, e, 1.0)
				w.push_player(e.sp_dir, HEAD_KNOCK, 16)
				w.stun_player(16 + HEAD_STUN)
				w.shake(6.0)
				# Il s'arrête net sur le coup.
				e.sp_timer = mini(e.sp_timer, 4)
			if e.sp_timer <= 0:
				_end(e)
		"staff_aim":
			if e.sp_timer > 6:
				e.sp_dir = dir
			if e.sp_timer <= 0:
				_start(e, "staff", STAFF_TIME)
				Audio.sfx("attack", 0.4)
				if dist < STAFF_R + p.radius and absf(angle_difference(dir.angle(), e.sp_dir.angle())) < STAFF_HALF:
					_hurt(w, e, 1.2)
					w.push_player(dir, STAFF_KNOCK, 18)
					w.shake(5.0)
		"staff":
			if e.sp_timer <= 0:
				_end(e)
		"raise":
			if e.sp_timer <= 0:
				_raise(w, e)
				_end(e)
		"souls":
			if e.sp_timer <= 0:
				_release_souls(w, e)
				_end(e)

## Distance parcourue par la vague de feu depuis son départ.
static func wave_dist(e: Enemy) -> float:
	return e.top() * 0.5 + WAVE_SPEED * (WAVE_TIME - e.sp_timer)

static func wave_half(e: Enemy) -> float:
	return lerpf(WAVE_HALF_MIN, WAVE_HALF_MAX, 1.0 - float(e.sp_timer) / WAVE_TIME)

## Gueule du Mangeur de soldats, où il tient le héros (coordonnées locales).
static func mouth(e: Enemy) -> Vector2:
	return Vector2(-9.0 if e.face_left else 9.0, -3.0) * e.sprite_scale

## L'arbre abattu touche-t-il ce point ? Le tronc puis la ramure, au bout.
static func tree_hits(e: Enemy, pos: Vector2, margin: float) -> bool:
	var rel := pos - e.sp_origin
	var along := rel.dot(e.sp_dir)
	if along > 0.0 and along < FALL_TRUNK and absf(rel.dot(e.sp_dir.orthogonal())) < FALL_HALF + margin:
		return true
	return pos.distance_to(e.sp_origin + e.sp_dir * FALL_CROWN) < FALL_CROWN_R + margin

static func _in_cone(from: Vector2, dir: Vector2, length: float, half: float, pos: Vector2, margin: float) -> bool:
	var rel := pos - from
	var d := rel.length()
	if d > length + margin:
		return false
	if d < margin:
		return true
	return absf(angle_difference(dir.angle(), rel.angle())) < half + asin(clampf(margin / d, 0.0, 1.0))

## Monstres invoqués par le Nécromancien encore en vie.
static func _raised(w: World) -> int:
	var n := 0
	for o in w.enemies:
		if o.is_mini and not o.is_soul and o.element != Data.CHAOS:
			n += 1
	return n

## Âmes du Nécromancien encore en vie.
static func _souls(w: World) -> int:
	var n := 0
	for o in w.enemies:
		if o.is_soul:
			n += 1
	return n

## Âmes : monstres de mêlée de la vague, fragiles, plus rapides que les autres
## mais moins que le héros. Comme les monstres invoqués, elles meurent avec le
## Nécromancien et ne rapportent presque rien.
static func _release_souls(w: World, e: Enemy) -> void:
	var n := mini(SOULS_COUNT, SOULS_MAX - _souls(w))
	for i in n:
		var m := w.make_enemy(e.element, false, false)
		m.position = e.sp_points[i % e.sp_points.size()]
		m.is_mini = true
		m.is_soul = true
		m.radius = 12.0
		m.hp = m.max_hp * 0.5
		m.max_hp = m.hp
		m.dmg = e.dmg * 0.3
		m.speed = SOUL_SPEED
		m.gold_value = 1
		m.attack_cooldown = 20
		w.queue_spawn(m)
		Fx.puff(w.fx_layer, m.position, SOUL_COLOR, 1.2)
	Audio.sfx("boss_warning", 1.5)

## Invocation du Nécromancien : des monstres ordinaires de la vague, d'un
## élément tiré au hasard parmi les 7 (jamais une mini-créature du Chaos).
## Marqués `is_mini`, ils meurent avec lui, et ne rapportent presque rien :
## sinon il suffirait de le laisser invoquer pour amasser de l'or.
static func _raise(w: World, e: Enemy) -> void:
	var n := mini(RAISE_COUNT, RAISED_MAX - _raised(w))
	for i in n:
		var element: String = Data.MOB_ELEMENTS.pick_random()
		var m := w.make_enemy(element, false, false)
		m.position = e.sp_points[i % e.sp_points.size()]
		m.is_mini = true
		m.gold_value = 2
		m.attack_cooldown = 30
		w.queue_spawn(m)
		Fx.puff(w.fx_layer, m.position, Color(0.65, 0.35, 1.0), 1.6)
	w.shake(4.0)

static func _start(e: Enemy, attack: String, frames: int) -> void:
	e.sp_attack = attack
	e.sp_timer = frames
	e.sp_age = 0
	e.sp_hit = false
	e.sp_hit2 = false

static func _end(e: Enemy) -> void:
	e.sp_attack = ""
	e.sp_cooldown = (130 if e.is_final else 170) + randi() % 90

static func _hurt(w: World, e: Enemy, mult: float) -> void:
	if World.harms_player():
		w.hit_player(e.dmg * mult)

static func _clamp(e: Enemy, pos: Vector2) -> Vector2:
	var margin := Vector2.ONE * e.radius
	return pos.clamp(margin, Data.ARENA - margin)

static func _inside(pos: Vector2, margin: float) -> Vector2:
	return pos.clamp(Vector2.ONE * margin, Data.ARENA - Vector2.ONE * margin)

## Visuel des attaques, en coordonnées de l'arène. Deux instances par boss : au
## sol (télégraphes, flaques), sous les créatures, et par-dessus (cendres,
## flammes, mâchoires, arbres, épées, bâton).
class Visual extends Node2D:
	const PUDDLE := preload("res://assets/sprites/fx/blood_puddle.png")
	const TREES: Array[Texture2D] = [preload("res://assets/sprites/fx/tree_0.png"), preload("res://assets/sprites/fx/tree_1.png")]
	const SWORD := preload("res://assets/sprites/fx/sword.png")
	const SHIELD := preload("res://assets/sprites/fx/shield.png")
	const STAFF := preload("res://assets/sprites/fx/staff.png")
	const BLOOD := Color(0.75, 0.02, 0.08)
	const ARCANE := Color(0.7, 0.4, 1.0)
	const WOOD := Color(0.9, 0.6, 0.2)
	var enemy: Enemy
	var player: Player
	var ground := false
	var _t := 0.0

	func _process(delta: float) -> void:
		# Le boss mort ou retiré emporte ses attaques et ses flaques.
		if not is_instance_valid(enemy) or enemy._dying > 0.0:
			queue_free()
			return
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(enemy):
			return
		if ground:
			_draw_ground(enemy)
		else:
			_draw_top(enemy)

	func _draw_ground(e: Enemy) -> void:
		for pd in e.puddles:
			var fade := clampf(pd.z / 40.0, 0.0, 1.0)
			var r := BossMoves.PUDDLE_R * 1.3
			draw_texture_rect(PUDDLE, Rect2(Vector2(pd.x, pd.y) - Vector2.ONE * r, Vector2.ONE * r * 2.0), false, Color(1, 1, 1, 0.85 * fade))
		var k := float(e.sp_timer)
		var blink := 0.5 + 0.5 * sin(_t * 20.0)
		var col := e.glow
		match e.sp_attack:
			"breath_aim":
				var locked := k <= BossMoves.BREATH_LOCK
				_cone(e.position, e.sp_dir, BossMoves.BREATH_LEN, BossMoves.BREATH_HALF,
					Color(0.85, 0.85, 0.85, 0.1 + (0.15 * blink if locked else 0.05)), Color(0.9, 0.9, 0.9, 0.7 if locked else 0.4))
			"breath":
				_cone(e.position, e.sp_dir, BossMoves.BREATH_LEN, BossMoves.BREATH_HALF, Color(0.5, 0.5, 0.5, 0.12), Color(0.8, 0.8, 0.8, 0.25))
			"bite_aim":
				var locked := k <= BossMoves.BITE_LOCK
				draw_circle(e.sp_origin, BossMoves.BITE_R, Color(BLOOD, 0.12 + (0.2 * blink if locked else 0.0)))
				draw_arc(e.sp_origin, BossMoves.BITE_R, 0.0, TAU, 40, Color(1, 0.15, 0.2, 0.85 if locked else 0.45), 2.5)
			"splash":
				var f := 1.0 - k / BossMoves.SPLASH_FLY
				for pt in e.sp_points:
					draw_circle(pt, BossMoves.PUDDLE_R * f, Color(BLOOD, 0.2))
					draw_arc(pt, BossMoves.PUDDLE_R, 0.0, TAU, 32, Color(1, 0.2, 0.2, 0.7), 2.0)
			"firewave_aim":
				var length := BossMoves.WAVE_SPEED * BossMoves.WAVE_TIME
				_wedge(e.position, e.sp_dir, length, BossMoves.WAVE_HALF_MIN, BossMoves.WAVE_HALF_MAX, Color(1, 0.45, 0.05, 0.08 + 0.1 * blink))
				for i in 5:
					var c := e.position + e.sp_dir * (60.0 + 70.0 * i + fposmod(_t * 120.0, 70.0))
					_chevron(c, e.sp_dir, 16.0, Color(1, 0.6, 0.1, 0.6))
			"firewave":
				_wedge(e.sp_origin, e.sp_dir, BossMoves.wave_dist(e), BossMoves.WAVE_HALF_MIN, BossMoves.wave_half(e), Color(1, 0.3, 0.02, 0.1))
			"devour_aim":
				_band(e.position, e.sp_dir, BossMoves.DEVOUR_SPEED * BossMoves.DEVOUR_LUNGE + e.radius, e.radius, Color(col, 0.12 + 0.12 * blink))
			"shield_aim":
				_band(e.position, e.sp_dir, BossMoves.SHIELD_SPEED * BossMoves.SHIELD_TIME + e.radius + 30.0, e.radius, Color(col, 0.12 + 0.12 * blink))
			"headbutt_aim":
				_band(e.position, e.sp_dir, BossMoves.HEAD_SPEED * BossMoves.HEAD_TIME + e.radius, e.radius * 0.8, Color(col, 0.12 + 0.15 * blink))
			"staff_aim":
				_cone(e.position, e.sp_dir, BossMoves.STAFF_R, BossMoves.STAFF_HALF, Color(ARCANE, 0.1 + 0.12 * blink), Color(ARCANE, 0.6))
			"roots":
				for i in e.sp_points.size():
					var pt := e.sp_points[i]
					var at := BossMoves.ROOTS_AIM + BossMoves.ROOTS_STEP * i
					if e.sp_age < at:
						# Le sol se fend là où l'arbre va jaillir.
						var f := clampf(float(e.sp_age) / BossMoves.ROOTS_AIM, 0.0, 1.0)
						draw_circle(pt, BossMoves.ROOTS_R * f, Color(0.3, 0.17, 0.06, 0.4))
						draw_arc(pt, BossMoves.ROOTS_R, 0.0, TAU, 32, Color(WOOD, 0.35 + 0.4 * blink), 2.0)
						for j in 5:
							var d := Vector2.from_angle(TAU * j / 5.0 + i)
							draw_polyline(PackedVector2Array([pt, pt + d * 12.0 * f + d.orthogonal() * 4.0, pt + d * 26.0 * f]), Color(0.15, 0.08, 0.02, 0.8), 2.0)
					elif e.sp_age < at + BossMoves.ROOTS_WHIP:
						draw_arc(pt, BossMoves.ROOTS_WHIP_R, 0.0, TAU, 40, Color(WOOD, 0.2 + 0.25 * blink), 1.5)
			"treefall":
				var hit_at := BossMoves.FALL_GROW + BossMoves.FALL_AIM + BossMoves.FALL_DROP
				if e.sp_age < hit_at:
					var f := clampf(float(e.sp_age) / (BossMoves.FALL_GROW + BossMoves.FALL_AIM), 0.0, 1.0)
					var fill := Color(WOOD, (0.1 + 0.15 * blink) * f)
					_band(e.sp_origin, e.sp_dir, BossMoves.FALL_TRUNK, BossMoves.FALL_HALF, fill)
					var crown := e.sp_origin + e.sp_dir * BossMoves.FALL_CROWN
					draw_circle(crown, BossMoves.FALL_CROWN_R, fill)
					draw_arc(crown, BossMoves.FALL_CROWN_R, 0.0, TAU, 40, Color(WOOD, 0.7 * f), 2.0)
			"raise":
				var f := 1.0 - k / BossMoves.RAISE_TIME
				for pt in e.sp_points:
					draw_circle(pt, 30.0 * f, Color(ARCANE, 0.22))
					for j in 6:
						var a := TAU * j / 6.0 + _t * 3.0
						draw_arc(pt, 32.0, a, a + 0.6, 6, Color(ARCANE, 0.8), 2.5)
			"souls":
				var f := 1.0 - k / BossMoves.SOULS_TIME
				for pt in e.sp_points:
					draw_circle(pt, 22.0 * f, Color(BossMoves.SOUL_COLOR, 0.2))
					draw_arc(pt, 24.0, 0.0, TAU, 24, Color(BossMoves.SOUL_COLOR, 0.4 + 0.4 * sin(_t * 20.0)), 2.0)

	func _draw_top(e: Enemy) -> void:
		var k := float(e.sp_timer)
		match e.sp_attack:
			"breath":
				var open := clampf(minf(BossMoves.BREATH_TIME - k, k) / 8.0, 0.0, 1.0)
				for i in 36:
					var h1 := _hash(i * 1.37)
					var h2 := _hash(i * 7.91 + 3.0)
					var f := fposmod(_t * 1.5 + h1, 1.0)
					var d := e.sp_dir.rotated((h2 * 2.0 - 1.0) * BossMoves.BREATH_HALF * 0.9)
					var pos := e.position + d * (e.radius * 0.6 + f * (BossMoves.BREATH_LEN - e.radius * 0.6))
					var g := lerpf(0.85, 0.35, f)
					draw_circle(pos, 5.0 + 17.0 * f, Color(g, g, g, 0.5 * (1.0 - f) * open))
					if i % 6 == 0:
						draw_circle(pos, 2.5, Color(1, 0.55, 0.15, (1.0 - f) * open))
			"bite_aim":
				if k <= BossMoves.BITE_LOCK:
					_jaws(e.sp_origin, BossMoves.BITE_R, BossMoves.BITE_R * 0.9, 0.8)
			"bite":
				var f := 1.0 - k / BossMoves.BITE_SNAP
				_jaws(e.sp_origin, BossMoves.BITE_R * maxf(0.0, 1.0 - f * 3.0), BossMoves.BITE_R * 0.9, 1.0 - f * 0.7)
			"splash":
				var f := 1.0 - k / BossMoves.SPLASH_FLY
				for pt in e.sp_points:
					var pos := e.sp_origin.lerp(pt, f) + Vector2(0, -sin(f * PI) * 90.0)
					draw_circle(pos, 8.0, BLOOD)
					draw_circle(pos + Vector2(-2, -2), 3.0, Color(1, 0.4, 0.4))
			"firewave":
				_flames(e)
			"devour_hold":
				var phase := float(e.sp_age % BossMoves.DEVOUR_BITE) / BossMoves.DEVOUR_BITE
				_jaws(e.position + BossMoves.mouth(e), 26.0 * absf(cos(phase * PI)), 30.0, 1.0)
			"swords_aim":
				var f := 1.0 - k / BossMoves.SWORDS_AIM
				for i in BossMoves.SWORDS_COUNT:
					var d := e.sp_dir.rotated((i - (BossMoves.SWORDS_COUNT - 1) / 2.0) * BossMoves.SWORDS_SPREAD * 2.0)
					var pos := e.position + Vector2(0, -e.top() * 0.6) + d * (e.radius + 6.0) * f
					_sprite(SWORD, pos, d.angle() + PI / 4.0, 2.0, f)
			"shield_aim", "shield":
				var reach := e.radius + (14.0 if e.sp_attack == "shield" else 4.0)
				_sprite(SHIELD, e.position + e.sp_dir * reach, 0.0, 2.2, 1.0)
				if e.sp_attack == "shield":
					var a := e.sp_dir.angle()
					draw_arc(e.position, reach + 24.0, a - 0.7, a + 0.7, 16, Color(1, 1, 1, k / BossMoves.SHIELD_TIME), 5.0)
			"staff_aim":
				var hand := e.position + Vector2(0, -e.top() * 0.3)
				var a := e.sp_dir.angle() - BossMoves.STAFF_HALF - 0.5 + sin(_t * 18.0) * 0.05
				_sprite(STAFF, hand + Vector2.from_angle(a) * 30.0, a + PI / 4.0, 3.5, 1.0)
			"staff":
				var hand := e.position + Vector2(0, -e.top() * 0.3)
				var f := 1.0 - k / BossMoves.STAFF_TIME
				var a0 := e.sp_dir.angle() - BossMoves.STAFF_HALF
				var a := lerpf(a0, e.sp_dir.angle() + BossMoves.STAFF_HALF, minf(1.0, f * 2.0))
				draw_arc(e.position, BossMoves.STAFF_R * 0.8, a0, a, 20, Color(ARCANE, 0.7 * (1.0 - f)), 14.0)
				_sprite(STAFF, hand + Vector2.from_angle(a) * 40.0, a + PI / 4.0, 3.5, 1.0)
			"roots":
				for i in e.sp_points.size():
					var life := e.sp_age - (BossMoves.ROOTS_AIM + BossMoves.ROOTS_STEP * i)
					if life < 0 or life >= BossMoves.ROOTS_STAND + BossMoves.ROOTS_SINK:
						continue
					var pt := e.sp_points[i]
					var grow := clampf(life / 6.0, 0.0, 1.0)
					var sink := clampf(float(life - BossMoves.ROOTS_STAND) / BossMoves.ROOTS_SINK, 0.0, 1.0)
					# Coup de branches : l'arbre se penche vers le héros, puis revient.
					var lean := 0.0
					var wl := life - (BossMoves.ROOTS_WHIP - 8)
					if wl >= 0 and wl < 16:
						lean = sin(wl / 16.0 * PI) * 0.7 * signf(player.position.x - pt.x)
					draw_set_transform(pt, lean, Vector2(BossMoves.TREE_SCALE, BossMoves.TREE_SCALE * grow * (1.0 - sink)))
					draw_texture(TREES[i % 2], Vector2(-16, -30), Color(1, 1, 1, 1.0 - sink * 0.5))
					draw_set_transform(Vector2.ZERO)
			"treefall":
				var grow := clampf(float(e.sp_age) / BossMoves.FALL_GROW, 0.0, 1.0)
				var aim := clampf(float(e.sp_age - BossMoves.FALL_GROW) / BossMoves.FALL_AIM, 0.0, 1.0)
				var drop := clampf(float(e.sp_age - BossMoves.FALL_GROW - BossMoves.FALL_AIM) / BossMoves.FALL_DROP, 0.0, 1.0)
				# L'arbre debout pointe vers le haut ; abattu, vers le héros.
				var rot := wrapf(e.sp_dir.angle() + PI / 2.0, -PI, PI) * drop * drop
				if drop == 0.0:
					rot = sin(_t * 25.0) * 0.04 * aim
				var fade := clampf(k / 12.0, 0.0, 1.0)
				draw_set_transform(e.sp_origin, rot, Vector2(BossMoves.FALL_SCALE, BossMoves.FALL_SCALE * grow))
				draw_texture(TREES[0], Vector2(-16, -30), Color(1, 1, 1, fade))
				draw_set_transform(Vector2.ZERO)
			"raise":
				var f := 1.0 - k / BossMoves.RAISE_TIME
				for pt in e.sp_points:
					draw_line(pt, pt + Vector2(0, -70.0 * f), Color(ARCANE, 0.6), 7.0 * f + 1.0)
					draw_circle(pt + Vector2(0, -70.0 * f), 5.0 * f, Color(1, 0.85, 1, 0.9))
			"souls":
				# Volutes qui s'échappent du Nécromancien vers chaque point d'apparition.
				var f := 1.0 - k / BossMoves.SOULS_TIME
				var from := e.position + Vector2(0, -e.top() * 0.5)
				for pt in e.sp_points:
					var pos := from.lerp(pt, f) + Vector2(sin(_t * 9.0 + pt.x) * 6.0, 0)
					draw_circle(pos, 4.0 + 7.0 * f, Color(BossMoves.SOUL_COLOR, 0.35))
					draw_circle(pos, 2.0 + 3.0 * f, Color(0.85, 1, 0.9, 0.9))

	## Front de la vague de feu : une rangée de langues de flammes.
	func _flames(e: Enemy) -> void:
		var c := e.sp_origin + e.sp_dir * BossMoves.wave_dist(e)
		var n := e.sp_dir.orthogonal()
		var half := BossMoves.wave_half(e)
		var fade := clampf(float(e.sp_timer) / 10.0, 0.0, 1.0)
		_band(c - e.sp_dir * BossMoves.WAVE_DEPTH, e.sp_dir, BossMoves.WAVE_DEPTH * 2.0, half, Color(1, 0.35, 0.05, 0.35 * fade))
		var count := int(half / 9.0) + 2
		for i in count:
			var base := c + n * lerpf(-half, half, float(i) / (count - 1))
			var h := 26.0 + 12.0 * sin(_t * 22.0 + i * 1.7)
			var tip := base + e.sp_dir * h * 0.5 + Vector2(0, -h)
			draw_colored_polygon(PackedVector2Array([base - n * 10.0, base + n * 10.0, tip]), Color(1, 0.45, 0.05, 0.85 * fade))
			var tip2 := base + e.sp_dir * h * 0.3 + Vector2(0, -h * 0.6)
			draw_colored_polygon(PackedVector2Array([base - n * 5.0, base + n * 5.0, tip2]), Color(1, 0.9, 0.3, 0.9 * fade))

	## Mâchoires écartées de `gap` de part et d'autre de `c`, crocs vers le centre.
	func _jaws(c: Vector2, gap: float, w: float, a: float) -> void:
		var gum := Color(0.5, 0.02, 0.06, a)
		var tooth := Color(0.96, 0.92, 0.84, a)
		for s: float in [-1.0, 1.0]:
			var y := c.y + s * gap
			draw_rect(Rect2(c.x - w, y - 10.0 if s < 0.0 else y, w * 2.0, 10.0), gum)
			const TEETH := 5
			for i in TEETH:
				var x0 := c.x - w + w * 2.0 * i / TEETH
				var x1 := x0 + w * 2.0 / TEETH
				draw_colored_polygon(PackedVector2Array([Vector2(x0, y), Vector2(x1, y), Vector2((x0 + x1) / 2.0, y - s * 13.0)]), tooth)

	func _sprite(tex: Texture2D, pos: Vector2, rot: float, s: float, a: float) -> void:
		draw_set_transform(pos, rot, Vector2.ONE * s)
		draw_texture(tex, -tex.get_size() / 2.0, Color(1, 1, 1, a))
		draw_set_transform(Vector2.ZERO)

	func _cone(from: Vector2, dir: Vector2, length: float, half: float, fill: Color, edge: Color) -> void:
		var pts := PackedVector2Array([from])
		const STEPS := 14
		for i in STEPS + 1:
			pts.append(from + dir.rotated(lerpf(-half, half, float(i) / STEPS)) * length)
		draw_colored_polygon(pts, fill)
		pts.append(from)
		draw_polyline(pts, edge, 2.0)

	func _band(from: Vector2, dir: Vector2, length: float, half: float, col: Color) -> void:
		var n := dir.orthogonal() * half
		var end := from + dir * length
		draw_colored_polygon(PackedVector2Array([from + n, end + n, end - n, from - n]), col)

	## Trapèze qui s'élargit de `half0` à `half1` : chemin de la vague de feu.
	func _wedge(from: Vector2, dir: Vector2, length: float, half0: float, half1: float, col: Color) -> void:
		var n := dir.orthogonal()
		var end := from + dir * length
		draw_colored_polygon(PackedVector2Array([from + n * half0, end + n * half1, end - n * half1, from - n * half0]), col)

	func _chevron(c: Vector2, dir: Vector2, size: float, col: Color) -> void:
		var n := dir.orthogonal()
		draw_polyline(PackedVector2Array([c - dir * size + n * size, c, c - dir * size - n * size]), col, 3.0)

	static func _hash(x: float) -> float:
		return fposmod(sin(x * 12.9898) * 43758.5453, 1.0)
