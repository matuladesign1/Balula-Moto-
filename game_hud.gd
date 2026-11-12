class_name GameHud
extends Control
## Affichage pendant la conduite : vitesse, carburant, état, argent, mini-carte, lieu proche,
## boutons tactiles (tourner, accélérer, freiner), pause, essai.

signal pause_pressed
signal zone_button_pressed(zone_id: String)
signal end_trial_pressed

const ZONE_TEXT := {"garage": "Entrer à l'atelier (Garage)", "shop": "Entrer au magasin de véhicules"}
const FUEL_COLORS := [Color("#2ecc71"), Color("#f39c12"), Color("#ce1126")]

var vehicle: VehicleController
var map = null
var trial := false

var _speed_label: Label
var _fuel_bar: ProgressBar
var _fuel_label: Label
var _cond_bar: ProgressBar
var _money_label: Label
var _place_label: Label
var _pass_button: Button
var _zone_button: Button
var _fps_label: Label
var _minimap: Minimap
var _pads: Array[TouchPad] = []
var _zone_id := ""
var _fuel_band := -1
var _place_timer := 0.0


func setup(p_vehicle: VehicleController, p_map: Object, p_trial: bool) -> void:
	vehicle = p_vehicle
	map = p_map
	trial = p_trial


func _ready() -> void:
	theme = UiKit.get_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(rows)
	rows.add_child(_build_top())
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(spacer)
	rows.add_child(_build_bottom())
	GameState.money_changed.connect(_on_money_changed)
	_update_passenger_text()
	_update_place()


# ---------------------------------------------------------------- construction

func _ign(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _hud_label(text: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := UiKit.label(text, size, color, align)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _build_top() -> Control:
	var top := HBoxContainer.new()
	_ign(top)
	# gauche : mini-carte, lieu proche, passagers
	var left := UiKit.vbox(6)
	_ign(left)
	top.add_child(left)
	_minimap = Minimap.new()
	_minimap.custom_minimum_size = Vector2(190, 190)
	_minimap.map = map
	_minimap.target = vehicle
	if map != null and map.get("minimap_scale") != null:
		_minimap.pixels_per_meter = float(map.get("minimap_scale"))
	left.add_child(_minimap)
	_place_label = _hud_label("", 18, UiKit.C_YELLOW)
	_place_label.custom_minimum_size = Vector2(190, 0)
	_place_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_place_label)
	_pass_button = UiKit.button("", _on_passengers_pressed, "", Vector2(190, 44))
	_pass_button.add_theme_font_size_override("font_size", 17)
	left.add_child(_pass_button)
	# centre : bandeau d'essai et bouton de zone
	var center := UiKit.vbox(8)
	_ign(center)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(center)
	if trial:
		var banner := UiKit.panel(8)
		banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var bb := UiKit.panel_body(banner)
		bb.add_child(UiKit.label("MODE ESSAI : rien n'est acheté", 22, UiKit.C_YELLOW, HORIZONTAL_ALIGNMENT_CENTER))
		bb.add_child(UiKit.button("Terminer l'essai", _on_end_trial_pressed, "PrimaryButton", Vector2(280, 48)))
		center.add_child(banner)
	_zone_button = UiKit.button("", _on_zone_pressed, "PrimaryButton", Vector2(380, 56))
	_zone_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_zone_button.visible = false
	center.add_child(_zone_button)
	# droite : argent, pause, images par seconde
	var right := UiKit.vbox(6)
	_ign(right)
	top.add_child(right)
	_money_label = _hud_label(Balance.cdf(GameState.money()), 26, UiKit.C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(_money_label)
	right.add_child(UiKit.button("Pause", _on_pause_pressed, "", Vector2(150, 52)))
	_fps_label = _hud_label("", 16, UiKit.C_MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_fps_label.visible = bool(GameState.settings.get("show_fps", false))
	right.add_child(_fps_label)
	return top


func _build_bottom() -> Control:
	var bottom := HBoxContainer.new()
	_ign(bottom)
	var touch := bool(GameState.settings.get("touch_controls", true))
	var steer := UiKit.hbox(14)
	_ign(steer)
	steer.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(steer)
	if touch:
		steer.add_child(_make_pad("steer_left", "<", Vector2(130, 130), Color(1, 1, 1, 0.2)))
		steer.add_child(_make_pad("steer_right", ">", Vector2(130, 130), Color(1, 1, 1, 0.2)))
	# centre : vitesse et jauges
	var mid := UiKit.vbox(4)
	_ign(mid)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(mid)
	_speed_label = _hud_label("0", 56, UiKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	mid.add_child(_speed_label)
	mid.add_child(_hud_label("km/h", 18, UiKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_fuel_label = _hud_label("Carburant", 17, UiKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	mid.add_child(_fuel_label)
	_fuel_bar = UiKit.bar(1.0, UiKit.C_GREEN)
	_ign(_fuel_bar)
	_fuel_bar.custom_minimum_size = Vector2(220, 16)
	mid.add_child(_fuel_bar)
	mid.add_child(_hud_label("État du véhicule", 17, UiKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	_cond_bar = UiKit.bar(1.0, UiKit.C_BLUE)
	_ign(_cond_bar)
	_cond_bar.custom_minimum_size = Vector2(220, 16)
	mid.add_child(_cond_bar)
	# droite : frein et accélérateur
	var pedals := UiKit.hbox(14)
	_ign(pedals)
	pedals.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(pedals)
	if touch:
		pedals.add_child(_make_pad("brake", "FREIN", Vector2(120, 120), Color(0.81, 0.07, 0.15, 0.35)))
		pedals.add_child(_make_pad("accelerate", "GAZ", Vector2(160, 160), Color(0.18, 0.8, 0.44, 0.35)))
	return bottom


func _make_pad(action: String, caption: String, size_px: Vector2, color: Color) -> TouchPad:
	var pad := TouchPad.new()
	pad.setup(action, caption, size_px, color)
	pad.size_flags_vertical = Control.SIZE_SHRINK_END
	_pads.append(pad)
	return pad


# ---------------------------------------------------------------- mise à jour

func _process(delta: float) -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		return
	_speed_label.text = str(int(round(vehicle.speed_kmh())))
	var fr := vehicle.fuel_ratio()
	_fuel_bar.value = fr
	var band := 0
	if fr <= 0.1:
		band = 2
	elif fr <= 0.25:
		band = 1
	if band != _fuel_band:
		_fuel_band = band
		_set_fill(_fuel_bar, FUEL_COLORS[band])
	_fuel_label.text = "Carburant : %.1f / %.0f L" % [vehicle.fuel_l, vehicle.fuel_cap]
	_cond_bar.value = vehicle.current_condition() / 100.0
	if _fps_label.visible:
		_fps_label.text = "%d i/s" % Engine.get_frames_per_second()
	_place_timer += delta
	if _place_timer >= 0.5:
		_place_timer = 0.0
		_update_place()


func _set_fill(bar: ProgressBar, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", sb)


func _update_place() -> void:
	if map == null or vehicle == null:
		return
	var lms: Variant = map.get("landmarks")
	if not (lms is Array):
		return
	var p := Vector2(vehicle.global_position.x, vehicle.global_position.z)
	var best := ""
	var best_d := 90.0
	for lm in lms:
		var lp: Vector2 = lm["pos"]
		var d := p.distance_to(lp)
		if d < best_d:
			best_d = d
			best = str(lm["label"])
	_place_label.text = ("Près de : " + best) if best != "" else ""


func _update_passenger_text() -> void:
	if vehicle == null or vehicle.model == null:
		return
	_pass_button.text = "Passagers (test) : %d/%d" % [vehicle.passengers, vehicle.max_passengers()]


func _on_money_changed(amount: int) -> void:
	_money_label.text = Balance.cdf(amount)


func _on_passengers_pressed() -> void:
	var n := vehicle.passengers + 1
	if n > vehicle.max_passengers():
		n = 0
	vehicle.set_passengers(n)
	_update_passenger_text()


func _on_pause_pressed() -> void:
	pause_pressed.emit()


func _on_end_trial_pressed() -> void:
	end_trial_pressed.emit()


func _on_zone_pressed() -> void:
	zone_button_pressed.emit(_zone_id)


# ---------------------------------------------------------------- appelé par la scène de jeu

func show_zone(zone_id: String) -> void:
	_zone_id = zone_id
	_zone_button.text = str(ZONE_TEXT.get(zone_id, "Entrer"))
	_zone_button.visible = true


func hide_zone(zone_id: String) -> void:
	if zone_id == _zone_id:
		_zone_button.visible = false
		_zone_id = ""


func release_all() -> void:
	for pad in _pads:
		pad.release_all()


func toast(text: String, good: bool = true) -> void:
	UiKit.toast(self, text, good)
