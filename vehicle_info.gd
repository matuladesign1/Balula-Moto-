class_name VehicleInfo
extends RefCounted
## Morceaux d'interface partagés par le magasin et le garage : barres de statistiques et comparaison.

const STAT_DEFS := [
	{"key": "max_speed_kmh", "label": "Vitesse max", "unit": " km/h", "better": 1},
	{"key": "power_hp", "label": "Puissance", "unit": " ch", "better": 1},
	{"key": "consumption_l100", "label": "Consommation", "unit": " L/100 km", "better": -1},
	{"key": "fuel_tank_l", "label": "Réservoir", "unit": " L", "better": 1},
	{"key": "passengers", "label": "Passagers", "unit": "", "better": 1},
	{"key": "cargo_kg", "label": "Charge utile", "unit": " kg", "better": 1},
	{"key": "weight_kg", "label": "Poids", "unit": " kg", "better": 0},
]


## Valeur d'une statistique : les stats réelles d'un véhicule possédé (améliorations, état) l'emportent.
static func value_of(key: String, def: Dictionary, stats: Dictionary) -> float:
	if stats.has(key):
		return float(stats[key])
	return float(def.get(key, 0))


static func _max_of(key: String) -> float:
	var m := 1.0
	for v in Catalog.all_vehicles():
		m = maxf(m, float(v.get(key, 0)))
	return m


static func fmt(v: float, stat: Dictionary) -> String:
	var txt := str(int(round(v)))
	if absf(v - round(v)) > 0.05:
		txt = "%.1f" % v
	return txt + str(stat.get("unit", ""))


## Une ligne par statistique : nom, barre, valeur.
static func stats_panel(def: Dictionary, stats: Dictionary = {}) -> Control:
	var box := UiKit.vbox(6)
	for sd in STAT_DEFS:
		var key: String = sd["key"]
		var v := value_of(key, def, stats)
		var row := UiKit.hbox(8)
		var name_l := UiKit.label(str(sd["label"]), 18, UiKit.C_MUTED)
		name_l.custom_minimum_size = Vector2(122, 0)
		row.add_child(name_l)
		row.add_child(UiKit.bar(clampf(v / _max_of(key), 0.0, 1.0), UiKit.C_BLUE))
		var val := UiKit.label(fmt(v, sd), 18, UiKit.C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		val.custom_minimum_size = Vector2(120, 0)
		row.add_child(val)
		box.add_child(row)
	return box


## Tableau de comparaison de deux véhicules (vert = meilleur, rouge = moins bon).
static func compare_panel(def_a: Dictionary, stats_a: Dictionary, name_a: String, def_b: Dictionary, stats_b: Dictionary, name_b: String) -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	grid.add_child(UiKit.label("", 18))
	grid.add_child(_cell(name_a, UiKit.C_YELLOW, true))
	grid.add_child(_cell(name_b, UiKit.C_YELLOW, true))
	var rows: Array = [{"key": "price_cdf", "label": "Prix", "unit": " CDF", "better": -1}]
	rows.append_array(STAT_DEFS)
	for sd in rows:
		var key: String = sd["key"]
		var a := value_of(key, def_a, stats_a)
		var b := value_of(key, def_b, stats_b)
		var better: int = int(sd["better"])
		var col_a := UiKit.C_TEXT
		var col_b := UiKit.C_TEXT
		if better != 0 and absf(a - b) > 0.001:
			var a_wins := (a > b) if better > 0 else (a < b)
			col_a = UiKit.C_GREEN if a_wins else UiKit.C_RED
			col_b = UiKit.C_RED if a_wins else UiKit.C_GREEN
		grid.add_child(UiKit.label(str(sd["label"]), 18, UiKit.C_MUTED))
		grid.add_child(_cell(fmt(a, sd), col_a, false))
		grid.add_child(_cell(fmt(b, sd), col_b, false))
	return grid


static func _cell(text: String, color: Color, wrap: bool) -> Label:
	var l := UiKit.label(text, 18, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size = Vector2(190, 0)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
