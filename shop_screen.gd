extends ScreenBase
## Magasin de véhicules : catégories, liste, aperçu 3D, statistiques, achat, essai, comparaison.
## Les véhicules viennent du catalogue (fichiers JSON) : en ajouter un ne demande aucun changement ici.

var _cats: Array = []
var _cat_id := ""
var _model_id := ""
var _tab_buttons: Dictionary = {}
var _list_box: VBoxContainer
var _preview: VehiclePreview
var _info_box: VBoxContainer
var _footer: HBoxContainer


func _ready() -> void:
	begin_screen("Magasin de véhicules")
	if Catalog.all_vehicles().is_empty():
		content.add_child(UiKit.wrapped_label("Aucun véhicule trouvé dans le catalogue. Vérifie les fichiers du dossier data/vehicles (voir Paramètres).", 22, Color("#ffb347")))
		return
	_cats = _category_list()
	_choose_initial()
	_build_layout()
	_rebuild_all()


# ---------------------------------------------------------------- données

## Catégories du fichier categories.json + celles que des véhicules ajoutés pourraient utiliser.
func _category_list() -> Array:
	var out: Array = []
	var known: Dictionary = {}
	for c in Catalog.categories:
		var cid := str(c.get("id", ""))
		out.append({"id": cid, "label": str(c.get("label", cid))})
		known[cid] = true
	for v in Catalog.all_vehicles():
		var vcat := str(v["category"])
		if not known.has(vcat):
			known[vcat] = true
			out.append({"id": vcat, "label": vcat.capitalize()})
	return out


func _choose_initial() -> void:
	var mem_model := str(GameState.ui_memory.get("shop_model", ""))
	if Catalog.has_vehicle(mem_model):
		_model_id = mem_model
		_cat_id = str(Catalog.get_vehicle(mem_model)["category"])
		return
	var first: Dictionary = Catalog.all_vehicles()[0]
	_model_id = str(first["id"])
	_cat_id = str(first["category"])


func _remember() -> void:
	GameState.ui_memory["shop_cat"] = _cat_id
	GameState.ui_memory["shop_model"] = _model_id


func _owned_count(model_id: String) -> int:
	var n := 0
	for inst in GameState.all_instances():
		if str(inst["model_id"]) == model_id:
			n += 1
	return n


# ---------------------------------------------------------------- construction

func _build_layout() -> void:
	var tabs := GridContainer.new()
	tabs.columns = 4
	tabs.add_theme_constant_override("h_separation", 8)
	tabs.add_theme_constant_override("v_separation", 8)
	content.add_child(tabs)
	for c in _cats:
		var cid := str(c["id"])
		var tb := UiKit.button(str(c["label"]), _on_category.bind(cid), "", Vector2(0, 46))
		tb.add_theme_font_size_override("font_size", 19)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tab_buttons[cid] = tb
		tabs.add_child(tb)

	var main := UiKit.hbox(12)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(main)

	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(310, 0)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(list_scroll)
	_list_box = UiKit.vbox(8)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_list_box)

	var detail := UiKit.panel(12)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(detail)
	var dbody := UiKit.panel_body(detail)
	dbody.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cols := UiKit.hbox(14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dbody.add_child(cols)
	_preview = VehiclePreview.new()
	_preview.custom_minimum_size = Vector2(340, 260)
	cols.add_child(_preview)
	var info_scroll := ScrollContainer.new()
	info_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(info_scroll)
	_info_box = UiKit.vbox(6)
	_info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_scroll.add_child(_info_box)
	_footer = UiKit.hbox(10)
	dbody.add_child(_footer)


func _rebuild_all() -> void:
	for cid in _tab_buttons:
		var tb: Button = _tab_buttons[cid]
		tb.theme_type_variation = "SelectedButton" if str(cid) == _cat_id else ""
	_rebuild_list()
	_rebuild_detail()


func _rebuild_list() -> void:
	UiKit.clear(_list_box)
	var items := Catalog.vehicles_in_category(_cat_id)
	if items.is_empty():
		_list_box.add_child(UiKit.wrapped_label("Aucun véhicule dans cette catégorie.", 20))
		return
	for def in items:
		var mid := str(def["id"])
		var text := "%s\n%s" % [str(def["name"]), Balance.cdf(int(def["price_cdf"]))]
		var owned := _owned_count(mid)
		if owned > 0:
			text += "   (possédé x%d)" % owned
		var variant := "SelectedButton" if mid == _model_id else ""
		var b := UiKit.button(text, _on_pick.bind(mid), variant, Vector2(0, 74))
		b.add_theme_font_size_override("font_size", 20)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_list_box.add_child(b)


func _rebuild_detail() -> void:
	UiKit.clear(_info_box)
	UiKit.clear(_footer)
	var def := Catalog.get_vehicle(_model_id)
	if def.is_empty():
		_preview.show_vehicle({}, {}, {})
		_info_box.add_child(UiKit.wrapped_label("Choisis un véhicule dans la liste.", 22))
		return
	_preview.show_vehicle(def, def.get("default_custom", {}), {})

	var kind := "Moto" if str(def["type"]) == "moto" else "Tricycle"
	_info_box.add_child(UiKit.label(str(def["name"]), 30, UiKit.C_YELLOW))
	_info_box.add_child(UiKit.label("%s  -  %s" % [kind, Catalog.category_label(str(def["category"]))], 19, UiKit.C_MUTED))
	if str(def["description"]) != "":
		_info_box.add_child(UiKit.wrapped_label(str(def["description"]), 19, UiKit.C_TEXT))

	var price := int(def["price_cdf"])
	_info_box.add_child(UiKit.label("Prix : " + Balance.cdf(price), 26))
	var missing := price - GameState.money()
	if missing > 0:
		_info_box.add_child(UiKit.wrapped_label("Budget insuffisant : il te manque %s." % Balance.cdf(missing), 19, Color("#ffb347")))
	else:
		_info_box.add_child(UiKit.label("Tu as assez d'argent.", 19, UiKit.C_GREEN))
	var owned := _owned_count(_model_id)
	if owned > 0:
		_info_box.add_child(UiKit.label("Dans ton garage : %d" % owned, 19, UiKit.C_GREEN))

	var perf := UiKit.hbox(10)
	perf.add_child(UiKit.label("Performance", 19, UiKit.C_MUTED))
	perf.add_child(UiKit.pips(int(def["performance_level"])))
	_info_box.add_child(perf)
	_info_box.add_child(VehicleInfo.stats_panel(def))
	_info_box.add_child(UiKit.wrapped_label("Marques et modèles cités à titre indicatif, sans partenariat officiel. Prix et performances : valeurs du jeu, pas des valeurs réelles.", 16))

	var buy := UiKit.button("Acheter", _on_buy, "PrimaryButton" if missing <= 0 else "", Vector2(0, 60))
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(buy)
	var try_b := UiKit.button("Essayer", _on_try, "", Vector2(0, 60))
	try_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(try_b)
	var pinned := str(GameState.ui_memory.get("shop_pin", "")) == _model_id
	var pin := UiKit.button("Désépingler" if pinned else "Épingler", _on_pin, "SelectedButton" if pinned else "", Vector2(0, 60))
	pin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(pin)
	var cmp := UiKit.button("Comparer", _on_compare, "", Vector2(0, 60))
	cmp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(cmp)


# ---------------------------------------------------------------- choix

func _on_category(cat_id: String) -> void:
	_cat_id = cat_id
	var items := Catalog.vehicles_in_category(cat_id)
	var keep := false
	for def in items:
		if str(def["id"]) == _model_id:
			keep = true
	if not keep:
		_model_id = str(items[0]["id"]) if not items.is_empty() else ""
	_remember()
	_rebuild_all()


func _on_pick(model_id: String) -> void:
	_model_id = model_id
	_remember()
	_rebuild_list()
	_rebuild_detail()


# ---------------------------------------------------------------- achat, essai, comparaison

func _on_buy() -> void:
	var def := Catalog.get_vehicle(_model_id)
	if def.is_empty():
		return
	var price := int(def["price_cdf"])
	if not GameState.can_afford(price):
		say("Budget insuffisant : il te manque %s." % Balance.cdf(price - GameState.money()), false)
		return
	var msg := "Acheter %s pour %s ?\nIl te restera %s." % [str(def["name"]), Balance.cdf(price), Balance.cdf(GameState.money() - price)]
	var buttons: Array = [
		{"text": "Annuler"},
		{"text": "Acheter", "callback": _confirm_buy, "variant": "PrimaryButton"},
	]
	UiKit.show_dialog(self, "Confirmer l'achat", msg, buttons)


func _confirm_buy() -> void:
	var res := GameState.buy_vehicle(_model_id)
	_rebuild_all()
	if bool(res.get("ok", false)):
		GameState.ui_memory["garage_uid"] = str(res.get("uid", ""))
		var buttons: Array = [
			{"text": "Continuer"},
			{"text": "Ouvrir le garage", "callback": _open_garage, "variant": "PrimaryButton"},
		]
		UiKit.show_dialog(self, "Achat réussi", str(res.get("message", "")), buttons)
	else:
		say_result(res)


func _open_garage() -> void:
	GameState.navigate(GameState.SCENE_GARAGE)


func _on_try() -> void:
	if _model_id == "":
		return
	_remember()
	GameState.start_trial(_model_id)


func _on_pin() -> void:
	if str(GameState.ui_memory.get("shop_pin", "")) == _model_id:
		GameState.ui_memory["shop_pin"] = ""
		say("Épingle retirée.")
	else:
		GameState.ui_memory["shop_pin"] = _model_id
		say("Véhicule épinglé : choisis-en un autre puis appuie sur Comparer.")
	_rebuild_detail()


func _on_compare() -> void:
	var def := Catalog.get_vehicle(_model_id)
	if def.is_empty():
		return
	var other_def: Dictionary = {}
	var other_stats: Dictionary = {}
	var other_label := ""
	var pin_id := str(GameState.ui_memory.get("shop_pin", ""))
	if pin_id != "" and pin_id != _model_id and Catalog.has_vehicle(pin_id):
		other_def = Catalog.get_vehicle(pin_id)
		other_label = str(other_def["name"]) + " (épinglé)"
	else:
		var inst := GameState.active_instance()
		other_def = Catalog.get_vehicle(str(inst.get("model_id", "")))
		other_stats = GameState.effective_stats(inst)
		other_label = str(other_def.get("name", "?")) + " (ton véhicule actif)"
	if other_def.is_empty():
		say("Aucun autre véhicule à comparer.", false)
		return
	var table := VehicleInfo.compare_panel(def, {}, str(def["name"]), other_def, other_stats, other_label)
	var hint := UiKit.wrapped_label("Vert = meilleur, rouge = moins bon. Astuce : épingle un véhicule pour le comparer avec n'importe quel autre.", 17)
	var holder := UiKit.vbox(10)
	holder.add_child(table)
	holder.add_child(hint)
	UiKit.show_dialog(self, "Comparaison", "", [{"text": "Fermer", "variant": "PrimaryButton"}], holder)
