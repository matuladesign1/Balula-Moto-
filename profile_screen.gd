extends ScreenBase
## Profil du joueur : nom, statistiques, historique de l'argent, outils de test, nouvelle partie.

const MAX_ROWS := 80

var _name_edit: LineEdit
var _stats_box: VBoxContainer
var _ledger_box: VBoxContainer
var _filter := "tout"                 # "tout", "gains" ou "depenses"
var _filter_buttons: Dictionary = {}


func _ready() -> void:
	begin_screen("Profil")
	var root := UiKit.hbox(16)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(root)
	root.add_child(_build_left())
	root.add_child(_build_right())
	_refresh_stats()
	_refresh_ledger()
	GameState.garage_changed.connect(_on_state_changed)


func _on_state_changed() -> void:
	_refresh_stats()
	_refresh_ledger()


# ---------------------------------------------------------------- colonne de gauche

func _build_left() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := UiKit.vbox(12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	var p1 := UiKit.panel(14)
	col.add_child(p1)
	var b1 := UiKit.panel_body(p1)
	b1.add_child(UiKit.label("Nom du chauffeur", 24, UiKit.C_YELLOW))
	var row := UiKit.hbox(10)
	b1.add_child(row)
	_name_edit = LineEdit.new()
	_name_edit.text = str(GameState.profile.get("player_name", ""))
	_name_edit.max_length = 20
	_name_edit.custom_minimum_size = Vector2(0, 56)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name_edit)
	row.add_child(UiKit.button("Enregistrer", _on_save_name, "PrimaryButton", Vector2(150, 56)))

	var p2 := UiKit.panel(14)
	col.add_child(p2)
	_stats_box = UiKit.panel_body(p2)

	var p3 := UiKit.panel(14)
	col.add_child(p3)
	var b3 := UiKit.panel_body(p3)
	b3.add_child(UiKit.label("Outils", 24, UiKit.C_YELLOW))
	b3.add_child(UiKit.wrapped_label("Mode test : donne de l'argent pour essayer le magasin (les prix sont en millions de CDF). Outil de test, à retirer avant la publication.", 18))
	b3.add_child(UiKit.button("Mode test : +%s" % Balance.cdf(Balance.TEST_BONUS), _on_test_bonus))
	b3.add_child(UiKit.wrapped_label("Nouvelle partie : recommence avec %s et la moto de départ. L'ancienne sauvegarde est copiée avant d'être remplacée." % Balance.cdf(Balance.START_MONEY), 18))
	b3.add_child(UiKit.button("Nouvelle partie", _on_new_game, "DangerButton"))
	return scroll


func _stat_row(title: String, value: String) -> Control:
	var row := UiKit.hbox(10)
	row.add_child(UiKit.label(title, 21, UiKit.C_MUTED))
	row.add_child(UiKit.spacer())
	row.add_child(UiKit.label(value, 21, UiKit.C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
	return row


func _refresh_stats() -> void:
	UiKit.clear(_stats_box)
	var st: Dictionary = GameState.profile.get("stats", {})
	_stats_box.add_child(UiKit.label("Statistiques", 24, UiKit.C_YELLOW))
	_stats_box.add_child(_stat_row("Argent", Balance.cdf(GameState.money())))
	_stats_box.add_child(_stat_row("Véhicules dans le garage", str(GameState.all_instances().size())))
	_stats_box.add_child(_stat_row("Distance parcourue", "%.1f km" % float(st.get("total_km", 0.0))))
	_stats_box.add_child(_stat_row("Courses terminées", str(int(st.get("rides", 0)))))
	_stats_box.add_child(_stat_row("Niveau", str(int(GameState.profile.get("level", 1)))))
	_stats_box.add_child(_stat_row("Réputation", str(int(GameState.profile.get("reputation", 0)))))
	_stats_box.add_child(UiKit.wrapped_label("Niveau et réputation évolueront avec les courses (phase suivante).", 17))


func _on_save_name() -> void:
	var clean := _name_edit.text.strip_edges()
	if clean.is_empty():
		say("Le nom ne peut pas être vide.", false)
		return
	GameState.set_player_name(clean)
	say("Nom enregistré : " + clean)


func _on_test_bonus() -> void:
	GameState.add_test_bonus()
	say("+%s (mode test)" % Balance.cdf(Balance.TEST_BONUS))


func _on_new_game() -> void:
	var msg := "Tu vas recommencer avec %s et la moto de départ. Ton garage actuel sera effacé. L'ancienne sauvegarde est d'abord copiée dans le fichier « balula_save_avant_nouvelle_partie.json »." % Balance.cdf(Balance.START_MONEY)
	var buttons: Array = [
		{"text": "Annuler", "variant": "PrimaryButton"},
		{"text": "Nouvelle partie", "callback": _do_new_game, "variant": "DangerButton"},
	]
	UiKit.show_dialog(self, "Recommencer à zéro ?", msg, buttons)


func _do_new_game() -> void:
	GameState.start_new_game(_name_edit.text)
	GameState.go_home()


# ---------------------------------------------------------------- historique

func _build_right() -> Control:
	var p := UiKit.panel(14)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body := UiKit.panel_body(p)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(UiKit.label("Historique de l'argent", 24, UiKit.C_YELLOW))
	var filters := UiKit.hbox(8)
	body.add_child(filters)
	for spec in [["tout", "Tout"], ["gains", "Gains"], ["depenses", "Dépenses"]]:
		var b := UiKit.button(str(spec[1]), _on_filter.bind(str(spec[0])), "", Vector2(130, 46))
		_filter_buttons[str(spec[0])] = b
		filters.add_child(b)
	_style_filters()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_ledger_box = UiKit.vbox(6)
	_ledger_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_ledger_box)
	return p


func _on_filter(filter_id: String) -> void:
	_filter = filter_id
	_style_filters()
	_refresh_ledger()


func _style_filters() -> void:
	for id in _filter_buttons:
		var b: Button = _filter_buttons[id]
		b.theme_type_variation = "SelectedButton" if str(id) == _filter else ""


func _refresh_ledger() -> void:
	UiKit.clear(_ledger_box)
	var ledger: Array = GameState.profile.get("ledger", [])
	var shown := 0
	for i in range(ledger.size() - 1, -1, -1):
		var raw: Variant = ledger[i]
		if not (raw is Dictionary):
			continue
		var e: Dictionary = raw
		var amount := int(e.get("amount", 0))
		if _filter == "gains" and amount <= 0:
			continue
		if _filter == "depenses" and amount >= 0:
			continue
		_ledger_box.add_child(_ledger_row(e, amount))
		shown += 1
		if shown >= MAX_ROWS:
			break
	if shown == 0:
		_ledger_box.add_child(UiKit.wrapped_label("Aucune opération pour l'instant.", 20))


func _ledger_row(e: Dictionary, amount: int) -> Control:
	var row := UiKit.hbox(12)
	var date_l := UiKit.label(UiKit.time_text(float(e.get("t", 0))), 17, UiKit.C_MUTED)
	date_l.custom_minimum_size = Vector2(150, 0)
	row.add_child(date_l)
	var what := UiKit.label(str(e.get("label", "")), 20)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	what.clip_text = true
	row.add_child(what)
	var color := UiKit.C_GREEN if amount >= 0 else Color("#ff7a7a")
	var sign_text := "+" if amount > 0 else ""
	var amt := UiKit.label(sign_text + Balance.cdf(amount), 20, color, HORIZONTAL_ALIGNMENT_RIGHT)
	amt.custom_minimum_size = Vector2(190, 0)
	row.add_child(amt)
	return row
