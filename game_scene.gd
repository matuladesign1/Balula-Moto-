extends Node3D
## Scène de jeu : construit la carte, le véhicule, la caméra, la circulation et l'affichage.
## Choix de la carte : réglage "map" des paramètres ("test" ou "kinshasa").
## Cette scène reste active pendant la pause (pour entendre la touche Échap) ; le monde 3D et
## l'affichage, eux, s'arrêtent grâce à leur mode "pausable".

var _map: Node3D
var _vehicle: VehicleController
var _cam: FollowCamera
var _hud: GameHud
var _hud_layer: CanvasLayer
var _pause_layer: CanvasLayer
var _pause_host: Control = null
var _trial := false
var _pause_open := false
var _leaving := false
var _last_crash_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.apply_settings()
	var inst: Dictionary
	_trial = GameState.trial_model_id != ""
	if _trial:
		inst = GameState.make_trial_instance(GameState.trial_model_id)
	else:
		inst = GameState.active_instance()
	var def := Catalog.get_vehicle(str(inst.get("model_id", "")))
	if def.is_empty():
		push_error("Aucun véhicule à conduire : retour au menu.")
		GameState.go_home()
		return

	var world := Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)

	# Version minimale jouable : seule la carte de test est disponible pour l'instant.
	_map = TestMap.new()
	_map.name = "Map"
	world.add_child(_map)

	_vehicle = VehicleController.new()
	_vehicle.setup(def, inst, _trial)
	world.add_child(_vehicle)
	var start: Transform3D = _map.call("spawn_transform")
	_vehicle.place_at(start)
	_vehicle.crashed.connect(_on_crashed)
	_vehicle.out_of_fuel.connect(_on_out_of_fuel)

	_cam = FollowCamera.new()
	_cam.target = _vehicle
	world.add_child(_cam)

	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	_hud_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_hud_layer)
	_hud = GameHud.new()
	_hud.setup(_vehicle, _map, _trial)
	_hud_layer.add_child(_hud)
	_hud.pause_pressed.connect(_toggle_pause)
	_hud.zone_button_pressed.connect(_on_zone_button)
	_hud.end_trial_pressed.connect(_end_trial)

	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 20
	add_child(_pause_layer)

	_map.connect("zone_entered", _on_zone_entered)
	_map.connect("zone_exited", _on_zone_exited)
	GameState.back_requested.connect(_on_back_requested)


func _exit_tree() -> void:
	if GameState.back_requested.is_connected(_on_back_requested):
		GameState.back_requested.disconnect(_on_back_requested)
	Input.action_release("accelerate")
	Input.action_release("brake")
	Input.action_release("steer_left")
	Input.action_release("steer_right")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_open_pause()


# ---------------------------------------------------------------- pause

func _toggle_pause() -> void:
	if _pause_open:
		_resume()
	else:
		_open_pause()


func _on_back_requested() -> void:
	_toggle_pause()


func _open_pause() -> void:
	if _pause_open or _leaving or _vehicle == null:
		return
	_pause_open = true
	_hud.release_all()
	_vehicle.sync_to_state()
	get_tree().paused = true
	_pause_host = Control.new()
	_pause_host.theme = UiKit.get_theme()
	_pause_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(_pause_host)
	var buttons: Array = [{"text": "Reprendre", "callback": _resume, "variant": "PrimaryButton"}]
	if _trial:
		buttons.append({"text": "Terminer l'essai", "callback": _end_trial})
	else:
		buttons.append({"text": "Garage", "callback": _go_garage})
		buttons.append({"text": "Magasin de véhicules", "callback": _go_shop})
		buttons.append({"text": "Menu principal", "callback": _go_menu})
	var hint := UiKit.wrapped_label("Clavier : flèches ou W A S D pour conduire, Espace pour freiner, Échap pour la pause.", 18)
	UiKit.show_dialog(_pause_host, "Pause", "", buttons, hint, true)


func _resume() -> void:
	if not _pause_open:
		return
	_pause_open = false
	get_tree().paused = false
	if _pause_host != null:
		_pause_host.queue_free()
		_pause_host = null


# ---------------------------------------------------------------- zones et navigation

func _on_zone_entered(zone_id: String) -> void:
	if not _trial:
		_hud.show_zone(zone_id)


func _on_zone_exited(zone_id: String) -> void:
	_hud.hide_zone(zone_id)


func _on_zone_button(zone_id: String) -> void:
	if zone_id == "garage":
		_go_garage()
	elif zone_id == "shop":
		_go_shop()


func _go_garage() -> void:
	_leave(GameState.SCENE_GARAGE)


func _go_shop() -> void:
	_leave(GameState.SCENE_SHOP)


func _go_menu() -> void:
	if _leaving:
		return
	_leaving = true
	_vehicle.sync_to_state()
	GameState.go_home()


func _end_trial() -> void:
	if _leaving:
		return
	_leaving = true
	GameState.end_trial()


func _leave(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	_vehicle.sync_to_state()
	GameState.navigate(path)


# ---------------------------------------------------------------- événements du véhicule

func _on_crashed(_impact: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_crash_ms > 1500:
		_last_crash_ms = now
		_hud.toast("Choc ! Le véhicule s'abîme.", false)


func _on_out_of_fuel() -> void:
	_hud.toast("Panne sèche ! Ouvre la pause et va au garage pour faire le plein.", false)
