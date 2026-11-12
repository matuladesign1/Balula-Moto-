extends Node
## État global du jeu (singleton "GameState") :
## profil du joueur, argent, garage, achats, réparations, sauvegarde automatique, navigation.
##
## Règle d'or : toute modification du profil passe par ce fichier, qui sauvegarde ensuite.

signal money_changed(amount: int)
signal garage_changed
signal profile_replaced
signal back_requested   # bouton "Retour" d'Android

const SAVE_PATH := "user://balula_save.json"
const BACKUP_PATH := "user://balula_save.bak.json"
const BEFORE_NEW_GAME_PATH := "user://balula_save_avant_nouvelle_partie.json"

const SCENE_MENU := "res://scenes/main_menu.tscn"
const SCENE_GAME := "res://scenes/game.tscn"
const SCENE_SHOP := "res://scenes/shop.tscn"
const SCENE_GARAGE := "res://scenes/garage.tscn"
const SCENE_PROFILE := "res://scenes/profile.tscn"
const SCENE_SETTINGS := "res://scenes/settings.tscn"

var profile: Dictionary = {}
var settings: Dictionary = {}
var trial_model_id: String = ""          # non vide = essai d'un véhicule non acheté
var ui_memory: Dictionary = {}           # petites mémoires d'écran (dernier véhicule choisi...)
var nav_stack: Array[String] = []

var _dirty := false
var _autosave_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_quit_on_go_back(false)
	_setup_input_map()
	_load_or_create()
	apply_settings()


func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= 10.0:
		_autosave_timer = 0.0
		if _dirty:
			save_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			save_game()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			back_requested.emit()


# ---------------------------------------------------------------- entrées

func _setup_input_map() -> void:
	# Touches physiques : WASD correspond à ZQSD sur un clavier AZERTY.
	var defs := {
		"accelerate": [KEY_W, KEY_UP],
		"brake": [KEY_S, KEY_DOWN, KEY_SPACE],
		"steer_left": [KEY_A, KEY_LEFT],
		"steer_right": [KEY_D, KEY_RIGHT],
		"pause_game": [KEY_ESCAPE, KEY_P],
	}
	for action in defs:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key in defs[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- création / chargement

func _new_profile(player_name: String) -> Dictionary:
	return {
		"version": Balance.SAVE_VERSION,
		"player_name": player_name,
		"money": Balance.START_MONEY,
		"level": 1, "xp": 0, "reputation": 0,
		"vehicles": [], "active_uid": "",
		"missions_done": [],
		"ledger": [],
		"stats": {"total_km": 0.0, "rides": 0},
		"created": Time.get_unix_time_from_system(),
	}


func _give_starting_vehicle() -> void:
	var model_id: String = Balance.START_VEHICLE_ID
	if not Catalog.has_vehicle(model_id):
		var all := Catalog.all_vehicles()
		if all.is_empty():
			push_error("Aucun véhicule dans le catalogue ! Vérifie les fichiers de data/vehicles/.")
			return
		model_id = str(all[0]["id"])
	var inst := make_instance(model_id, Balance.START_CONDITION, 0)
	profile["vehicles"].append(inst)
	profile["active_uid"] = inst["uid"]


func _load_or_create() -> void:
	for path in [SAVE_PATH, BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.get("profile") is Dictionary:
			profile = _sanitize_profile(parsed["profile"])
			settings = _sanitize_settings(parsed.get("settings"))
			return
		push_warning("Sauvegarde illisible : " + path)
	settings = _sanitize_settings(null)
	profile = _new_profile("Chauffeur")
	_give_starting_vehicle()
	save_game()


func _sanitize_profile(p: Dictionary) -> Dictionary:
	var base := _new_profile(str(p.get("player_name", "Chauffeur")))
	base["money"] = int(p.get("money", Balance.START_MONEY))
	base["level"] = int(p.get("level", 1))
	base["xp"] = int(p.get("xp", 0))
	base["reputation"] = int(p.get("reputation", 0))
	base["created"] = p.get("created", base["created"])
	var vehicles: Array = []
	var src: Variant = p.get("vehicles", [])
	if src is Array:
		for v in src:
			if v is Dictionary and v.has("uid") and v.has("model_id"):
				vehicles.append(_sanitize_instance(v))
	base["vehicles"] = vehicles
	var ledger: Variant = p.get("ledger", [])
	base["ledger"] = ledger if ledger is Array else []
	var done: Variant = p.get("missions_done", [])
	base["missions_done"] = done if done is Array else []
	var st: Variant = p.get("stats", {})
	if st is Dictionary:
		base["stats"] = {"total_km": float(st.get("total_km", 0.0)), "rides": int(st.get("rides", 0))}
	var active := str(p.get("active_uid", ""))
	var found := false
	for v in vehicles:
		if v["uid"] == active:
			found = true
	if not found and not vehicles.is_empty():
		active = str(vehicles[0]["uid"])
	base["active_uid"] = active
	profile = base # nécessaire pour _give_starting_vehicle ci-dessous
	if vehicles.is_empty():
		_give_starting_vehicle()
	return profile


func _sanitize_instance(v: Dictionary) -> Dictionary:
	var up := {"engine": 0, "brakes": 0, "suspension": 0, "tires": "standard"}
	var src_up: Variant = v.get("upgrades", {})
	if src_up is Dictionary:
		for k in ["engine", "brakes", "suspension"]:
			up[k] = clampi(int(src_up.get(k, 0)), 0, 3)
		up["tires"] = str(src_up.get("tires", "standard"))
	var cust: Variant = v.get("custom", {})
	var unl: Variant = v.get("unlocked", [])
	return {
		"uid": str(v["uid"]),
		"model_id": str(v["model_id"]),
		"condition": clampf(float(v.get("condition", 100.0)), 0.0, 100.0),
		"fuel": maxf(0.0, float(v.get("fuel", 0.0))),
		"km": maxf(0.0, float(v.get("km", 0.0))),
		"custom": cust if cust is Dictionary else {},
		"unlocked": unl if unl is Array else [],
		"upgrades": up,
		"paid": int(v.get("paid", 0)),
		"acquired": v.get("acquired", 0),
	}


func _sanitize_settings(s: Variant) -> Dictionary:
	var d := {"touch_controls": true, "fps_cap": 60, "show_fps": false, "map": "test"}
	if s is Dictionary:
		d["touch_controls"] = bool(s.get("touch_controls", true))
		d["fps_cap"] = 30 if int(s.get("fps_cap", 60)) <= 30 else 60
		d["show_fps"] = bool(s.get("show_fps", false))
		d["map"] = "kinshasa" if str(s.get("map", "test")) == "kinshasa" else "test"
	return d


func apply_settings() -> void:
	Engine.max_fps = int(settings.get("fps_cap", 60))


# ---------------------------------------------------------------- sauvegarde

func save_game() -> void:
	var data := {"version": Balance.SAVE_VERSION, "profile": profile, "settings": settings}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Sauvegarde impossible, erreur %d" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	_dirty = false


func mark_dirty() -> void:
	_dirty = true


func has_progress() -> bool:
	var st: Dictionary = profile.get("stats", {})
	return profile["ledger"].size() > 0 or profile["vehicles"].size() > 1 or float(st.get("total_km", 0.0)) > 0.1


## Nouvelle partie : l'ancienne sauvegarde est copiée avant d'être remplacée.
func start_new_game(player_name: String) -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, BEFORE_NEW_GAME_PATH)
	var clean := player_name.strip_edges().left(20)
	profile = _new_profile(clean if not clean.is_empty() else "Chauffeur")
	_give_starting_vehicle()
	save_game()
	profile_replaced.emit()
	money_changed.emit(money())
	garage_changed.emit()


func set_player_name(player_name: String) -> void:
	var clean := player_name.strip_edges().left(20)
	if not clean.is_empty():
		profile["player_name"] = clean
		_commit()


func _commit() -> void:
	save_game()
	money_changed.emit(money())
	garage_changed.emit()


# ---------------------------------------------------------------- argent et historique

func money() -> int:
	return int(profile.get("money", 0))


func can_afford(amount: int) -> bool:
	return money() >= amount


func _add_ledger(kind: String, label: String, amount: int) -> void:
	var ledger: Array = profile["ledger"]
	ledger.append({"t": Time.get_unix_time_from_system(), "kind": kind, "label": label, "amount": amount})
	while ledger.size() > Balance.MAX_LEDGER:
		ledger.pop_front()


func _earn(amount: int, kind: String, label: String) -> void:
	profile["money"] = money() + amount
	_add_ledger(kind, label, amount)


func _spend(amount: int, kind: String, label: String) -> void:
	profile["money"] = money() - amount
	_add_ledger(kind, label, -amount)


## Gain d'argent (courses, livraisons...). Sauvegardé aussitôt.
func earn(amount: int, kind: String, label: String) -> void:
	_earn(amount, kind, label)
	_commit()


func add_test_bonus() -> void:
	earn(Balance.TEST_BONUS, "test", "Bonus de test")


func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}


func _ok(message: String) -> Dictionary:
	return {"ok": true, "message": message}


# ---------------------------------------------------------------- véhicules possédés

func _new_uid() -> String:
	var uid := ""
	while uid.is_empty() or not find_instance(uid).is_empty():
		uid = "v%d%03d" % [int(Time.get_unix_time_from_system() * 1000.0), randi() % 1000]
	return uid


func make_instance(model_id: String, condition: float, paid: int) -> Dictionary:
	var def := Catalog.get_vehicle(model_id)
	var cap := float(def.get("fuel_tank_l", 10.0))
	var custom: Dictionary = {}
	var dc: Variant = def.get("default_custom", {})
	if dc is Dictionary:
		custom = dc.duplicate(true)
	# Les options d'origine du véhicule sont déjà débloquées (on peut y revenir gratuitement).
	var unlocked: Array = []
	for cat_id in custom:
		unlocked.append("%s:%s" % [str(cat_id), str(custom[cat_id])])
	return {
		"uid": _new_uid(),
		"model_id": model_id,
		"condition": condition,
		"fuel": cap * 0.5,
		"km": 0.0,
		"custom": custom,
		"unlocked": unlocked,
		"upgrades": {"engine": 0, "brakes": 0, "suspension": 0, "tires": "standard"},
		"paid": paid,
		"acquired": Time.get_unix_time_from_system(),
	}


## Véhicule temporaire pour l'essai (jamais ajouté au garage).
func make_trial_instance(model_id: String) -> Dictionary:
	var inst := make_instance(model_id, 100.0, 0)
	inst["fuel"] = float(Catalog.get_vehicle(model_id).get("fuel_tank_l", 10.0))
	return inst


func all_instances() -> Array:
	return profile["vehicles"]


func find_instance(uid: String) -> Dictionary:
	if not profile.has("vehicles"):
		return {}
	for v in profile["vehicles"]:
		if v["uid"] == uid:
			return v
	return {}


func owns_model(model_id: String) -> bool:
	for v in profile["vehicles"]:
		if v["model_id"] == model_id:
			return true
	return false


func active_instance() -> Dictionary:
	var inst := find_instance(str(profile.get("active_uid", "")))
	if inst.is_empty() and not profile["vehicles"].is_empty():
		inst = profile["vehicles"][0]
	return inst


func set_active(uid: String) -> void:
	if not find_instance(uid).is_empty():
		profile["active_uid"] = uid
		_commit()


func vehicle_name(inst: Dictionary) -> String:
	var def := Catalog.get_vehicle(str(inst.get("model_id", "")))
	return str(def.get("name", "Véhicule inconnu"))


# ---------------------------------------------------------------- achat / vente

func buy_vehicle(model_id: String) -> Dictionary:
	var def := Catalog.get_vehicle(model_id)
	if def.is_empty():
		return _fail("Ce véhicule n'existe pas dans le catalogue.")
	var price: int = def["price_cdf"]
	if not can_afford(price):
		return _fail("Budget insuffisant : il te manque %s." % Balance.cdf(price - money()))
	_spend(price, "achat", "Achat : " + str(def["name"]))
	var inst := make_instance(model_id, 100.0, price)
	profile["vehicles"].append(inst)
	_commit()
	return {"ok": true, "message": "%s ajouté à ton garage !" % def["name"], "uid": inst["uid"]}


func resale_value(inst: Dictionary) -> int:
	var def := Catalog.get_vehicle(str(inst.get("model_id", "")))
	var cond := float(inst.get("condition", 100.0)) / 100.0
	var pct := Balance.RESALE_BASE + Balance.RESALE_CONDITION * cond
	return int(round(float(def.get("price_cdf", 0)) * pct / 1000.0)) * 1000


func sell_vehicle(uid: String) -> Dictionary:
	var inst := find_instance(uid)
	if inst.is_empty():
		return _fail("Véhicule introuvable.")
	if profile["vehicles"].size() <= 1:
		return _fail("Tu dois garder au moins un véhicule pour travailler.")
	var value := resale_value(inst)
	var label := vehicle_name(inst)
	_earn(value, "vente", "Vente : " + label)
	var list: Array = profile["vehicles"]
	for i in list.size():
		if list[i]["uid"] == uid:
			list.remove_at(i)
			break
	if profile["active_uid"] == uid:
		profile["active_uid"] = list[0]["uid"]
	_commit()
	return _ok("%s vendu pour %s." % [label, Balance.cdf(value)])


# ---------------------------------------------------------------- réparation / carburant

func repair_cost(inst: Dictionary) -> int:
	var def := Catalog.get_vehicle(str(inst.get("model_id", "")))
	var missing := 100.0 - float(inst.get("condition", 100.0))
	var raw := missing * float(def.get("price_cdf", 0)) * Balance.REPAIR_COST_PER_POINT_PCT
	return int(round(raw / 500.0)) * 500


func repair(uid: String) -> Dictionary:
	var inst := find_instance(uid)
	if inst.is_empty():
		return _fail("Véhicule introuvable.")
	var cost := repair_cost(inst)
	if float(inst["condition"]) >= 99.5:
		return _fail("Ce véhicule est déjà en parfait état.")
	if not can_afford(cost):
		return _fail("Réparation : %s. Il te manque %s." % [Balance.cdf(cost), Balance.cdf(cost - money())])
	_spend(cost, "reparation", "Réparation : " + vehicle_name(inst))
	inst["condition"] = 100.0
	_commit()
	return _ok("Réparation terminée (%s)." % Balance.cdf(cost))


func refuel_cost(inst: Dictionary) -> int:
	var def := Catalog.get_vehicle(str(inst.get("model_id", "")))
	var missing := float(def.get("fuel_tank_l", 10.0)) - float(inst.get("fuel", 0.0))
	return int(round(maxf(missing, 0.0) * Balance.FUEL_PRICE_CDF / 100.0)) * 100


func refuel(uid: String) -> Dictionary:
	var inst := find_instance(uid)
	if inst.is_empty():
		return _fail("Véhicule introuvable.")
	var def := Catalog.get_vehicle(str(inst["model_id"]))
	var cost := refuel_cost(inst)
	if cost <= 0:
		return _fail("Le réservoir est déjà plein.")
	if not can_afford(cost):
		return _fail("Le plein coûte %s. Il te manque %s." % [Balance.cdf(cost), Balance.cdf(cost - money())])
	_spend(cost, "carburant", "Plein : " + vehicle_name(inst))
	inst["fuel"] = float(def.get("fuel_tank_l", 10.0))
	_commit()
	return _ok("Plein effectué (%s)." % Balance.cdf(cost))


## Appelé par le véhicule pendant la conduite (pas de sauvegarde immédiate : l'autosave s'en charge).
func record_drive(inst: Dictionary, km: float, damage_points: float) -> void:
	inst["km"] = float(inst.get("km", 0.0)) + km
	inst["condition"] = clampf(float(inst.get("condition", 100.0)) - km * Balance.WEAR_PER_KM - damage_points, 0.0, 100.0)
	if not find_instance(str(inst.get("uid", ""))).is_empty():
		var st: Dictionary = profile["stats"]
		st["total_km"] = float(st.get("total_km", 0.0)) + km
		_dirty = true


# ---------------------------------------------------------------- améliorations / personnalisation

func upgrade_level(inst: Dictionary, upgrade_id: String) -> int:
	return int(inst.get("upgrades", {}).get(upgrade_id, 0))


func buy_upgrade(uid: String, upgrade_id: String) -> Dictionary:
	var inst := find_instance(uid)
	if inst.is_empty():
		return _fail("Véhicule introuvable.")
	var def := Catalog.get_vehicle(str(inst["model_id"]))
	var u := Catalog.performance_upgrade(upgrade_id)
	var next_level := upgrade_level(inst, upgrade_id) + 1
	if next_level > u.get("levels", []).size():
		return _fail("Niveau maximum déjà atteint.")
	var price := Catalog.upgrade_price(def, upgrade_id, next_level)
	if not can_afford(price):
		return _fail("Il te manque %s." % Balance.cdf(price - money()))
	var level_name := str(u["levels"][next_level - 1].get("name", "Niveau %d" % next_level))
	_spend(price, "amelioration", "%s : %s" % [u.get("label", upgrade_id), level_name])
	inst["upgrades"][upgrade_id] = next_level
	_commit()
	return _ok("%s installé !" % level_name)


func set_tires(uid: String, tire_id: String) -> Dictionary:
	var inst := find_instance(uid)
	if inst.is_empty():
		return _fail("Véhicule introuvable.")
	if str(inst["upgrades"].get("tires", "standard")) == tire_id:
		return _fail("Ces pneus sont déjà montés.")
	var def := Catalog.get_vehicle(str(inst["model_id"]))
	var key := "tires:" + tire_id
	var price := 0 if inst["unlocked"].has(key) else Catalog.tire_price(def, tire_id)
	if not can_afford(price):
		return _fail("Il te manque %s." % Balance.cdf(price - money()))
	if price > 0:
		_spend(price, "amelioration", "Pneus : " + str(Catalog.tire_option(tire_id).get("name", tire_id)))
		inst["unlocked"].append(key)
	inst["upgrades"]["tires"] = tire_id
	_commit()
	return _ok("Pneus montés.")


func custom_option_price(inst: Dictionary, cat_id: String, option_id: String) -> int:
	if inst["unlocked"].has(cat_id + ":" + option_id):
		return 0
	return int(Catalog.aesthetic_option(cat_id, option_id).get("price", 0))


func set_custom(uid: String, cat_id: String, option_id: String) -> Dictionary:
	var inst := find_instance(uid)
	if inst.is_empty():
		return _fail("Véhicule introuvable.")
	if str(inst["custom"].get(cat_id, "")) == option_id:
		return _fail("Déjà installé.")
	var opt := Catalog.aesthetic_option(cat_id, option_id)
	if opt.is_empty():
		return _fail("Option inconnue.")
	var price := custom_option_price(inst, cat_id, option_id)
	if not can_afford(price):
		return _fail("Il te manque %s." % Balance.cdf(price - money()))
	if price > 0:
		_spend(price, "personnalisation", "%s : %s" % [cat_id.capitalize(), opt.get("name", option_id)])
		inst["unlocked"].append(cat_id + ":" + option_id)
	inst["custom"][cat_id] = option_id
	_commit()
	return _ok("%s appliqué." % opt.get("name", option_id))


## Statistiques réelles utilisées pour la conduite : base du modèle + améliorations + état du véhicule.
func effective_stats(inst: Dictionary) -> Dictionary:
	var def := Catalog.get_vehicle(str(inst.get("model_id", "")))
	if def.is_empty():
		return {}
	var up: Dictionary = inst.get("upgrades", {})
	var cond := float(inst.get("condition", 100.0)) / 100.0
	var cf := Balance.MIN_CONDITION_FACTOR + (1.0 - Balance.MIN_CONDITION_FACTOR) * cond
	var eng := Catalog.upgrade_effect("engine", int(up.get("engine", 0)))
	var brk := Catalog.upgrade_effect("brakes", int(up.get("brakes", 0)))
	var sus := Catalog.upgrade_effect("suspension", int(up.get("suspension", 0)))
	var tire := Catalog.tire_option(str(up.get("tires", "standard")))
	var grip := float(tire.get("grip_mult", 1.0))
	var drive: Dictionary = def["drive"]
	return {
		"power_hp": float(def["power_hp"]) * float(eng.get("power_mult", 1.0)) * cf,
		"max_speed_kmh": float(def["max_speed_kmh"]) * float(eng.get("speed_mult", 1.0)) * cf,
		"accel": float(drive["accel"]) * float(eng.get("accel_mult", 1.0)) * cf,
		"brake": float(drive["brake"]) * float(brk.get("brake_mult", 1.0)) * (0.9 + 0.1 * grip),
		"turn_rate": float(drive["turn_rate"]) * float(sus.get("handling_mult", 1.0)) * grip,
		"lean": float(drive["lean"]),
		"damage_mult": float(sus.get("damage_mult", 1.0)),
		"consumption_l100": float(def["consumption_l100"]) * (1.0 + 0.04 * int(up.get("engine", 0))),
		"fuel_tank_l": float(def["fuel_tank_l"]),
	}


# ---------------------------------------------------------------- essai et navigation

func start_trial(model_id: String) -> void:
	trial_model_id = model_id
	navigate(SCENE_GAME)


func end_trial() -> void:
	trial_model_id = ""
	go_back()


func navigate(path: String) -> void:
	save_game()
	var cur := get_tree().current_scene
	if cur != null and cur.scene_file_path != "" and cur.scene_file_path != path:
		nav_stack.append(cur.scene_file_path)
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func go_back() -> void:
	save_game()
	var target := SCENE_MENU
	if not nav_stack.is_empty():
		target = nav_stack.pop_back()
	if target == SCENE_MENU:
		nav_stack.clear()
	get_tree().paused = false
	get_tree().change_scene_to_file(target)


func go_home() -> void:
	nav_stack.clear()
	trial_model_id = ""
	save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENE_MENU)
