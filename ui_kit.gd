class_name UiKit
extends RefCounted
## Petite boîte à outils pour construire l'interface par code : thème, boutons, fenêtres, messages.
## Couleurs inspirées du taxi jaune et du drapeau congolais (bleu ciel, jaune, rouge).

const C_BG := Color("#10151f")
const C_BG2 := Color("#1b2a44")
const C_PANEL := Color("#1a2232")
const C_PANEL_LIGHT := Color("#26334d")
const C_YELLOW := Color("#f7c600")
const C_BLUE := Color("#0b8bd6")
const C_RED := Color("#ce1126")
const C_GREEN := Color("#2ecc71")
const C_TEXT := Color("#f2f5fa")
const C_MUTED := Color("#9aa7bd")

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build_theme()
	return _theme


static func _flat(color: Color, radius: int = 12, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	return sb


static func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_color("font_color", "Label", C_TEXT)
	# Boutons
	t.set_stylebox("normal", "Button", _flat(C_PANEL_LIGHT))
	t.set_stylebox("hover", "Button", _flat(C_PANEL_LIGHT.lightened(0.12)))
	t.set_stylebox("pressed", "Button", _flat(C_PANEL_LIGHT.darkened(0.2), 12, C_YELLOW, 2))
	t.set_stylebox("disabled", "Button", _flat(Color("#1a2232"), 12))
	t.set_stylebox("focus", "Button", _flat(Color(0, 0, 0, 0), 12, C_YELLOW, 2))
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", C_TEXT)
	t.set_color("font_pressed_color", "Button", C_TEXT)
	t.set_color("font_disabled_color", "Button", Color("#5d6a80"))
	t.set_font_size("font_size", "Button", 22)
	# Bouton principal (jaune)
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", _flat(C_YELLOW))
	t.set_stylebox("hover", "PrimaryButton", _flat(C_YELLOW.lightened(0.15)))
	t.set_stylebox("pressed", "PrimaryButton", _flat(C_YELLOW.darkened(0.15)))
	t.set_stylebox("disabled", "PrimaryButton", _flat(Color("#4a4520")))
	t.set_color("font_color", "PrimaryButton", Color("#10151f"))
	t.set_color("font_hover_color", "PrimaryButton", Color("#10151f"))
	t.set_color("font_pressed_color", "PrimaryButton", Color("#10151f"))
	t.set_color("font_disabled_color", "PrimaryButton", Color("#8a8460"))
	# Bouton danger (rouge)
	t.set_type_variation("DangerButton", "Button")
	t.set_stylebox("normal", "DangerButton", _flat(C_RED))
	t.set_stylebox("hover", "DangerButton", _flat(C_RED.lightened(0.15)))
	t.set_stylebox("pressed", "DangerButton", _flat(C_RED.darkened(0.2)))
	# Bouton de liste sélectionné (bleu)
	t.set_type_variation("SelectedButton", "Button")
	t.set_stylebox("normal", "SelectedButton", _flat(C_BLUE, 12, C_YELLOW, 3))
	t.set_stylebox("hover", "SelectedButton", _flat(C_BLUE.lightened(0.1), 12, C_YELLOW, 3))
	t.set_stylebox("pressed", "SelectedButton", _flat(C_BLUE.darkened(0.1), 12, C_YELLOW, 3))
	# Panneaux, barres
	t.set_stylebox("panel", "PanelContainer", _flat(C_PANEL, 14))
	t.set_stylebox("background", "ProgressBar", _flat(Color("#0c111a"), 6))
	t.set_stylebox("fill", "ProgressBar", _flat(C_BLUE, 6))
	t.set_constant("separation", "HBoxContainer", 10)
	t.set_constant("separation", "VBoxContainer", 8)
	return t


# ---------------------------------------------------------------- fabriques de widgets

static func label(text: String, size: int = 22, color: Color = C_TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align as HorizontalAlignment
	return l


static func wrapped_label(text: String, size: int = 20, color: Color = C_MUTED) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func button(text: String, callback: Callable, variant: String = "", min_size: Vector2 = Vector2(0, 56)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	if variant != "":
		b.theme_type_variation = variant
	if callback.is_valid():
		b.pressed.connect(callback)
	return b


static func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## Panneau arrondi avec marges. Ajoute les enfants au conteneur renvoyé par panel.get_meta("body").
static func panel(margin: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	var m := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, margin)
	p.add_child(m)
	var body := vbox(8)
	m.add_child(body)
	p.set_meta("body", body)
	return p


static func panel_body(p: Control) -> VBoxContainer:
	return p.get_meta("body") as VBoxContainer


static func bar(ratio: float, color: Color = C_BLUE) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.value = clampf(ratio, 0.0, 1.0)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(120, 16)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.add_theme_stylebox_override("fill", _flat(color, 6))
	return pb


## Rangée de petits carrés (niveau 1 à 5) : évite les symboles qui manquent dans la police.
static func pips(level: int, max_level: int = 5) -> HBoxContainer:
	var h := hbox(5)
	for i in max_level:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(18, 18)
		r.color = C_YELLOW if i < level else Color("#0c111a")
		h.add_child(r)
	return h


static func background(host: Control) -> void:
	var g := Gradient.new()
	g.set_color(0, C_BG)
	g.set_color(1, C_BG2)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 256
	var tr := TextureRect.new()
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(tr)


## Barre du haut : bouton Retour, titre, argent. Renvoie la barre ; meta "back_button" et "money_label".
static func top_bar(title: String) -> PanelContainer:
	var p := PanelContainer.new()
	var m := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(side, 14)
	for side in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 6)
	p.add_child(m)
	var h := hbox(14)
	m.add_child(h)
	var back := button("< Retour", Callable(), "", Vector2(150, 52))
	h.add_child(back)
	h.add_child(label(title, 30, C_YELLOW))
	h.add_child(spacer())
	var money := label(Balance.cdf(GameState.money()), 26, C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	h.add_child(money)
	p.set_meta("back_button", back)
	p.set_meta("money_label", money)
	return p


## Retire et supprime tous les enfants d'un conteneur (pour reconstruire une liste).
static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## Date et heure locales lisibles à partir d'un temps Unix (UTC) : "11/11/2026 13:48".
static func time_text(unix_time: float) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(int(unix_time) + bias * 60)
	return "%02d/%02d/%04d %02d:%02d" % [int(d["day"]), int(d["month"]), int(d["year"]), int(d["hour"]), int(d["minute"])]


# ---------------------------------------------------------------- fenêtres et messages

## Fenêtre de dialogue au-dessus de l'écran. buttons = [{"text": "...", "callback": Callable, "variant": "PrimaryButton"}]
static func show_dialog(host: Control, title: String, message: String, buttons: Array, extra: Control = null, vertical: bool = false) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var p := panel(22)
	p.custom_minimum_size = Vector2(560, 0)
	center.add_child(p)
	var body := panel_body(p)
	body.add_child(label(title, 28, C_YELLOW))
	if message != "":
		body.add_child(wrapped_label(message, 21, C_TEXT))
	if extra != null:
		body.add_child(extra)
	var row: BoxContainer = vbox(10) if vertical else hbox(12)
	body.add_child(row)
	for spec in buttons:
		var cb: Callable = spec.get("callback", Callable())
		var on_press := func() -> void:
			overlay.queue_free()
			if cb.is_valid():
				cb.call()
		var b := button(str(spec.get("text", "OK")), on_press, str(spec.get("variant", "")))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	host.add_child(overlay)
	return overlay


## Message court en bas de l'écran (vert = succès, rouge = erreur).
static func toast(host: Control, text: String, good: bool = true) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _flat(C_GREEN.darkened(0.35) if good else C_RED.darkened(0.2), 14))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, 22, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	p.add_child(l)
	host.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 30)
	var tw := host.create_tween()
	tw.tween_interval(2.6)
	tw.tween_callback(p.queue_free)
