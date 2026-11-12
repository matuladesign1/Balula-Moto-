extends ScreenBase
## Paramètres : commandes tactiles, images par seconde, catalogue de véhicules, aide.

var _toggle_buttons: Dictionary = {}
var _fps_buttons: Dictionary = {}
var _catalog_info: Label
var _warn_box: VBoxContainer


func _ready() -> void:
	begin_screen("Paramètres")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var col := UiKit.vbox(14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	col.add_child(UiKit.label("Affichage et commandes", 26, UiKit.C_YELLOW))
	col.add_child(_toggle_row("Boutons tactiles dans le jeu", "Flèches, gaz et frein affichés à l'écran (utile sur téléphone). Tu peux les cacher sur PC si tu joues au clavier.", "touch_controls"))
	col.add_child(_toggle_row("Afficher les images par seconde", "Petit compteur FPS en haut à droite pendant la conduite.", "show_fps"))
	col.add_child(_fps_row())

	col.add_child(UiKit.label("Catalogue de véhicules", 26, UiKit.C_YELLOW))
	_catalog_info = UiKit.wrapped_label("", 20, UiKit.C_TEXT)
	col.add_child(_catalog_info)
	col.add_child(UiKit.wrapped_label("Pour ajouter un véhicule sans refaire le jeu : copie un fichier .json dans le dossier ci-dessous, puis appuie sur « Recharger le catalogue » (explications dans docs/AJOUTER_UN_VEHICULE.md).", 18))
	col.add_child(UiKit.wrapped_label(ProjectSettings.globalize_path("user://vehicles"), 18, UiKit.C_YELLOW))
	var btns := UiKit.hbox(12)
	var reload_btn := UiKit.button("Recharger le catalogue", _on_reload, "PrimaryButton")
	reload_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(reload_btn)
	var folder_btn := UiKit.button("Créer / ouvrir le dossier", _on_open_folder)
	folder_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(folder_btn)
	col.add_child(btns)
	_warn_box = UiKit.vbox(4)
	col.add_child(_warn_box)
	_refresh_catalog_info()

	col.add_child(UiKit.label("Commandes", 26, UiKit.C_YELLOW))
	col.add_child(UiKit.wrapped_label("Clavier : flèches ou W A S D (touches ZQSD sur un clavier AZERTY), Espace = frein, Échap ou P = pause.\nTéléphone : boutons à l'écran. Le bouton Retour d'Android ouvre la pause en jeu et revient à l'écran précédent dans les menus.", 19))

	col.add_child(UiKit.label("À propos", 26, UiKit.C_YELLOW))
	col.add_child(UiKit.wrapped_label("BALULA MOTO, version de démonstration 0.1 (phase 1). Marques et modèles cités à titre indicatif, sans partenariat officiel. Les lieux de la carte de Kinshasa sont inspirés de lieux réels et simplifiés ; ceux marqués « fictif » n'existent pas.", 18))


# ---------------------------------------------------------------- réglages simples

func _toggle_row(title: String, hint: String, key: String) -> Control:
	var row := UiKit.hbox(14)
	var texts := UiKit.vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(UiKit.label(title, 24))
	texts.add_child(UiKit.wrapped_label(hint, 18))
	row.add_child(texts)
	var b := UiKit.button("", Callable(), "", Vector2(170, 56))
	b.pressed.connect(_on_toggle.bind(key))
	_toggle_buttons[key] = b
	_style_toggle(key)
	row.add_child(b)
	return row


func _on_toggle(key: String) -> void:
	GameState.settings[key] = not bool(GameState.settings.get(key, false))
	GameState.save_game()
	_style_toggle(key)


func _style_toggle(key: String) -> void:
	var b: Button = _toggle_buttons[key]
	var on := bool(GameState.settings.get(key, false))
	b.text = "Activé" if on else "Désactivé"
	b.theme_type_variation = "SelectedButton" if on else ""


func _fps_row() -> Control:
	var row := UiKit.hbox(14)
	var texts := UiKit.vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(UiKit.label("Limite d'images par seconde", 24))
	texts.add_child(UiKit.wrapped_label("30 économise la batterie des téléphones modestes ; 60 est plus fluide.", 18))
	row.add_child(texts)
	for fps in [30, 60]:
		var b := UiKit.button("%d FPS" % fps, _on_fps.bind(fps), "", Vector2(110, 56))
		_fps_buttons[fps] = b
		row.add_child(b)
	_style_fps()
	return row


func _on_fps(fps: int) -> void:
	GameState.settings["fps_cap"] = fps
	GameState.apply_settings()
	GameState.save_game()
	_style_fps()


func _style_fps() -> void:
	var current := int(GameState.settings.get("fps_cap", 60))
	for fps in _fps_buttons:
		var b: Button = _fps_buttons[fps]
		b.theme_type_variation = "SelectedButton" if int(fps) == current else ""


# ---------------------------------------------------------------- catalogue

func _refresh_catalog_info() -> void:
	_catalog_info.text = "%d véhicules chargés, %d catégories." % [Catalog.all_vehicles().size(), Catalog.categories.size()]
	UiKit.clear(_warn_box)
	if Catalog.load_warnings.is_empty():
		_warn_box.add_child(UiKit.label("Aucun problème détecté dans les fichiers.", 19, UiKit.C_GREEN))
	else:
		for w in Catalog.load_warnings:
			_warn_box.add_child(UiKit.wrapped_label("- " + str(w), 18, Color("#ffb347")))


func _on_reload() -> void:
	Catalog.reload()
	_refresh_catalog_info()
	say("Catalogue rechargé : %d véhicules." % Catalog.all_vehicles().size(), Catalog.load_warnings.is_empty())


func _on_open_folder() -> void:
	DirAccess.make_dir_recursive_absolute("user://vehicles")
	var path := ProjectSettings.globalize_path("user://vehicles")
	if OS.has_feature("pc"):
		OS.shell_open(path)
		say("Dossier ouvert : " + path)
	else:
		say("Dossier créé : " + path)
