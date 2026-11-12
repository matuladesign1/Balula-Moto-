extends ScreenBase
## Garage / atelier : mes véhicules, état, réparation, plein, vente, améliorations, personnalisation 3D.
## Toutes les opérations passent par GameState (qui vérifie l'argent et sauvegarde).

const EFFECT_LABELS := {
	"power_mult": "Puissance",
	"accel_mult": "Accélération",
	"speed_mult": "Vitesse max",
	"brake_mult": "Freinage",
	"handling_mult": "Maniabilité",
	"damage_mult": "Dégâts subis",
}

var _uid := ""
var _tab := "infos"            # "infos", "upgrades" ou "custom"
var _pv_cat := ""              # option de personnalisation en aperçu (pas encore achetée)
var _pv_opt := ""
var _cmp_offset := 1
var _list_box: VBoxContainer
var _preview: VehiclePreview
var _summary_box: VBoxContainer
var _tab_buttons: Dictionary = {}
var _tab_box: VBoxContainer
var _pv_bar: HBoxContainer


func _ready() -> void:
	begin_screen("Garage")
	var mem := str(GameState.ui_memory.get("garage_uid", ""))
	if not GameState.find_instance(mem).is_empty():
		_uid = mem
	else:
		_uid = str(GameState.active_instance().get("uid", ""))
	_build_layout()
	_refresh_all()
	GameState.garage_changed.connect(_refresh_all)


# ---------------------------------------------------------------- construction

func _build_layout() -> void:
	var root := UiKit.hbox(12)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(root)

	# Colonne A : liste de mes véhicules
	var col_a := UiKit.vbox(8)
	col_a.custom_minimum_size = Vector2(280, 0)
	root.add_child(col_a)
	col_a.add_child(UiKit.label("Mes véhicules", 24, UiKit.C_YELLOW))
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col_a.add_child(list_scroll)
	_list_box = UiKit.vbox(8)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_list_box)
	col_a.add_child(UiKit.button("Acheter un véhicule", _open_shop, "", Vector2(0, 56)))

	# Colonne B : aperçu 3D, nom, actions rapides
	var col_b := UiKit.vbox(8)
	col_b.custom_minimum_size = Vector2(340, 0)
	root.add_child(col_b)
	_preview = VehiclePreview.new()
	_preview.custom_minimum_size = Vector2(340, 240)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_b.add_child(_preview)
	_summary_box = UiKit.vbox(6)
	col_b.add_child(_summary_box)

	# Colonne C : onglets
	var col_c := UiKit.vbox(8)
	col_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(col_c)
	var tabs := UiKit.hbox(8)
	col_c.add_child(tabs)
	for spec in [["infos", "Infos"], ["upgrades", "Améliorations"], ["custom", "Personnaliser"]]:
		var tb := UiKit.button(str(spec[1]), _on_tab.bind(str(spec[0])), "", Vector2(0, 50))
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tab_buttons[str(spec[0])] = tb
		tabs.add_child(tb)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col_c.add_child(scroll)
	_tab_box = UiKit.vbox(10)
	_tab_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_tab_box)
	_pv_bar = UiKit.hbox(10)
	col_c.add_child(_pv_bar)


func _refresh_all() -> void:
	if GameState.find_instance(_uid).is_empty():
		_uid = str(GameState.active_instance().get("uid", ""))
		_pv_cat = ""
		_pv_opt = ""
	_rebuild_list()
	_rebuild_summary()
	_rebuild_tab()
	_refresh_preview_model()
	_update_preview_bar()


func _rebuild_list() -> void:
	UiKit.clear(_list_box)
	var active_uid := str(GameState.profile.get("active_uid", ""))
	for inst in GameState.all_instances():
		var uid := str(inst["uid"])
		var def := Catalog.get_vehicle(str(inst["model_id"]))
		var title := "Modèle inconnu (%s)" % str(inst["model_id"])
		if not def.is_empty():
			title = str(def["name"])
		if uid == active_uid:
			title += "  [ACTIF]"
		var sub := "État %d %%" % int(float(inst.get("condition", 100.0)))
		if not def.is_empty():
			sub += "  -  %d / %d L" % [int(float(inst.get("fuel", 0.0))), int(float(def["fuel_tank_l"]))]
		var variant := "SelectedButton" if uid == _uid else ""
		var b := UiKit.button(title + "\n" + sub, _on_select.bind(uid), variant, Vector2(0, 74))
		b.add_theme_font_size_override("font_size", 19)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_list_box.add_child(b)


func _rebuild_summary() -> void:
	UiKit.clear(_summary_box)
	var inst := GameState.find_instance(_uid)
	if inst.is_empty():
		return
	var def := Catalog.get_vehicle(str(inst["model_id"]))
	if def.is_empty():
		_summary_box.add_child(UiKit.wrapped_label("Ce modèle n'est plus dans le catalogue (fichier supprimé ?). Tu peux seulement le vendre.", 19, Color("#ffb347")))
		_summary_box.add_child(UiKit.button("Vendre", _on_sell, "DangerButton", Vector2(0, 52)))
		return
	var active := str(GameState.profile.get("active_uid", "")) == _uid
	_summary_box.add_child(UiKit.label(str(def["name"]), 28, UiKit.C_YELLOW))
	if active:
		_summary_box.add_child(UiKit.label("Véhicule actif", 19, UiKit.C_GREEN))
	else:
		_summary_box.add_child(UiKit.label("Pas le véhicule actif", 19, UiKit.C_MUTED))
	_summary_box.add_child(UiKit.button("Conduire ce véhicule", _on_drive, "PrimaryButton", Vector2(0, 56)))
	if not active:
		_summary_box.add_child(UiKit.button("Définir comme actif", _on_set_active, "", Vector2(0, 52)))


func _rebuild_tab() -> void:
	for id in _tab_buttons:
		var tb: Button = _tab_buttons[id]
		tb.theme_type_variation = "SelectedButton" if str(id) == _tab else ""
	UiKit.clear(_tab_box)
	var inst := GameState.find_instance(_uid)
	var def := Catalog.get_vehicle(str(inst.get("model_id", "")))
	if inst.is_empty() or def.is_empty():
		return
	if _tab == "upgrades":
		_build_upgrades(inst, def)
	elif _tab == "custom":
		_build_custom(inst, def)
	else:
		_build_infos(inst, def)


func _refresh_preview_model() -> void:
	var inst := GameState.find_instance(_uid)
	var def := Catalog.get_vehicle(str(inst.get("model_id", "")))
	if inst.is_empty() or def.is_empty():
		_preview.show_vehicle({}, {}, {})
		return
	var custom: Dictionary = inst["custom"].duplicate()
	if _pv_opt != "":
		custom[_pv_cat] = _pv_opt
	_preview.show_vehicle(def, custom, inst["upgrades"])


# ---------------------------------------------------------------- onglet Infos

func _bar_row(title: String, ratio: float, value_text: String, color: Color) -> Control:
	var row := UiKit.hbox(8)
	var l := UiKit.label(title, 19, UiKit.C_MUTED)
	l.custom_minimum_size = Vector2(130, 0)
	row.add_child(l)
	row.add_child(UiKit.bar(ratio, color))
	var v := UiKit.label(value_text, 19, UiKit.C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	v.custom_minimum_size = Vector2(110, 0)
	row.add_child(v)
	return row


func _build_infos(inst: Dictionary, def: Dictionary) -> void:
	var stats := GameState.effective_stats(inst)
	var p1 := UiKit.panel(12)
	_tab_box.add_child(p1)
	var b1 := UiKit.panel_body(p1)
	b1.add_child(UiKit.label("Performances actuelles", 24, UiKit.C_YELLOW))
	b1.add_child(VehicleInfo.stats_panel(def, stats))
	b1.add_child(UiKit.wrapped_label("Valeurs avec améliorations et usure prises en compte.", 17))

	var cond := float(inst.get("condition", 100.0))
	var fuel := float(inst.get("fuel", 0.0))
	var cap := maxf(float(def["fuel_tank_l"]), 1.0)
	var p2 := UiKit.panel(12)
	_tab_box.add_child(p2)
	var b2 := UiKit.panel_body(p2)
	b2.add_child(UiKit.label("État du véhicule", 24, UiKit.C_YELLOW))
	var cond_color := UiKit.C_GREEN
	if cond < 30.0:
		cond_color = UiKit.C_RED
	elif cond < 60.0:
		cond_color = Color("#f0a030")
	b2.add_child(_bar_row("État général", cond / 100.0, "%d %%" % int(cond), cond_color))
	var fuel_color := UiKit.C_BLUE
	if fuel / cap < 0.15:
		fuel_color = UiKit.C_RED
	elif fuel / cap < 0.4:
		fuel_color = Color("#f0a030")
	b2.add_child(_bar_row("Carburant", fuel / cap, "%d / %d L" % [int(fuel), int(cap)], fuel_color))
	b2.add_child(UiKit.label("Distance parcourue : %.1f km" % float(inst.get("km", 0.0)), 19))
	b2.add_child(UiKit.label("Valeur de revente : " + Balance.cdf(GameState.resale_value(inst)), 19))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_tab_box.add_child(grid)
	var repair_text := "Réparer - " + Balance.cdf(GameState.repair_cost(inst))
	if cond >= 99.5:
		repair_text = "Réparer (parfait état)"
	var fuel_text := "Faire le plein - " + Balance.cdf(GameState.refuel_cost(inst))
	if GameState.refuel_cost(inst) <= 0:
		fuel_text = "Réservoir plein"
	_action_button(grid, repair_text, _on_repair, "")
	_action_button(grid, fuel_text, _on_refuel, "")
	_action_button(grid, "Comparer", _on_compare, "")
	_action_button(grid, "Vendre - " + Balance.cdf(GameState.resale_value(inst)), _on_sell, "DangerButton")


func _action_button(grid: GridContainer, text: String, callback: Callable, variant: String) -> void:
	var b := UiKit.button(text, callback, variant, Vector2(0, 56))
	b.add_theme_font_size_override("font_size", 20)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(b)


# ---------------------------------------------------------------- onglet Améliorations

func _effects_text(level: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in EFFECT_LABELS:
		if level.has(key):
			var pct := int(round((float(level[key]) - 1.0) * 100.0))
			var sign_text := "+" if pct > 0 else ""
			parts.append("%s %s%d %%" % [str(EFFECT_LABELS[key]), sign_text, pct])
	return ", ".join(parts)


func _build_upgrades(inst: Dictionary, def: Dictionary) -> void:
	for u in Catalog.performance_upgrades():
		_tab_box.add_child(_upgrade_card(inst, def, u))
	_tab_box.add_child(_tires_card(inst, def))


func _upgrade_card(inst: Dictionary, def: Dictionary, u: Dictionary) -> Control:
	var up_id := str(u.get("id", ""))
	var levels: Array = u.get("levels", [])
	var level := GameState.upgrade_level(inst, up_id)
	var p := UiKit.panel(12)
	var body := UiKit.panel_body(p)
	var head := UiKit.hbox(12)
	body.add_child(head)
	head.add_child(UiKit.label(str(u.get("label", up_id)), 24, UiKit.C_YELLOW))
	head.add_child(UiKit.spacer())
	head.add_child(UiKit.pips(level, maxi(levels.size(), 1)))
	body.add_child(UiKit.wrapped_label(str(u.get("description", "")), 18))
	if levels.is_empty():
		body.add_child(UiKit.label("Indisponible.", 19))
	elif level >= levels.size():
		body.add_child(UiKit.wrapped_label("Niveau maximum : " + str(levels[levels.size() - 1].get("name", "")), 20, UiKit.C_GREEN))
	else:
		var nxt: Dictionary = levels[level]
		var price := Catalog.upgrade_price(def, up_id, level + 1)
		body.add_child(UiKit.wrapped_label("Prochain niveau : %s\n%s" % [str(nxt.get("name", "")), _effects_text(nxt)], 19, UiKit.C_TEXT))
		var variant := "PrimaryButton" if GameState.can_afford(price) else ""
		body.add_child(UiKit.button("Installer - " + Balance.cdf(price), _on_buy_upgrade.bind(up_id), variant, Vector2(0, 54)))
	return p


func _tires_card(inst: Dictionary, def: Dictionary) -> Control:
	var p := UiKit.panel(12)
	var body := UiKit.panel_body(p)
	body.add_child(UiKit.label("Pneus", 24, UiKit.C_YELLOW))
	body.add_child(UiKit.wrapped_label("Route : plus d'adhérence sur le bitume. Tout-terrain : pour les pistes.", 18))
	var current := str(inst["upgrades"].get("tires", "standard"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	body.add_child(flow)
	for o in Catalog.tire_options():
		var oid := str(o.get("id", ""))
		var key := "tires:" + oid
		var owned: bool = inst["unlocked"].has(key)
		var price := 0 if owned else Catalog.tire_price(def, oid)
		var sub := Balance.cdf(price)
		if oid == current:
			sub = "monté"
		elif owned:
			sub = "possédé"
		elif price == 0:
			sub = "gratuit"
		var variant := "SelectedButton" if oid == current else ""
		var b := UiKit.button("%s\n%s" % [str(o.get("name", oid)), sub], _on_tires.bind(oid), variant, Vector2(170, 66))
		b.add_theme_font_size_override("font_size", 19)
		flow.add_child(b)
	return p


# ---------------------------------------------------------------- onglet Personnaliser

func _swatch(color: Color) -> ImageTexture:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _build_custom(inst: Dictionary, def: Dictionary) -> void:
	_tab_box.add_child(UiKit.wrapped_label("Choisis une option pour la voir sur le véhicule. Elle n'est achetée que si tu appuies sur « Acheter » ou « Appliquer ».", 18))
	for cat in Catalog.aesthetic_categories(str(def.get("type", "moto"))):
		var cid := str(cat["id"])
		var options: Array = cat["options"]
		var current := str(inst["custom"].get(cid, ""))
		if current == "" and not options.is_empty():
			current = str(options[0]["id"])   # sans choix enregistré, c'est l'option d'origine
		var box := UiKit.vbox(6)
		_tab_box.add_child(box)
		box.add_child(UiKit.label(str(cat["label"]), 22, UiKit.C_YELLOW))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		box.add_child(flow)
		for o in options:
			var oid := str(o["id"])
			var key := cid + ":" + oid
			var sub := ""
			if oid == current:
				sub = "installé"
			elif inst["unlocked"].has(key):
				sub = "possédé"
			elif int(o.get("price", 0)) == 0:
				sub = "gratuit"
			else:
				sub = Balance.cdf(int(o.get("price", 0)))
			var variant := ""
			if oid == current:
				variant = "SelectedButton"
			elif cid == _pv_cat and oid == _pv_opt:
				variant = "PrimaryButton"
			var b := UiKit.button("%s\n%s" % [str(o.get("name", oid)), sub], _on_option.bind(cid, oid), variant, Vector2(150, 64))
			b.add_theme_font_size_override("font_size", 18)
			if cid == "color" and o.has("value"):
				b.icon = _swatch(Color(str(o["value"])))
			flow.add_child(b)


func _update_preview_bar() -> void:
	UiKit.clear(_pv_bar)
	_pv_bar.visible = (_tab == "custom" and _pv_opt != "")
	if not _pv_bar.visible:
		return
	var inst := GameState.find_instance(_uid)
	if inst.is_empty():
		return
	var opt := Catalog.aesthetic_option(_pv_cat, _pv_opt)
	var price := GameState.custom_option_price(inst, _pv_cat, _pv_opt)
	var l := UiKit.label("Aperçu : %s" % str(opt.get("name", _pv_opt)), 21, UiKit.C_YELLOW)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pv_bar.add_child(l)
	var apply_text := "Appliquer (gratuit)" if price == 0 else "Acheter - " + Balance.cdf(price)
	_pv_bar.add_child(UiKit.button(apply_text, _on_apply_preview, "PrimaryButton", Vector2(0, 52)))
	_pv_bar.add_child(UiKit.button("Annuler", _on_cancel_preview, "", Vector2(0, 52)))


func _on_option(cat_id: String, option_id: String) -> void:
	var inst := GameState.find_instance(_uid)
	if inst.is_empty():
		return
	var current := str(inst["custom"].get(cat_id, ""))
	if option_id == current:
		_pv_cat = ""
		_pv_opt = ""
		_rebuild_tab()
		_refresh_preview_model()
		_update_preview_bar()
		say("Déjà installé.", false)
		return
	_pv_cat = cat_id
	_pv_opt = option_id
	_rebuild_tab()
	_refresh_preview_model()
	_update_preview_bar()


func _on_apply_preview() -> void:
	var cat := _pv_cat
	var opt := _pv_opt
	if opt == "":
		return
	_pv_cat = ""
	_pv_opt = ""
	var res := GameState.set_custom(_uid, cat, opt)
	say_result(res)
	if not bool(res.get("ok", false)):
		_pv_cat = cat
		_pv_opt = opt


func _on_cancel_preview() -> void:
	_pv_cat = ""
	_pv_opt = ""
	_rebuild_tab()
	_refresh_preview_model()
	_update_preview_bar()


# ---------------------------------------------------------------- actions

func _on_tab(tab_id: String) -> void:
	_tab = tab_id
	_pv_cat = ""
	_pv_opt = ""
	_rebuild_tab()
	_refresh_preview_model()
	_update_preview_bar()


func _on_select(uid: String) -> void:
	_uid = uid
	GameState.ui_memory["garage_uid"] = uid
	_pv_cat = ""
	_pv_opt = ""
	_refresh_all()


func _on_set_active() -> void:
	GameState.set_active(_uid)
	say("Véhicule actif : " + GameState.vehicle_name(GameState.find_instance(_uid)))


func _on_drive() -> void:
	GameState.set_active(_uid)
	GameState.navigate(GameState.SCENE_GAME)


func _open_shop() -> void:
	GameState.navigate(GameState.SCENE_SHOP)


func _on_repair() -> void:
	say_result(GameState.repair(_uid))


func _on_refuel() -> void:
	say_result(GameState.refuel(_uid))


func _on_buy_upgrade(upgrade_id: String) -> void:
	say_result(GameState.buy_upgrade(_uid, upgrade_id))


func _on_tires(tire_id: String) -> void:
	say_result(GameState.set_tires(_uid, tire_id))


func _on_sell() -> void:
	var inst := GameState.find_instance(_uid)
	if inst.is_empty():
		return
	if GameState.all_instances().size() <= 1:
		say("Tu dois garder au moins un véhicule pour travailler.", false)
		return
	var value := GameState.resale_value(inst)
	var msg := "Vendre %s pour %s ? Cette action est définitive." % [GameState.vehicle_name(inst), Balance.cdf(value)]
	var buttons: Array = [
		{"text": "Annuler", "variant": "PrimaryButton"},
		{"text": "Vendre", "callback": _confirm_sell, "variant": "DangerButton"},
	]
	UiKit.show_dialog(self, "Confirmer la vente", msg, buttons)


func _confirm_sell() -> void:
	say_result(GameState.sell_vehicle(_uid))


# ---------------------------------------------------------------- comparaison

func _on_compare() -> void:
	if GameState.all_instances().size() < 2:
		var buttons: Array = [
			{"text": "Fermer"},
			{"text": "Ouvrir le magasin", "callback": _open_shop, "variant": "PrimaryButton"},
		]
		UiKit.show_dialog(self, "Comparer", "Tu n'as qu'un véhicule. Au magasin, tu peux comparer chaque modèle avec ton véhicule actif.", buttons)
		return
	_cmp_offset = 1
	_show_compare()


func _next_compare() -> void:
	var n := GameState.all_instances().size()
	_cmp_offset = (_cmp_offset % maxi(n - 1, 1)) + 1
	_show_compare()


func _show_compare() -> void:
	var list: Array = GameState.all_instances()
	var idx := 0
	for i in list.size():
		if str(list[i]["uid"]) == _uid:
			idx = i
	var a: Dictionary = list[idx]
	var b: Dictionary = list[(idx + _cmp_offset) % list.size()]
	var table := VehicleInfo.compare_panel(
		Catalog.get_vehicle(str(a["model_id"])), GameState.effective_stats(a), GameState.vehicle_name(a),
		Catalog.get_vehicle(str(b["model_id"])), GameState.effective_stats(b), GameState.vehicle_name(b))
	var buttons: Array = [
		{"text": "Fermer", "variant": "PrimaryButton"},
		{"text": "Autre véhicule", "callback": _next_compare},
	]
	UiKit.show_dialog(self, "Comparaison de mes véhicules", "", buttons, table)
