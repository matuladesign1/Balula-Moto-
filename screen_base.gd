class_name ScreenBase
extends Control
## Base commune des écrans (magasin, garage, profil, paramètres) :
## fond, barre du haut avec bouton Retour et argent, bouton Retour d'Android.
## Chaque écran appelle begin_screen("Titre") au début de son _ready(), puis remplit `content`.

var content: VBoxContainer
var top_bar: PanelContainer
var money_label: Label


func begin_screen(title: String) -> void:
	theme = UiKit.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	add_child(margin)
	var rows := UiKit.vbox(10)
	margin.add_child(rows)
	top_bar = UiKit.top_bar(title)
	rows.add_child(top_bar)
	var back: Button = top_bar.get_meta("back_button")
	back.pressed.connect(_on_back)
	money_label = top_bar.get_meta("money_label")
	GameState.money_changed.connect(_on_money_changed)
	GameState.back_requested.connect(_on_back)
	content = UiKit.vbox(10)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(content)


func _on_back() -> void:
	GameState.go_back()


func _on_money_changed(amount: int) -> void:
	if money_label != null:
		money_label.text = Balance.cdf(amount)


func _exit_tree() -> void:
	if GameState.back_requested.is_connected(_on_back):
		GameState.back_requested.disconnect(_on_back)


## Message court en bas de l'écran.
func say(text: String, good: bool = true) -> void:
	UiKit.toast(self, text, good)


## Affiche le résultat d'une opération de GameState ({"ok": bool, "message": String}).
func say_result(res: Dictionary) -> void:
	say(str(res.get("message", "")), bool(res.get("ok", false)))
