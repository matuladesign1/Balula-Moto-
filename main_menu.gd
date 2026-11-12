extends Control
## Menu principal : Jouer / Continuer, Garage, Magasin, Missions, Carte, Profil, Paramètres.

var _preview: VehiclePreview
var _name_label: Label
var _sub_label: Label
var _money_label: Label
var _map_label: Label
var _quit_dialog: Control = null


func _ready() -> void:
	theme = UiKit.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	add_child(margin)
	var root := UiKit.hbox(34)
	margin.add_child(root)
	root.add_child(_build_left())
	root.add_child(_build_right())
	_refresh_vehicle()
	_refresh_map_label()
	GameState.back_requested.connect(_on_back_requested)


func _exit_tree() -> void:
	if GameState.back_requested.is_connected(_on_back_requested):
		GameState.back_requested.disconnect(_on_back_requested)


# ---------------------------------------------------------------- construction

func _build_left() -> Control:
	var col := UiKit.vbox(12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UiKit.label("BALULA MOTO", 68, UiKit.C_YELLOW))
	col.add_child(UiKit.label("Simulation de taxi-moto en RDC", 24))
	col.add_child(UiKit.label("Version de démonstration 0.1 (phase 1)", 17, UiKit.C_MUTED))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)

	var play_text := "Continuer" if GameState.has_progress() else "Jouer"
	var play := UiKit.button(play_text, _on_play, "PrimaryButton", Vector2(0, 84))
	play.add_theme_font_size_override("font_size", 34)
	col.add_child(play)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)
	_grid_button(grid, "Garage", _on_garage)
	_grid_button(grid, "Magasin", _on_shop)
	_grid_button(grid, "Missions", _on_missions)
	_grid_button(grid, "Carte", _on_map)
	_grid_button(grid, "Profil", _on_profile)
	_grid_button(grid, "Paramètres", _on_settings)

	col.add_child(UiKit.spacer())
	col.add_child(UiKit.wrapped_label(_save_text(), 18))
	if not Catalog.load_warnings.is_empty():
		var warn := "Attention : %d problème(s) dans les fichiers de véhicules (détails dans Paramètres)." % Catalog.load_warnings.size()
		col.add_child(UiKit.wrapped_label(warn, 18, Color("#ffb347")))
	col.add_child(UiKit.wrapped_label("Marques et modèles cités à titre indicatif, sans partenariat officiel.", 16))
	return col


func _grid_button(grid: GridContainer, text: String, callback: Callable) -> void:
	var b := UiKit.button(text, callback, "", Vector2(0, 64))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(b)


func _build_right() -> Control:
	var col := UiKit.vbox(10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview = VehiclePreview.new()
	_preview.custom_minimum_size = Vector2(460, 330)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_preview)
	var info := UiKit.panel(12)
	col.add_child(info)
	var body := UiKit.panel_body(info)
	_name_label = UiKit.label("", 28, UiKit.C_YELLOW)
	body.add_child(_name_label)
	_sub_label = UiKit.wrapped_label("", 19)
	body.add_child(_sub_label)
	_money_label = UiKit.label("", 26)
	body.add_child(_money_label)
	_map_label = UiKit.label("", 20, UiKit.C_MUTED)
	body.add_child(_map_label)
	return col


# ---------------------------------------------------------------- affichage

func _save_text() -> String:
	if FileAccess.file_exists(GameState.SAVE_PATH):
		return "Dernière sauvegarde : " + UiKit.time_text(float(FileAccess.get_modified_time(GameState.SAVE_PATH)))
	return "Aucune sauvegarde pour l'instant."


func _refresh_vehicle() -> void:
	_money_label.text = "Argent : " + Balance.cdf(GameState.money())
	var inst := GameState.active_instance()
	var def := Catalog.get_vehicle(str(inst.get("model_id", "")))
	if def.is_empty():
		_name_label.text = "Aucun véhicule"
		_sub_label.text = "Ouvre le magasin pour en acheter un."
		return
	_name_label.text = "Véhicule actif : " + str(def["name"])
	_sub_label.text = "État %d %%   Carburant %d / %d L   %d km parcourus" % [
		int(float(inst.get("condition", 100.0))),
		int(float(inst.get("fuel", 0.0))),
		int(float(def["fuel_tank_l"])),
		int(float(inst.get("km", 0.0))),
	]
	_preview.show_vehicle(def, inst.get("custom", {}), inst.get("upgrades", {}))


func _refresh_map_label() -> void:
	var m := str(GameState.settings.get("map", "test"))
	_map_label.text = "Carte : " + ("Kinshasa (lieux réels simplifiés)" if m == "kinshasa" else "zone de test")


# ---------------------------------------------------------------- boutons

func _on_play() -> void:
	GameState.navigate(GameState.SCENE_GAME)


func _on_garage() -> void:
	GameState.navigate(GameState.SCENE_GARAGE)


func _on_shop() -> void:
	GameState.navigate(GameState.SCENE_SHOP)


func _on_profile() -> void:
	GameState.navigate(GameState.SCENE_PROFILE)


func _on_settings() -> void:
	GameState.navigate(GameState.SCENE_SETTINGS)


func _on_missions() -> void:
	var msg := "Pas encore disponible dans cette version. Prévu : courses avec clients (négociation du prix en français et en lingala), livraisons et missions du jour. En attendant, tu peux conduire librement, acheter, réparer et améliorer des véhicules."
	UiKit.show_dialog(self, "Missions", msg, [{"text": "OK", "variant": "PrimaryButton"}])


func _on_map() -> void:
	var msg := "Pour l'instant, seule la zone de test est jouable : petite ville inventée pour essayer la conduite.\n\nLa carte de Kinshasa (Gare Centrale, Stade des Martyrs, Palais du Peuple, échangeur de Limete...) est en préparation et arrivera dans une prochaine version."
	UiKit.show_dialog(self, "Carte", msg, [{"text": "OK", "variant": "PrimaryButton"}])


func _set_map(map_id: String) -> void:
	GameState.settings["map"] = map_id
	GameState.save_game()
	_refresh_map_label()
	UiKit.toast(self, "Carte choisie : " + ("Kinshasa" if map_id == "kinshasa" else "zone de test"), true)


# ---------------------------------------------------------------- bouton Retour d'Android

func _on_back_requested() -> void:
	if _quit_dialog != null and is_instance_valid(_quit_dialog):
		return
	var buttons: Array = [
		{"text": "Rester", "variant": "PrimaryButton"},
		{"text": "Quitter", "callback": _quit_game, "variant": "DangerButton"},
	]
	_quit_dialog = UiKit.show_dialog(self, "Quitter le jeu ?", "Ta progression est sauvegardée automatiquement.", buttons)


func _quit_game() -> void:
	GameState.save_game()
	get_tree().quit()
