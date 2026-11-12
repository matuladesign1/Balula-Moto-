extends Node
## Catalogue des véhicules et des améliorations (singleton "Catalog").
##
## Les véhicules sont lus dans tous les fichiers .json de :
##   - res://data/vehicles/   (fournis avec le jeu)
##   - user://vehicles/       (ajoutés sans refaire le jeu, voir docs/AJOUTER_UN_VEHICULE.md)
## Un fichier peut contenir un véhicule { ... } ou une liste [ { ... }, { ... } ].

signal catalog_reloaded

const VEHICLE_DIRS: Array[String] = ["res://data/vehicles", "user://vehicles"]
const CATEGORIES_PATH := "res://data/categories.json"
const UPGRADES_PATH := "res://data/upgrades.json"

var categories: Array = []
var upgrades: Dictionary = {}
var load_warnings: Array[String] = []

var _vehicles: Dictionary = {}
var _order: Array[String] = []


func _ready() -> void:
	reload()


func reload() -> void:
	load_warnings.clear()
	_vehicles.clear()
	_order.clear()
	var cats: Variant = _read_json(CATEGORIES_PATH)
	categories = cats if cats is Array else []
	var ups: Variant = _read_json(UPGRADES_PATH)
	upgrades = ups if ups is Dictionary else {}
	for dir_path in VEHICLE_DIRS:
		_load_vehicle_dir(dir_path)
	_order.sort_custom(_sort_vehicle_ids)
	for w in load_warnings:
		push_warning("[Catalog] " + w)
	catalog_reloaded.emit()


# ---------------------------------------------------------------- chargement

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		load_warnings.append("Fichier introuvable : " + path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		load_warnings.append("JSON invalide (virgule oubliée ?) : " + path)
	return parsed


func _load_vehicle_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return # dossier absent : normal pour user://vehicles
	var files: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.get_extension().to_lower() == "json":
			files.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	files.sort()
	for file_name in files:
		var path := dir_path.path_join(file_name)
		var parsed: Variant = _read_json(path)
		if parsed is Dictionary:
			_register(parsed, path)
		elif parsed is Array:
			for item in parsed:
				if item is Dictionary:
					_register(item, path)


func _register(raw: Dictionary, source: String) -> void:
	var id := str(raw.get("id", "")).strip_edges()
	if id.is_empty():
		load_warnings.append("Véhicule sans \"id\" ignoré dans " + source)
		return
	if _vehicles.has(id):
		load_warnings.append("Identifiant en double \"%s\" (%s) : le premier est conservé." % [id, source])
		return
	_vehicles[id] = _normalize(raw, id)
	_order.append(id)


func _normalize(raw: Dictionary, id: String) -> Dictionary:
	var v: Dictionary = raw.duplicate(true)
	v["id"] = id
	v["name"] = str(raw.get("name", id))
	v["brand"] = str(raw.get("brand", ""))
	v["type"] = str(raw.get("type", "moto"))
	v["category"] = str(raw.get("category", "classique"))
	v["description"] = str(raw.get("description", ""))
	v["price_cdf"] = int(raw.get("price_cdf", 1000000))
	v["power_hp"] = float(raw.get("power_hp", 10.0))
	v["max_speed_kmh"] = float(raw.get("max_speed_kmh", 80.0))
	v["consumption_l100"] = float(raw.get("consumption_l100", 2.5))
	v["fuel_tank_l"] = float(raw.get("fuel_tank_l", 10.0))
	v["passengers"] = int(raw.get("passengers", 1))
	v["cargo_kg"] = int(raw.get("cargo_kg", 0))
	var is_moto: bool = v["type"] == "moto"
	v["weight_kg"] = float(raw.get("weight_kg", 110.0 if is_moto else 450.0))
	v["performance_level"] = clampi(int(raw.get("performance_level", roundi(v["power_hp"] / 8.0))), 1, 5)
	if not (raw.get("model") is Dictionary):
		v["model"] = {"style": "classique" if is_moto else "re"}
	if not (raw.get("default_custom") is Dictionary):
		v["default_custom"] = {}
	# Paramètres de conduite "arcade" (modifiables dans le JSON via "drive": { ... })
	var hp: float = v["power_hp"]
	var drive: Dictionary = {}
	if is_moto:
		drive = {"accel": clampf(1.6 + hp * 0.14, 2.0, 7.0), "brake": 9.0, "turn_rate": 2.0, "lean": 0.42}
	else:
		var load_penalty: float = float(v["cargo_kg"]) / 5000.0
		drive = {"accel": clampf(0.9 + hp * 0.10 - load_penalty, 1.2, 3.5), "brake": 6.5, "turn_rate": 1.45, "lean": 0.05}
	var override: Variant = raw.get("drive")
	if override is Dictionary:
		for k in override:
			drive[k] = float(override[k])
	v["drive"] = drive
	return v


func _sort_vehicle_ids(a: String, b: String) -> bool:
	var ca := _category_index(str(_vehicles[a]["category"]))
	var cb := _category_index(str(_vehicles[b]["category"]))
	if ca != cb:
		return ca < cb
	return int(_vehicles[a]["price_cdf"]) < int(_vehicles[b]["price_cdf"])


func _category_index(cat_id: String) -> int:
	for i in categories.size():
		if str(categories[i].get("id", "")) == cat_id:
			return i
	return 99


# ---------------------------------------------------------------- véhicules

func has_vehicle(id: String) -> bool:
	return _vehicles.has(id)


## Renvoie la fiche du véhicule, ou {} si l'identifiant est inconnu.
func get_vehicle(id: String) -> Dictionary:
	if _vehicles.has(id):
		return _vehicles[id]
	return {}


func all_vehicles() -> Array:
	var out: Array = []
	for id in _order:
		out.append(_vehicles[id])
	return out


func vehicles_in_category(cat_id: String) -> Array:
	var out: Array = []
	for id in _order:
		if _vehicles[id]["category"] == cat_id:
			out.append(_vehicles[id])
	return out


func category_label(cat_id: String) -> String:
	for c in categories:
		if str(c.get("id", "")) == cat_id:
			return str(c.get("label", cat_id))
	return cat_id


# ---------------------------------------------------------------- améliorations

func performance_upgrades() -> Array:
	var arr: Variant = upgrades.get("performance", [])
	return arr if arr is Array else []


func performance_upgrade(upgrade_id: String) -> Dictionary:
	for u in performance_upgrades():
		if str(u.get("id", "")) == upgrade_id:
			return u
	return {}


## Prix du niveau `level` (1, 2 ou 3) d'une amélioration pour ce véhicule. 0 si inconnu.
func upgrade_price(vehicle_def: Dictionary, upgrade_id: String, level: int) -> int:
	var u := performance_upgrade(upgrade_id)
	var levels: Array = u.get("levels", [])
	if level < 1 or level > levels.size():
		return 0
	var pct: float = float(levels[level - 1].get("price_pct", 0.0))
	return _round_price(float(vehicle_def.get("price_cdf", 0)) * pct)


## Effet cumulé d'une amélioration au niveau donné ({} au niveau 0).
func upgrade_effect(upgrade_id: String, level: int) -> Dictionary:
	if level <= 0:
		return {}
	var levels: Array = performance_upgrade(upgrade_id).get("levels", [])
	if levels.is_empty():
		return {}
	return levels[clampi(level, 1, levels.size()) - 1]


func tire_options() -> Array:
	var t: Variant = upgrades.get("tires", {})
	return t.get("options", []) if t is Dictionary else []


func tire_option(tire_id: String) -> Dictionary:
	for o in tire_options():
		if str(o.get("id", "")) == tire_id:
			return o
	return {}


func tire_price(vehicle_def: Dictionary, tire_id: String) -> int:
	var pct: float = float(tire_option(tire_id).get("price_pct", 0.0))
	return _round_price(float(vehicle_def.get("price_cdf", 0)) * pct)


## Catégories de personnalisation esthétique, filtrées selon le type ("moto" ou "tricycle").
func aesthetic_categories(vehicle_type: String) -> Array:
	var out: Array = []
	var src: Variant = upgrades.get("aesthetic", [])
	if not (src is Array):
		return out
	for cat in src:
		var opts: Array = []
		for o in cat.get("options", []):
			var only: Variant = o.get("for")
			if only is Array and not only.has(vehicle_type):
				continue
			opts.append(o)
		if not opts.is_empty():
			out.append({"id": cat.get("id", ""), "label": cat.get("label", ""), "options": opts})
	return out


func aesthetic_option(cat_id: String, option_id: String) -> Dictionary:
	var src: Variant = upgrades.get("aesthetic", [])
	if src is Array:
		for cat in src:
			if str(cat.get("id", "")) == cat_id:
				for o in cat.get("options", []):
					if str(o.get("id", "")) == option_id:
						return o
	return {}


func color_from_id(color_id: String, fallback: Color = Color("#1f4bd8")) -> Color:
	var o := aesthetic_option("color", color_id)
	if o.has("value"):
		return Color(str(o["value"]))
	return fallback


func _round_price(x: float) -> int:
	return int(round(x / 5000.0)) * 5000
