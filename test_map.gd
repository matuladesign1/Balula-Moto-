class_name TestMap
extends Node3D
## Carte de test inspirée de l'ambiance de Kinshasa. C'est un lieu FICTIF : ce n'est pas la reproduction
## d'un quartier réel (les vrais lieux viendront avec tes photos, phase 10).
## Éléments : avenue + boulevard avec rond-point, rues, immeubles, marché, station-service verte,
## poteaux électriques et câbles, panneaux, arrêts de taxi-moto, atelier (garage) et magasin de véhicules.
## Tout est dessiné avec un seul gros maillage (MeshBatch) pour rester fluide sur un téléphone modeste.

signal zone_entered(zone_id: String)
signal zone_exited(zone_id: String)

const HALF := 300.0
# [position du centre de la rue, largeur]
const STREETS := [[-220.0, 10.0], [-110.0, 10.0], [0.0, 18.0], [110.0, 10.0], [220.0, 10.0]]

const GROUND_COLOR := Color("#b9a98d")
const ROAD_COLOR := Color("#3b3f45")
const MARK_COLOR := Color("#e8e4d8")
const WINDOW_COLOR := Color("#39495c")
const WALL_COLORS := [Color("#e9d8a6"), Color("#cfe3ea"), Color("#f2efe6"), Color("#e8b9a0"), Color("#b7d3a8"), Color("#e6c28a"), Color("#c9c3d9"), Color("#d9d9d9")]
const ROOF_COLORS := [Color("#7a7d82"), Color("#8c5b46"), Color("#6b6f75")]

var road_rects: Array[Rect2] = []        # pour la mini-carte
var building_rects: Array[Rect2] = []
var landmarks: Array = []                # [{"pos": Vector2, "color": Color, "label": String}]
var stops: Array[Vector3] = []           # arrêts de taxi-moto

var _batch := MeshBatch.new()
var _colliders: StaticBody3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260101
	_build_environment()
	_colliders = StaticBody3D.new()
	_colliders.name = "Colliders"
	add_child(_colliders)
	_build_ground_and_roads()
	_build_blocks()
	_build_market()
	_build_station()
	_build_services()
	_build_street_furniture()
	_build_boundaries()
	var mi := MeshInstance3D.new()
	mi.name = "MapMesh"
	mi.mesh = _batch.build(MeshBatch.make_material())
	add_child(mi)


func spawn_transform() -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(5.0, 0.1, 45.0))


# ---------------------------------------------------------------- outils

func _box(center: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	_batch.add_box(center, size, color, yaw)


## Boîte visible ET solide (le véhicule la heurte).
func _solid(center: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	_batch.add_box(center, size, color, yaw)
	_collider(center, size, yaw)


func _collider(center: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), center)
	_colliders.add_child(cs)


func _label(text: String, pos: Vector3, font_size: int = 64, color: Color = Color.WHITE) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	add_child(l)


func _landmark(pos: Vector3, color: Color, label: String) -> void:
	landmarks.append({"pos": Vector2(pos.x, pos.z), "color": color, "label": label})


func _intervals() -> Array:
	var out: Array = []
	var prev := -HALF
	for s in STREETS:
		var a: float = s[0] - s[1] * 0.5
		if a > prev:
			out.append([prev, a])
		prev = s[0] + s[1] * 0.5
	if prev < HALF:
		out.append([prev, HALF])
	return out


# ---------------------------------------------------------------- environnement, sol, routes

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#aebccb")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d7dde6")
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color("#aebccb")
	env.fog_density = 0.003
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 0.95
	sun.light_color = Color("#fff1d6")
	sun.shadow_enabled = false
	add_child(sun)


func _build_ground_and_roads() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(HALF * 2.0 + 40.0, 1.0, HALF * 2.0 + 40.0), GROUND_COLOR)
	_collider(Vector3(0, -1.0, 0), Vector3(HALF * 2.0 + 40.0, 2.0, HALF * 2.0 + 40.0))
	for s in STREETS:
		var wide: bool = s[1] > 12.0
		var top := 0.02 if wide else 0.015
		var w: float = s[1]
		var c: float = s[0]
		_box(Vector3(c, top * 0.5, 0), Vector3(w, top, HALF * 2.0), ROAD_COLOR)           # rue nord-sud
		_box(Vector3(0, top * 0.5, c), Vector3(HALF * 2.0, top, w), ROAD_COLOR)           # rue est-ouest
		road_rects.append(Rect2(c - w * 0.5, -HALF, w, HALF * 2.0))
		road_rects.append(Rect2(-HALF, c - w * 0.5, HALF * 2.0, w))
	# ligne centrale pointillée sur l'avenue et le boulevard
	var d := -HALF + 6.0
	while d < HALF - 6.0:
		if absf(d) > 14.0:
			_box(Vector3(0, 0.03, d), Vector3(0.25, 0.012, 3.0), MARK_COLOR)
			_box(Vector3(d, 0.03, 0), Vector3(3.0, 0.012, 0.25), MARK_COLOR)
		d += 9.0
	# passages piétons autour du rond-point
	_zebra(0.0, -12.5, true)
	_zebra(0.0, 12.5, true)
	_zebra(-12.5, 0.0, false)
	_zebra(12.5, 0.0, false)
	# rond-point : îlot central avec monument
	_solid(Vector3(0, 0.15, 0), Vector3(9.6, 0.3, 9.6), Color("#5a8f43"))
	_solid(Vector3(0, 0.15, 0), Vector3(9.6, 0.3, 9.6), Color("#5a8f43"), PI * 0.25)
	_solid(Vector3(0, 3.6, 0), Vector3(1.6, 6.6, 1.6), Color("#d8d2c4"))
	_box(Vector3(0, 7.2, 0), Vector3(2.4, 0.8, 2.4), Color("#f7c600"))
	_landmark(Vector3(0, 0, 0), Color("#5a8f43"), "Rond-point")
	# plaques de réparation et zones abîmées sur les rues secondaires
	for i in 60:
		var s: Array = STREETS[_rng.randi() % STREETS.size()]
		if s[1] > 12.0:
			continue
		var along := _rng.randf_range(-HALF + 10.0, HALF - 10.0)
		var off := _rng.randf_range(-3.5, 3.5)
		var size := Vector3(_rng.randf_range(0.8, 2.4), 0.01, _rng.randf_range(0.8, 2.2))
		var col := Color("#2a2c30") if _rng.randf() < 0.6 else Color("#4f5257")
		var pos := Vector3(float(s[0]) + off, 0.027, along) if _rng.randf() < 0.5 else Vector3(along, 0.027, float(s[0]) + off)
		_box(pos, size, col, _rng.randf_range(0.0, PI))


func _zebra(cx: float, cz: float, across_x: bool) -> void:
	for i in 9:
		var o := -8.0 + i * 2.0
		if across_x:
			_box(Vector3(cx + o, 0.03, cz), Vector3(0.8, 0.012, 3.0), MARK_COLOR)
		else:
			_box(Vector3(cx, 0.03, cz + o), Vector3(3.0, 0.012, 0.8), MARK_COLOR)


# ---------------------------------------------------------------- bâtiments

func _build_blocks() -> void:
	var xs := _intervals()
	var zs := _intervals()
	for ix in xs.size():
		for iz in zs.size():
			# blocs réservés : atelier (2,2), magasin (3,2), station (2,3), marché (4,3)
			if (ix == 2 and iz == 2) or (ix == 3 and iz == 2) or (ix == 2 and iz == 3) or (ix == 4 and iz == 3):
				continue
			_fill_block(xs[ix][0], xs[ix][1], zs[iz][0], zs[iz][1])


func _fill_block(x0: float, x1: float, z0: float, z1: float) -> void:
	var inset := 3.0
	for side in [0, 1]:
		var z_face := z0 + inset if side == 0 else z1 - inset
		var x := x0 + inset
		while x < x1 - inset - 8.0:
			var w := minf(_rng.randf_range(9.0, 20.0), x1 - inset - x)
			var d := _rng.randf_range(9.0, 18.0)
			var h := _rng.randf_range(4.0, 15.0)
			var zc := z_face + d * 0.5 if side == 0 else z_face - d * 0.5
			if _rng.randf() > 0.12:
				_building(Vector3(x + w * 0.5, 0.0, zc), Vector3(w, h, d))
			x += w + _rng.randf_range(0.5, 3.0)
	var zlo := z0 + inset + 20.0
	var zhi := z1 - inset - 20.0
	for side in [0, 1]:
		var x_face := x0 + inset if side == 0 else x1 - inset
		var z := zlo
		while z < zhi - 6.0:
			var d := _rng.randf_range(9.0, 15.0)
			var w := minf(_rng.randf_range(8.0, 16.0), zhi - z)
			var h := _rng.randf_range(4.0, 12.0)
			var xc := x_face + d * 0.5 if side == 0 else x_face - d * 0.5
			if _rng.randf() > 0.15:
				_building(Vector3(xc, 0.0, z + w * 0.5), Vector3(d, h, w))
			z += w + _rng.randf_range(0.5, 3.0)


func _building(c: Vector3, s: Vector3) -> void:
	var col: Color = WALL_COLORS[_rng.randi() % WALL_COLORS.size()]
	_solid(Vector3(c.x, s.y * 0.5, c.z), s, col)
	_box(Vector3(c.x, s.y + 0.15, c.z), Vector3(s.x + 0.4, 0.3, s.z + 0.4), ROOF_COLORS[_rng.randi() % ROOF_COLORS.size()])
	if s.y > 5.5:
		for k in int(s.y / 3.2):
			var y := 2.2 + k * 3.0
			if y < s.y - 1.0:
				_box(Vector3(c.x, y, c.z + s.z * 0.5 + 0.02), Vector3(s.x * 0.8, 1.1, 0.06), WINDOW_COLOR)
				_box(Vector3(c.x, y, c.z - s.z * 0.5 - 0.02), Vector3(s.x * 0.8, 1.1, 0.06), WINDOW_COLOR)
	building_rects.append(Rect2(c.x - s.x * 0.5, c.z - s.z * 0.5, s.x, s.z))


# ---------------------------------------------------------------- marché, station, services

func _build_market() -> void:
	var x0 := 125.0
	var x1 := 205.0
	var tarps := [Color("#2e6fb7"), Color("#e07b24"), Color("#2f9e5a"), Color("#c0392b"), Color("#f1c40f")]
	var wood := Color("#8a6a45")
	for row in 5:
		var z := 22.0 + row * 17.0
		_collider(Vector3((x0 + x1) * 0.5, 1.1, z), Vector3(x1 - x0, 2.2, 2.2))
		var x := x0 + 2.0
		while x < x1 - 2.0:
			_box(Vector3(x, 0.45, z), Vector3(2.4, 0.9, 1.6), wood)
			_box(Vector3(x, 2.3, z), Vector3(2.8, 0.08, 2.2), tarps[_rng.randi() % tarps.size()])
			for px in [-1.3, 1.3]:
				for pz in [-1.0, 1.0]:
					_box(Vector3(x + px, 1.15, z + pz), Vector3(0.06, 2.3, 0.06), wood)
			x += 3.6
	_solid(Vector3(212.0, 1.2, 57.0), Vector3(0.15, 2.4, 92.0), Color("#2c6fb7"))     # tôles ondulées bleues
	_solid(Vector3(165.0, 1.2, 12.0), Vector3(96.0, 2.4, 0.15), Color("#2c6fb7"))
	building_rects.append(Rect2(125.0, 15.0, 80.0, 75.0))
	_landmark(Vector3(165, 0, 57), Color("#e07b24"), "Marché")
	_label("MARCHÉ (zone d'étals)", Vector3(165, 5.0, 14.0), 56)


func _build_station() -> void:
	var green := Color("#2e9e4f")
	_solid(Vector3(-55.0, 2.0, 55.0), Vector3(22.0, 4.0, 8.0), green)
	_box(Vector3(-55.0, 4.15, 55.0), Vector3(22.8, 0.3, 8.8), Color("#f2f2f2"))
	_box(Vector3(-55.0, 5.4, 24.0), Vector3(26.0, 0.5, 13.0), green)                 # auvent
	_box(Vector3(-55.0, 5.0, 17.4), Vector3(26.0, 0.5, 0.2), Color("#f7c600"))
	for px in [-66.0, -44.0]:
		for pz in [19.0, 29.0]:
			_solid(Vector3(px, 2.6, pz), Vector3(0.6, 5.2, 0.6), Color("#f2f2f2"))
	for px in [-61.0, -55.0, -49.0]:
		_solid(Vector3(px, 0.8, 24.0), Vector3(0.7, 1.6, 0.5), Color("#f2f2f2"))
		_box(Vector3(px, 1.65, 24.0), Vector3(0.75, 0.2, 0.55), green)
	building_rects.append(Rect2(-66.0, 51.0, 22.0, 8.0))
	building_rects.append(Rect2(-68.0, 17.5, 26.0, 13.0))
	_landmark(Vector3(-55, 0, 24), Color("#2ecc71"), "Station-service")
	_label("STATION-SERVICE", Vector3(-55.0, 7.4, 17.0), 64)


func _build_services() -> void:
	# Atelier (garage) : bâtiment orange à gauche de l'avenue, côté nord du boulevard
	_solid(Vector3(-45.0, 3.0, -26.0), Vector3(24.0, 6.0, 12.0), Color("#e08a2d"))
	_box(Vector3(-45.0, 6.15, -26.0), Vector3(24.8, 0.3, 12.8), Color("#6b6f75"))
	_box(Vector3(-45.0, 2.0, -19.9), Vector3(10.0, 3.6, 0.1), Color("#4a3b2a"))       # grande porte
	building_rects.append(Rect2(-57.0, -32.0, 24.0, 12.0))
	_label("ATELIER - GARAGE", Vector3(-45.0, 8.2, -19.0), 64, Color("#ffd27a"))
	_add_zone("garage", Vector3(-45.0, 1.5, -12.0), Vector3(14.0, 3.0, 8.0), Color("#f7c600"))
	_landmark(Vector3(-45, 0, -12), Color("#f7a600"), "Garage")
	# Magasin de véhicules : bâtiment bleu à droite
	_solid(Vector3(45.0, 3.0, -26.0), Vector3(26.0, 6.0, 12.0), Color("#1f6fb5"))
	_box(Vector3(45.0, 6.15, -26.0), Vector3(26.8, 0.3, 12.8), Color("#6b6f75"))
	_box(Vector3(45.0, 2.4, -19.9), Vector3(16.0, 3.8, 0.1), Color("#9fd0f0"))        # grande vitrine
	building_rects.append(Rect2(32.0, -32.0, 26.0, 12.0))
	_label("MAGASIN DE VÉHICULES", Vector3(45.0, 8.2, -19.0), 64, Color("#bfe3ff"))
	_add_zone("shop", Vector3(45.0, 1.5, -12.0), Vector3(14.0, 3.0, 8.0), Color("#0b8bd6"))
	_landmark(Vector3(45, 0, -12), Color("#0b8bd6"), "Magasin")


func _add_zone(id: String, center: Vector3, size: Vector3, paint: Color) -> void:
	var a := Area3D.new()
	a.name = "Zone_" + id
	a.collision_layer = 0
	a.collision_mask = 2
	a.position = center
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	a.add_child(cs)
	a.body_entered.connect(func(_b: Node3D) -> void: zone_entered.emit(id))
	a.body_exited.connect(func(_b: Node3D) -> void: zone_exited.emit(id))
	add_child(a)
	_box(Vector3(center.x, 0.035, center.z), Vector3(size.x, 0.02, size.z), paint)


# ---------------------------------------------------------------- poteaux, panneaux, arbres, arrêts

func _build_street_furniture() -> void:
	_pole_line(true)
	_pole_line(false)
	var board_colors := [Color("#1f6fb5"), Color("#2e9e4f"), Color("#e07b24")]
	var spots := [Vector3(70, 0, 15), Vector3(-150, 0, -16), Vector3(16, 0, 160)]
	for i in spots.size():
		var p: Vector3 = spots[i]
		_solid(Vector3(p.x - 2.5, 3.0, p.z), Vector3(0.3, 6.0, 0.3), Color("#555a60"))
		_solid(Vector3(p.x + 2.5, 3.0, p.z), Vector3(0.3, 6.0, 0.3), Color("#555a60"))
		_box(Vector3(p.x, 6.6, p.z), Vector3(7.0, 3.0, 0.25), board_colors[i])
		_box(Vector3(p.x, 6.6, p.z + 0.14), Vector3(6.4, 0.5, 0.05), Color("#f7c600"))
		_box(Vector3(p.x, 7.3, p.z + 0.14), Vector3(6.4, 0.3, 0.05), Color("#f2f2f2"))
	# arbres le long du boulevard et de l'avenue
	var t := -270.0
	while t < 270.0:
		if absf(t) > 22.0:
			for sgn in [-1.0, 1.0]:
				_tree(Vector3(t + 7.0, 0.0, sgn * 15.5))
				_tree(Vector3(sgn * 15.5, 0.0, t + 7.0))
		t += 38.0
	# arrêts de taxi-moto
	for p in [Vector3(-70, 0, -12.5), Vector3(70, 0, 12.5), Vector3(12.5, 0, -90), Vector3(-12.5, 0, 90)]:
		_solid(Vector3(p.x, 1.2, p.z), Vector3(0.12, 2.4, 0.12), Color("#555a60"))
		_box(Vector3(p.x, 2.55, p.z), Vector3(1.0, 0.6, 0.06), Color("#f7c600"))
		_box(Vector3(p.x, 0.03, p.z + (1.8 if p.z < 0.0 else -1.8)), Vector3(7.0, 0.012, 3.0), Color("#f7c600"))
		_label("ARRET TAXI-MOTO", Vector3(p.x, 3.6, p.z), 44, Color("#f7c600"))
		stops.append(p)
		_landmark(p, Color("#f7c600"), "Arrêt")


func _tree(p: Vector3) -> void:
	_solid(Vector3(p.x, 1.5, p.z), Vector3(0.4, 3.0, 0.4), Color("#6b4a2f"))
	var g := Color("#3f8a3c") if _rng.randf() < 0.5 else Color("#4e9a45")
	_box(Vector3(p.x, 4.4, p.z), Vector3(3.2, 2.8, 3.2), g)


## Poteaux électriques et câbles le long du boulevard (along_x = true) ou de l'avenue.
func _pole_line(along_x: bool) -> void:
	var pole := Color("#5b4636")
	var cable := Color("#1d1d1f")
	for side in [-1.0, 1.0]:
		var prev := 0.0
		var has_prev := false
		var t := -285.0
		while t <= 285.0:
			if absf(t) > 15.0:
				var pos := Vector3(t, 0.0, side * 12.0) if along_x else Vector3(side * 12.0, 0.0, t)
				_solid(Vector3(pos.x, 4.0, pos.z), Vector3(0.3, 8.0, 0.3), pole)
				_box(Vector3(pos.x, 7.6, pos.z), Vector3(2.0, 0.15, 0.15) if not along_x else Vector3(0.15, 0.15, 2.0), pole)
				if has_prev and absf(t - prev) < 40.0:
					var mid := (t + prev) * 0.5
					var span := absf(t - prev)
					for k in [-0.8, 0.0, 0.8]:
						if along_x:
							_box(Vector3(mid, 7.65, side * 12.0 + k), Vector3(span, 0.04, 0.04), cable)
						else:
							_box(Vector3(side * 12.0 + k, 7.65, mid), Vector3(0.04, 0.04, span), cable)
				prev = t
				has_prev = true
			t += 30.0


func _build_boundaries() -> void:
	var e := HALF + 10.0
	_collider(Vector3(0, 3, -e), Vector3(e * 2.0, 6.0, 2.0))
	_collider(Vector3(0, 3, e), Vector3(e * 2.0, 6.0, 2.0))
	_collider(Vector3(-e, 3, 0), Vector3(2.0, 6.0, e * 2.0))
	_collider(Vector3(e, 3, 0), Vector3(2.0, 6.0, e * 2.0))
